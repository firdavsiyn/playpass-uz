-- ============================================================
-- Migration: visits-based model (BM v1.2)
-- Date: 2026-06-10
--
-- Adds the new purchasable tariffs 'day' & 'anytime', allows their codes
-- in the subscriptions CHECK constraint, and documents that hours_balance
-- now counts VISITS (not hours). Idempotent.
-- ============================================================

-- ── 1. subscriptions.plan CHECK — allow 'day' & 'anytime' ───────────
-- (keeps every legacy code so existing rows stay valid)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'subscriptions_plan_check'
             AND conrelid = 'public.subscriptions'::regclass) THEN
    ALTER TABLE public.subscriptions DROP CONSTRAINT subscriptions_plan_check;
  END IF;
  ALTER TABLE public.subscriptions
    ADD CONSTRAINT subscriptions_plan_check
    CHECK (plan IN (
      'daily','day','anytime',                              -- current purchasable
      'basic','standard','pro','vip',                       -- legacy monthly
      'standard_annual','vip_annual',                       -- legacy annual
      'start','unlimited'                                   -- oldest legacy
    ));
END $$;

-- ── 2. subscriptions.hours_balance now means VISITS ─────────────────
COMMENT ON COLUMN public.subscriptions.hours_balance IS
  'Now counts VISITS remaining (BM v1.2). NULL = unlimited (legacy plans).';

-- ── 3. subscription_plans — upsert 'day' & 'anytime' ────────────────
-- create-payment reads price_uzs from here, so these rows must exist.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename='subscription_plans') THEN
    -- 'name' is NOT NULL, so it must be supplied.
    INSERT INTO public.subscription_plans (code, name, price_uzs)
      VALUES ('day', 'Day', 149000), ('anytime', 'Anytime', 249000)
    ON CONFLICT (code) DO UPDATE
      SET price_uzs = EXCLUDED.price_uzs, name = EXCLUDED.name;
    -- keep daily as the 25k trial
    INSERT INTO public.subscription_plans (code, name, price_uzs)
      VALUES ('daily', 'Day Pass', 25000)
    ON CONFLICT (code) DO NOTHING;
  END IF;
END $$;

-- ── 4. TODO for activate_subscription_from_payment ──────────────────
-- This DB function (created earlier outside migrations) activates a sub
-- from a completed payment. It MUST map plan → visits on hours_balance:
--   'daily'   → 4
--   'day'     → 12   (and end_date = start + 30 days)
--   'anytime' → 12
-- and must NOT set hours_balance = -1 (no unlimited monthly).
-- If the function currently copies a plan's hours from subscription_plans,
-- add a visits column there, or hardcode the mapping above. Verify its body
-- in the SQL Editor and patch accordingly. (Left as explicit TODO — body
-- not in repo, do not guess.)

NOTIFY pgrst, 'reload schema';
