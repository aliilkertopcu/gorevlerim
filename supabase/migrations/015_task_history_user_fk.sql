-- task_history.user_id referenced auth.users without an ON DELETE rule, which made
-- deleting any user fail (FK violation). History rows should outlive the user:
-- keep them, null the reference (user_name column still carries the display name).

ALTER TABLE task_history ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE task_history DROP CONSTRAINT IF EXISTS task_history_user_id_fkey;
ALTER TABLE task_history
  ADD CONSTRAINT task_history_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
