import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import 'desktop_dialog.dart';

class TaskForm extends ConsumerWidget {
  const TaskForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerColor = ref.watch(currentOwnerColorProvider);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showAddTaskDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Yeni Görev Ekle'),
        style: ElevatedButton.styleFrom(
          backgroundColor: ownerColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final descFocusNode = FocusNode();
    var isLoading = false;

    void addTask(BuildContext dialogContext, StateSetter setDialogState) async {
      final title = titleController.text.trim();
      if (title.isEmpty) return;

      final description = descController.text.trim();
      final owner = ref.read(ownerContextProvider);
      final user = ref.read(currentUserProvider);
      final date = ref.read(selectedDateProvider);

      if (owner == null || user == null) return;

      setDialogState(() => isLoading = true);

      try {
        final lines = description.split('\n');
        final subtaskTitles = <String>[];
        final descLines = <String>[];

        for (final line in lines) {
          if (line.trimLeft().startsWith('* ')) {
            subtaskTitles.add(line.trimLeft().substring(2).trim());
          } else {
            descLines.add(line);
          }
        }

        final cleanDesc = descLines.join('\n').trim();

        await ref.read(taskServiceProvider).createTask(
          ownerId: owner.ownerId,
          ownerType: owner.ownerType,
          date: date,
          title: title,
          description: cleanDesc.isEmpty ? null : cleanDesc,
          createdBy: user.id,
          subtaskTitles: subtaskTitles,
        );

        ref.invalidate(tasksStreamProvider);

        if (dialogContext.mounted) {
          Navigator.pop(dialogContext);
        }
      } catch (e) {
        if (dialogContext.mounted) {
          ScaffoldMessenger.of(dialogContext).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
          setDialogState(() => isLoading = false);
        }
      }
    }

    showAppDialog(
      context: context,
      title: const Text('Yeni Görev'),
      contentBuilder: (ctx, setDialogState) => KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter &&
              HardwareKeyboard.instance.isControlPressed) {
            addTask(ctx, setDialogState);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: 'Görev başlığı',
              ),
              autofocus: true,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => descFocusNode.requestFocus(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              focusNode: descFocusNode,
              decoration: const InputDecoration(
                hintText: 'Açıklama (opsiyonel)\n* ile alt görev ekle\nCtrl+Enter ile ekle',
              ),
              maxLines: 4,
              minLines: 2,
            ),
          ],
        ),
      ),
      actionsBuilder: (ctx, setDialogState) => [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : () => addTask(ctx, setDialogState),
          style: ElevatedButton.styleFrom(backgroundColor: ref.read(currentOwnerColorProvider)),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Ekle'),
        ),
      ],
    );
  }
}
