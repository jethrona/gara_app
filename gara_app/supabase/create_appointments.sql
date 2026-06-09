CREATE TABLE IF NOT EXISTS appointments (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  patient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  doctor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  consultation_id BIGINT REFERENCES consultations(id) ON DELETE SET NULL,
  requested_date TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_appointments_patient_id ON appointments(patient_id);
CREATE INDEX IF NOT EXISTS idx_appointments_doctor_id ON appointments(doctor_id);
CREATE INDEX IF NOT EXISTS idx_appointments_status ON appointments(status);

ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can insert appointments" ON appointments
  FOR INSERT WITH CHECK (auth.uid() = patient_id);

CREATE POLICY "Users can read their own appointments" ON appointments
  FOR SELECT USING (auth.uid() = patient_id OR auth.uid() = doctor_id);

CREATE POLICY "Doctors can update appointment status" ON appointments
  FOR UPDATE USING (auth.uid() = doctor_id)
  WITH CHECK (auth.uid() = doctor_id AND status IN ('confirmed', 'cancelled', 'completed'));
