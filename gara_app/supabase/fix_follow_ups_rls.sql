-- Step 1: Drop ALL existing policies on follow_ups
DROP POLICY IF EXISTS "Doctors can insert follow-ups" ON follow_ups;
DROP POLICY IF EXISTS "Users can read their own follow-ups" ON follow_ups;
DROP POLICY IF EXISTS "Patients can update their own reply" ON follow_ups;
DROP POLICY IF EXISTS "Allow all select" ON follow_ups;
DROP POLICY IF EXISTS "Allow all insert" ON follow_ups;
DROP POLICY IF EXISTS "Allow all update" ON follow_ups;
DROP POLICY IF EXISTS "Allow all delete" ON follow_ups;

-- Step 2: Create permissive policies (matching custom_auth.sql pattern)
CREATE POLICY "Allow all select" ON follow_ups FOR SELECT USING (true);
CREATE POLICY "Allow all insert" ON follow_ups FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow all update" ON follow_ups FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Allow all delete" ON follow_ups FOR DELETE USING (true);

-- Step 3: Enable realtime (safe to run multiple times)
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS follow_ups;
