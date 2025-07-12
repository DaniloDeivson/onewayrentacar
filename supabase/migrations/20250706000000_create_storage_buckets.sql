-- Create storage buckets for photos and signatures
-- This migration creates the necessary storage buckets for the application

-- Create photos bucket for inspection photos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'photos',
  'photos',
  true,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
) ON CONFLICT (id) DO NOTHING;

-- Create signatures bucket for digital signatures
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'signatures',
  'signatures',
  true,
  5242880, -- 5MB limit
  ARRAY['image/png', 'image/jpeg', 'image/jpg']
) ON CONFLICT (id) DO NOTHING;

-- Create RLS policies for photos bucket
CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (bucket_id = 'photos');
CREATE POLICY "Authenticated users can upload photos" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'photos' AND auth.role() = 'authenticated'
);
CREATE POLICY "Users can update their own photos" ON storage.objects FOR UPDATE USING (
  bucket_id = 'photos' AND auth.role() = 'authenticated'
);
CREATE POLICY "Users can delete their own photos" ON storage.objects FOR DELETE USING (
  bucket_id = 'photos' AND auth.role() = 'authenticated'
);

-- Create RLS policies for signatures bucket
CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (bucket_id = 'signatures');
CREATE POLICY "Authenticated users can upload signatures" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'signatures' AND auth.role() = 'authenticated'
);
CREATE POLICY "Users can update their own signatures" ON storage.objects FOR UPDATE USING (
  bucket_id = 'signatures' AND auth.role() = 'authenticated'
);
CREATE POLICY "Users can delete their own signatures" ON storage.objects FOR DELETE USING (
  bucket_id = 'signatures' AND auth.role() = 'authenticated'
); 