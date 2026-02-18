import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../web_utils.dart' if (dart.library.io) '../web_utils_stub.dart';
import 'desktop_dialog.dart';

const _chatGptUrl = 'https://chatgpt.com/g/g-698064fcef40819193c8d429b724f1b1-gorevlerim';

class TaskForm extends ConsumerWidget {
  const TaskForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerColor = ref.watch(currentOwnerColorProvider);

    return Row(
      children: [
        // Ana buton — Yeni Görev Ekle
        Expanded(
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
        ),
        const SizedBox(width: 8),
        // ChatGPT butonu
        SizedBox(
          height: 48,
          width: 48,
          child: ElevatedButton(
            onPressed: () {
              if (kIsWeb) {
                openUrl(_chatGptUrl);
              } else {
                launchUrl(
                  Uri.parse(_chatGptUrl),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF000000),
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/0/04/ChatGPT_logo.svg',
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.smart_toy, size: 22, color: Colors.white),
            ),
          ),
        ),
      ],
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

        // Log if group task
        if (owner.ownerType == 'group') {
          ref.read(groupServiceProvider).logActivity(
            groupId: owner.ownerId,
            userId: user.id,
            action: 'task_created',
            details: '"$title"',
          );
        }

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
              maxLines: null,
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
