-- ============================================
-- Fix: task history triggers fail during new user signup
-- ============================================
-- When a new user signs up, the trigger chain creates a welcome task
-- (auth.users → profiles → create_personal_group → tasks INSERT).
-- At that point auth.uid() returns NULL (no JWT context in trigger chain),
-- so the old code fell back to a nil UUID ('00000000-...') which violates
-- the FK constraint on task_history.user_id → auth.users(id).
-- Fix: skip history logging when there is no authenticated context.

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
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(display_name, email, '') INTO v_user_name
    FROM profiles WHERE id = v_user_id;

  IF TG_OP = 'INSERT' THEN
    INSERT INTO task_history (task_id, user_id, user_name, action, details)
    VALUES (NEW.id, v_user_id, COALESCE(v_user_name, ''), 'task_created', '"' || NEW.title || '"');
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
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

    IF OLD.owner_id IS DISTINCT FROM NEW.owner_id THEN
      SELECT name INTO v_group_name FROM groups WHERE id = NEW.owner_id;
      SELECT name INTO v_old_group_name FROM groups WHERE id = OLD.owner_id;
      v_details := COALESCE(v_old_group_name, 'Kişisel') || ' → ' || COALESCE(v_group_name, 'Kişisel');

      INSERT INTO task_history (task_id, user_id, user_name, action, details)
      VALUES (NEW.id, v_user_id, COALESCE(v_user_name, ''), 'task_moved', v_details);
    END IF;

    IF OLD.date IS DISTINCT FROM NEW.date THEN
      v_details := TO_CHAR(OLD.date, 'DD.MM.YYYY') || ' → ' || TO_CHAR(NEW.date, 'DD.MM.YYYY');

      INSERT INTO task_history (task_id, user_id, user_name, action, details)
      VALUES (NEW.id, v_user_id, COALESCE(v_user_name, ''), 'task_postponed', v_details);
    END IF;

    IF OLD.locked IS DISTINCT FROM NEW.locked THEN
      v_action := CASE WHEN NEW.locked THEN 'task_locked' ELSE 'task_unlocked' END;

      INSERT INTO task_history (task_id, user_id, user_name, action, details)
      VALUES (NEW.id, v_user_id, COALESCE(v_user_name, ''), v_action, '"' || NEW.title || '"');
    END IF;

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


CREATE OR REPLACE FUNCTION log_subtask_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_user_name TEXT;
  v_action TEXT;
  v_details TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(display_name, email, '') INTO v_user_name
    FROM profiles WHERE id = v_user_id;

  IF TG_OP = 'INSERT' THEN
    INSERT INTO task_history (task_id, subtask_id, user_id, user_name, action, details)
    VALUES (NEW.task_id, NEW.id, v_user_id, COALESCE(v_user_name, ''), 'subtask_created', '"' || NEW.title || '"');
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.title = NEW.title
       AND OLD.status = NEW.status
       AND OLD.task_id = NEW.task_id
       AND OLD.block_reason IS NOT DISTINCT FROM NEW.block_reason
    THEN
      RETURN NEW;
    END IF;

    IF OLD.task_id IS DISTINCT FROM NEW.task_id THEN
      INSERT INTO task_history (task_id, subtask_id, user_id, user_name, action, details)
      VALUES (NEW.task_id, NEW.id, v_user_id, COALESCE(v_user_name, ''), 'subtask_moved', '"' || NEW.title || '"');
      RETURN NEW;
    END IF;

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
