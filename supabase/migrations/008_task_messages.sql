-- Task/Subtask chat messages table
CREATE TABLE task_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
  subtask_id UUID REFERENCES subtasks(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  user_name TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  -- Exactly one of task_id or subtask_id must be set
  CONSTRAINT one_message_target CHECK (
    (task_id IS NOT NULL)::int + (subtask_id IS NOT NULL)::int = 1
  )
);

CREATE INDEX task_messages_task_id_idx ON task_messages(task_id);
CREATE INDEX task_messages_subtask_id_idx ON task_messages(subtask_id);
CREATE INDEX task_messages_created_at_idx ON task_messages(created_at);

-- RLS
ALTER TABLE task_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "authenticated_can_read_messages" ON task_messages
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated_can_insert_own_messages" ON task_messages
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

CREATE POLICY "authenticated_can_delete_own_messages" ON task_messages
  FOR DELETE TO authenticated USING (user_id = auth.uid());

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE task_messages;
