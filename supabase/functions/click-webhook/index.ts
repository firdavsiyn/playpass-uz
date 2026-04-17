// Click.uz — payment webhook handler (prepare + complete)
//
// Click sends two sequential requests to this endpoint:
//   1. Prepare (action=0) — confirm order exists & is valid
//   2. Complete (action=1) — money received, activate subscription
//
// Docs: https://docs.click.uz/click-api/
//
// Expected parameters (POST x-www-form-urlencoded):
//   click_trans_id, service_id, click_paydoc_id, merchant_trans_id (= our payments.id),
//   amount, action (0|1), sign_time, sign_string (md5 hash), error, error_note

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { crypto as stdCrypto } from 'https://deno.land/std@0.224.0/crypto/mod.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const CLICK_SECRET_KEY = Deno.env.get('CLICK_SECRET_KEY') || '';
const CLICK_SERVICE_ID = Deno.env.get('CLICK_SERVICE_ID') || '';

Deno.serve(async (req) => {
  try {
    const params = await parseBody(req);
    const action = Number(params.get('action') || '-1');

    // 1. Verify signature
    const expectedSign = await buildSign(params);
    const receivedSign = params.get('sign_string') || '';
    if (expectedSign !== receivedSign) {
      return clickError(-1, 'Signature check failed');
    }

    const orderId = params.get('merchant_trans_id') || '';
    const amount = Number(params.get('amount') || '0');
    const clickTransId = params.get('click_trans_id') || '';

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

    // 2. Fetch our payment record
    const { data: payment, error: payErr } = await admin
      .from('payments')
      .select('*')
      .eq('id', orderId)
      .single();

    if (payErr || !payment) {
      return clickError(-5, 'Order not found');
    }

    // 3. Amount check
    if (payment.amount_uzs !== amount) {
      return clickError(-2, 'Amount mismatch');
    }

    if (action === 0) {
      // Prepare: just confirm order is valid and pending
      if (payment.status !== 'pending') {
        return clickError(-4, 'Order already processed');
      }
      return clickOk({
        click_trans_id: clickTransId,
        merchant_trans_id: orderId,
        merchant_prepare_id: payment.id,
      });
    }

    if (action === 1) {
      // Complete: mark paid, activate subscription
      if (payment.status === 'completed') {
        return clickOk({
          click_trans_id: clickTransId,
          merchant_trans_id: orderId,
          merchant_confirm_id: payment.id,
        });
      }

      // Update payment
      await admin
        .from('payments')
        .update({
          status: 'completed',
          provider_transaction_id: clickTransId,
          completed_at: new Date().toISOString(),
        })
        .eq('id', orderId);

      // Activate subscription: call a DB function that handles activation atomically
      const { error: activateErr } = await admin.rpc('activate_subscription_from_payment', {
        payment_id: orderId,
      });

      if (activateErr) {
        console.error('Activation failed:', activateErr);
        // Payment is marked completed but activation failed — needs manual review
        return clickError(-9, 'Activation failed: ' + activateErr.message);
      }

      return clickOk({
        click_trans_id: clickTransId,
        merchant_trans_id: orderId,
        merchant_confirm_id: payment.id,
      });
    }

    return clickError(-3, 'Unknown action');
  } catch (e) {
    console.error('click-webhook error:', e);
    return clickError(-9, e instanceof Error ? e.message : 'Unknown error');
  }
});

async function parseBody(req: Request): Promise<URLSearchParams> {
  const contentType = req.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    const json = await req.json();
    const p = new URLSearchParams();
    for (const [k, v] of Object.entries(json)) p.set(k, String(v));
    return p;
  }
  const text = await req.text();
  return new URLSearchParams(text);
}

async function buildSign(params: URLSearchParams): Promise<string> {
  const action = params.get('action') || '';
  const formula = [
    params.get('click_trans_id') || '',
    params.get('service_id') || '',
    CLICK_SECRET_KEY,
    params.get('merchant_trans_id') || '',
    action === '1' ? (params.get('merchant_prepare_id') || '') : '',
    params.get('amount') || '',
    action,
    params.get('sign_time') || '',
  ].join('');

  const encoder = new TextEncoder();
  const hashBuf = await stdCrypto.subtle.digest('MD5', encoder.encode(formula));
  return Array.from(new Uint8Array(hashBuf))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function clickOk(extra: Record<string, string | number> = {}): Response {
  return new Response(JSON.stringify({ error: 0, error_note: 'Success', ...extra }), {
    headers: { 'Content-Type': 'application/json' },
  });
}

function clickError(code: number, note: string): Response {
  return new Response(JSON.stringify({ error: code, error_note: note }), {
    headers: { 'Content-Type': 'application/json' },
  });
}
