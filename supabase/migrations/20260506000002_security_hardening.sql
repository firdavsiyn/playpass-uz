-- ============================================================
-- Security hardening — close real privilege-escalation gaps.
-- Date: 2026-05-06
--
-- Findings addressed (from live source-code audit):
--   #1  users_update_own → user could write level/xp/total_visits/streak
--   #2  subscriptions_update_own → user could set hours_balance = -1, plan=vip
--   #3  promos_update USING(true) → user could reset usage_count
--   #4  clubs_update_owner → owner could promote tier to vip
--   #5  storage 'review-photos' / 'stories' → upload any file to any path
--
-- All changes are additive: nothing is dropped that wasn't created by us.
-- ============================================================

-- ============================================================
-- 1. users — block self-promotion of gamification stats.
-- ============================================================
--
-- The old policy let `users` UPDATE their own row freely. That gave them
-- write access to `level`, `xp`, `total_visits`, `total_hours`,
-- `streak_days`, `referral_code`, `referred_by`, `welcome_bonus_at`.
-- A malicious user could max out their streak, claim premium level,
-- or change referral linkage post-hoc.
--
-- Fix: drop the broad UPDATE policy and replace with one that allows
-- writes ONLY to "profile" columns. Sensitive columns are write-locked
-- via a row-level trigger that aborts if their values change.

DROP POLICY IF EXISTS users_update_own ON public.users;

CREATE POLICY users_update_own ON public.users
  FOR UPDATE USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Trigger enforces column-level immutability. Service-role bypasses RLS
-- and the trigger checks `current_setting('role')` to skip for service.
CREATE OR REPLACE FUNCTION public.users_block_protected_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  is_service boolean := (current_setting('request.jwt.claim.role', true) = 'service_role');
BEGIN
  IF is_service THEN
    RETURN NEW; -- service role can do anything
  END IF;

  -- Compare protected columns; raise if any changed.
  IF NEW.level IS DISTINCT FROM OLD.level
     OR NEW.xp IS DISTINCT FROM OLD.xp
     OR NEW.total_visits IS DISTINCT FROM OLD.total_visits
     OR NEW.total_hours IS DISTINCT FROM OLD.total_hours
     OR NEW.streak_days IS DISTINCT FROM OLD.streak_days
     OR NEW.referral_code IS DISTINCT FROM OLD.referral_code
     OR NEW.referred_by IS DISTINCT FROM OLD.referred_by
     OR NEW.welcome_bonus_at IS DISTINCT FROM OLD.welcome_bonus_at THEN
    RAISE EXCEPTION 'Permission denied: cannot modify protected user fields';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_block_protected ON public.users;
CREATE TRIGGER trg_users_block_protected
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.users_block_protected_columns();

-- ============================================================
-- 2. subscriptions — KILL user-side UPDATE entirely.
-- ============================================================
--
-- The old `subscriptions_update_own` let users set hours_balance = -1
-- (unlimited), plan = 'vip', end_date = '2099-12-31'. This is a direct
-- monetary loss vector. Anyone with a JWT could give themselves VIP.
--
-- All subscription mutations must go through:
--   • Edge Functions running with service_role (click-webhook,
--     activate_subscription_from_payment), OR
--   • SECURITY DEFINER RPCs (bump_subscription_hours, freeze, etc.)
--
-- Users can still SELECT their own subscriptions (read-only).

DROP POLICY IF EXISTS subscriptions_update_own ON public.subscriptions;

-- (No replacement INSERT/UPDATE/DELETE policy for users — they can
-- only mutate via SECURITY DEFINER functions that gate the logic.)

-- ============================================================
-- 3. promos — only superadmin can mutate.
-- ============================================================
--
-- The old policy was `FOR UPDATE USING (true) WITH CHECK (true)` with
-- a comment "should move to Edge Function in production". It never did.
-- Any user could change discount_pct, reset usage_count, or extend
-- valid_until to forever.

DROP POLICY IF EXISTS promos_update ON public.promos;

CREATE POLICY promos_update_superadmin ON public.promos
  FOR UPDATE USING (public.is_superadmin())
  WITH CHECK (public.is_superadmin());

-- Promo redemption (incrementing usage_count) now must go through this
-- SECURITY DEFINER RPC. The client app calls redeem_promo(code) and the
-- function validates + atomically increments + records usage.
CREATE OR REPLACE FUNCTION public.redeem_promo(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_promo public.promos%ROWTYPE;
  v_already_used boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_authenticated');
  END IF;

  -- Atomically pick + increment if available.
  SELECT * INTO v_promo
    FROM public.promos
   WHERE code = p_code
     AND (valid_until IS NULL OR valid_until > now())
     AND (max_uses IS NULL OR usage_count < max_uses)
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_or_exhausted');
  END IF;

  -- One-per-user check.
  SELECT EXISTS (
    SELECT 1 FROM public.promo_usages
     WHERE user_id = v_uid AND promo_id = v_promo.id
  ) INTO v_already_used;

  IF v_already_used THEN
    RETURN jsonb_build_object('success', false, 'reason', 'already_used');
  END IF;

  UPDATE public.promos
     SET usage_count = usage_count + 1
   WHERE id = v_promo.id;

  INSERT INTO public.promo_usages (user_id, promo_id)
    VALUES (v_uid, v_promo.id);

  RETURN jsonb_build_object('success', true, 'promo', row_to_json(v_promo));
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_promo(text) TO authenticated;

-- ============================================================
-- 4. clubs — owner can update their club BUT not tier or status.
-- ============================================================
--
-- The old `clubs_update_owner` let an owner change `tier`
-- (basic → vip) and `status` (suspended → active). That's a paid
-- feature flip without payment.

DROP POLICY IF EXISTS clubs_update_owner ON public.clubs;

CREATE POLICY clubs_update_owner ON public.clubs
  FOR UPDATE USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- Trigger blocks privileged column changes for non-superadmin updates.
CREATE OR REPLACE FUNCTION public.clubs_block_privileged_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  is_admin boolean;
BEGIN
  -- Superadmin or service_role bypasses everything.
  IF current_setting('request.jwt.claim.role', true) = 'service_role' THEN
    RETURN NEW;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.admin_users
     WHERE id = auth.uid() AND role = 'superadmin'
  ) INTO is_admin;

  IF is_admin THEN
    RETURN NEW;
  END IF;

  IF NEW.tier IS DISTINCT FROM OLD.tier
     OR NEW.status IS DISTINCT FROM OLD.status
     OR NEW.owner_id IS DISTINCT FROM OLD.owner_id THEN
    RAISE EXCEPTION 'Permission denied: only superadmin may change tier/status/owner';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_clubs_block_privileged ON public.clubs;
CREATE TRIGGER trg_clubs_block_privileged
  BEFORE UPDATE ON public.clubs
  FOR EACH ROW EXECUTE FUNCTION public.clubs_block_privileged_columns();

-- ============================================================
-- 5. Storage buckets — restrict upload paths + size.
-- ============================================================
--
-- The old policies allowed any authenticated user to upload any file
-- to /review-photos/* and /stories/* with no size, type, or path
-- constraint. An attacker could fill the bucket with junk, upload
-- arbitrary mime types, or impersonate other users.
--
-- We tighten by: (a) restricting uploads to user-owned folders,
-- (b) limiting file extensions to images, (c) Supabase enforces
-- per-bucket size limit via Dashboard but we add a name-pattern check.

DROP POLICY IF EXISTS "review_photos_upload" ON storage.objects;
CREATE POLICY "review_photos_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'review-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text  -- own folder only
    AND lower(name) ~ '\.(jpe?g|png|webp|heic)$'           -- images only
  );

DROP POLICY IF EXISTS "stories_upload" ON storage.objects;
CREATE POLICY "stories_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'stories'
    AND (storage.foldername(name))[1] = auth.uid()::text
    AND lower(name) ~ '\.(jpe?g|png|webp|heic|mp4|mov)$'
  );

-- (Read policies stay public — these buckets are public-display by design.)

-- ============================================================
-- 6. subscription_plans — read-only for everyone; superadmin can mutate.
-- ============================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename='subscription_plans') THEN
    EXECUTE 'ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS sp_read ON public.subscription_plans';
    EXECUTE 'CREATE POLICY sp_read ON public.subscription_plans FOR SELECT USING (true)';
    EXECUTE 'DROP POLICY IF EXISTS sp_admin ON public.subscription_plans';
    EXECUTE 'CREATE POLICY sp_admin ON public.subscription_plans FOR ALL USING (public.is_superadmin()) WITH CHECK (public.is_superadmin())';
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
