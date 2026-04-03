-- ═══════════════════════════════════════════════
-- PlayPass: Club Admin Features
-- Tables: club_pcs, bookings, club_staff
-- ═══════════════════════════════════════════════

-- 1. Club PCs
CREATE TABLE IF NOT EXISTS public.club_pcs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id         uuid NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  pc_number       int NOT NULL,
  label           text NOT NULL DEFAULT '',
  status          text NOT NULL DEFAULT 'free'
                      CHECK (status IN ('free', 'busy', 'broken', 'reserved')),
  current_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  session_start   timestamptz,
  zone            text NOT NULL DEFAULT 'main',
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (club_id, pc_number)
);

CREATE INDEX IF NOT EXISTS idx_club_pcs_club ON public.club_pcs(club_id);
CREATE INDEX IF NOT EXISTS idx_club_pcs_status ON public.club_pcs(club_id, status);

-- 2. Bookings
CREATE TABLE IF NOT EXISTS public.bookings (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id     uuid NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  pc_id       uuid NOT NULL REFERENCES public.club_pcs(id) ON DELETE CASCADE,
  date        date NOT NULL,
  start_time  time NOT NULL,
  end_time    time NOT NULL,
  status      text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT no_negative_duration CHECK (end_time > start_time)
);

CREATE INDEX IF NOT EXISTS idx_bookings_club_date ON public.bookings(club_id, date);
CREATE INDEX IF NOT EXISTS idx_bookings_pc_date ON public.bookings(pc_id, date);

-- 3. Club Staff
CREATE TABLE IF NOT EXISTS public.club_staff (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id       uuid NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  name          text NOT NULL,
  role          text NOT NULL DEFAULT 'cashier'
                    CHECK (role IN ('admin', 'cashier', 'tech')),
  phone         text NOT NULL DEFAULT '',
  shift_pattern text NOT NULL DEFAULT 'morning'
                    CHECK (shift_pattern IN ('morning', 'evening', 'night', 'flexible')),
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_club_staff_club ON public.club_staff(club_id);

-- 4. RLS Policies
ALTER TABLE public.club_pcs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.club_staff ENABLE ROW LEVEL SECURITY;

-- club_pcs
CREATE POLICY club_pcs_all ON public.club_pcs FOR ALL USING (true) WITH CHECK (true);

-- bookings
CREATE POLICY bookings_all ON public.bookings FOR ALL USING (true) WITH CHECK (true);

-- club_staff
CREATE POLICY club_staff_all ON public.club_staff FOR ALL USING (true) WITH CHECK (true);

-- Grant access
GRANT ALL ON public.club_pcs TO authenticated;
GRANT ALL ON public.bookings TO authenticated;
GRANT ALL ON public.club_staff TO authenticated;

NOTIFY pgrst, 'reload schema';
