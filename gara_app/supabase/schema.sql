-- Gara Database Schema
-- Execute this in your Supabase SQL Editor

-- Create Consultation State Enumeration
CREATE TYPE care_status AS ENUM ('pending_payment', 'in_process', 'complete');
CREATE TYPE doc_type AS ENUM ('prescription', 'transfer_slip');

-- 1. Profiles Table (Handles Patients and the Single Doctor)
CREATE TABLE profiles (
    id UUID PRIMARY KEY, -- Maps to Supabase Auth User ID
    phone_number VARCHAR UNIQUE NOT NULL,
    full_name VARCHAR NOT NULL,
    is_doctor BOOLEAN DEFAULT FALSE,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Consultation Management Tracking Table
CREATE TABLE consultations (
    id BIGSERIAL PRIMARY KEY,
    patient_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    status care_status DEFAULT 'pending_payment',
    biological_sex VARCHAR NOT NULL,
    severity_level VARCHAR NOT NULL,
    duration_symptoms VARCHAR NOT NULL,
    ai_brief_summary TEXT,
    momo_transaction_id VARCHAR UNIQUE,
    payment_amount DECIMAL(10,2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    paid_at TIMESTAMP WITH TIME ZONE,
    closed_at TIMESTAMP WITH TIME ZONE
);

-- 3. Polymorphic Multimedia Chat Messages Table
CREATE TABLE messages (
    id BIGSERIAL PRIMARY KEY,
    consultation_id INT REFERENCES consultations(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    message_type VARCHAR CHECK (message_type IN ('text', 'voice', 'photo')),
    content TEXT NOT NULL, -- Stores text message string OR Supabase Storage URL link
    duration_seconds INT DEFAULT 0, -- Only used for voice clips
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Clinical PDF Documents Map Table
CREATE TABLE clinical_documents (
    id BIGSERIAL PRIMARY KEY,
    consultation_id INT REFERENCES consultations(id) ON DELETE CASCADE,
    patient_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    document_kind doc_type NOT NULL,
    pdf_storage_url TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_documents ENABLE ROW LEVEL SECURITY;

-- Helper function to check doctor role (SECURITY DEFINER avoids RLS recursion)
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

-- RLS Policies for Profiles
CREATE POLICY "Users can view own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Doctors can view all profiles"
    ON profiles FOR SELECT
    USING (public.is_doctor());

-- RLS Policies for Consultations
CREATE POLICY "Patients can view own consultations"
    ON consultations FOR SELECT
    USING (patient_id = auth.uid());

CREATE POLICY "Patients can insert own consultations"
    ON consultations FOR INSERT
    WITH CHECK (patient_id = auth.uid());

CREATE POLICY "Doctors can view all consultations"
    ON consultations FOR SELECT
    USING (public.is_doctor());

CREATE POLICY "Doctors can update consultations"
    ON consultations FOR UPDATE
    USING (public.is_doctor());

-- RLS Policies for Messages
CREATE POLICY "Users can view messages in their consultations"
    ON messages FOR SELECT
    USING (
        consultation_id IN (
            SELECT id FROM consultations
            WHERE patient_id = auth.uid()
        ) OR
        public.is_doctor()
    );

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

-- RLS Policies for Clinical Documents
CREATE POLICY "Patients can view own documents"
    ON clinical_documents FOR SELECT
    USING (patient_id = auth.uid());

CREATE POLICY "Doctors can view all documents"
    ON clinical_documents FOR SELECT
    USING (public.is_doctor());

CREATE POLICY "Doctors can insert documents"
    ON clinical_documents FOR INSERT
    WITH CHECK (public.is_doctor());

-- Enable realtime for all tables
ALTER PUBLICATION supabase_realtime ADD TABLE consultations;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;

-- Create indexes for performance
CREATE INDEX idx_consultations_patient_id ON consultations(patient_id);
CREATE INDEX idx_consultations_status ON consultations(status);
CREATE INDEX idx_consultations_created_at ON consultations(created_at DESC);
CREATE INDEX idx_messages_consultation_id ON messages(consultation_id);
CREATE INDEX idx_clinical_documents_patient_id ON clinical_documents(patient_id);
CREATE INDEX idx_clinical_documents_consultation_id ON clinical_documents(consultation_id);

-- 6. Notifications Table
CREATE TABLE notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    title VARCHAR NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR NOT NULL DEFAULT 'info',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications"
    ON notifications FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can update own notifications"
    ON notifications FOR UPDATE
    USING (user_id = auth.uid());

CREATE POLICY "System can insert notifications"
    ON notifications FOR INSERT
    WITH CHECK (true);

ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
