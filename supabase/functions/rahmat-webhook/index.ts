// ============================================================
// GamePass UZ — Edge Function: rahmat-webhook
// POST /functions/v1/rahmat-webhook
// Called by Rahmat.uz upon successful payment
// ============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RAHMAT_WEBHOOK_SECRET = Deno.env.get("RAHMAT_WEBHOOK_SECRET")!;
const N8N_WEBHOOK_URL = Deno.env.get("N8N_WEBHOOK_URL")!;

// Plan definitions
const PLAN_CONFIG: Record<string, { hours: number | null; days: number; price: number }> = {
  start:    { hours: 10,   days: 30, price: 99000  },
  standard: { hours: 25,   days: 30, price: 199000 },
  unlimited:{ hours: null, days: 30, price: 349000 },
};

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const body = await req.text();
    const payload = JSON.parse(body);

    // ── 1. Verify Rahmat.uz webhook signature ─────────────────
    const signature = req.headers.get("X-Rahmat-Signature");
    if (!await verifySignature(body, signature, RAHMAT_WEBHOOK_SECRET)) {
      console.error("Invalid webhook signature");
      return new Response("Forbidden", { status: 403 });
    }

    // ── 2. Extract payment data ───────────────────────────────
    // Rahmat.uz webhook payload structure (adapt to actual API docs):
    // { order_id, status, amount, currency, metadata: { user_id, plan } }
    const { order_id, status, amount, metadata } = payload;

    if (status !== "paid") {
      // Acknowledge non-paid events without action
      return new Response(JSON.stringify({ received: true }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { user_id, plan } = metadata ?? {};
    if (!user_id || !plan || !PLAN_CONFIG[plan]) {
      console.error("Invalid metadata:", metadata);
      return new Response("Bad Request", { status: 400 });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // ── 3. Cancel any existing active subscription ────────────
    await supabase
      .from("subscriptions")
      .update({ status: "cancelled" })
      .eq("user_id", user_id)
      .eq("status", "active");

    // ── 4. Create new subscription ────────────────────────────
    const planCfg = PLAN_CONFIG[plan];
    const startDate = new Date();
    const endDate = new Date();
    endDate.setDate(endDate.getDate() + planCfg.days);

    const { data: subscription, error: subError } = await supabase
      .from("subscriptions")
      .insert({
        user_id,
        plan,
        start_date: startDate.toISOString().split("T")[0],
        end_date: endDate.toISOString().split("T")[0],
        hours_balance: planCfg.hours,
        status: "active",
        rahmat_order_id: order_id,
        price_uzs: amount ?? planCfg.price,
      })
      .select()
      .single();

    if (subError) {
      console.error("Subscription insert error:", subError);
      return new Response("Internal Server Error", { status: 500 });
    }

    // ── 5. Apply referral bonus if first subscription ─────────
    const { count: subCount } = await supabase
      .from("subscriptions")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user_id);

    if (subCount === 1) {
      await applyReferralBonus(supabase, user_id);
    }

    // ── 6. Trigger n8n for push + SMS notifications ───────────
    await fetch(N8N_WEBHOOK_URL + "/subscription-activated", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        user_id,
        plan,
        hours_balance: planCfg.hours,
        end_date: endDate.toISOString().split("T")[0],
        subscription_id: subscription.id,
      }),
    });

    return new Response(
      JSON.stringify({ success: true, subscription_id: subscription.id }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("Rahmat webhook error:", err);
    return new Response("Internal Server Error", { status: 500 });
  }
});

// ── Helpers ───────────────────────────────────────────────────

async function verifySignature(
  body: string,
  signature: string | null,
  secret: string
): Promise<boolean> {
  if (!signature) return false;
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw", encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(body));
  const expected = "sha256=" + Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return expected === signature;
}

async function applyReferralBonus(supabase: ReturnType<typeof createClient>, userId: string) {
  try {
    const { data: user } = await supabase
      .from("users")
      .select("referred_by")
      .eq("id", userId)
      .single();

    if (!user?.referred_by) return;

    // Insert bonus record
    const { error } = await supabase
      .from("referral_bonuses")
      .insert({
        inviter_id: user.referred_by,
        invitee_id: userId,
        bonus_hours: 3,
        applied: false,
      })
      .select()
      .single();

    if (error) {
      console.error("Referral bonus insert error:", error);
      return;
    }

    // Add +3 hours to both inviter and invitee subscriptions
    for (const uid of [user.referred_by, userId]) {
      const { data: sub } = await supabase
        .from("subscriptions")
        .select("id, hours_balance, plan")
        .eq("user_id", uid)
        .eq("status", "active")
        .single();

      if (sub && sub.plan !== "unlimited") {
        await supabase
          .from("subscriptions")
          .update({ hours_balance: (sub.hours_balance ?? 0) + 3 })
          .eq("id", sub.id);
      }
    }

    // Mark bonus as applied
    await supabase
      .from("referral_bonuses")
      .update({ applied: true })
      .eq("invitee_id", userId);

  } catch (err) {
    console.error("Referral bonus error:", err);
  }
}
