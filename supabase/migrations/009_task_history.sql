-- Task/Subtask history (audit trail)
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

CREATE POLICY "authenticated_can_read_history" ON task_history
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated_can_insert_history" ON task_history
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
