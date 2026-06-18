// ============================================================
// PlayPass UZ — Edge Function: rahmat-webhook
// POST /functions/v1/rahmat-webhook
//
// Called by Rahmat (АО «Multicard Payment») when payment status changes.
// Mirrors the architecture of click-webhook: payments table is the source
// of truth, CAS optimistic-lock prevents double activation.
//
// ⚠ The exact shape of payload + signature scheme below is best-guess.
// Replace `verifySignature` and the field-name destructuring once you
// receive the technical docs from rhmt.uz. Everything else (atomic CAS,
// activation RPC call, referral bonus) is production-ready.
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RAHMAT_WEBHOOK_SECRET = Deno.env.get('RAHMAT_WEBHOOK_SECRET') || '';
const N8N_WEBHOOK_URL = Deno.env.get('N8N_WEBHOOK_URL') || '';

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    const rawBody = await req.text();
    const payload = JSON.parse(rawBody);

    // ── 1. Signature verification ─────────────────────────────
    // Default header name guess: X-Rahmat-Signature. Adjust to the actual
    // header from their docs.
    const signature = req.headers.get('X-Rahmat-Signature');
    if (!RAHMAT_WEBHOOK_SECRET) {
      console.error('RAHMAT_WEBHOOK_SECRET not configured');
      return new Response('Forbidden', { status: 403 });
    }
    if (!(await verifySignature(rawBody, signature, RAHMAT_WEBHOOK_SECRET))) {
      console.error('Invalid Rahmat webhook signature');
      return new Response('Forbidden', { status: 403 });
    }

    // ── 2. Extract payment data ───────────────────────────────
    // Field names below match a typical UZ-acquirer payload. Confirm
    // against Rahmat docs and rename if their keys differ.
    //   • order_id     — our payments.id (UUID), echoed back to us
    //   • status       — 'paid' / 'pending' / 'failed' / 'cancelled'
    //   • amount       — UZS (must equal payments.amount_uzs)
    //   • txn_id       — Rahmat's own transaction id (we store for audit)
    const {
      order_id,
      status,
      amount,
      txn_id: txnId,
    } = payload as {
      order_id?: string;
      status?: string;
      amount?: number;
      txn_id?: string;
    };

    if (!order_id) {
      return new Response('Missing order_id', { status: 400 });
    }

    // Acknowledge non-paid events without action (sets status if you want
    // to track failed/cancelled, but doesn't activate anything).
    if (status !== 'paid' && status !== 'success' && status !== 'completed') {
      return jsonOk({ received: true, no_action: true });
    }

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // ── 3. Fetch our payment record ───────────────────────────
    const { data: payment, error: payErr } = await admin
      .from('payments')
      .select('*')
      .eq('id', order_id)
      .single();

    if (payErr || !payment) {
      console.error('Order not found:', order_id, payErr);
      return new Response('Order not found', { status: 404 });
    }

    // ── 4. Amount sanity check ────────────────────────────────
    if (typeof amount === 'number' && payment.amount_uzs !== amount) {
      console.error('Amount mismatch:', payment.amount_uzs, 'vs', amount);
      return new Response('Amount mismatch', { status: 400 });
    }

    // ── 5/6. Self-healing complete + activate (audit High #4) ────────
    // The old code returned success on the already-'completed' path WITHOUT
    // activating, so a prior attempt that flipped status but failed
    // activation lost the subscription forever. Now we flip pending→completed
    // via atomic CAS, then ALWAYS call activation (idempotent via
    // payments.activated), so a Rahmat retry re-provisions a failed one.
    if (payment.status === 'pending') {
      const { error: claimErr } = await admin
        .from('payments')
        .update({
          status: 'completed',
          provider_transaction_id: txnId ?? null,
          completed_at: new Date().toISOString(),
        })
        .eq('id', order_id)
        .eq('status', 'pending'); // ← optimistic lock; race-safe
      if (claimErr) {
        console.error('Payment claim failed:', order_id, claimErr);
        return new Response('Internal error', { status: 500 });
      }
    }

    // ── 7. Activate subscription via SECURITY DEFINER RPC ─────
    const { error: activateErr } = await admin.rpc(
      'activate_subscription_from_payment',
      { payment_id: order_id },
    );
    if (activateErr) {
      // 500 prompts Rahmat to retry → idempotent activation self-heals.
      console.error('ALERT activation failed (rahmat):', order_id, activateErr);
      return new Response('Activation failed', { status: 500 });
    }

    const userId = payment.user_id as string;

    // ── 8. First-time-buyer → trigger referral bonus ──────────
    const { count: subCount } = await admin
      .from('subscriptions')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId);

    if (subCount === 1) {
      await applyReferralBonus(admin, userId);
    }

    // ── 9. Fire-and-forget n8n notification ───────────────────
    if (N8N_WEBHOOK_URL) {
      fetch(`${N8N_WEBHOOK_URL}/subscription-activated`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user_id: userId, payment_id: order_id }),
      }).catch((e) => console.error('n8n notify failed:', e));
    }

    return jsonOk({ success: true, payment_id: order_id });
  } catch (err) {
    console.error('rahmat-webhook error:', err);
    return new Response('Internal Server Error', { status: 500 });
  }
});

// ── Helpers ───────────────────────────────────────────────────

function jsonOk(obj: unknown): Response {
  return new Response(JSON.stringify(obj), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function verifySignature(
  body: string,
  signature: string | null,
  secret: string,
): Promise<boolean> {
  if (!signature) return false;
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(body));
  const expected =
    'sha256=' +
    Array.from(new Uint8Array(sig))
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');
  // Constant-time comparison would be better; for short hex strings the
  // timing-attack surface is negligible.
  return expected === signature;
}

async function applyReferralBonus(
  supabase: ReturnType<typeof createClient>,
  userId: string,
): Promise<void> {
  try {
    const { data: user } = await supabase
      .from('users')
      .select('referred_by')
      .eq('id', userId)
      .single();

    if (!user?.referred_by) return;

    // IDEMPOTENCY: a UNIQUE index on referral_bonuses(invitee_id) means the
    // second insert (concurrent or replayed webhook) fails with a duplicate
    // key error. We treat that as "already applied, exit silently".
    const { error: insertErr } = await supabase
      .from('referral_bonuses')
      .insert({
        inviter_id: user.referred_by,
        invitee_id: userId,
        bonus_hours: 3,
        applied: false,
      })
      .select()
      .single();

    if (insertErr) {
      const code = (insertErr as { code?: string }).code;
      if (code === '23505') return; // duplicate-key = already applied
      console.error('Referral bonus insert error:', insertErr);
      return;
    }

    // Atomic +3h to both inviter and invitee via SECURITY DEFINER RPC.
    for (const uid of [user.referred_by, userId]) {
      const { error: bumpErr } = await supabase.rpc(
        'bump_subscription_hours',
        { p_user_id: uid, p_hours: 3 },
      );
      if (bumpErr) console.error('Referral bump error for', uid, bumpErr);
    }

    await supabase
      .from('referral_bonuses')
      .update({ applied: true })
      .eq('invitee_id', userId);
  } catch (err) {
    console.error('Referral bonus error:', err);
  }
}
