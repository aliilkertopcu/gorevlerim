-- ============================================
-- Group Description & Activity Log Migration
-- ============================================

-- 1. Add description column to groups
ALTER TABLE groups ADD COLUMN IF NOT EXISTS description TEXT;

-- 2. Group activity log table
CREATE TABLE IF NOT EXISTS group_activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  details TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_group_activity_log_group
  ON group_activity_log(group_id, created_at DESC);

-- 3. RLS for group_activity_log
ALTER TABLE group_activity_log ENABLE ROW LEVEL SECURITY;

-- Members can view activity logs of their groups
CREATE POLICY "Members can view group activity logs"
  ON group_activity_log FOR SELECT
  USING (
    group_id IN (SELECT public.get_my_group_ids())
  );

-- Members can insert activity logs for their groups
CREATE POLICY "Members can insert group activity logs"
  ON group_activity_log FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND group_id IN (SELECT public.get_my_group_ids())
  );
