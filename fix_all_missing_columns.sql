-- ============================================================
-- COMPREHENSIVE FIX: Add all missing columns and tables
-- Run this in Supabase SQL Editor (one-time)
-- ============================================================

-- ── 1. Users table: add loyalty/gamification columns ────────
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS xp integer DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS loyalty_level text DEFAULT 'bronze';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS streak_days integer DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_visit_date date;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS total_visits integer DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS total_hours integer DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS preferred_language text DEFAULT 'ru';

-- ── 2. Clubs table: add missing detail columns ─────────────
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS logo_url text;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS price_per_hour integer DEFAULT 12000;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS review_count integer DEFAULT 0;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS contact_phone text;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS contact_telegram text;

-- ── 3. Notifications table: ensure title/body/is_read ──────
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS title text;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS body text;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS is_read boolean DEFAULT false;

-- ── 4. Bookings table: ensure all columns ──────────────────
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS booking_time timestamptz;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS duration_hours integer DEFAULT 1;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS zone text DEFAULT 'basic';

-- Make pc_id nullable (not all bookings have a specific PC)
ALTER TABLE public.bookings ALTER COLUMN pc_id DROP NOT NULL;

-- ── 5. Create referral_bonuses table if missing ─────────────
CREATE TABLE IF NOT EXISTS public.referral_bonuses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inviter_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  invitee_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  bonus_hours integer DEFAULT 3,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.referral_bonuses ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Users can view own referral bonuses" ON public.referral_bonuses
  FOR SELECT USING (auth.uid() = inviter_id OR auth.uid() = invitee_id);

GRANT SELECT ON public.referral_bonuses TO authenticated;

-- ── 6. Create loyalty_points table if missing ──────────────
CREATE TABLE IF NOT EXISTS public.loyalty_points (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  amount integer NOT NULL DEFAULT 0,
  reason text,
  reference_id text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.loyalty_points ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Users can view own loyalty points" ON public.loyalty_points
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY IF NOT EXISTS "Users can insert own loyalty points" ON public.loyalty_points
  FOR INSERT WITH CHECK (auth.uid() = user_id);

GRANT SELECT, INSERT ON public.loyalty_points TO authenticated;

-- ── 7. Create notification_prefs table if missing ──────────
CREATE TABLE IF NOT EXISTS public.notification_prefs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  push_enabled boolean DEFAULT true,
  promo_enabled boolean DEFAULT true,
  tournament_enabled boolean DEFAULT true,
  subscription_enabled boolean DEFAULT true,
  club_news_enabled boolean DEFAULT true,
  fcm_token text,
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.notification_prefs ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Users can manage own notification prefs" ON public.notification_prefs
  FOR ALL USING (auth.uid() = user_id);

GRANT ALL ON public.notification_prefs TO authenticated;

-- ── 8. Create player_profiles table if missing ─────────────
CREATE TABLE IF NOT EXISTS public.player_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  game text NOT NULL,
  nickname text NOT NULL,
  rank text,
  hours_played integer DEFAULT 0,
  kd_ratio double precision,
  winrate double precision,
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, game)
);

ALTER TABLE public.player_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Users can view all player profiles" ON public.player_profiles
  FOR SELECT USING (true);
CREATE POLICY IF NOT EXISTS "Users can manage own player profiles" ON public.player_profiles
  FOR ALL USING (auth.uid() = user_id);

GRANT SELECT ON public.player_profiles TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.player_profiles TO authenticated;

-- ── 9. Create achievements tables if missing ────────────────
CREATE TABLE IF NOT EXISTS public.achievements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  icon text,
  xp_reward integer DEFAULT 0,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_achievements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  achievement_id uuid REFERENCES public.achievements(id) ON DELETE CASCADE,
  unlocked_at timestamptz DEFAULT now(),
  UNIQUE(user_id, achievement_id)
);

ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "Anyone can view achievements" ON public.achievements FOR SELECT USING (true);
CREATE POLICY IF NOT EXISTS "Users can view own achievements" ON public.user_achievements FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY IF NOT EXISTS "Users can unlock achievements" ON public.user_achievements FOR INSERT WITH CHECK (auth.uid() = user_id);

GRANT SELECT ON public.achievements TO authenticated, anon;
GRANT SELECT, INSERT ON public.user_achievements TO authenticated;

-- ── 10. Create gift_certificates table if missing ───────────
CREATE TABLE IF NOT EXISTS public.gift_certificates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  redeemed_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  plan text NOT NULL,
  amount_uzs integer NOT NULL,
  code text UNIQUE NOT NULL,
  recipient_name text,
  recipient_email text,
  recipient_phone text,
  status text DEFAULT 'paid',
  redeemed_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.gift_certificates ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Users can view own gift certificates" ON public.gift_certificates
  FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = redeemed_by);
CREATE POLICY IF NOT EXISTS "Users can create gift certificates" ON public.gift_certificates
  FOR INSERT WITH CHECK (auth.uid() = buyer_id);
CREATE POLICY IF NOT EXISTS "Users can redeem gift certificates" ON public.gift_certificates
  FOR UPDATE USING (true);

GRANT SELECT, INSERT, UPDATE ON public.gift_certificates TO authenticated;

-- ── 11. Create happy_hours table if missing ─────────────────
CREATE TABLE IF NOT EXISTS public.happy_hours (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id uuid REFERENCES public.clubs(id) ON DELETE CASCADE,
  day_of_week integer NOT NULL, -- 0=Mon, 6=Sun
  start_time time NOT NULL,
  end_time time NOT NULL,
  discount_percent integer DEFAULT 20,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.happy_hours ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Anyone can view happy hours" ON public.happy_hours FOR SELECT USING (true);

GRANT SELECT ON public.happy_hours TO authenticated, anon;

-- ── 12. Create active_sessions table if missing ─────────────
CREATE TABLE IF NOT EXISTS public.active_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  club_id uuid REFERENCES public.clubs(id) ON DELETE CASCADE,
  checkin_time timestamptz DEFAULT now(),
  ended_at timestamptz,
  status text DEFAULT 'active',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.active_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Users can view own sessions" ON public.active_sessions
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY IF NOT EXISTS "Users can update own sessions" ON public.active_sessions
  FOR UPDATE USING (auth.uid() = user_id);

GRANT SELECT, UPDATE ON public.active_sessions TO authenticated;

-- ── 13. Create banners table if missing ─────────────────────
CREATE TABLE IF NOT EXISTS public.banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text,
  image_url text,
  link_url text,
  is_active boolean DEFAULT true,
  sort_order integer DEFAULT 0,
  expires_at timestamptz,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Anyone can view banners" ON public.banners FOR SELECT USING (true);

GRANT SELECT ON public.banners TO authenticated, anon;

-- ── 14. Create story_views table if missing ─────────────────
CREATE TABLE IF NOT EXISTS public.story_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id uuid REFERENCES public.stories(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(story_id, user_id)
);

ALTER TABLE public.story_views ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Users can manage own story views" ON public.story_views
  FOR ALL USING (auth.uid() = user_id);

GRANT ALL ON public.story_views TO authenticated;

-- ── 15. Create promo_usages table if missing ────────────────
CREATE TABLE IF NOT EXISTS public.promo_usages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  promo_id uuid REFERENCES public.promos(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, promo_id)
);

ALTER TABLE public.promo_usages ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Users can view own promo usages" ON public.promo_usages
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY IF NOT EXISTS "Users can insert own promo usages" ON public.promo_usages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

GRANT SELECT, INSERT ON public.promo_usages TO authenticated;

-- ── 16. Create lfg_responses table if missing ───────────────
CREATE TABLE IF NOT EXISTS public.lfg_responses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid REFERENCES public.lfg_posts(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(post_id, user_id)
);

ALTER TABLE public.lfg_responses ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Anyone can view lfg responses" ON public.lfg_responses FOR SELECT USING (true);
CREATE POLICY IF NOT EXISTS "Users can respond to lfg" ON public.lfg_responses
  FOR INSERT WITH CHECK (auth.uid() = user_id);

GRANT SELECT, INSERT ON public.lfg_responses TO authenticated;

-- ── 17. Ensure RLS + GRANT on all core tables ──────────────
DO $$
DECLARE
  tbl text;
BEGIN
  FOR tbl IN
    SELECT unnest(ARRAY[
      'users','clubs','subscriptions','visits','bookings','reviews',
      'favorites','notifications','tournaments','tournament_participants',
      'stories','lfg_posts','promos','subscription_requests','club_zones'
    ])
  LOOP
    EXECUTE format('ALTER TABLE IF EXISTS public.%I ENABLE ROW LEVEL SECURITY', tbl);
    EXECUTE format('GRANT SELECT ON public.%I TO authenticated', tbl);
    EXECUTE format('GRANT SELECT ON public.%I TO anon', tbl);
  END LOOP;
END $$;

-- Grant write access where needed
GRANT INSERT, UPDATE ON public.users TO authenticated;
GRANT INSERT ON public.visits TO authenticated;
GRANT INSERT, UPDATE ON public.bookings TO authenticated;
GRANT INSERT ON public.reviews TO authenticated;
GRANT INSERT, DELETE ON public.favorites TO authenticated;
GRANT INSERT, UPDATE ON public.notifications TO authenticated;
GRANT INSERT ON public.subscription_requests TO authenticated;
GRANT INSERT ON public.tournament_participants TO authenticated;
GRANT DELETE ON public.tournament_participants TO authenticated;
GRANT INSERT ON public.lfg_posts TO authenticated;
GRANT UPDATE ON public.subscriptions TO authenticated;
GRANT UPDATE ON public.promos TO authenticated;

-- ── Done! ──────────────────────────────────────────────────
SELECT 'All missing columns and tables created successfully!' AS result;
