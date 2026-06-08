-- GARA FIX MIGRATION -- Run in Supabase SQL Editor
-- Fully idempotent (safe to run multiple times)

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS consultation_fee INTEGER DEFAULT 2000;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS reset_otp TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS reset_otp_expiry TIMESTAMPTZ;

ALTER TABLE consultations ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;

ALTER TABLE consultations ADD COLUMN IF NOT EXISTS momo_transaction_id TEXT;

ALTER TABLE consultations ADD COLUMN IF NOT EXISTS payment_amount NUMERIC(12,2);

ALTER TABLE consultations ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ;

ALTER TABLE clinical_documents ADD COLUMN IF NOT EXISTS patient_id TEXT;
CREATE INDEX IF NOT EXISTS idx_clinical_docs_patient ON clinical_documents(patient_id);

DO $$
BEGIN
  ALTER TABLE clinical_documents ALTER COLUMN document_kind TYPE TEXT;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

UPDATE clinical_documents cd
SET patient_id = c.patient_id
FROM consultations c
WHERE cd.consultation_id = c.id
  AND cd.patient_id IS NULL;

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS consultation_id INTEGER REFERENCES consultations(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_consultations_patient ON consultations(patient_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_consultations_status ON consultations(status);
