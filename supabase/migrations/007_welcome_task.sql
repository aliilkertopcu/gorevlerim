-- ============================================
-- Welcome Task for New Users
-- ============================================
-- Updates create_personal_group() to also insert a welcome task
-- with subtasks that guide new users through app features.

CREATE OR REPLACE FUNCTION public.create_personal_group()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_group_id UUID;
  new_task_id  UUID;
BEGIN
  -- 1. Create personal group
  INSERT INTO public.groups (name, color, created_by, is_personal)
  VALUES ('Günlük Görevler', '#667eea', NEW.id, true)
  RETURNING id INTO new_group_id;

  INSERT INTO public.group_members (group_id, user_id)
  VALUES (new_group_id, NEW.id);

  -- 2. Create welcome task for today
  INSERT INTO public.tasks (owner_id, owner_type, date, title, description, status, sort_order, created_by)
  VALUES (
    new_group_id,
    'group',
    CURRENT_DATE,
    'Hoşgeldim! 👋',
    'aynaları kontrol et, şöyle bi koltuğuna yerleş, hazırsan başlayalım! 🪑✨',
    'pending',
    0,
    NEW.id
  )
  RETURNING id INTO new_task_id;

  -- 3. Create onboarding subtasks
  INSERT INTO public.subtasks (task_id, title, status, sort_order) VALUES
    (new_task_id, '🎥 ne demişler 1 video bin kelimeden iyidir, [bunu izledin mi?](https://youtu.be/v2gCtEVzm9E)', 'pending', 0),
    (new_task_id, '⭐ yıldız koyup sonrasına da bir boşluk bırakarak alt görev eklemeyi öğrendin mi?', 'pending', 1),
    (new_task_id, '👥 sol üstten gruplar yaratabilir, birilerini o gruplara davet edebilirsin (evin işlerini tek kişi üstlenemez sonuçta)', 'pending', 2),
    (new_task_id, '🎨 gruplarını renklendirebilir ve kendine göre özelleştirebilirsin', 'pending', 3),
    (new_task_id, '⏱️ uff çok fazla birikti dersen odak modumuz mevcut, keşfedebilirsin', 'pending', 4),
    (new_task_id, '🤖 [custom GPT ile](https://chatgpt.com/g/g-698064fcef40819193c8d429b724f1b1-gorevlerim) sesle yapılacaklarını doldurabilirsin', 'pending', 5);

  RETURN NEW;
END;
$$;

-- Trigger already exists from migration 006; replacing the function is enough.
