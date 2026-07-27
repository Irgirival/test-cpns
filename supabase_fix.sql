-- RUN THIS IN SUPABASE SQL EDITOR: https://yhcizybaxhtohgmtlgpj.supabase.com
-- Fix: remove trigger, use app-side profile creation

-- 1. Drop the trigger that's causing 500 errors
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

-- 2. Recreate profiles table (simpler, no FK constraint issues)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  premium BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Premium keys table
CREATE TABLE IF NOT EXISTS premium_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,
  used BOOLEAN DEFAULT false,
  used_by UUID,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Test history table
CREATE TABLE IF NOT EXISTS test_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  mode TEXT NOT NULL CHECK (mode IN ('custom', 'simulation')),
  total_soal INTEGER NOT NULL,
  total_score INTEGER NOT NULL,
  twk_score INTEGER DEFAULT 0,
  tiu_score INTEGER DEFAULT 0,
  tkp_score INTEGER DEFAULT 0,
  passed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. RLS Policies (allow insert from app)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can read own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Enable insert for authenticated" ON profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable read own" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Enable update own" ON profiles FOR UPDATE USING (auth.uid() = id);

ALTER TABLE premium_keys ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read unused keys" ON premium_keys;
DROP POLICY IF EXISTS "Admin can manage keys" ON premium_keys;
CREATE POLICY "Enable all for authenticated" ON premium_keys FOR ALL USING (true);

ALTER TABLE test_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can read own history" ON test_history;
DROP POLICY IF EXISTS "Users can insert own history" ON test_history;
DROP POLICY IF EXISTS "Users can delete own history" ON test_history;
CREATE POLICY "Enable insert own" ON test_history FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Enable read own" ON test_history FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Enable delete own" ON test_history FOR DELETE USING (auth.uid() = user_id);

-- 6. Indexes
CREATE INDEX IF NOT EXISTS idx_premium_keys_key ON premium_keys(key);
CREATE INDEX IF NOT EXISTS idx_test_history_user_id ON test_history(user_id);
CREATE INDEX IF NOT EXISTS idx_test_history_created_at ON test_history(created_at DESC);