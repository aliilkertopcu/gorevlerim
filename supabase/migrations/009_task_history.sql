-- ============================================
-- Task History — DB Trigger-based Audit Trail
-- ============================================

-- 1. task_history table
CREATE TABLE task_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  subtask_id UUID REFERENCES subtasks(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  user_name TEXT NOT NULL DEFAULT '',
  action TEXT NOT NULL,
  details TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_task_history_task ON task_history(task_id, created_at DESC);
CREATE INDEX idx_task_history_subtask ON task_history(subtask_id, created_at DESC);

-- RLS
ALTER TABLE task_history ENABLE ROW LEVEL SECURITY;

-- Users can view history for tasks they can access (own tasks + group tasks)
CREATE POLICY "Users can view task history"
  ON task_history FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM tasks t
      WHERE t.id = task_history.task_id
      AND (
        (t.owner_type = 'user' AND t.owner_id = auth.uid())
        OR
        (t.owner_type = 'group' AND t.owner_id IN (SELECT public.get_my_group_ids()))
      )
    )
  );

-- Only triggers insert (no direct user inserts needed, but allow for SECURITY DEFINER)
CREATE POLICY "System can insert task history"
  ON task_history FOR INSERT
  WITH CHECK (true);

-- ============================================
-- 2. Task trigger: log_task_changes
-- ============================================
CREATE OR REPLACE FUNCTION log_task_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_user_name TEXT;
  v_action TEXT;
  v_details TEXT;
  v_group_name TEXT;
  v_old_group_name TEXT;
BEGIN
  -- Get current user
  v_user_id := COALESCE(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid);
  SELECT COALESCE(display_name, email, '') INTO v_user_name
    FROM profiles WHERE id = v_user_id;

  IF TG_OP = 'INSERT' THEN
    INSERT INTO task_history (task_id, user_id, user_name, action, details)
    VALUES (NEW.id, v_user_id, COALESCE(v_user_name, ''), 'task_created', '"' || NEW.title || '"');
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    -- Skip sort_order-only or updated_at-only changes
    IF OLD.title = NEW.title
       AND OLD.description IS NOT DISTINCT FROM NEW.description
       AND OLD.status = NEW.status
       AND OLD.owner_id = NEW.owner_id
       AND OLD.date = NEW.date
       AND OLD.locked IS NOT DISTINCT FROM NEW.locked
       AND OLD.block_reason IS NOT DISTINCT FROM NEW.block_reason
    THEN
      RETURN NEW;
    END IF;

    -- Status changes
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      IF NEW.status = 'completed' THEN
        v_action := 'task_completed';
        v_details := '"' || NEW.title || '"';
      ELSIF OLD.status = 'completed' AND NEW.status = 'pending' THEN
        v_action := 'task_uncompleted';
        v_details := '"' || NEW.title || '"';
      ELSIF NEW.status = 'blocked' THEN
        v_action := 'task_blocked';
        v_details := COALESCE(NEW.block_reason, '');
      ELSIF OLD.status = 'blocked' AND NEW.status = 'pending' THEN
        v_action := 'task_unblocked';
        v_details := '"' || NEW.title || '"';
      ELSIF NEW.status = 'postponed' THEN
        v_action := 'task_deleted';
        v_details := '"' || NEW.title || '"';
      END IF;

      IF v_action IS NOT NULL THEN
        INSERT INTO task_history (task_id, user_id, user_name, action, details)
        VALUES (NEW.id, v_user_id, COALESCE(v_user_name, ''), v_action, v_details);
      END IF;
    END IF;

    -- Owner change (moved to different group/user)
    IF OLD.owner_id IS DISTINCT FROM NEW.owner_id THEN
      -- Lookup group names
      SELECT name INTO v_group_name FROM groups WHERE id = NEW.owner_id;
      SELECT name INTO v_old_group_name FROM groups WHERE id = OLD.owner_id;
      v_details := COALESCE(v_old_group_name, 'Kişisel') || ' → ' || COALESCE(v_group_name, 'Kişisel');

      INSERT INTO task_history (task_id, user_id, user_name, action, details)
      VALUES (NEW.id, v_user_id, COALESCE(v_user_name, ''), 'task_moved', v_details);
    END IF;

    -- Date change (postponed)
    IF OLD.date IS DISTINCT FROM NEW.date THEN
      v_details := TO_CHAR(OLD.date, 'DD.MM.YYYY') || ' → ' || TO_CHAR(NEW.date, 'DD.MM.YYYY');

      INSERT INTO task_history (task_id, user_id, user_name, action, details)
      VALUES (NEW.id, v_user_id, COALESCE(v_user_name, ''), 'task_postponed', v_details);
    END IF;

    -- Lock change
    IF OLD.locked IS DISTINCT FROM NEW.locked THEN
      v_action := CASE WHEN NEW.locked THEN 'task_locked' ELSE 'task_unlocked' END;

      INSERT INTO task_history (task_id, user_id, user_name, action, details)
      VALUES (NEW.id, v_user_id, COALESCE(v_user_name, ''), v_action, '"' || NEW.title || '"');
    END IF;

    -- Title or description change
    IF OLD.title IS DISTINCT FROM NEW.title OR OLD.description IS DISTINCT FROM NEW.description THEN
      v_details := '';
      IF OLD.title IS DISTINCT FROM NEW.title THEN
        v_details := '"' || OLD.title || '" → "' || NEW.title || '"';
      END IF;

      INSERT INTO task_history (task_id, user_id, user_name, action, details)
      VALUES (NEW.id, v_user_id, COALESCE(v_user_name, ''), 'task_edited', v_details);
    END IF;

    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_task_change
  AFTER INSERT OR UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION log_task_changes();

-- ============================================
-- 3. Subtask trigger: log_subtask_changes
-- ============================================
CREATE OR REPLACE FUNCTION log_subtask_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_user_name TEXT;
  v_action TEXT;
  v_details TEXT;
BEGIN
  -- Get current user
  v_user_id := COALESCE(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid);
  SELECT COALESCE(display_name, email, '') INTO v_user_name
    FROM profiles WHERE id = v_user_id;

  IF TG_OP = 'INSERT' THEN
    INSERT INTO task_history (task_id, subtask_id, user_id, user_name, action, details)
    VALUES (NEW.task_id, NEW.id, v_user_id, COALESCE(v_user_name, ''), 'subtask_created', '"' || NEW.title || '"');
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    -- Skip sort_order-only changes
    IF OLD.title = NEW.title
       AND OLD.status = NEW.status
       AND OLD.task_id = NEW.task_id
       AND OLD.block_reason IS NOT DISTINCT FROM NEW.block_reason
    THEN
      RETURN NEW;
    END IF;

    -- Task change (subtask moved to different task)
    IF OLD.task_id IS DISTINCT FROM NEW.task_id THEN
      INSERT INTO task_history (task_id, subtask_id, user_id, user_name, action, details)
      VALUES (NEW.task_id, NEW.id, v_user_id, COALESCE(v_user_name, ''), 'subtask_moved', '"' || NEW.title || '"');
      RETURN NEW;
    END IF;

    -- Status changes
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      IF NEW.status = 'completed' THEN
        v_action := 'subtask_completed';
        v_details := '"' || NEW.title || '"';
      ELSIF OLD.status = 'completed' AND NEW.status = 'pending' THEN
        v_action := 'subtask_uncompleted';
        v_details := '"' || NEW.title || '"';
      ELSIF NEW.status = 'blocked' THEN
        v_action := 'subtask_blocked';
        v_details := COALESCE(NEW.block_reason, '');
      ELSIF OLD.status = 'blocked' AND NEW.status = 'pending' THEN
        v_action := 'subtask_unblocked';
        v_details := '"' || NEW.title || '"';
      END IF;

      IF v_action IS NOT NULL THEN
        INSERT INTO task_history (task_id, subtask_id, user_id, user_name, action, details)
        VALUES (NEW.task_id, NEW.id, v_user_id, COALESCE(v_user_name, ''), v_action, v_details);
      END IF;
    END IF;

    -- Title change
    IF OLD.title IS DISTINCT FROM NEW.title THEN
      v_details := '"' || OLD.title || '" → "' || NEW.title || '"';

      INSERT INTO task_history (task_id, subtask_id, user_id, user_name, action, details)
      VALUES (NEW.task_id, NEW.id, v_user_id, COALESCE(v_user_name, ''), 'subtask_edited', v_details);
    END IF;

    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_subtask_change
  AFTER INSERT OR UPDATE ON subtasks
  FOR EACH ROW EXECUTE FUNCTION log_subtask_changes();
