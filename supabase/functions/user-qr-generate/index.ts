import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Get authenticated user
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userErr } = await supabase.auth.getUser();
    if (userErr || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check active subscription
    const today = new Date().toISOString().split("T")[0];
    const { data: sub } = await supabase
      .from("subscriptions")
      .select("id, plan, hours_balance, end_date")
      .eq("user_id", user.id)
      .eq("status", "active")
      .gte("end_date", today)
      .order("created_at", { ascending: false })
      .limit(1)
      .single();

    if (!sub) {
      return new Response(JSON.stringify({ error: "No active subscription" }), {
        status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Generate time-based token (5 min window)
    const now = Date.now();
    const timeWindow = Math.floor(now / (5 * 60 * 1000)); // 5-minute buckets
    const payload = `${user.id}:${timeWindow}:${sub.id}`;

    // Get today's secret from DB
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: secretRow } = await supabaseAdmin
      .from("daily_secrets")
      .select("secret")
      .eq("valid_date", today)
      .single();

    let secret = secretRow?.secret;
    if (!secret) {
      // Auto-generate if missing
      secret = crypto.randomUUID();
      await supabaseAdmin.from("daily_secrets").insert({ valid_date: today, secret });
    }

    // HMAC-SHA256 sign
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(secret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );
    const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload));
    const token = btoa(String.fromCharCode(...new Uint8Array(sig)))
      .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

    // QR data: gamepassuz://user-checkin?uid={userId}&t={timeWindow}&sig={token}
    const qrData = `gamepassuz://user-checkin?uid=${user.id}&t=${timeWindow}&sig=${token}`;

    // Compute expiry: end of current 5-min window
    const windowEndMs = (timeWindow + 1) * 5 * 60 * 1000;
    const expiresInSeconds = Math.floor((windowEndMs - now) / 1000);

    return new Response(JSON.stringify({
      qr_data: qrData,
      user_id: user.id,
      expires_in: expiresInSeconds,
      subscription: {
        plan: sub.plan,
        hours_balance: sub.hours_balance,
        end_date: sub.end_date,
      },
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
