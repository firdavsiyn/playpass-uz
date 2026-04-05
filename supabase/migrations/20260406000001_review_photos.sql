-- Add photo_urls array column to reviews table
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS photo_urls TEXT[] DEFAULT '{}';

-- Create storage bucket for review photos
INSERT INTO storage.buckets (id, name, public) VALUES ('review-photos', 'review-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload review photos
CREATE POLICY "review_photos_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'review-photos');

-- Allow public read access to review photos
CREATE POLICY "review_photos_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'review-photos');

-- Allow users to delete their own review photos
CREATE POLICY "review_photos_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'review-photos' AND (storage.foldername(name))[1] = auth.uid()::text);
