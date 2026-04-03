-- ============================================================
-- GamePass UZ — Row Level Security Policies
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE public.users           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clubs           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visits          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payouts         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_bonuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_secrets   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications   ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- HELPERS
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_superadmin()
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE id = auth.uid() AND role = 'superadmin'
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.my_club_id()
RETURNS uuid AS $$
  SELECT club_id FROM public.admin_users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ============================================================
-- users table
-- ============================================================
-- Users can read/update only their own row
CREATE POLICY users_select_own ON public.users
  FOR SELECT USING (id = auth.uid());

CREATE POLICY users_update_own ON public.users
  FOR UPDATE USING (id = auth.uid());

-- Superadmin can read all
CREATE POLICY users_select_superadmin ON public.users
  FOR SELECT USING (public.is_superadmin());

-- ============================================================
-- admin_users table
-- ============================================================
CREATE POLICY admin_users_select_own ON public.admin_users
  FOR SELECT USING (id = auth.uid());

CREATE POLICY admin_users_superadmin ON public.admin_users
  FOR ALL USING (public.is_superadmin());

-- ============================================================
-- clubs table
-- ============================================================
-- All authenticated users can read active clubs
CREATE POLICY clubs_select_active ON public.clubs
  FOR SELECT USING (status = 'active');

-- Club owner can update their own club
CREATE POLICY clubs_update_owner ON public.clubs
  FOR UPDATE USING (owner_id = auth.uid());

-- Superadmin full access
CREATE POLICY clubs_all_superadmin ON public.clubs
  FOR ALL USING (public.is_superadmin());

-- ============================================================
-- subscriptions table
-- ============================================================
-- Users see only their own subscriptions
CREATE POLICY subscriptions_select_own ON public.subscriptions
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY subscriptions_update_own ON public.subscriptions
  FOR UPDATE USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Superadmin full access
CREATE POLICY subscriptions_superadmin ON public.subscriptions
  FOR ALL USING (public.is_superadmin());

-- ============================================================
-- visits table
-- ============================================================
-- Users see their own visits
CREATE POLICY visits_select_own ON public.visits
  FOR SELECT USING (user_id = auth.uid());

-- Club admin/owner sees visits for their club
CREATE POLICY visits_select_club ON public.visits
  FOR SELECT USING (club_id = public.my_club_id());

-- Superadmin full access
CREATE POLICY visits_superadmin ON public.visits
  FOR ALL USING (public.is_superadmin());

-- Edge Functions insert visits (using service role — bypasses RLS)

-- ============================================================
-- payouts table
-- ============================================================
-- Club owner sees their own payouts
CREATE POLICY payouts_select_club ON public.payouts
  FOR SELECT USING (club_id = public.my_club_id());

-- Superadmin full access
CREATE POLICY payouts_superadmin ON public.payouts
  FOR ALL USING (public.is_superadmin());

-- ============================================================
-- referral_bonuses table
-- ============================================================
CREATE POLICY referral_select_own ON public.referral_bonuses
  FOR SELECT USING (inviter_id = auth.uid() OR invitee_id = auth.uid());

CREATE POLICY referral_superadmin ON public.referral_bonuses
  FOR ALL USING (public.is_superadmin());

-- ============================================================
-- daily_secrets table
-- ============================================================
-- Only service role (Edge Functions) can access daily_secrets
-- No public policies — all access via SECURITY DEFINER functions

-- ============================================================
-- notifications table
-- ============================================================
CREATE POLICY notifications_select_own ON public.notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY notifications_superadmin ON public.notifications
  FOR ALL USING (public.is_superadmin());
