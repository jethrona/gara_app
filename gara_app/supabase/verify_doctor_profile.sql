-- ═══════════════════════════════════════════════════════════════════════════
-- RUN THIS IN SUPABASE SQL EDITOR
-- Shows what is stored for the doctor row and fixes null values.
-- ═══════════════════════════════════════════════════════════════════════════

-- Step 1: See the doctor's raw row
SELECT 
  id,
  full_name,
  clinic_name,
  phone_number,
  consultation_fee,
  is_doctor
FROM profiles
WHERE is_doctor = true;

-- Step 2: See ALL columns on the profiles table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles'
ORDER BY ordinal_position;

-- Step 3: Ensure columns exist with correct names
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS clinic_name TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_number TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS consultation_fee INTEGER DEFAULT 2000;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_doctor BOOLEAN DEFAULT false;

-- Step 4: Back-fill null values for the doctor (replace with real values)
UPDATE profiles
SET 
  full_name    = COALESCE(NULLIF(full_name, ''), 'Dr. GARA'),
  clinic_name  = COALESCE(NULLIF(clinic_name, ''), 'GARA Health Center'),
  phone_number = COALESCE(NULLIF(phone_number, ''), '0788000000'),
  consultation_fee = COALESCE(consultation_fee, 2000)
WHERE is_doctor = true;

-- Step 5: Verify the result
SELECT id, full_name, clinic_name, phone_number, consultation_fee, is_doctor
FROM profiles
WHERE is_doctor = true;
