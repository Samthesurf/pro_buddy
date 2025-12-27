-- Migration: Add persistent storage for users, goals, and app_selections
-- These replace in-memory storage that was lost on server restart

-- Users table - stores user profile data
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,                      -- Firebase UID
    email TEXT NOT NULL,
    display_name TEXT,
    photo_url TEXT,
    onboarding_complete INTEGER DEFAULT 0,    -- 0 = false, 1 = true
    created_at INTEGER NOT NULL,              -- Unix timestamp (ms)
    updated_at INTEGER NOT NULL               -- Unix timestamp (ms)
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Goals table - stores user goals from onboarding
CREATE TABLE IF NOT EXISTS goals (
    id TEXT PRIMARY KEY,                      -- UUID for goal
    user_id TEXT NOT NULL,                    -- Firebase UID
    content TEXT NOT NULL,                    -- Goal description
    reason TEXT,                              -- Why this goal matters
    timeline TEXT,                            -- When to achieve
    created_at INTEGER NOT NULL,              -- Unix timestamp (ms)
    updated_at INTEGER NOT NULL               -- Unix timestamp (ms)
);

CREATE INDEX IF NOT EXISTS idx_goals_user_id ON goals(user_id);

-- App selections table - stores user's selected apps during onboarding
CREATE TABLE IF NOT EXISTS app_selections (
    id TEXT PRIMARY KEY,                      -- UUID for selection
    user_id TEXT NOT NULL,                    -- Firebase UID
    package_name TEXT NOT NULL,               -- Android package name
    app_name TEXT NOT NULL,                   -- Display name
    reason TEXT,                              -- Why user selected this app
    importance_rating INTEGER DEFAULT 3,      -- 1-5 rating
    created_at INTEGER NOT NULL,              -- Unix timestamp (ms)
    updated_at INTEGER NOT NULL               -- Unix timestamp (ms)
);

CREATE INDEX IF NOT EXISTS idx_app_selections_user_id ON app_selections(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_app_selections_user_package 
    ON app_selections(user_id, package_name);

-- Notification profiles table - stores goal discovery conversation results
CREATE TABLE IF NOT EXISTS notification_profiles (
    user_id TEXT PRIMARY KEY,                 -- Firebase UID
    profile_data TEXT NOT NULL DEFAULT '{}',  -- JSON blob with all profile fields
    created_at INTEGER NOT NULL,              -- Unix timestamp (ms)
    updated_at INTEGER NOT NULL               -- Unix timestamp (ms)
);
