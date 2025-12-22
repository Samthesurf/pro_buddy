-- Pro Buddy Usage Store - initial schema

-- Stores every usage feedback record returned by the backend monitor endpoint.
CREATE TABLE IF NOT EXISTS usage_feedback (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  package_name TEXT NOT NULL,
  app_name TEXT NOT NULL,
  alignment TEXT NOT NULL,
  message TEXT NOT NULL,
  reason TEXT,
  created_at_ms INTEGER NOT NULL,
  notification_sent INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_usage_feedback_user_time
  ON usage_feedback(user_id, created_at_ms DESC);

CREATE INDEX IF NOT EXISTS idx_usage_feedback_user_pkg
  ON usage_feedback(user_id, package_name);

-- Stores cooldown timestamps for notifications.
CREATE TABLE IF NOT EXISTS notification_cooldowns (
  user_id TEXT NOT NULL,
  package_name TEXT NOT NULL,
  alignment TEXT NOT NULL,
  last_sent_at_ms INTEGER NOT NULL,
  PRIMARY KEY (user_id, package_name, alignment)
);
