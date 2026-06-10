-- ============================================================
-- Migration 3/3: function-grant hardening
-- Date: 2026-05-06
--
-- Default PostgreSQL behaviour grants EXECUTE on every newly
-- created function to PUBLIC (= anon + authenticated). Our
-- previous migrations explicitly GRANTed to service_role /
-- authenticated, but did NOT revoke the PUBLIC default.
--
-- Effect of the gap (caught in smoke test):
--   • anon could POST /rest/v1/rpc/bump_subscription_hours with
--     a guessed user_id. RLS doesn't run inside SECURITY DEFINER
--     functions, so a successful guess would add hours to any
--     user's subscription.
--   • anon could POST /rest/v1/rpc/redeem_promo without auth
--     (function returns "not_authenticated" but is still callable).
--
-- Fix: REVOKE PUBLIC, keep targeted GRANTs.
-- ============================================================

REVOKE EXECUTE ON FUNCTION public.bump_subscription_hours(uuid, int) FROM PUBLIC;
-- service_role grant remains from migration #1

REVOKE EXECUTE ON FUNCTION public.redeem_promo(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.redeem_promo(text) TO authenticated;
-- anon can no longer call it; only logged-in users (which is correct —
-- the function itself returns 'not_authenticated' for anon anyway, but
-- now the call is blocked at PostgREST layer before the function runs).

-- Also harden the other SECURITY DEFINER functions we created earlier.
DO $$
DECLARE
  fn record;
BEGIN
  FOR fn IN
    SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN (
         'users_block_protected_columns',
         'clubs_block_privileged_columns',
         'is_superadmin',
         'my_club_id',
         'handle_new_user'
       )
  LOOP
    EXECUTE format(
      'REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM PUBLIC',
      fn.nspname, fn.proname, fn.args
    );
  END LOOP;
END $$;

-- Reload the schema cache so PostgREST picks up the new grants.
NOTIFY pgrst, 'reload schema';
