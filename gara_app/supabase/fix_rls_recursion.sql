-- Fix infinite recursion in RLS policies on profiles table
-- Run this in Supabase SQL Editor

-- 1. Create a security definer function to bypass RLS recursion
CREATE OR REPLACE FUNCTION public.is_doctor()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND is_doctor = true
  );
$$;

-- 2. Drop old problematic policies on profiles
DROP POLICY IF EXISTS "Doctors can view all profiles" ON profiles;

-- 3. Recreate using the helper function
CREATE POLICY "Doctors can view all profiles"
    ON profiles FOR SELECT
    USING (public.is_doctor());

-- 4. Fix policies on other tables that had the same pattern
DROP POLICY IF EXISTS "Doctors can view all consultations" ON consultations;
CREATE POLICY "Doctors can view all consultations"
    ON consultations FOR SELECT
    USING (public.is_doctor());

DROP POLICY IF EXISTS "Doctors can update consultations" ON consultations;
CREATE POLICY "Doctors can update consultations"
    ON consultations FOR UPDATE
    USING (public.is_doctor());

DROP POLICY IF EXISTS "Users can view messages in their consultations" ON messages;
CREATE POLICY "Users can view messages in their consultations"
    ON messages FOR SELECT
    USING (
        consultation_id IN (
            SELECT id FROM consultations
            WHERE patient_id = auth.uid()
        ) OR
        public.is_doctor()
    );

DROP POLICY IF EXISTS "Users can insert messages in their consultations" ON messages;
CREATE POLICY "Users can insert messages in their consultations"
    ON messages FOR INSERT
    WITH CHECK (
        sender_id = auth.uid() AND (
            consultation_id IN (
                SELECT id FROM consultations
                WHERE patient_id = auth.uid()
            ) OR
            public.is_doctor()
        )
    );

DROP POLICY IF EXISTS "Doctors can view all documents" ON clinical_documents;
CREATE POLICY "Doctors can view all documents"
    ON clinical_documents FOR SELECT
    USING (public.is_doctor());

DROP POLICY IF EXISTS "Doctors can insert documents" ON clinical_documents;
CREATE POLICY "Doctors can insert documents"
    ON clinical_documents FOR INSERT
    WITH CHECK (public.is_doctor());
