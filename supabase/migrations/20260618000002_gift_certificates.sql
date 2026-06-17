-- ════════════════════════════════════════════════════════════════════════
-- Audit 2026-06-18 — LAUNCH BLOCKER #4 (secure foundation)
-- The gift_certificates table already exists in the live DB (created outside
-- migrations) with columns: code, plan, amount_uzs, buyer_id, recipient_name,
-- recipient_email, recipient_phone, expires_at, status, redeemed_by,
-- redeemed_at. This migration secures it (RLS + atomic redeem RPC). The
-- CREATE TABLE IF NOT EXISTS is a no-op on the live DB and only matters for a
-- fresh setup; it uses the SAME column names the client/live schema use.
--
-- Gift UI stays OFF (FeatureFlags.gifts=false) until CREATION is wired to a
-- verified payment webhook (a cert must only become 'paid' server-side).
-- ════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.gift_certificates (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code            text UNIQUE NOT NULL,
  plan            text NOT NULL,
  amount_uzs      int  NOT NULL,
  buyer_id        uuid REFERENCES public.users(id) ON DELETE SET NULL,
  recipient_name  text,
  recipient_email text,
  recipient_phone text,
  expires_at      timestamptz,
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

-- Users may read only certs they bought or redeemed. No client INSERT/UPDATE/
-- DELETE: writes go through the redeem RPC (definer) or service_role (payment
-- webhook / admin). No bare code-lookup SELECT (prevents code enumeration).
DROP POLICY IF EXISTS gift_certificates_select_own ON public.gift_certificates;
CREATE POLICY gift_certificates_select_own ON public.gift_certificates
  FOR SELECT TO authenticated
  USING (buyer_id = auth.uid() OR redeemed_by = auth.uid());

-- Atomic redemption: CAS-claims a PAID, non-expired cert and provisions the
-- subscription in one transaction. Double-spend safe (CAS succeeds only while
-- status='paid').
CREATE OR REPLACE FUNCTION public.redeem_gift_certificate(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_cert   public.gift_certificates%ROWTYPE;
  v_visits int;
  v_end    date;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  UPDATE public.gift_certificates
     SET status      = 'redeemed',
         redeemed_by = v_uid,
         redeemed_at = now()
   WHERE code = p_code
     AND status = 'paid'
     AND (expires_at IS NULL OR expires_at > now())
  RETURNING * INTO v_cert;

  IF NOT FOUND THEN
    SELECT * INTO v_cert FROM public.gift_certificates WHERE code = p_code;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'error', 'not_found');
    ELSIF v_cert.status = 'redeemed' THEN
      RETURN jsonb_build_object('ok', false, 'error', 'already_redeemed');
    ELSIF v_cert.status = 'paid'
          AND v_cert.expires_at IS NOT NULL
          AND v_cert.expires_at <= now() THEN
      RETURN jsonb_build_object('ok', false, 'error', 'expired');
    ELSE
      RETURN jsonb_build_object('ok', false, 'error', 'not_paid');
    END IF;
  END IF;

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
