-- Optional per-user override for the daily voice quota (seconds).
-- NULL = use the function default (VOICE_DAILY_LIMIT_SEC env, 600).
-- Set via SQL editor, e.g.:
--   UPDATE profiles SET voice_limit_sec = 1800 WHERE email = 'me@example.com';

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS voice_limit_sec INTEGER;
