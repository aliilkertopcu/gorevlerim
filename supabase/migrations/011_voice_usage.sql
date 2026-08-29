-- Voice-to-tasks daily quota tracking
-- Each row = one user's audio usage for one day (seconds transcribed).
-- Written by the voice-to-tasks Edge Function (service role); users can read their own.

CREATE TABLE voice_usage (
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  usage_date DATE NOT NULL DEFAULT CURRENT_DATE,
  seconds_used INTEGER NOT NULL DEFAULT 0,
  request_count INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, usage_date)
);

ALTER TABLE voice_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own voice usage"
  ON voice_usage FOR SELECT
  USING (user_id = auth.uid());

-- Atomic increment used by the Edge Function (service role bypasses RLS)
CREATE OR REPLACE FUNCTION increment_voice_usage(p_user_id UUID, p_seconds INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total INTEGER;
BEGIN
  INSERT INTO voice_usage (user_id, usage_date, seconds_used, request_count, updated_at)
  VALUES (p_user_id, CURRENT_DATE, p_seconds, 1, now())
  ON CONFLICT (user_id, usage_date) DO UPDATE
    SET seconds_used = voice_usage.seconds_used + EXCLUDED.seconds_used,
        request_count = voice_usage.request_count + 1,
        updated_at = now()
  RETURNING seconds_used INTO v_total;
  RETURN v_total;
END;
$$;

REVOKE ALL ON FUNCTION increment_voice_usage(UUID, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION increment_voice_usage(UUID, INTEGER) TO service_role;
