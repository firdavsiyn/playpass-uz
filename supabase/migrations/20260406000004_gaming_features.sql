-- ============================================================
-- Gaming Features:
--   1. Player Stats (Steam/game profiles)
--   2. Teammate Finder (LFG - Looking For Group)
--   3. Club Player Leaderboard
--   4. Happy Hours
-- ============================================================

-- ── 1. PLAYER GAME PROFILES ────────────────────────────────

CREATE TABLE IF NOT EXISTS public.player_profiles (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  game        text NOT NULL,
  nickname    text NOT NULL,
  rank        text,
  rank_icon   text,
  hours_played int DEFAULT 0,
  kd_ratio    numeric(5,2),
  winrate     numeric(5,2),
  is_public   boolean NOT NULL DEFAULT true,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, game)
);

CREATE INDEX IF NOT EXISTS idx_pp_user ON public.player_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_pp_game ON public.player_profiles(game);

ALTER TABLE public.player_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY pp_read ON public.player_profiles FOR SELECT USING (is_public = true OR user_id = auth.uid());
CREATE POLICY pp_own ON public.player_profiles FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ── 2. TEAMMATE FINDER (LFG) ──────────────────────────────

CREATE TABLE IF NOT EXISTS public.lfg_posts (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  game        text NOT NULL,
  rank_min    text,
  rank_max    text,
  players_needed int NOT NULL DEFAULT 1,
  club_id     uuid REFERENCES public.clubs(id) ON DELETE SET NULL,
  message     text,
  mic_required boolean NOT NULL DEFAULT false,
  language    text DEFAULT 'ru',
  status      text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'filled', 'expired')),
  expires_at  timestamptz NOT NULL DEFAULT (now() + interval '4 hours'),
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.lfg_responses (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id     uuid NOT NULL REFERENCES public.lfg_posts(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  message     text,
  status      text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_lfg_game ON public.lfg_posts(game, status);
CREATE INDEX IF NOT EXISTS idx_lfg_user ON public.lfg_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_lfg_resp_post ON public.lfg_responses(post_id);

ALTER TABLE public.lfg_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lfg_responses ENABLE ROW LEVEL SECURITY;

CREATE POLICY lfg_read ON public.lfg_posts FOR SELECT USING (status = 'active' AND expires_at > now());
CREATE POLICY lfg_own ON public.lfg_posts FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY lfg_resp_read ON public.lfg_responses FOR SELECT
  USING (user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.lfg_posts p WHERE p.id = post_id AND p.user_id = auth.uid()));
CREATE POLICY lfg_resp_insert ON public.lfg_responses FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY lfg_resp_update ON public.lfg_responses FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.lfg_posts p WHERE p.id = post_id AND p.user_id = auth.uid()));

-- ── 3. CLUB LEADERBOARD ────────────────────────────────────

-- Uses existing visits + users tables. We add a materialized stat:
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS total_visits int NOT NULL DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS total_hours int NOT NULL DEFAULT 0;

-- ── 4. HAPPY HOURS ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.happy_hours (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id     uuid NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  title       text NOT NULL DEFAULT 'Happy Hour',
  discount_pct int NOT NULL DEFAULT 30,
  day_of_week smallint NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time  time NOT NULL,
  end_time    time NOT NULL,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hh_club ON public.happy_hours(club_id);

ALTER TABLE public.happy_hours ENABLE ROW LEVEL SECURITY;
CREATE POLICY hh_read ON public.happy_hours FOR SELECT USING (is_active = true);
CREATE POLICY hh_manage ON public.happy_hours FOR ALL
  USING (club_id = public.my_club_id() OR public.is_superadmin())
  WITH CHECK (club_id = public.my_club_id() OR public.is_superadmin());

-- ── 5. Add latitude/longitude columns if missing ───────────

ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS latitude double precision;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS longitude double precision;

NOTIFY pgrst, 'reload schema';
