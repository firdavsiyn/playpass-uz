-- ═══════════════════════════════════════════════
-- PlayPass: Achievements & Promo Codes
-- ═══════════════════════════════════════════════

-- 1. Achievements catalog
CREATE TABLE IF NOT EXISTS public.achievements (
  id          text PRIMARY KEY,
  name_ru     text NOT NULL,
  name_uz     text NOT NULL DEFAULT '',
  desc_ru     text NOT NULL DEFAULT '',
  desc_uz     text NOT NULL DEFAULT '',
  icon        text NOT NULL DEFAULT '🏆',
  category    text NOT NULL DEFAULT 'visits'
                  CHECK (category IN ('visits', 'explorer', 'time', 'social')),
  threshold   int NOT NULL DEFAULT 1,
  sort_order  int NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- 2. User achievements (unlocked)
CREATE TABLE IF NOT EXISTS public.user_achievements (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  achievement_id  text NOT NULL REFERENCES public.achievements(id) ON DELETE CASCADE,
  unlocked_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_user_achievements_user ON public.user_achievements(user_id);

-- 3. Promo codes
CREATE TABLE IF NOT EXISTS public.promos (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code        text NOT NULL UNIQUE,
  description text NOT NULL DEFAULT '',
  type        text NOT NULL DEFAULT 'hours'
                  CHECK (type IN ('hours', 'days', 'discount')),
  value       int NOT NULL DEFAULT 0,
  max_uses    int NOT NULL DEFAULT 0,
  used_count  int NOT NULL DEFAULT 0,
  is_active   boolean NOT NULL DEFAULT true,
  expires_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_promos_code ON public.promos(code);

-- 4. Promo usage tracking
CREATE TABLE IF NOT EXISTS public.promo_usages (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id   uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  promo_id  uuid NOT NULL REFERENCES public.promos(id) ON DELETE CASCADE,
  used_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, promo_id)
);

CREATE INDEX IF NOT EXISTS idx_promo_usages_user ON public.promo_usages(user_id);

-- 5. RLS Policies
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promo_usages ENABLE ROW LEVEL SECURITY;

CREATE POLICY achievements_read ON public.achievements FOR SELECT USING (true);
CREATE POLICY user_achievements_all ON public.user_achievements FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY promos_read ON public.promos FOR SELECT USING (true);
CREATE POLICY promos_update ON public.promos FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY promo_usages_all ON public.promo_usages FOR ALL USING (true) WITH CHECK (true);

GRANT SELECT ON public.achievements TO authenticated;
GRANT ALL ON public.user_achievements TO authenticated;
GRANT SELECT, UPDATE ON public.promos TO authenticated;
GRANT ALL ON public.promo_usages TO authenticated;

-- 6. Seed achievements
INSERT INTO public.achievements (id, name_ru, name_uz, desc_ru, desc_uz, icon, category, threshold, sort_order)
VALUES
  ('first_visit',       'Первый визит',        'Birinchi tashrif',      'Посетите клуб впервые',              'Klubga birinchi marta tashrif buyuring',    '🎮', 'visits',   1,  1),
  ('five_visits',       '5 визитов',           '5 ta tashrif',          'Посетите клубы 5 раз',               'Klublarga 5 marta tashrif buyuring',        '🔥', 'visits',   5,  2),
  ('ten_visits',        '10 визитов',          '10 ta tashrif',         'Посетите клубы 10 раз',              'Klublarga 10 marta tashrif buyuring',       '⚡', 'visits',   10, 3),
  ('twenty_five_visits','25 визитов',          '25 ta tashrif',         'Посетите клубы 25 раз',              'Klublarga 25 marta tashrif buyuring',       '💎', 'visits',   25, 4),
  ('ten_clubs',         'Исследователь',       'Kashfiyotchi',          'Посетите 10 разных клубов',          '10 ta turli klubga tashrif buyuring',       '🗺️', 'explorer', 10, 5),
  ('night_gamer',       'Ночной геймер',       'Tungi geymer',          'Посетите клуб 5 раз ночью (00-08)',  'Klubga 5 marta tunda tashrif (00-08)',      '🌙', 'time',     5,  6),
  ('weekend_warrior',   'Воин выходных',       'Dam olish kuni jangchisi','Посетите клуб 10 раз в выходные', 'Dam olish kunlari 10 marta tashrif',        '⚔️', 'time',     10, 7),
  ('social_butterfly',  'Социальная бабочка',  'Ijtimoiy kapalak',      'Пригласите 3 друзей',               '3 ta do\'stni taklif qiling',               '🦋', 'social',   3,  8),
  ('favorite_collector','Коллекционер',        'Kolleksioner',          'Добавьте 5 клубов в избранное',      '5 ta klubni sevimlilarga qo\'shing',       '❤️', 'social',   5,  9),
  ('first_review',      'Критик',              'Tanqidchi',             'Оставьте первый отзыв',             'Birinchi sharhingizni qoldiring',           '✍️', 'social',   1,  10),
  ('reviewer',          'Обозреватель',        'Sharxchi',              'Оставьте 5 отзывов',                '5 ta sharh qoldiring',                      '📝', 'social',   5,  11)
ON CONFLICT (id) DO NOTHING;

NOTIFY pgrst, 'reload schema';
