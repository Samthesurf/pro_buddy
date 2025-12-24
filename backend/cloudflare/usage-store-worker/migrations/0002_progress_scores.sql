-- Pro Buddy Usage Store - progress scores schema

-- Stores daily goal-progress percentage + model reasoning.
-- Date is stored as an ISO day string (YYYY-MM-DD) in UTC for simplicity.
CREATE TABLE IF NOT EXISTS progress_scores (
  user_id TEXT NOT NULL,
  date_utc TEXT NOT NULL,
  score_percent INTEGER NOT NULL,
  reason TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY (user_id, date_utc)
);

CREATE INDEX IF NOT EXISTS idx_progress_scores_user_date
  ON progress_scores(user_id, date_utc DESC);
