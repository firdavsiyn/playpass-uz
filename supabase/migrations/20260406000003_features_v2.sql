-- ============================================================
-- PlayPass v2 Features:
--   1. Tournaments & Events
--   2. Club Occupancy Analytics
--   3. Stories / News Feed
--   4. Loyalty Points & Levels
--   5. Push Notification Preferences
-- ============================================================

-- ── 1. TOURNAMENTS ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.tournaments (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id       uuid NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  title         text NOT NULL,
  description   text,
  game          text NOT NULL DEFAULT 'CS2',
  image_url     text,
  max_players   int NOT NULL DEFAULT 16,
  entry_fee     int NOT NULL DEFAULT 0,
  prize_pool    text,
  status        text NOT NULL DEFAULT 'upcoming'
                    CHECK (status IN ('upcoming', 'registration', 'ongoing', 'finished', 'cancelled')),
  starts_at     timestamptz NOT NULL,
  ends_at       timestamptz,
  rules         text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tournament_participants (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id uuid NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
  user_id       uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  team_name     text,
  status        text NOT NULL DEFAULT 'registered'
                    CHECK (status IN ('registered', 'checked_in', 'eliminated', 'winner')),
  placement     int,
  registered_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tournament_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_tournaments_club ON public.tournaments(club_id);
CREATE INDEX IF NOT EXISTS idx_tournaments_status ON public.tournaments(status);
CREATE INDEX IF NOT EXISTS idx_tournaments_starts ON public.tournaments(starts_at);
CREATE INDEX IF NOT EXISTS idx_tp_tournament ON public.tournament_participants(tournament_id);
CREATE INDEX IF NOT EXISTS idx_tp_user ON public.tournament_participants(user_id);

-- RLS
ALTER TABLE public.tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY tournaments_read ON public.tournaments FOR SELECT USING (true);
CREATE POLICY tournaments_manage ON public.tournaments FOR ALL
  USING (club_id = public.my_club_id() OR public.is_superadmin())
  WITH CHECK (club_id = public.my_club_id() OR public.is_superadmin());

CREATE POLICY tp_read ON public.tournament_participants FOR SELECT USING (true);
CREATE POLICY tp_register ON public.tournament_participants FOR INSERT
  WITH CHECK (user_id = auth.uid());
CREATE POLICY tp_manage ON public.tournament_participants FOR UPDATE
  USING (user_id = auth.uid() OR public.is_superadmin()
    OR EXISTS (SELECT 1 FROM public.tournaments t WHERE t.id = tournament_id AND t.club_id = public.my_club_id()));
CREATE POLICY tp_delete ON public.tournament_participants FOR DELETE
  USING (user_id = auth.uid() OR public.is_superadmin());

-- ── 2. OCCUPANCY SNAPSHOTS (for analytics) ─────────────────

CREATE TABLE IF NOT EXISTS public.occupancy_snapshots (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id     uuid NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  total_pcs   int NOT NULL DEFAULT 0,
  busy_pcs    int NOT NULL DEFAULT 0,
  hour        smallint NOT NULL,
  day_of_week smallint NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_occ_club ON public.occupancy_snapshots(club_id);
CREATE INDEX IF NOT EXISTS idx_occ_date ON public.occupancy_snapshots(recorded_at);

ALTER TABLE public.occupancy_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY occ_read ON public.occupancy_snapshots FOR SELECT
  USING (club_id = public.my_club_id() OR public.is_superadmin());
CREATE POLICY occ_insert ON public.occupancy_snapshots FOR INSERT
  WITH CHECK (club_id = public.my_club_id() OR public.is_superadmin());

-- ── 3. STORIES / NEWS FEED ─────────────────────────────────

CREATE TABLE IF NOT EXISTS public.stories (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id     uuid REFERENCES public.clubs(id) ON DELETE CASCADE,
  author_type text NOT NULL DEFAULT 'club' CHECK (author_type IN ('club', 'platform')),
  title       text NOT NULL,
  body        text,
  image_url   text,
  video_url   text,
  link_url    text,
  link_label  text,
  is_pinned   boolean NOT NULL DEFAULT false,
  is_active   boolean NOT NULL DEFAULT true,
  views_count int NOT NULL DEFAULT 0,
  expires_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.story_views (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id  uuid NOT NULL REFERENCES public.stories(id) ON DELETE CASCADE,
  user_id   uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  viewed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (story_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_stories_club ON public.stories(club_id);
CREATE INDEX IF NOT EXISTS idx_stories_active ON public.stories(is_active, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_story_views_user ON public.story_views(user_id);

ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY stories_read ON public.stories FOR SELECT
  USING (is_active = true AND (expires_at IS NULL OR expires_at > now()));
CREATE POLICY stories_manage ON public.stories FOR ALL
  USING (club_id = public.my_club_id() OR public.is_superadmin())
  WITH CHECK (club_id = public.my_club_id() OR public.is_superadmin());

CREATE POLICY sv_read ON public.story_views FOR SELECT
  USING (user_id = auth.uid() OR public.is_superadmin());
CREATE POLICY sv_insert ON public.story_views FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- ── 4. LOYALTY POINTS ──────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.loyalty_points (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  amount      int NOT NULL,
  reason      text NOT NULL,
  reference_id uuid,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lp_user ON public.loyalty_points(user_id);

ALTER TABLE public.loyalty_points ENABLE ROW LEVEL SECURITY;
CREATE POLICY lp_read ON public.loyalty_points FOR SELECT
  USING (user_id = auth.uid() OR public.is_superadmin());
CREATE POLICY lp_insert ON public.loyalty_points FOR INSERT
  WITH CHECK (true);

-- Add XP / loyalty columns to users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS xp int NOT NULL DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS loyalty_level text NOT NULL DEFAULT 'bronze'
  CHECK (loyalty_level IN ('bronze', 'silver', 'gold', 'diamond'));
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS streak_days int NOT NULL DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_visit_date date;

-- ── 5. NOTIFICATION PREFERENCES ────────────────────────────

CREATE TABLE IF NOT EXISTS public.notification_prefs (
  user_id             uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  push_enabled        boolean NOT NULL DEFAULT true,
  promo_enabled       boolean NOT NULL DEFAULT true,
  tournament_enabled  boolean NOT NULL DEFAULT true,
  subscription_enabled boolean NOT NULL DEFAULT true,
  club_news_enabled   boolean NOT NULL DEFAULT true,
  fcm_token           text,
  updated_at          timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notification_prefs ENABLE ROW LEVEL SECURITY;
CREATE POLICY np_own ON public.notification_prefs FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ── 6. STORAGE BUCKET FOR STORIES ──────────────────────────

INSERT INTO storage.buckets (id, name, public) VALUES ('stories', 'stories', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "stories_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'stories');

CREATE POLICY "stories_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'stories');

NOTIFY pgrst, 'reload schema';
