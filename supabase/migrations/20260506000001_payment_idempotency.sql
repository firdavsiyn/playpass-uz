-- ============================================================
-- Migration: payment & referral idempotency hardening
-- Date: 2026-05-06
--
-- Purpose: prevent double-credit attacks / network-retry races
--   in payment processing & referral bonus application.
--
-- All changes are non-destructive: existing rows are left alone,
-- only future inserts/updates are constrained.
-- ============================================================

-- ── 1. Payments: provider_transaction_id must be unique per provider ─
-- Click.uz (and Rahmat/Payme) send a unique transaction id per payment.
-- If the same provider_transaction_id arrives twice (retry, replay), the
-- second INSERT/UPDATE that tries to reuse it must fail.
--
-- We use a *partial* unique index so that:
--   • rows without an id yet (status=pending) are not constrained;
--   • completed rows are unique by (provider_transaction_id) only when set.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'idx_payments_provider_tx_unique'
  ) THEN
    CREATE UNIQUE INDEX idx_payments_provider_tx_unique
      ON public.payments (provider_transaction_id)
      WHERE provider_transaction_id IS NOT NULL;
  END IF;
END $$;

-- ── 2. Referral bonuses: one bonus per invitee, ever ─────────────────
-- Prevents the rahmat-webhook from awarding +3h twice if invoked twice
-- (concurrent or replayed). Even if the function code is racy, the DB
-- INSERT will fail on the second attempt.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'referral_bonuses') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public'
        AND indexname = 'idx_referral_bonuses_invitee_unique'
    ) THEN
      CREATE UNIQUE INDEX idx_referral_bonuses_invitee_unique
        ON public.referral_bonuses (invitee_id);
    END IF;
  END IF;
END $$;

-- ── 3. Atomic hours-balance bump (kills lost-update race) ────────────
-- Replaces the read-modify-write pattern in rahmat-webhook with a single
-- SQL statement that does `hours_balance = hours_balance + delta`
-- atomically inside Postgres.
--
-- Usage from Edge Function:
--   await admin.rpc('bump_subscription_hours', { p_user_id, p_hours: 3 });
CREATE OR REPLACE FUNCTION public.bump_subscription_hours(
  p_user_id uuid,
  p_hours int
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.subscriptions
     SET hours_balance = hours_balance + p_hours
   WHERE user_id = p_user_id
     AND status = 'active'
     AND plan <> 'unlimited'              -- legacy plan code, ignore
     AND hours_balance IS NOT NULL
     AND hours_balance <> -1;              -- skip ∞ subscriptions
END;
$$;

GRANT EXECUTE ON FUNCTION public.bump_subscription_hours(uuid, int) TO service_role;

-- ── 4. Payment-status enum guard (defence in depth) ──────────────────
-- Click-webhook now does `.eq('status','pending')` for the claim, which
-- gives us optimistic concurrency. Belt-and-braces: a CHECK constraint
-- so a future bug can't write garbage statuses.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'payments') THEN
    -- Drop+re-add to ensure latest enum membership.
    IF EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = 'payments_status_check_v2'
        AND conrelid = 'public.payments'::regclass
    ) THEN
      ALTER TABLE public.payments DROP CONSTRAINT payments_status_check_v2;
    END IF;
    ALTER TABLE public.payments
      ADD CONSTRAINT payments_status_check_v2
      CHECK (status IN ('pending', 'completed', 'failed', 'cancelled', 'refunded'));
  END IF;
END $$;
