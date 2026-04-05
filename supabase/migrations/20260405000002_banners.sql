-- Banners table for home screen carousel
CREATE TABLE IF NOT EXISTS public.banners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  bg_color TEXT DEFAULT '#6366F1',
  action_url TEXT,
  is_active BOOLEAN DEFAULT true,
  sort_order INT DEFAULT 0,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;

-- Everyone can read active banners
CREATE POLICY "banners_read" ON public.banners
  FOR SELECT USING (is_active = true AND (expires_at IS NULL OR expires_at > now()));

-- Only service_role / super-admin can manage banners (via API)
CREATE POLICY "banners_admin" ON public.banners
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'super_admin')
  );
