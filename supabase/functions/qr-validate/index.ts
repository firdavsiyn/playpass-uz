// ============================================================
// GamePass UZ — Edge Function: qr-validate
// GET /functions/v1/qr-validate?club_id=xxx
// Returns current valid QR token for a club (for PDF generation)
// Auth: Service role or club admin JWT
// ============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Support both GET (?club_id=...) and POST (body: {club_id, regenerate})
    const url = new URL(req.url);
    let club_id = url.searchParams.get("club_id");
    let regenerate = url.searchParams.get("regenerate") === "true";

    if (req.method === "POST") {
      try {
        const body = await req.json();
        club_id = body.club_id ?? club_id;
        regenerate = body.regenerate === true || regenerate;
      } catch { /* no body is fine */ }
    }

    if (!club_id) {
      return json({ error: "club_id is required" }, 400);
    }

    // Auth check — must be club owner or superadmin
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Unauthorized" }, 401);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    const { data: { user }, error: authErr } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", "")
    );
    if (authErr || !user) return json({ error: "Unauthorized" }, 401);

    // Verify club access
    const { data: adminUser } = await supabase
      .from("admin_users")
      .select("role, club_id")
      .eq("id", user.id)
      .single();

    const isSuperadmin = adminUser?.role === "superadmin";
    const isClubOwner = adminUser?.club_id === club_id;

    if (!isSuperadmin && !isClubOwner) {
      return json({ error: "Access denied" }, 403);
    }

    // Get today's secret
    const today = new Date().toISOString().split("T")[0];
    const { data: dailySecret } = await supabase
      .from("daily_secrets")
      .select("secret")
      .eq("valid_date", today)
      .single();

    if (!dailySecret) {
      return json({ error: "Daily secret not yet generated. n8n runs at 00:00." }, 503);
    }

    // Generate (or regenerate) QR token for club
    const qrToken = await hmacSha256(club_id, dailySecret.secret);

    // Update club's qr_token
    if (regenerate) {
      await supabase
        .from("clubs")
        .update({ qr_token: qrToken })
        .eq("id", club_id);
    }

    // Get club info for QR data
    const { data: club } = await supabase
      .from("clubs")
      .select("name, address")
      .eq("id", club_id)
      .single();

    return json({
      club_id,
      club_name: club?.name,
      club_address: club?.address,
      qr_token: qrToken,
      valid_date: today,
      // QR content — encoded in the static poster as: gamepassuz://checkin?c=CLUB_ID&t=QR_TOKEN
      // The token changes daily but the poster stays the same (club_id is permanent)
      qr_payload: `gamepassuz://checkin?c=${club_id}&t=${qrToken}`,
    });

  } catch (err) {
    console.error("QR validate error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function hmacSha256(message: string, secret: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw", encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(message));
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
