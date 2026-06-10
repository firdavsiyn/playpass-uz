// Rahmat (АО «Multicard Payment») — create payment session.
//
// SCAFFOLD: the actual HTTP call to Rahmat is a best-guess shape. Replace
// the body of step 5 once you receive the technical documentation from
// rhmt.uz / your account manager. Everything else (auth, plan validation,
// payments row creation, idempotency) is production-ready.
//
// POST /functions/v1/rahmat-create-payment
// Headers: Authorization: Bearer <user-jwt>
// Body: { plan: 'basic' | 'standard' | 'pro' | 'vip' | 'daily' |
//                'standard_annual' | 'vip_annual' }
// Response: { payment_url: string, order_id: string }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// Set these in Edge Function secrets once Rahmat issues credentials.
const RAHMAT_API_URL = Deno.env.get('RAHMAT_API_URL') || '';
const RAHMAT_API_KEY = Deno.env.get('RAHMAT_API_KEY') || '';
const RAHMAT_MERCHANT_ID = Deno.env.get('RAHMAT_MERCHANT_ID') || '';
const RAHMAT_RETURN_URL =
  Deno.env.get('RAHMAT_RETURN_URL') ||
  'https://app.playpass.uz/payment-success';

const ALLOWED_PLANS = new Set([
  'basic',
  'standard',
  'pro',
  'vip',
  'daily',
  'standard_annual',
  'vip_annual',
]);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // ── 0. Reject early if Rahmat isn't configured (no creds yet) ──
    if (!RAHMAT_API_KEY || !RAHMAT_MERCHANT_ID || !RAHMAT_API_URL) {
      return json(
        {
          error: 'rahmat_not_configured',
          message: 'Платёжный шлюз Rahmat ещё не подключён',
        },
        503,
      );
    }

    // ── 1. Auth ───────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: 'Missing Authorization' }, 401);
    }
    const token = authHeader.replace('Bearer ', '');
    const userClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: userData, error: authErr } = await userClient.auth.getUser(
      token,
    );
    if (authErr || !userData.user) {
      return json({ error: 'Invalid token' }, 401);
    }
    const userId = userData.user.id;

    // ── 2. Parse + validate plan ──────────────────────────────
    const body = await req.json();
    const plan = body.plan as string;
    if (!ALLOWED_PLANS.has(plan)) {
      return json({ error: 'Invalid plan' }, 400);
    }

    // ── 3. Load price from DB (single source of truth) ────────
    // The client never sends amount — that would let an attacker pay 1 sum
    // for a VIP plan. Price comes only from the trusted subscription_plans
    // table that we control.
    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);
    const { data: planRow, error: planErr } = await admin
      .from('subscription_plans')
      .select('price_uzs')
      .eq('code', plan)
      .single();

    if (planErr || !planRow) {
      return json({ error: 'Plan not found' }, 404);
    }
    const amount = planRow.price_uzs as number;

    // ── 4. Create pending payment row ─────────────────────────
    const { data: payment, error: payErr } = await admin
      .from('payments')
      .insert({
        user_id: userId,
        plan,
        amount_uzs: amount,
        provider: 'rahmat',
        status: 'pending',
      })
      .select()
      .single();

    if (payErr) {
      return json(
        { error: 'Failed to create payment', details: payErr.message },
        500,
      );
    }

    // ── 5. Call Rahmat API to create payment session ──────────
    //
    // ⚠ TODO: this is a best-guess body. Replace with the exact format from
    // Rahmat technical docs (you get them after signing the merchant
    // agreement). Common UZ-acquirer differences:
    //   • Authorization header style (Bearer / Basic / custom)
    //   • Body shape (snake_case / camelCase, root keys)
    //   • Signature/HMAC of the body (HMAC-SHA256 / MD5)
    //   • amount field (sum vs tiyin × 100)
    //
    let rahmatResp: Response;
    try {
      rahmatResp = await fetch(`${RAHMAT_API_URL}/payment/create`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${RAHMAT_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          merchant_id: RAHMAT_MERCHANT_ID,
          order_id: payment.id,
          amount: amount,
          currency: 'UZS',
          return_url: RAHMAT_RETURN_URL,
          // We pass these so the webhook can identify our user & plan.
          metadata: { user_id: userId, plan },
        }),
      });
    } catch (e) {
      console.error('Rahmat network error:', e);
      await admin
        .from('payments')
        .update({ status: 'failed' })
        .eq('id', payment.id);
      return json({ error: 'Платёжный шлюз недоступен' }, 502);
    }

    if (!rahmatResp.ok) {
      const txt = await rahmatResp.text();
      console.error('Rahmat HTTP error:', rahmatResp.status, txt);
      await admin
        .from('payments')
        .update({ status: 'failed' })
        .eq('id', payment.id);
      return json(
        { error: 'Платёжный шлюз вернул ошибку', status: rahmatResp.status },
        502,
      );
    }

    const rahmatData = await rahmatResp.json();
    // Different acquirers return the URL under different keys; try the
    // common ones, fall through to error if none present.
    const paymentUrl =
      rahmatData.payment_url ||
      rahmatData.checkout_url ||
      rahmatData.url ||
      rahmatData.data?.payment_url ||
      rahmatData.data?.url;

    if (!paymentUrl) {
      console.error('Rahmat returned no payment_url:', rahmatData);
      await admin
        .from('payments')
        .update({ status: 'failed' })
        .eq('id', payment.id);
      return json({ error: 'Некорректный ответ платёжного шлюза' }, 502);
    }

    return json({
      payment_url: paymentUrl,
      order_id: payment.id,
    });
  } catch (e) {
    console.error('rahmat-create-payment error:', e);
    return json(
      { error: e instanceof Error ? e.message : 'Unknown error' },
      500,
    );
  }
});

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
