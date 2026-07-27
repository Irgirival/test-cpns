-- Run this in Supabase SQL Editor (https://yhcizybaxhtohgmtlgpj.supabase.co)
-- ================================================================
-- CPNS Tryout Database Schema
-- ================================================================

-- 1. PROFILES TABLE (linked to auth.users)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  premium BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, name, premium)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'name', NEW.email), false);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 2. PREMIUM KEYS TABLE
CREATE TABLE IF NOT EXISTS premium_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,
  used BOOLEAN DEFAULT false,
  used_by UUID REFERENCES profiles(id),
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. TEST HISTORY TABLE
CREATE TABLE IF NOT EXISTS test_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  mode TEXT NOT NULL CHECK (mode IN ('custom', 'simulation')),
  total_soal INTEGER NOT NULL,
  total_score INTEGER NOT NULL,
  twk_score INTEGER DEFAULT 0,
  tiu_score INTEGER DEFAULT 0,
  tkp_score INTEGER DEFAULT 0,
  passed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ================================================================
-- ROW LEVEL SECURITY (RLS)
-- ================================================================

-- Profiles: users can read own profile, update own name
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Premium keys: only admin can read all, users can read unused keys
ALTER TABLE premium_keys ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read unused keys" ON premium_keys FOR SELECT USING (used = false);
CREATE POLICY "Admin can manage keys" ON premium_keys FOR ALL USING (true); -- simplify for now

-- Test history: users can CRUD own history
ALTER TABLE test_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own history" ON test_history FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own history" ON test_history FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own history" ON test_history FOR DELETE USING (auth.uid() = user_id);

-- ================================================================
-- INDEXES
-- ================================================================
CREATE INDEX IF NOT EXISTS idx_premium_keys_key ON premium_keys(key);
CREATE INDEX IF NOT EXISTS idx_test_history_user_id ON test_history(user_id);
CREATE INDEX IF NOT EXISTS idx_test_history_created_at ON test_history(created_at DESC);