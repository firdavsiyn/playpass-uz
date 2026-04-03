// ============================================================
// GamePass UZ — Edge Function: payout-calc
// POST /functions/v1/payout-calc
// Called by n8n on 1st of month to calculate club payouts
// Auth: Service role only
// ============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RAHMAT_API_URL = Deno.env.get("RAHMAT_API_URL")!;
const RAHMAT_API_KEY = Deno.env.get("RAHMAT_API_KEY")!;
const RATE_PER_VISIT_UZS = 8000;

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Only callable with service role key (from n8n)
  const authKey = req.headers.get("Authorization")?.replace("Bearer ", "");
  if (authKey !== SUPABASE_SERVICE_KEY) {
    return new Response("Forbidden", { status: 403 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  // Calculate period: previous month
  const now = new Date();
  const periodStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const periodEnd = new Date(now.getFullYear(), now.getMonth(), 0); // last day of prev month
  const periodMonth = periodStart.toISOString().split("T")[0]; // e.g. "2025-02-01"

  console.log(`Calculating payouts for period: ${periodMonth}`);

  try {
    // ── 1. Aggregate visits per club for the period ───────────
    const { data: visitStats, error: statsError } = await supabase
      .from("visits")
      .select("club_id, count:id")
      .gte("created_at", periodStart.toISOString())
      .lte("created_at", periodEnd.toISOString() + "T23:59:59Z");

    if (statsError) {
      console.error("Stats query error:", statsError);
      return new Response("DB Error", { status: 500 });
    }

    // Group by club_id
    const clubVisits: Record<string, number> = {};
    for (const row of visitStats ?? []) {
      const clubId = row.club_id as string;
      clubVisits[clubId] = (clubVisits[clubId] ?? 0) + 1;
    }

    // ── 2. Get active clubs with payout details ───────────────
    const { data: clubs } = await supabase
      .from("clubs")
      .select("id, name, payout_details")
      .eq("status", "active");

    const payoutRows = [];
    const rahmatPayouts = [];

    for (const club of clubs ?? []) {
      const visitCount = clubVisits[club.id] ?? 0;
      if (visitCount === 0) continue;

      const amountUzs = visitCount * RATE_PER_VISIT_UZS;

      payoutRows.push({
        club_id: club.id,
        period_month: periodMonth,
        visit_count: visitCount,
        amount_uzs: amountUzs,
        status: "processing",
      });

      rahmatPayouts.push({
        club_name: club.name,
        amount: amountUzs,
        payout_details: club.payout_details,
      });
    }

    // ── 3. Insert payout records ──────────────────────────────
    const { data: insertedPayouts, error: insertError } = await supabase
      .from("payouts")
      .upsert(payoutRows, { onConflict: "club_id,period_month" })
      .select();

    if (insertError) {
      console.error("Payout insert error:", insertError);
      return new Response("DB Error", { status: 500 });
    }

    // ── 4. Trigger Rahmat.uz batch payout ─────────────────────
    if (rahmatPayouts.length > 0) {
      const rahmatResponse = await fetch(`${RAHMAT_API_URL}/batch-payout`, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${RAHMAT_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          batch_id: `gamepass_${periodMonth}`,
          payouts: rahmatPayouts.map((p) => ({
            amount: p.amount,
            card_number: p.payout_details?.card_number,
            account_number: p.payout_details?.account_number,
            description: `GamePass UZ выплата за ${periodMonth}`,
          })),
        }),
      });

      const rahmatResult = await rahmatResponse.json();

      // Update payout records with batch ID
      if (rahmatResult.batch_id) {
        await supabase
          .from("payouts")
          .update({ rahmat_batch_id: rahmatResult.batch_id, status: "processing" })
          .eq("period_month", periodMonth);
      }
    }

    console.log(`Payouts created: ${payoutRows.length} clubs, total visits: ${
      Object.values(clubVisits).reduce((a, b) => a + b, 0)
    }`);

    return new Response(
      JSON.stringify({
        success: true,
        period: periodMonth,
        clubs_paid: payoutRows.length,
        total_visits: Object.values(clubVisits).reduce((a, b) => a + b, 0),
        total_amount_uzs: payoutRows.reduce((s, p) => s + p.amount_uzs, 0),
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("Payout calc error:", err);
    return new Response("Internal Server Error", { status: 500 });
  }
});
