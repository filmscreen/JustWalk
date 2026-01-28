-- ============================================
-- Just Walk - Supabase Schema
-- ============================================
-- Run these migrations in your Supabase SQL Editor
-- Identity Foundation + Tournament Leaderboards

-- ============================================
-- 0. PROFILES TABLE (Identity Foundation)
-- ============================================
-- Core user profile table linked to Supabase Auth
-- Keyed to auth.users UUID for Sign in with Apple integration

CREATE TABLE IF NOT EXISTS profiles (
    -- Primary key matches auth.users.id (Sign in with Apple UUID)
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Email from Apple (only available on first sign-in)
    email TEXT,

    -- Name fields (Apple only provides on first sign-in)
    -- Stored separately for flexible display formatting
    first_name TEXT,
    last_name TEXT,

    -- Pre-computed display name ("FirstName L." format)
    -- Updated via upsert from iOS app
    display_name TEXT,

    -- Subscription status (synced from StoreKit)
    is_pro BOOLEAN DEFAULT false,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for efficient display name lookups
CREATE INDEX IF NOT EXISTS idx_profiles_display_name
ON profiles(display_name);

-- Index for Pro status queries
CREATE INDEX IF NOT EXISTS idx_profiles_is_pro
ON profiles(is_pro) WHERE is_pro = true;

-- Enable RLS on profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Users can view all profiles (for leaderboards/Circles)
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON profiles;
CREATE POLICY "Profiles are viewable by everyone" ON profiles
    FOR SELECT USING (true);

-- Users can insert their own profile
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Users can update their own profile
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- Trigger to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS profiles_updated_at ON profiles;
CREATE TRIGGER profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- ============================================
-- 1. UPDATE daily_stats TABLE
-- ============================================

-- Add new columns if they don't exist
ALTER TABLE daily_stats
ADD COLUMN IF NOT EXISTS sync_date DATE,
ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT true;

-- Create composite unique constraint for upsert
-- This prevents duplicate entries for the same user on the same day
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'daily_stats_user_date_unique'
    ) THEN
        ALTER TABLE daily_stats
        ADD CONSTRAINT daily_stats_user_date_unique 
        UNIQUE (user_id, sync_date);
    END IF;
END $$;

-- Create index for efficient tournament queries
CREATE INDEX IF NOT EXISTS idx_daily_stats_user_date 
ON daily_stats(user_id, sync_date);

CREATE INDEX IF NOT EXISTS idx_daily_stats_verified 
ON daily_stats(is_verified) WHERE is_verified = true;


-- ============================================
-- 2. UPDATE leagues TABLE
-- ============================================

-- Add tournament type and finalization columns
ALTER TABLE leagues
ADD COLUMN IF NOT EXISTS tournament_type TEXT DEFAULT 'ongoing' 
    CHECK (tournament_type IN ('ongoing', 'fixed')),
ADD COLUMN IF NOT EXISTS is_finalized BOOLEAN DEFAULT false;

-- Create index for active tournaments
CREATE INDEX IF NOT EXISTS idx_leagues_active 
ON leagues(is_archived, is_finalized) 
WHERE is_archived = false AND is_finalized = false;


-- ============================================
-- 3. TOURNAMENT LEADERBOARD FUNCTION
-- ============================================

-- Function to calculate tournament standings
-- Returns ranked members with total verified steps within tournament date window
CREATE OR REPLACE FUNCTION get_tournament_standings(p_league_id UUID)
RETURNS TABLE (
    rank BIGINT,
    user_id UUID,
    display_name TEXT,
    total_steps BIGINT,
    total_distance DOUBLE PRECISION,
    days_active INT
) AS $$
BEGIN
    RETURN QUERY
    WITH tournament_dates AS (
        SELECT 
            COALESCE(l.start_date, l.created_at::DATE) as start_dt,
            COALESCE(l.end_date, CURRENT_DATE) as end_dt
        FROM leagues l
        WHERE l.id = p_league_id
    ),
    member_stats AS (
        SELECT 
            lm.user_id,
            p.display_name,
            COALESCE(SUM(ds.steps), 0)::BIGINT as total_steps,
            COALESCE(SUM(ds.distance), 0)::DOUBLE PRECISION as total_distance,
            COUNT(DISTINCT ds.sync_date)::INT as days_active
        FROM league_members lm
        LEFT JOIN daily_stats ds 
            ON ds.user_id = lm.user_id
            AND ds.sync_date >= (SELECT start_dt FROM tournament_dates)
            AND ds.sync_date <= (SELECT end_dt FROM tournament_dates)
            AND ds.is_verified = true
        LEFT JOIN profiles p ON p.id = lm.user_id
        WHERE lm.league_id = p_league_id
        GROUP BY lm.user_id, p.display_name
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY ms.total_steps DESC) as rank,
        ms.user_id,
        COALESCE(ms.display_name, 'Anonymous') as display_name,
        ms.total_steps,
        ms.total_distance,
        ms.days_active
    FROM member_stats ms
    ORDER BY ms.total_steps DESC;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- 4. FINALIZE TOURNAMENT FUNCTION
-- ============================================

-- Function to finalize a tournament and set the winner
-- Can only be called by the commissioner (verified via RLS)
CREATE OR REPLACE FUNCTION finalize_tournament(p_league_id UUID)
RETURNS VOID AS $$
DECLARE
    v_winner_id UUID;
BEGIN
    -- Get the user with highest steps
    SELECT user_id INTO v_winner_id
    FROM get_tournament_standings(p_league_id)
    WHERE rank = 1;
    
    -- Update the league
    UPDATE leagues
    SET 
        is_finalized = true,
        winner_id = v_winner_id
    WHERE id = p_league_id
      AND is_finalized = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================
-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Ensure users can only upsert their own daily_stats
ALTER TABLE daily_stats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view all daily stats" ON daily_stats;
CREATE POLICY "Users can view all daily stats" ON daily_stats
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert own stats" ON daily_stats;
CREATE POLICY "Users can insert own stats" ON daily_stats
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own stats" ON daily_stats;
CREATE POLICY "Users can update own stats" ON daily_stats
    FOR UPDATE USING (auth.uid() = user_id);

-- Ensure only commissioners can finalize their leagues
DROP POLICY IF EXISTS "Commissioners can finalize leagues" ON leagues;
CREATE POLICY "Commissioners can finalize leagues" ON leagues
    FOR UPDATE USING (auth.uid() = commissioner_id);


-- ============================================
-- 6. HELPER: Get User's Active Tournaments
-- ============================================

CREATE OR REPLACE FUNCTION get_user_active_tournaments(p_user_id UUID)
RETURNS TABLE (
    league_id UUID,
    league_name TEXT,
    member_count INT,
    user_rank BIGINT,
    user_steps BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.id as league_id,
        l.name as league_name,
        (SELECT COUNT(*)::INT FROM league_members WHERE league_id = l.id) as member_count,
        (SELECT rank FROM get_tournament_standings(l.id) WHERE user_id = p_user_id) as user_rank,
        (SELECT total_steps FROM get_tournament_standings(l.id) WHERE user_id = p_user_id) as user_steps
    FROM leagues l
    JOIN league_members lm ON lm.league_id = l.id
    WHERE lm.user_id = p_user_id
      AND l.is_archived = false
      AND l.is_finalized = false;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- 7. NOTIFICATIONS TABLE
-- ============================================
-- In-app notifications for Circles, achievements, and system messages

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN (
        'circle_invite',
        'leaderboard_update',
        'circle_activity',
        'achievement',
        'walk_reminder',
        'goal_reached',
        'system'
    )),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    circle_id UUID REFERENCES leagues(id) ON DELETE SET NULL,
    metadata JSONB
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_notifications_user
ON notifications(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_unread
ON notifications(user_id, is_read)
WHERE is_read = false;

CREATE INDEX IF NOT EXISTS idx_notifications_circle
ON notifications(circle_id)
WHERE circle_id IS NOT NULL;

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Users can only view their own notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

-- Users can update their own notifications (mark as read)
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own notifications
DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
CREATE POLICY "Users can delete own notifications" ON notifications
    FOR DELETE USING (auth.uid() = user_id);

-- System can insert notifications (via service role or triggers)
DROP POLICY IF EXISTS "Service can insert notifications" ON notifications;
CREATE POLICY "Service can insert notifications" ON notifications
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Enable realtime for notifications
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;


-- ============================================
-- 8. NOTIFICATION TRIGGERS
-- ============================================

-- Function to create notification when user joins a Circle
CREATE OR REPLACE FUNCTION notify_circle_join()
RETURNS TRIGGER AS $$
DECLARE
    v_league_name TEXT;
    v_commissioner_id UUID;
    v_joiner_name TEXT;
BEGIN
    -- Get league details
    SELECT name, commissioner_id INTO v_league_name, v_commissioner_id
    FROM leagues WHERE id = NEW.league_id;

    -- Get joiner's display name
    SELECT COALESCE(display_name, 'A new member') INTO v_joiner_name
    FROM profiles WHERE id = NEW.user_id;

    -- Notify the commissioner (if not joining their own Circle)
    IF NEW.user_id != v_commissioner_id THEN
        INSERT INTO notifications (user_id, type, title, body, circle_id)
        VALUES (
            v_commissioner_id,
            'circle_activity',
            'New Circle Member',
            v_joiner_name || ' joined ' || v_league_name,
            NEW.league_id
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for Circle joins
DROP TRIGGER IF EXISTS on_circle_join ON league_members;
CREATE TRIGGER on_circle_join
    AFTER INSERT ON league_members
    FOR EACH ROW
    EXECUTE FUNCTION notify_circle_join();


-- ============================================
-- 9. HELPER: Get Unread Notification Count
-- ============================================

CREATE OR REPLACE FUNCTION get_unread_notification_count(p_user_id UUID)
RETURNS INT AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INT
        FROM notifications
        WHERE user_id = p_user_id AND is_read = false
    );
END;
$$ LANGUAGE plpgsql;
