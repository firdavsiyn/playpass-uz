-- ============================================================
-- GamePass UZ — Supabase PostgreSQL Migration v1
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- TABLE: users (extends auth.users via trigger)
-- ============================================================
CREATE TABLE public.users (
  id           uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone        text UNIQUE NOT NULL,
  name         text NOT NULL DEFAULT '',
  avatar_url   text,
  referral_code text UNIQUE NOT NULL DEFAULT substr(md5(random()::text), 1, 8),
  referred_by  uuid REFERENCES public.users(id) ON DELETE SET NULL,
  level        text NOT NULL DEFAULT 'Новичок'
                   CHECK (level IN ('Новичок', 'Геймер', 'Про', 'Легенда')),
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- TABLE: admin_users (club owners & admins)
-- ============================================================
CREATE TABLE public.admin_users (
  id         uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email      text UNIQUE NOT NULL,
  name       text NOT NULL DEFAULT '',
  role       text NOT NULL DEFAULT 'admin' CHECK (role IN ('superadmin', 'owner', 'admin')),
  club_id    uuid, -- FK added after clubs table
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- TABLE: clubs
-- ============================================================
CREATE TABLE public.clubs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text NOT NULL,
  address         text NOT NULL,
  lat             float8,
  lon             float8,
  photos          text[] NOT NULL DEFAULT '{}',
  working_hours   jsonb NOT NULL DEFAULT '{}',
  pc_count        int NOT NULL DEFAULT 0,
  rating          float4 NOT NULL DEFAULT 0.0 CHECK (rating BETWEEN 0 AND 5),
  qr_token        text UNIQUE,
  payout_details  jsonb NOT NULL DEFAULT '{}',
  status          text NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('active', 'suspended', 'pending')),
  owner_id        uuid REFERENCES public.admin_users(id) ON DELETE SET NULL,
  tier            text NOT NULL DEFAULT 'basic'
                      CHECK (tier IN ('basic', 'standard', 'vip')),
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Add FK from admin_users to clubs
ALTER TABLE public.admin_users
  ADD CONSTRAINT fk_admin_users_club
  FOREIGN KEY (club_id) REFERENCES public.clubs(id) ON DELETE SET NULL;

-- ============================================================
-- TABLE: subscriptions
-- ============================================================
CREATE TABLE public.subscriptions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  plan          text NOT NULL CHECK (plan IN ('start', 'standard', 'unlimited')),
  start_date    date NOT NULL DEFAULT CURRENT_DATE,
  end_date      date NOT NULL,
  hours_balance int, -- NULL for unlimited
  status        text NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'frozen', 'expired', 'cancelled')),
  frozen_until  date,
  rahmat_order_id text,
  price_uzs     int NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- TABLE: visits (checkins)
-- ============================================================
CREATE TABLE public.visits (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  club_id       uuid NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  subscription_id uuid NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
  hours_spent   int NOT NULL DEFAULT 1,
  geo_lat       float8,
  geo_lon       float8,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- TABLE: payouts (club payments)
-- ============================================================
CREATE TABLE public.payouts (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id         uuid NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  period_month    date NOT NULL, -- first day of month, e.g. 2025-03-01
  visit_count     int NOT NULL DEFAULT 0,
  amount_uzs      int NOT NULL DEFAULT 0,
  status          text NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'processing', 'paid', 'failed')),
  rahmat_batch_id text,
  paid_at         timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (club_id, period_month)
);

-- ============================================================
-- TABLE: referral_bonuses
-- ============================================================
CREATE TABLE public.referral_bonuses (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inviter_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  invitee_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  bonus_hours    int NOT NULL DEFAULT 3,
  applied        boolean NOT NULL DEFAULT false,
  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (inviter_id, invitee_id)
);

-- ============================================================
-- TABLE: daily_secrets (for QR HMAC validation)
-- ============================================================
CREATE TABLE public.daily_secrets (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  secret     text NOT NULL,
  valid_date date NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- TABLE: notifications (push/SMS log)
-- ============================================================
CREATE TABLE public.notifications (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid REFERENCES public.users(id) ON DELETE CASCADE,
  club_id    uuid REFERENCES public.clubs(id) ON DELETE CASCADE,
  type       text NOT NULL, -- 'push' | 'sms' | 'email'
  event      text NOT NULL, -- 'checkin' | 'subscription_active' | 'expiry_reminder' etc.
  payload    jsonb NOT NULL DEFAULT '{}',
  status     text NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'failed', 'pending')),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_users_phone             ON public.users(phone);
CREATE INDEX idx_users_referral_code     ON public.users(referral_code);
CREATE INDEX idx_subscriptions_user_id   ON public.subscriptions(user_id);
CREATE INDEX idx_subscriptions_status    ON public.subscriptions(status);
CREATE INDEX idx_subscriptions_end_date  ON public.subscriptions(end_date);
CREATE INDEX idx_visits_user_id          ON public.visits(user_id);
CREATE INDEX idx_visits_club_id          ON public.visits(club_id);
CREATE INDEX idx_visits_created_at       ON public.visits(created_at);
CREATE INDEX idx_clubs_status            ON public.clubs(status);
CREATE INDEX idx_clubs_qr_token          ON public.clubs(qr_token);
CREATE INDEX idx_payouts_club_period     ON public.payouts(club_id, period_month);
CREATE INDEX idx_daily_secrets_date      ON public.daily_secrets(valid_date);

-- ============================================================
-- FUNCTION: get active subscription for user
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_active_subscription(p_user_id uuid)
RETURNS public.subscriptions AS $$
  SELECT * FROM public.subscriptions
  WHERE user_id = p_user_id
    AND status = 'active'
    AND end_date >= CURRENT_DATE
  ORDER BY created_at DESC
  LIMIT 1;
$$ LANGUAGE sql STABLE;

-- ============================================================
-- FUNCTION: update user level based on monthly hours
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_user_level(p_user_id uuid)
RETURNS void AS $$
DECLARE
  monthly_hours int;
  new_level text;
BEGIN
  SELECT COALESCE(SUM(hours_spent), 0) INTO monthly_hours
  FROM public.visits
  WHERE user_id = p_user_id
    AND created_at >= date_trunc('month', now());

  new_level := CASE
    WHEN monthly_hours >= 30 THEN 'Легенда'
    WHEN monthly_hours >= 16 THEN 'Про'
    WHEN monthly_hours >= 6  THEN 'Геймер'
    ELSE 'Новичок'
  END;

  UPDATE public.users SET level = new_level WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TRIGGER: update user level after visit insert
-- ============================================================
CREATE OR REPLACE FUNCTION public.trigger_update_level()
RETURNS trigger AS $$
BEGIN
  PERFORM public.update_user_level(NEW.user_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_visit_update_level
  AFTER INSERT ON public.visits
  FOR EACH ROW EXECUTE FUNCTION public.trigger_update_level();

-- ============================================================
-- TRIGGER: create public.users entry on auth.users insert
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, phone, name)
  VALUES (
    NEW.id,
    COALESCE(NEW.phone, NEW.email, ''),
    COALESCE(NEW.raw_user_meta_data->>'name', '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- TRIGGER: expire subscriptions past end_date
-- (run via cron in n8n or pg_cron)
-- ============================================================
CREATE OR REPLACE FUNCTION public.expire_subscriptions()
RETURNS void AS $$
  UPDATE public.subscriptions
  SET status = 'expired'
  WHERE status = 'active'
    AND end_date < CURRENT_DATE
    AND (frozen_until IS NULL OR frozen_until < CURRENT_DATE);
$$ LANGUAGE sql;
