-- Goal Journeys feature - stores user journey toward their goals

-- Goal journeys table - stores the overall journey metadata
CREATE TABLE IF NOT EXISTS goal_journeys (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    goal_id TEXT,
    goal_content TEXT NOT NULL,
    goal_reason TEXT,
    current_step_index INTEGER DEFAULT 0,
    overall_progress REAL DEFAULT 0.0,
    is_ai_generated INTEGER DEFAULT 1,
    ai_notes TEXT,
    map_width REAL DEFAULT 1000.0,
    map_height REAL DEFAULT 2000.0,
    journey_started_at TEXT NOT NULL DEFAULT (datetime('now')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_journeys_user ON goal_journeys(user_id);
CREATE INDEX IF NOT EXISTS idx_journeys_goal ON goal_journeys(goal_id);

-- Goal steps table - stores individual steps in a journey
CREATE TABLE IF NOT EXISTS goal_steps (
    id TEXT PRIMARY KEY,
    journey_id TEXT NOT NULL,
    title TEXT NOT NULL,
    custom_title TEXT,
    description TEXT,
    order_index INTEGER NOT NULL,
    status TEXT DEFAULT 'locked',
    prerequisites TEXT, -- JSON array of step IDs
    alternatives TEXT, -- JSON array of step IDs
    started_at TEXT,
    completed_at TEXT,
    notes TEXT, -- JSON array of notes
    metadata TEXT, -- JSON object with AI context
    position_x REAL DEFAULT 0.5,
    position_y REAL DEFAULT 0.0,
    position_layer INTEGER DEFAULT 0,
    path_type TEXT DEFAULT 'main',
    estimated_days INTEGER DEFAULT 14,
    actual_days_spent INTEGER,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (journey_id) REFERENCES goal_journeys(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_steps_journey ON goal_steps(journey_id);
CREATE INDEX IF NOT EXISTS idx_steps_status ON goal_steps(status);
CREATE INDEX IF NOT EXISTS idx_steps_order ON goal_steps(journey_id, order_index);

-- Step progress log - tracks daily progress entries linked to steps
CREATE TABLE IF NOT EXISTS step_progress_log (
    id TEXT PRIMARY KEY,
    step_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    note TEXT NOT NULL,
    logged_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (step_id) REFERENCES goal_steps(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_progress_step ON step_progress_log(step_id);
CREATE INDEX IF NOT EXISTS idx_progress_user ON step_progress_log(user_id, logged_at DESC);
