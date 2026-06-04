-- Migration: Add avatar_url to profiles, paid_at to consultations, notifications table
-- Run this in Supabase SQL Editor

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;

ALTER TABLE consultations ADD COLUMN IF NOT EXISTS paid_at TIMESTAMP WITH TIME ZONE;

CREATE TABLE IF NOT EXISTS notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    title VARCHAR NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR NOT NULL DEFAULT 'info',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can view own notifications') THEN
    CREATE POLICY "Users can view own notifications"
        ON notifications FOR SELECT
        USING (user_id = auth.uid());
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can update own notifications') THEN
    CREATE POLICY "Users can update own notifications"
        ON notifications FOR UPDATE
        USING (user_id = auth.uid());
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'System can insert notifications') THEN
    CREATE POLICY "System can insert notifications"
        ON notifications FOR INSERT
        WITH CHECK (true);
  END IF;
END $$;

ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
