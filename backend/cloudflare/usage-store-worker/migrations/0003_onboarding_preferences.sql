-- Migration: Add onboarding_preferences table
-- Stores user's onboarding data (challenges, habits, etc.) for future features

CREATE TABLE IF NOT EXISTS onboarding_preferences (
    user_id TEXT PRIMARY KEY,
    challenges TEXT DEFAULT '[]',  -- JSON array of challenge strings
    habits TEXT DEFAULT '[]',      -- JSON array of habit strings
    distraction_hours REAL DEFAULT 0,
    focus_duration_minutes REAL DEFAULT 0,
    goal_clarity INTEGER DEFAULT 5,
    productive_time TEXT DEFAULT 'Morning',
    check_in_frequency TEXT DEFAULT 'Daily',
    created_at INTEGER NOT NULL,   -- Unix timestamp (ms)
    updated_at INTEGER NOT NULL    -- Unix timestamp (ms)
);

CREATE INDEX IF NOT EXISTS idx_onboarding_preferences_updated_at ON onboarding_preferences(updated_at);
