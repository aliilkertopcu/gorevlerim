-- ============================================
-- Permissions & Invite Links Migration
-- ============================================

-- 1. Add locked column to tasks
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS locked BOOLEAN DEFAULT false;

-- 2. Group invites table
CREATE TABLE IF NOT EXISTS group_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  token TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(16), 'hex'),
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_group_invites_token ON group_invites(token);
CREATE INDEX IF NOT EXISTS idx_group_invites_group ON group_invites(group_id);

-- 3. RLS for group_invites
ALTER TABLE group_invites ENABLE ROW LEVEL SECURITY;

-- Anyone can read invites (needed for token lookup by unauthenticated preview)
CREATE POLICY "Anyone can view invites by token"
  ON group_invites FOR SELECT
  USING (true);

-- Only group creator can create invites
CREATE POLICY "Group creator can create invites"
  ON group_invites FOR INSERT
  WITH CHECK (
    auth.uid() = created_by
    AND group_id IN (
      SELECT id FROM groups WHERE created_by = auth.uid()
    )
  );

-- Only group creator can delete invites
CREATE POLICY "Group creator can delete invites"
  ON group_invites FOR DELETE
  USING (
    group_id IN (
      SELECT id FROM groups WHERE created_by = auth.uid()
    )
  );
