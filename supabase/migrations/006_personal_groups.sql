-- ============================================
-- Personal Groups & Show Past Incomplete
-- ============================================

-- 1. Add is_personal column to groups
ALTER TABLE groups ADD COLUMN IF NOT EXISTS is_personal BOOLEAN DEFAULT false;

-- 2. Create personal groups for all existing users who don't have one
INSERT INTO groups (name, color, created_by, is_personal)
SELECT
  'Günlük Görevler',
  '#667eea',
  p.id,
  true
FROM profiles p
WHERE NOT EXISTS (
  SELECT 1 FROM groups g WHERE g.created_by = p.id AND g.is_personal = true
);

-- 3. Add creator as member of their own personal group
INSERT INTO group_members (group_id, user_id)
SELECT g.id, g.created_by
FROM groups g
WHERE g.is_personal = true
AND NOT EXISTS (
  SELECT 1 FROM group_members gm WHERE gm.group_id = g.id AND gm.user_id = g.created_by
);

-- 4. Migrate personal tasks to personal groups
UPDATE tasks
SET owner_id = g.id::text, owner_type = 'group'
FROM groups g
WHERE tasks.owner_type = 'user'
  AND tasks.owner_id = g.created_by::text
  AND g.is_personal = true;

-- 5. Auto-create personal group for new users (trigger)
CREATE OR REPLACE FUNCTION create_personal_group()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_group_id UUID;
BEGIN
  INSERT INTO groups (name, color, created_by, is_personal)
  VALUES ('Günlük Görevler', '#667eea', NEW.id, true)
  RETURNING id INTO new_group_id;

  INSERT INTO group_members (group_id, user_id)
  VALUES (new_group_id, NEW.id);

  RETURN NEW;
END;
$$;

-- Drop trigger if exists, then create
DROP TRIGGER IF EXISTS on_profile_created_personal_group ON profiles;
CREATE TRIGGER on_profile_created_personal_group
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION create_personal_group();

-- 6. Prevent adding other members to personal groups (RLS enhancement)
-- We'll handle this in the application layer since group_members RLS
-- already restricts inserts to group creators only
