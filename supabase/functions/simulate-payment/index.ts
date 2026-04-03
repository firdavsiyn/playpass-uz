// ============================================================
// GamePass UZ — Payment Simulator (DEMO mode, no real money)
// POST /functions/v1/simulate-payment
// Body: { plan: 'start'|'standard'|'unlimited' }
// ============================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const PLAN_CONFIG: Record<string, { hours: number | null; priceUzs: number; name: string }> = {
  start:     { hours: 10,   priceUzs:  99000, name: 'Старт'    },
  standard:  { hours: 25,   priceUzs: 199000, name: 'Стандарт' },
  unlimited: { hours: null, priceUzs: 349000, name: 'Безлимит' },
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Auth — require valid JWT
    const authHeader = req.headers.get('authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Get user from JWT
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: userErr } = await userClient.auth.getUser();
    if (userErr || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json();
    const plan = body.plan as string;

    if (!PLAN_CONFIG[plan]) {
      return new Response(JSON.stringify({ error: `Unknown plan: ${plan}` }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const cfg = PLAN_CONFIG[plan];

    // Simulate 1-second "payment processing"
    await new Promise(r => setTimeout(r, 1000));

    // Deactivate any existing active subscription
    await supabase
      .from('subscriptions')
      .update({ status: 'expired' })
      .eq('user_id', user.id)
      .eq('status', 'active');

    // Activate new subscription (30 days from now)
    const now = new Date();
    const expiresAt = new Date(now);
    expiresAt.setDate(expiresAt.getDate() + 30);

    const { data: sub, error: subErr } = await supabase
      .from('subscriptions')
      .insert({
        user_id:        user.id,
        plan:           plan,
        status:         'active',
        hours_balance:  cfg.hours,
        start_date:     now.toISOString().split('T')[0],
        end_date:       expiresAt.toISOString().split('T')[0],
        rahmat_order_id: `DEMO-${Date.now()}`,
        price_uzs:      cfg.priceUzs,
      })
      .select()
      .single();

    if (subErr) throw subErr;

    // Update user level based on plan
    const levelMap: Record<string, string> = {
      start: 'Новичок', standard: 'Геймер', unlimited: 'Легенда',
    };
    await supabase
      .from('users')
      .update({ level: levelMap[plan] })
      .eq('id', user.id);

    return new Response(
      JSON.stringify({
        success: true,
        demo: true,
        message: `✅ DEMO: Подписка «${cfg.name}» активирована на 30 дней`,
        subscription: sub,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );

  } catch (err) {
    console.error('[simulate-payment]', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
