-- Supabase SQL Migration for Just Walk - Social Circles
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor)
-- Version: 2.0 - Full multi-user Circles support

---------------------------------------------------
-- PROFILES TABLE (User information)
---------------------------------------------------

CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT,
  display_name TEXT,
  is_pro BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view all profiles"
  ON profiles FOR SELECT
  USING (true);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Grant access
GRANT SELECT, INSERT, UPDATE ON profiles TO authenticated;

-- Create profile automatically when user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, display_name)
  VALUES (new.id, new.email, COALESCE(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)));
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user registration
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

---------------------------------------------------
-- DAILY STATS TABLE (Step tracking)

-- Create daily_stats table for tracking user steps per day
CREATE TABLE IF NOT EXISTS daily_stats (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,
  steps INT DEFAULT 0,
  distance DOUBLE PRECISION DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  -- Ensure one row per user per day
  UNIQUE(user_id, date)
);

-- Create index for faster queries by user and date range
CREATE INDEX IF NOT EXISTS idx_daily_stats_user_date 
  ON daily_stats(user_id, date DESC);

-- Enable Row Level Security
ALTER TABLE daily_stats ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read all members' stats (for leaderboards)
CREATE POLICY "Users can view all daily stats" 
  ON daily_stats FOR SELECT 
  USING (true);

-- Policy: Users can only insert/update their own stats
CREATE POLICY "Users can insert own stats" 
  ON daily_stats FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own stats" 
  ON daily_stats FOR UPDATE 
  USING (auth.uid() = user_id);

-- Grant access to authenticated users
GRANT SELECT, INSERT, UPDATE ON daily_stats TO authenticated;

---------------------------------------------------
-- LEAGUES TABLES (if not already created)
---------------------------------------------------

-- Leagues table
CREATE TABLE IF NOT EXISTS leagues (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  code TEXT UNIQUE NOT NULL,
  commissioner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  start_date TIMESTAMP WITH TIME ZONE,
  end_date TIMESTAMP WITH TIME ZONE,
  is_archived BOOLEAN DEFAULT false,
  is_finalized BOOLEAN DEFAULT false,
  winner_id UUID REFERENCES auth.users(id),
  parent_circle_id UUID REFERENCES leagues(id),
  season_number INT DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Index for finding leagues by invite code
CREATE INDEX IF NOT EXISTS idx_leagues_code ON leagues(code);

-- Index for finding child seasons of a parent circle
CREATE INDEX IF NOT EXISTS idx_leagues_parent ON leagues(parent_circle_id);

-- League members table
CREATE TABLE IF NOT EXISTS league_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  league_id UUID REFERENCES leagues(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  display_name TEXT NOT NULL,
  is_pro BOOLEAN DEFAULT false,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  UNIQUE(league_id, user_id)
);

-- Enable RLS on leagues tables
ALTER TABLE leagues ENABLE ROW LEVEL SECURITY;
ALTER TABLE league_members ENABLE ROW LEVEL SECURITY;

-- Leagues policies
CREATE POLICY "Users can view leagues they're in" 
  ON leagues FOR SELECT 
  USING (
    id IN (SELECT league_id FROM league_members WHERE user_id = auth.uid())
    OR commissioner_id = auth.uid()
  );

CREATE POLICY "Users can create leagues" 
  ON leagues FOR INSERT 
  WITH CHECK (auth.uid() = commissioner_id);

CREATE POLICY "Commissioners can update their leagues" 
  ON leagues FOR UPDATE 
  USING (auth.uid() = commissioner_id);

-- League members policies  
CREATE POLICY "Users can view league members"
  ON league_members FOR SELECT
  USING (true);

CREATE POLICY "Users can join leagues"
  ON league_members FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave leagues"
  ON league_members FOR DELETE
  USING (auth.uid() = user_id);

-- Grant access
GRANT SELECT, INSERT, UPDATE, DELETE ON leagues TO authenticated;
GRANT SELECT, INSERT, DELETE ON league_members TO authenticated;

---------------------------------------------------
-- MIGRATION FOR EXISTING TABLES (run if upgrading)
---------------------------------------------------
-- If you already have the tables, run these ALTER statements to add new columns:

-- ALTER TABLE leagues ADD COLUMN IF NOT EXISTS is_finalized BOOLEAN DEFAULT false;
-- ALTER TABLE leagues ADD COLUMN IF NOT EXISTS parent_circle_id UUID REFERENCES leagues(id);
-- ALTER TABLE leagues ADD COLUMN IF NOT EXISTS season_number INT DEFAULT 1;

-- Upgrade start_date and end_date from DATE to TIMESTAMP if needed:
-- ALTER TABLE leagues ALTER COLUMN start_date TYPE TIMESTAMP WITH TIME ZONE;
-- ALTER TABLE leagues ALTER COLUMN end_date TYPE TIMESTAMP WITH TIME ZONE;
