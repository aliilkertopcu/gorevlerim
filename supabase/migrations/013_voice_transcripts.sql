-- Voice recording history: transcript + AI proposal, for review and debugging.
-- Written by the voice-to-tasks Edge Function (service role); users read their own.

CREATE TABLE voice_transcripts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  group_id UUID REFERENCES groups(id) ON DELETE SET NULL,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  transcript TEXT NOT NULL,
  proposal JSONB NOT NULL DEFAULT '{}'::jsonb,
  stt_model TEXT,
  llm_model TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX voice_transcripts_user_created_idx ON voice_transcripts (user_id, created_at DESC);

ALTER TABLE voice_transcripts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own voice transcripts"
  ON voice_transcripts FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete own voice transcripts"
  ON voice_transcripts FOR DELETE
  USING (user_id = auth.uid());
