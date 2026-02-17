-- ============================================
-- Group Improvements Migration
-- ============================================

-- 1. Add settings JSONB column to groups (for future settings like auto_postpone)
ALTER TABLE groups ADD COLUMN IF NOT EXISTS settings JSONB DEFAULT '{}';

-- 2. Allow users to view profiles of their group members
CREATE POLICY "Users can view group members profiles"
  ON profiles FOR SELECT
  USING (
    id IN (
      SELECT gm.user_id FROM group_members gm
      WHERE gm.group_id IN (SELECT public.get_my_group_ids())
    )
  );

-- 3. Allow group creator to remove members (in addition to users leaving themselves)
DROP POLICY IF EXISTS "Users can leave groups" ON group_members;
CREATE POLICY "Users can leave or creator can remove members"
  ON group_members FOR DELETE
  USING (
    auth.uid() = user_id
    OR
    group_id IN (SELECT id FROM groups WHERE created_by = auth.uid())
  );
