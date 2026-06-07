-- ═══════════════════════════════════════════════════════════════════════════
-- RUN THIS IN SUPABASE SQL EDITOR
-- First adds missing columns, then shows/fixes doctor data.
-- ═══════════════════════════════════════════════════════════════════════════

-- Step 1: Ensure columns exist before querying them
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS clinic_name TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_number TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS consultation_fee INTEGER DEFAULT 2000;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_doctor BOOLEAN DEFAULT false;

-- Step 2: See the doctor's raw row (now safe, columns exist)
SELECT 
  id,
  full_name,
  clinic_name,
  phone_number,
  consultation_fee,
  is_doctor
FROM profiles
WHERE is_doctor = true;

-- Step 3: Back-fill null values for the doctor (replace with real values)
UPDATE profiles
SET 
  full_name    = COALESCE(NULLIF(full_name, ''), 'Dr. GARA'),
  clinic_name  = COALESCE(NULLIF(clinic_name, ''), 'GARA Health Center'),
  phone_number = COALESCE(NULLIF(phone_number, ''), '0788000000'),
  consultation_fee = COALESCE(consultation_fee, 2000)
WHERE is_doctor = true;

-- Step 4: Verify the result
SELECT id, full_name, clinic_name, phone_number, consultation_fee, is_doctor
FROM profiles
WHERE is_doctor = true;
