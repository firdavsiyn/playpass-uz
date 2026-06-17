-- ════════════════════════════════════════════════════════════════════════
-- Audit 2026-06-18 — LAUNCH BLOCKER #2
-- clubs.qr_token (the check-in HMAC secret) and clubs.payout_details (club
-- bank card / account numbers) were readable by every anon/authenticated user:
-- the clubs SELECT policy is row-level only, and the client did `select *`, so
-- anyone could read the QR secret and check in remotely (fabricating payouts)
-- and scrape every club's bank details.
--
-- FIX: Postgres column privileges only take effect when the role has NO
-- table-level SELECT. So we REVOKE table-level SELECT from anon/authenticated
-- and re-GRANT SELECT on every column EXCEPT the two secrets. A DO block
-- enumerates columns dynamically → robust to schema drift (the live clubs
-- table has columns not present in repo migrations). New columns added later
-- are NOT auto-granted (safe default; re-run this grant when adding a public
-- column).
--
-- Edge functions (checkin / qr-validate / payout-calc) use the service_role,
-- which BYPASSES these grants, so they keep full access to the secrets.
-- The existing row-level RLS policy (clubs_select_active) is unaffected.
-- ════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  cols text;
BEGIN
  SELECT string_agg(quote_ident(column_name), ', ')
    INTO cols
    FROM information_schema.columns
   WHERE table_schema = 'public'
     AND table_name   = 'clubs'
     AND column_name NOT IN ('qr_token', 'payout_details');

  -- Drop the blanket table-level SELECT, then grant only the safe columns.
  REVOKE SELECT ON public.clubs FROM anon, authenticated;
  EXECUTE format(
    'GRANT SELECT (%s) ON public.clubs TO anon, authenticated', cols);
END $$;

NOTIFY pgrst, 'reload schema';
