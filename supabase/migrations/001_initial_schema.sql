-- ============================================
-- Todo App - Supabase Initial Schema
-- ============================================

-- 1. Profiles table (linked to auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  email TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'full_name', ''),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. Groups table
CREATE TABLE groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_by UUID REFERENCES profiles(id),
  invite_code TEXT UNIQUE DEFAULT substr(md5(random()::text), 1, 6),
  color TEXT DEFAULT '#667eea',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Group members (many-to-many)
CREATE TABLE group_members (
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);

-- 4. Tasks table
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL,
  owner_type TEXT NOT NULL CHECK (owner_type IN ('user', 'group')),
  date DATE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'blocked', 'postponed')),
  block_reason TEXT,
  postponed_to DATE,
  sort_order INTEGER DEFAULT 0,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_tasks_owner_date ON tasks(owner_id, owner_type, date);

-- 5. Subtasks table
CREATE TABLE subtasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'blocked')),
  block_reason TEXT,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_subtasks_task ON subtasks(task_id);

-- ============================================
-- Row Level Security (RLS)
-- ============================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE subtasks ENABLE ROW LEVEL SECURITY;

-- Helper function to avoid infinite recursion in group_members RLS
CREATE OR REPLACE FUNCTION public.get_my_group_ids()
RETURNS SETOF UUID AS $$
  SELECT group_id FROM public.group_members WHERE user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Profiles: users can read/update their own profile
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- Allow insert for the trigger (service role) and for the app
CREATE POLICY "Allow profile insert"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Groups: anyone can view (needed for invite code lookup)
CREATE POLICY "Anyone can find group by invite code"
  ON groups FOR SELECT
  USING (true);

CREATE POLICY "Users can create groups"
  ON groups FOR INSERT
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Creator can update group"
  ON groups FOR UPDATE
  USING (auth.uid() = created_by);

CREATE POLICY "Creator can delete group"
  ON groups FOR DELETE
  USING (auth.uid() = created_by);

-- Group members (uses helper function to avoid infinite recursion)
CREATE POLICY "Members can view group members"
  ON group_members FOR SELECT
  USING (
    user_id = auth.uid()
    OR
    group_id IN (SELECT public.get_my_group_ids())
  );

CREATE POLICY "Users can join groups"
  ON group_members FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave groups"
  ON group_members FOR DELETE
  USING (auth.uid() = user_id);

-- Tasks: owner or group member can access (uses helper function)
CREATE POLICY "Users can view own tasks"
  ON tasks FOR SELECT
  USING (
    (owner_type = 'user' AND owner_id = auth.uid())
    OR
    (owner_type = 'group' AND owner_id IN (SELECT public.get_my_group_ids()))
  );

CREATE POLICY "Users can create tasks"
  ON tasks FOR INSERT
  WITH CHECK (
    (owner_type = 'user' AND owner_id = auth.uid())
    OR
    (owner_type = 'group' AND owner_id IN (SELECT public.get_my_group_ids()))
  );

CREATE POLICY "Users can update tasks"
  ON tasks FOR UPDATE
  USING (
    (owner_type = 'user' AND owner_id = auth.uid())
    OR
    (owner_type = 'group' AND owner_id IN (SELECT public.get_my_group_ids()))
  );

CREATE POLICY "Users can delete tasks"
  ON tasks FOR DELETE
  USING (
    (owner_type = 'user' AND owner_id = auth.uid())
    OR
    (owner_type = 'group' AND owner_id IN (SELECT public.get_my_group_ids()))
  );

-- Subtasks: access follows parent task
CREATE POLICY "Users can view subtasks"
  ON subtasks FOR SELECT
  USING (
    task_id IN (SELECT id FROM tasks)
  );

CREATE POLICY "Users can create subtasks"
  ON subtasks FOR INSERT
  WITH CHECK (
    task_id IN (SELECT id FROM tasks)
  );

CREATE POLICY "Users can update subtasks"
  ON subtasks FOR UPDATE
  USING (
    task_id IN (SELECT id FROM tasks)
  );

CREATE POLICY "Users can delete subtasks"
  ON subtasks FOR DELETE
  USING (
    task_id IN (SELECT id FROM tasks)
  );

-- ============================================
-- Enable Realtime for tasks and subtasks
-- ============================================
ALTER PUBLICATION supabase_realtime ADD TABLE tasks;
ALTER PUBLICATION supabase_realtime ADD TABLE subtasks;
