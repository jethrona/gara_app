CREATE TABLE IF NOT EXISTS follow_ups (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  consultation_id BIGINT NOT NULL REFERENCES consultations(id) ON DELETE CASCADE,
  doctor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  patient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  doctor_message TEXT NOT NULL,
  patient_reply TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  replied_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_follow_ups_patient_id ON follow_ups(patient_id);
CREATE INDEX IF NOT EXISTS idx_follow_ups_doctor_id ON follow_ups(doctor_id);
CREATE INDEX IF NOT EXISTS idx_follow_ups_consultation_id ON follow_ups(consultation_id);

ALTER TABLE follow_ups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Doctors can insert follow-ups" ON follow_ups
  FOR INSERT WITH CHECK (auth.uid() = doctor_id);

CREATE POLICY "Users can read their own follow-ups" ON follow_ups
  FOR SELECT USING (auth.uid() = doctor_id OR auth.uid() = patient_id);

CREATE POLICY "Patients can update their own reply" ON follow_ups
  FOR UPDATE USING (auth.uid() = patient_id)
  WITH CHECK (auth.uid() = patient_id AND patient_reply IS NOT NULL AND replied_at IS NOT NULL);
