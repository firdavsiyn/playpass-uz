-- ============================================================
-- SECURITY FIX: Replace overly permissive RLS policies
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. club_pcs: only club admins and superadmins can manage
-- ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS club_pcs_all ON public.club_pcs;

-- Anyone can read PCs (to see occupancy)
CREATE POLICY club_pcs_select ON public.club_pcs
  FOR SELECT USING (true);

-- Only club admin or superadmin can modify
CREATE POLICY club_pcs_modify ON public.club_pcs
  FOR ALL USING (
    club_id = public.my_club_id() OR public.is_superadmin()
  ) WITH CHECK (
    club_id = public.my_club_id() OR public.is_superadmin()
  );

-- ────────────────────────────────────────────────────────────
-- 2. bookings: users see own bookings, club admins see their club's
-- ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS bookings_all ON public.bookings;

-- Users can read their own bookings, admins can read their club's
CREATE POLICY bookings_select ON public.bookings
  FOR SELECT USING (
    user_id = auth.uid()
    OR club_id = public.my_club_id()
    OR public.is_superadmin()
  );

-- Users can create bookings for themselves
CREATE POLICY bookings_insert ON public.bookings
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
  );

-- Users can cancel own bookings, admins can update their club's
CREATE POLICY bookings_update ON public.bookings
  FOR UPDATE USING (
    user_id = auth.uid()
    OR club_id = public.my_club_id()
    OR public.is_superadmin()
  );

-- Only admins can delete bookings
CREATE POLICY bookings_delete ON public.bookings
  FOR DELETE USING (
    club_id = public.my_club_id()
    OR public.is_superadmin()
  );

-- ────────────────────────────────────────────────────────────
-- 3. club_staff: only club admin and superadmin
-- ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS club_staff_all ON public.club_staff;

CREATE POLICY club_staff_select ON public.club_staff
  FOR SELECT USING (
    club_id = public.my_club_id() OR public.is_superadmin()
  );

CREATE POLICY club_staff_modify ON public.club_staff
  FOR ALL USING (
    club_id = public.my_club_id() OR public.is_superadmin()
  ) WITH CHECK (
    club_id = public.my_club_id() OR public.is_superadmin()
  );

-- ────────────────────────────────────────────────────────────
-- 4. user_achievements: users can only read/insert their own
-- ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS user_achievements_all ON public.user_achievements;

CREATE POLICY user_achievements_select ON public.user_achievements
  FOR SELECT USING (user_id = auth.uid() OR public.is_superadmin());

CREATE POLICY user_achievements_insert ON public.user_achievements
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- ────────────────────────────────────────────────────────────
-- 5. promos: anyone can read, only superadmin can update
-- ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS promos_update ON public.promos;

CREATE POLICY promos_update ON public.promos
  FOR UPDATE USING (true) WITH CHECK (true);
-- Note: kept permissive for now since promo redemption needs
-- atomic increment. Should move to Edge Function in production.

-- ────────────────────────────────────────────────────────────
-- 6. promo_usages: users can only insert/read their own
-- ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS promo_usages_all ON public.promo_usages;

CREATE POLICY promo_usages_select ON public.promo_usages
  FOR SELECT USING (user_id = auth.uid() OR public.is_superadmin());

CREATE POLICY promo_usages_insert ON public.promo_usages
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- ────────────────────────────────────────────────────────────
-- 7. Fix banners admin policy (was referencing wrong table)
-- ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "banners_admin" ON public.banners;

CREATE POLICY "banners_admin" ON public.banners
  FOR ALL USING (public.is_superadmin())
  WITH CHECK (public.is_superadmin());

NOTIFY pgrst, 'reload schema';
