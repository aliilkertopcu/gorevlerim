-- New visual identity: personal groups default to teal instead of the old
-- indigo. Existing personal groups still on the untouched default follow.

ALTER TABLE groups ALTER COLUMN color SET DEFAULT '#0D9488';

UPDATE groups SET color = '#0D9488' WHERE is_personal = true AND color = '#667eea';

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
  INSERT INTO public.groups (name, color, created_by, is_personal)
  VALUES ('Günlük Görevler', '#0D9488', NEW.id, true)
  RETURNING id INTO new_group_id;

  INSERT INTO public.group_members (group_id, user_id)
  VALUES (new_group_id, NEW.id);

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

  INSERT INTO public.subtasks (task_id, title, status, sort_order) VALUES
    (new_task_id, '🎥 ne demişler 1 video bin kelimeden iyidir, [bunu izledin mi?](https://youtu.be/v2gCtEVzm9E)', 'pending', 0),
    (new_task_id, '⭐ yıldız koyup sonrasına da bir boşluk bırakarak alt görev eklemeyi öğrendin mi?', 'pending', 1),
    (new_task_id, '👥 sol üstten gruplar yaratabilir, birilerini o gruplara davet edebilirsin (evin işlerini tek kişi üstlenemez sonuçta)', 'pending', 2),
    (new_task_id, '🎨 gruplarını renklendirebilir ve kendine göre özelleştirebilirsin', 'pending', 3),
    (new_task_id, '⏱️ uff çok fazla birikti dersen odak modumuz mevcut, keşfedebilirsin', 'pending', 4),
    (new_task_id, '🎤 "Yeni Görev Ekle"nin yanındaki mikrofona basıp yapacaklarını anlat, yapay zeka görevlere ayırsın', 'pending', 5);

  RETURN NEW;
END;
$$;
