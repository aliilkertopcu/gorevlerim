-- Make user deletion possible: creator references become NULL instead of blocking,
-- and a user's personal group (with its tasks) is removed together with the profile.

ALTER TABLE groups DROP CONSTRAINT IF EXISTS groups_created_by_fkey;
ALTER TABLE groups
  ADD CONSTRAINT groups_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_created_by_fkey;
ALTER TABLE tasks
  ADD CONSTRAINT tasks_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.delete_personal_group_on_profile_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- tasks/subtasks of the personal group are removed by the app-level cascade below
  DELETE FROM public.tasks
   WHERE owner_type = 'group'
     AND owner_id IN (SELECT id FROM public.groups WHERE created_by = OLD.id AND is_personal = true);
  DELETE FROM public.groups WHERE created_by = OLD.id AND is_personal = true;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS on_profile_deleted_personal_group ON profiles;
CREATE TRIGGER on_profile_deleted_personal_group
  BEFORE DELETE ON profiles
  FOR EACH ROW EXECUTE FUNCTION public.delete_personal_group_on_profile_delete();
