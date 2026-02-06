-- API Keys table for AI integration
-- Each user can have one API key to use with Claude/ChatGPT

CREATE TABLE api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  key TEXT UNIQUE NOT NULL,
  name TEXT DEFAULT 'Varsayılan',
  created_at TIMESTAMPTZ DEFAULT now(),
  last_used_at TIMESTAMPTZ
);

-- Each user can have only one key (for simplicity)
CREATE UNIQUE INDEX api_keys_user_id_unique ON api_keys(user_id);

-- Index for fast key lookup
CREATE INDEX api_keys_key_idx ON api_keys(key);

-- Enable RLS
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;

-- Users can only see and manage their own keys
CREATE POLICY "Users can view own api keys"
  ON api_keys FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own api keys"
  ON api_keys FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own api keys"
  ON api_keys FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete own api keys"
  ON api_keys FOR DELETE
  USING (user_id = auth.uid());

-- Allow service role to access all keys (for Edge Function)
-- This is automatic with service_role key
