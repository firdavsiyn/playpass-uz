// ============================================================
// GamePass UZ — Edge Function: checkin
// POST /functions/v1/checkin
// Body: { club_id, timestamp, geo_lat, geo_lon, qr_token }
// Auth: Bearer JWT (Supabase user)
// ============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RATE_PER_VISIT_UZS = 8000; // fixed payout per visit to club

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── 1. Auth: extract user from JWT ────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing authorization" }, 401);
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", "")
    );
    if (authError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    // ── 2. Parse body ─────────────────────────────────────────
    const { club_id, geo_lat, geo_lon, qr_token } = await req.json();
    if (!club_id || !qr_token) {
      return json({ error: "club_id and qr_token are required" }, 400);
    }

    // ── 3. Load club ──────────────────────────────────────────
    const { data: club, error: clubError } = await supabase
      .from("clubs")
      .select("id, name, lat, lon, qr_token, status, tier")
      .eq("id", club_id)
      .single();

    if (clubError || !club) {
      return json({ error: "Club not found" }, 404);
    }
    if (club.status !== "active") {
      return json({ error: "Клуб временно недоступен" }, 403);
    }

    // ── 4. Validate QR HMAC ───────────────────────────────────
    const { data: dailySecret } = await supabase
      .from("daily_secrets")
      .select("secret")
      .eq("valid_date", new Date().toISOString().split("T")[0])
      .single();

    if (!dailySecret) {
      return json({ error: "QR validation service unavailable" }, 503);
    }

    const expectedToken = await hmacSha256(club_id, dailySecret.secret);
    if (qr_token !== expectedToken) {
      return json({ error: "Недействительный QR-код" }, 403);
    }

    // ── 5. Check active subscription ─────────────────────────
    const { data: subscription } = await supabase
      .from("subscriptions")
      .select("*")
      .eq("user_id", user.id)
      .eq("status", "active")
      .gte("end_date", new Date().toISOString().split("T")[0])
      .order("created_at", { ascending: false })
      .limit(1)
      .single();

    if (!subscription) {
      return json({ error: "Нет активной подписки. Купите тариф в приложении." }, 403);
    }

    // ── 6. Check hours balance ────────────────────────────────
    // Both old ('unlimited') and new ('vip') unlimited plan codes pass,
    // plus the new hours_balance = -1 sentinel.
    const planIsInfinite = subscription.plan === "unlimited"
      || subscription.plan === "vip"
      || subscription.plan === "vip_annual"
      || subscription.hours_balance === -1;

    if (!planIsInfinite) {
      if (!subscription.hours_balance || subscription.hours_balance <= 0) {
        return json({ error: "Закончились часы. Купите новую подписку или обновите тариф." }, 403);
      }
    }

    // ── 6b. Off-peak gate for the Day tariff ──────────────────
    // Plan 'day' only works 08:00–18:00 (local Tashkent = UTC+5).
    if (subscription.plan === "day") {
      const tashkentHour = (new Date().getUTCHours() + 5) % 24;
      if (tashkentHour < 8 || tashkentHour >= 18) {
        return json({
          error: "Дневной тариф действует с 08:00 до 18:00. Для вечера нужен тариф Anytime.",
        }, 403);
      }
    }

    // ── 7. Tier access ────────────────────────────────────────
    // VIP-tier clubs require VIP-tier plan.
    if (club.tier === "vip" && !planIsInfinite) {
      return json({ error: "VIP-зона доступна только на тарифе VIP." }, 403);
    }
    if (club.tier === "standard" && (subscription.plan === "start" || subscription.plan === "basic")) {
      return json({ error: "Этот клуб доступен с тарифа Стандарт и выше." }, 403);
    }

    // ── 8. Cooldown: no visit in same club in last 30 min ─────
    const thirtyMinAgo = new Date(Date.now() - 30 * 60 * 1000).toISOString();
    const { data: recentVisit } = await supabase
      .from("visits")
      .select("id")
      .eq("user_id", user.id)
      .eq("club_id", club_id)
      .gte("created_at", thirtyMinAgo)
      .limit(1)
      .single();

    if (recentVisit) {
      return json({ error: "Повторный чекин в том же клубе доступен через 30 минут." }, 429);
    }

    // ── 9. Daily limit: max 8 checkins per day ────────────────
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const { count: todayCheckins } = await supabase
      .from("visits")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id)
      .gte("created_at", todayStart.toISOString());

    if ((todayCheckins ?? 0) >= 8) {
      return json({ error: "Достигнут дневной лимит: 8 чекинов в сутки." }, 429);
    }

    // ── 10. Geo validation (server-side, 300m radius) ─────────
    if (geo_lat && geo_lon && club.lat && club.lon) {
      const distMeters = haversineMeters(geo_lat, geo_lon, club.lat, club.lon);
      if (distMeters > 300) {
        return json({
          error: `Вы слишком далеко от клуба (${Math.round(distMeters)}м). Нужно быть в радиусе 300м.`
        }, 403);
      }
    }

    // ── 11. Create visit & decrement hours_balance atomically ─────
    //
    // SECURITY: previous code did `select hours_balance → insert visit
    // → update hours_balance - 1` which is racy: N concurrent checkin
    // requests could insert N visits but only decrement balance by 1.
    // We now do the decrement in a single conditional UPDATE that only
    // succeeds while balance > 0, then insert the visit only if the
    // decrement claimed the hour.
    //
    // 'unlimited' here is legacy; new infinite plans use
    // hours_balance = -1 sentinel which we treat as "skip decrement".
    const isUnlimited = subscription.plan === "unlimited"
      || subscription.plan === "vip"
      || subscription.hours_balance === -1;

    if (!isUnlimited) {
      const { data: claimed, error: claimErr } = await supabase
        .from("subscriptions")
        .update({ hours_balance: subscription.hours_balance - 1 })
        .eq("id", subscription.id)
        .eq("hours_balance", subscription.hours_balance) // CAS — only if value still matches
        .gt("hours_balance", 0)
        .select("id");

      if (claimErr) {
        console.error("Hours claim failed:", claimErr);
        return json({ error: "Не удалось списать час. Попробуйте снова." }, 500);
      }

      if (!claimed || claimed.length === 0) {
        // Another concurrent checkin won the race or balance dropped to 0.
        return json({ error: "Час уже списан другим устройством или баланс пуст." }, 409);
      }
    }

    const { data: visit, error: visitError } = await supabase
      .from("visits")
      .insert({
        user_id: user.id,
        club_id: club_id,
        subscription_id: subscription.id,
        hours_spent: 1,
        geo_lat,
        geo_lon,
      })
      .select()
      .single();

    if (visitError) {
      console.error("Visit insert error:", visitError);
      // Rollback the hour we just claimed (best-effort)
      if (!isUnlimited) {
        await supabase
          .from("subscriptions")
          .update({ hours_balance: subscription.hours_balance })
          .eq("id", subscription.id);
      }
      return json({ error: "Не удалось зафиксировать визит. Попробуйте снова." }, 500);
    }

    // ── 12. Return success response ───────────────────────────
    const remainingVisits = planIsInfinite
      ? null
      : subscription.hours_balance - 1;

    return json({
      success: true,
      message: `Добро пожаловать в ${club.name}!`,
      visit_id: visit.id,
      club_name: club.name,
      visits_remaining: remainingVisits,
      // legacy alias for older app builds still reading hours_*
      hours_remaining: remainingVisits,
      subscription_plan: subscription.plan,
    });

  } catch (err) {
    console.error("Checkin error:", err);
    return json({ error: "Внутренняя ошибка сервера" }, 500);
  }
});

// ── Helpers ───────────────────────────────────────────────────

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function hmacSha256(message: string, secret: string): Promise<string> {
  const encoder = new TextEncoder();
  const keyData = encoder.encode(secret);
  const msgData = encoder.encode(message);

  const key = await crypto.subtle.importKey(
    "raw", keyData,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", key, msgData);
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function haversineMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000; // Earth radius in meters
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
