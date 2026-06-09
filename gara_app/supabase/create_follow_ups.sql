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

-- Permissive RLS: allow all operations (matching custom_auth.sql pattern)
CREATE POLICY "Allow all select" ON follow_ups FOR SELECT USING (true);
CREATE POLICY "Allow all insert" ON follow_ups FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow all update" ON follow_ups FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Allow all delete" ON follow_ups FOR DELETE USING (true);

-- Enable realtime for follow_ups table
ALTER PUBLICATION supabase_realtime ADD TABLE follow_ups;
