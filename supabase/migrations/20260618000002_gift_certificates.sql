-- ════════════════════════════════════════════════════════════════════════
-- Audit 2026-06-18 — LAUNCH BLOCKER #4 (secure foundation)
-- The gift flow had NO table, NO RLS, took NO money, and granted NOTHING:
-- creation minted free certs with a client-chosen plan/amount; redemption
-- only flipped a status and provisioned no subscription; everything was a
-- client-side write. This migration lays the SECURE storage + redemption.
--
-- The gift UI is gated OFF in the app (FeatureFlags.gifts=false) until gift
-- CREATION is wired to the payment flow (a cert must only become 'paid' via a
-- verified payment webhook — never from the client). Until then, certs can be
-- created only by service_role (webhook/admin); redemption below is atomic and
-- server-authorized.
-- ════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.gift_certificates (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code            text UNIQUE NOT NULL,
  plan            text NOT NULL,
  amount_uzs      int  NOT NULL,
  purchaser_id    uuid REFERENCES public.users(id) ON DELETE SET NULL,
  recipient_name  text,
  recipient_phone text,
  payment_id      uuid,
  status          text NOT NULL DEFAULT 'pending_payment'
                    CHECK (status IN ('pending_payment','paid','redeemed','cancelled')),
  redeemed_by     uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  paid_at         timestamptz,
  redeemed_at     timestamptz
);

CREATE INDEX IF NOT EXISTS idx_gift_certificates_code ON public.gift_certificates(code);

ALTER TABLE public.gift_certificates ENABLE ROW LEVEL SECURITY;

-- Users may read only certs they purchased or redeemed. No client INSERT/
-- UPDATE/DELETE: all writes go through the redeem RPC (definer) or the
-- service_role (payment webhook / admin). No bare code-lookup SELECT — that
-- would let anyone enumerate/scrape codes.
DROP POLICY IF EXISTS gift_certificates_select_own ON public.gift_certificates;
CREATE POLICY gift_certificates_select_own ON public.gift_certificates
  FOR SELECT TO authenticated
  USING (purchaser_id = auth.uid() OR redeemed_by = auth.uid());

-- ── Atomic redemption ────────────────────────────────────────────────────
-- Claims a PAID cert (CAS, single-row UPDATE) and provisions the subscription
-- in one transaction. Idempotent against double-spend: the CAS only succeeds
-- while status='paid', so a second caller (or the same code twice) gets a
-- clear error instead of a second subscription.
CREATE OR REPLACE FUNCTION public.redeem_gift_certificate(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid       uuid := auth.uid();
  v_cert      public.gift_certificates%ROWTYPE;
  v_visits    int;
  v_end       date;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  -- Atomic claim: only one caller can flip paid → redeemed.
  UPDATE public.gift_certificates
     SET status      = 'redeemed',
         redeemed_by = v_uid,
         redeemed_at = now()
   WHERE code = p_code
     AND status = 'paid'
  RETURNING * INTO v_cert;

  IF NOT FOUND THEN
    -- Distinguish the failure for a useful client message.
    SELECT * INTO v_cert FROM public.gift_certificates WHERE code = p_code;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'error', 'not_found');
    ELSIF v_cert.status = 'redeemed' THEN
      RETURN jsonb_build_object('ok', false, 'error', 'already_redeemed');
    ELSE
      RETURN jsonb_build_object('ok', false, 'error', 'not_paid');
    END IF;
  END IF;

  -- Provision the subscription (BM v1.3 visit mapping; never unlimited).
  v_visits := CASE v_cert.plan
                WHEN 'daily'   THEN 4
                WHEN 'day'     THEN 12
                WHEN 'anytime' THEN 12
                ELSE NULL
              END;
  IF v_visits IS NULL THEN
    RAISE EXCEPTION 'gift cert % has non-purchasable plan %', p_code, v_cert.plan;
  END IF;
  v_end := CURRENT_DATE + INTERVAL '30 days';

  INSERT INTO public.subscriptions
    (user_id, plan, start_date, end_date, hours_balance, status, price_uzs)
  VALUES
    (v_uid, v_cert.plan, CURRENT_DATE, v_end, v_visits, 'active', v_cert.amount_uzs);

  RETURN jsonb_build_object('ok', true, 'plan', v_cert.plan, 'visits', v_visits);
END;
$$;

REVOKE ALL ON FUNCTION public.redeem_gift_certificate(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.redeem_gift_certificate(text) TO authenticated;

NOTIFY pgrst, 'reload schema';
