-- App Use Cases - Global cache for AI-generated app use cases
-- Shared across all users to avoid duplicate API calls

CREATE TABLE IF NOT EXISTS app_use_cases (
  package_name TEXT PRIMARY KEY,
  app_name TEXT NOT NULL,
  use_cases TEXT NOT NULL,  -- JSON array of strings e.g. ["Note-taking", "Project management"]
  category TEXT,            -- Optional category for filtering
  created_at_ms INTEGER NOT NULL
);

-- Index for searching by app name (partial matches in app)
CREATE INDEX IF NOT EXISTS idx_app_use_cases_name ON app_use_cases(app_name);
