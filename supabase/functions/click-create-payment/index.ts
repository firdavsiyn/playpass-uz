// Click.uz — create payment session
// Creates a pending payment record and returns the Click payment URL.
//
// POST /functions/v1/click-create-payment
// Body: { plan: 'basic' | 'standard' | 'pro' | 'vip' }
// Headers: Authorization: Bearer <user-jwt>
// Response: { payment_url: string, order_id: string }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const CLICK_MERCHANT_ID = Deno.env.get('CLICK_MERCHANT_ID') || '';
const CLICK_SERVICE_ID = Deno.env.get('CLICK_SERVICE_ID') || '';
// Click payment URL template. Use sandbox for tests.
const CLICK_PAY_URL_BASE = Deno.env.get('CLICK_PAY_URL_BASE') || 'https://my.click.uz/services/pay';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Auth check via JWT
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: 'Missing Authorization' }, 401);
    }
    const token = authHeader.replace('Bearer ', '');
    const userClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: userData, error: authErr } = await userClient.auth.getUser(token);
    if (authErr || !userData.user) {
      return json({ error: 'Invalid token' }, 401);
    }
    const userId = userData.user.id;

    // 2. Parse plan
    const body = await req.json();
    const plan = body.plan as string;
    if (!['basic', 'standard', 'pro', 'vip'].includes(plan)) {
      return json({ error: 'Invalid plan' }, 400);
    }

    // 3. Load price from subscription_plans
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

    // 4. Insert pending payment
    const { data: payment, error: payErr } = await admin
      .from('payments')
      .insert({
        user_id: userId,
        plan,
        amount_uzs: amount,
        provider: 'click',
        status: 'pending',
      })
      .select()
      .single();

    if (payErr) {
      return json({ error: 'Failed to create payment', details: payErr.message }, 500);
    }

    // 5. Build Click payment URL
    // Format: https://my.click.uz/services/pay?service_id=X&merchant_id=Y&amount=Z&transaction_param=ORDER_ID&return_url=...
    const params = new URLSearchParams({
      service_id: CLICK_SERVICE_ID,
      merchant_id: CLICK_MERCHANT_ID,
      amount: amount.toString(),
      transaction_param: payment.id,
      return_url: 'https://app.playpass.uz/payment-success',
    });

    const paymentUrl = `${CLICK_PAY_URL_BASE}?${params.toString()}`;

    return json({
      payment_url: paymentUrl,
      order_id: payment.id,
    });
  } catch (e) {
    console.error('click-create-payment error:', e);
    return json({ error: e instanceof Error ? e.message : 'Unknown error' }, 500);
  }
});

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
