-- Run this in Supabase SQL Editor
-- Adds custom auth columns and makes RLS permissive

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS password_hash TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS password_salt TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS session_token TEXT;

-- Drop old RLS policies that depend on auth.uid()
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Doctors can view all profiles" ON profiles;

-- Create permissive policies (auth is handled by app code)
CREATE POLICY "Allow all" ON profiles FOR ALL USING (true);

DROP POLICY IF EXISTS "Patients can view own consultations" ON consultations;
DROP POLICY IF EXISTS "Patients can insert own consultations" ON consultations;
DROP POLICY IF EXISTS "Doctors can view all consultations" ON consultations;
DROP POLICY IF EXISTS "Doctors can update consultations" ON consultations;
CREATE POLICY "Allow all" ON consultations FOR ALL USING (true);

DROP POLICY IF EXISTS "Users can view messages in their consultations" ON messages;
DROP POLICY IF EXISTS "Users can insert messages in their consultations" ON messages;
CREATE POLICY "Allow all" ON messages FOR ALL USING (true);

DROP POLICY IF EXISTS "Patients can view own documents" ON clinical_documents;
DROP POLICY IF EXISTS "Doctors can view all documents" ON clinical_documents;
DROP POLICY IF EXISTS "Doctors can insert documents" ON clinical_documents;
CREATE POLICY "Allow all" ON clinical_documents FOR ALL USING (true);

DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
DROP POLICY IF EXISTS "System can insert notifications" ON notifications;
CREATE POLICY "Allow all" ON notifications FOR ALL USING (true);

-- Remove the is_doctor() helper (no longer needed)
DROP FUNCTION IF EXISTS public.is_doctor();

-- Add consultation_id to notifications
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS consultation_id INTEGER REFERENCES consultations(id) ON DELETE SET NULL;

-- Create storage buckets if they don't exist
INSERT INTO storage.buckets (id, name, public, avif_autodetection, file_size_limit)
VALUES ('media', 'media', true, false, 52428800)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, avif_autodetection, file_size_limit)
VALUES ('clinical_documents', 'clinical_documents', true, false, 10485760)
ON CONFLICT (id) DO NOTHING;

-- Drop any existing storage policies first
DROP POLICY IF EXISTS "Allow all media" ON storage.objects;
DROP POLICY IF EXISTS "Allow all clinical_documents" ON storage.objects;

-- Storage bucket policies (allow all since auth is app-level)
CREATE POLICY "Allow all media" ON storage.objects FOR ALL USING (bucket_id = 'media');
CREATE POLICY "Allow all clinical_documents" ON storage.objects FOR ALL USING (bucket_id = 'clinical_documents');
