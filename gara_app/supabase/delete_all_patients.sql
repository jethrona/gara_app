-- ═══════════════════════════════════════════════════════════════════════════
-- DELETE ALL PATIENT DATA — keeps only the doctor profile.
-- Run in Supabase SQL Editor.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- 1. Delete notifications for patient consultations
DELETE FROM notifications
WHERE user_id IN (SELECT id FROM profiles WHERE is_doctor = false);

-- 2. Delete messages in patient consultations
DELETE FROM messages
WHERE consultation_id IN (
  SELECT id FROM consultations WHERE patient_id IN (
    SELECT id FROM profiles WHERE is_doctor = false
  )
);

-- 3. Delete clinical documents for patient consultations
DELETE FROM clinical_documents
WHERE consultation_id IN (
  SELECT id FROM consultations WHERE patient_id IN (
    SELECT id FROM profiles WHERE is_doctor = false
  )
);

-- 4. Delete patient consultations
DELETE FROM consultations
WHERE patient_id IN (SELECT id FROM profiles WHERE is_doctor = false);

-- 5. Delete patient profiles
DELETE FROM profiles
WHERE is_doctor = false;

COMMIT;

-- Verify: only doctor remains
SELECT id, full_name, phone_number, is_doctor FROM profiles;
