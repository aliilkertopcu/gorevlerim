import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'subtask_item.dart';

class TaskCard extends ConsumerWidget {
  final Task task;
  final int index;

  const TaskCard({super.key, required this.task, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = AppTheme.statusColor(task.status);
    final bgColor = AppTheme.statusBackground(task.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: statusColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 4, 6),
            child: Row(
              children: [
                // Drag handle (left side)
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 18,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
                // Number badge
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Checkbox
                GestureDetector(
                  onTap: () => _toggleComplete(ref),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: task.isCompleted ? AppTheme.completedColor : Colors.grey,
                        width: 2,
                      ),
                      color: task.isCompleted ? AppTheme.completedColor : Colors.transparent,
                    ),
                    child: task.isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                // Title + badges
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.isCompleted
                                ? Colors.grey
                                : null,
                          ),
                        ),
                      ),
                      if (task.subtasks.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${task.completedSubtaskCount}/${task.totalSubtaskCount}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      if (task.isBlocked || task.isPostponed) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            task.isBlocked ? 'Bloke' : 'Ertelendi',
                            style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                    const PopupMenuItem(value: 'block', child: Text('Bloke Et')),
                    const PopupMenuItem(value: 'postpone', child: Text('Ertele')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Sil', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  onSelected: (value) => _onMenuAction(context, ref, value),
                ),
              ],
            ),
          ),
          // Description
          if (task.description != null && task.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 12, 6),
              child: Text(
                task.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ),
          // Block reason
          if (task.isBlocked && task.blockReason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 12, 6),
              child: Text(
                'Sebep: ${task.blockReason}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.blockedColor.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          // Subtasks
          if (task.subtasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(44, 0, 8, 8),
              child: ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                proxyDecorator: (child, idx, animation) {
                  return Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(4),
                    child: child,
                  );
                },
                onReorder: (oldIndex, newIndex) async {
                  if (newIndex > oldIndex) newIndex--;
                  final ids = task.subtasks.map((s) => s.id).toList();
                  final movedId = ids.removeAt(oldIndex);
                  ids.insert(newIndex, movedId);
                  await ref.read(taskServiceProvider).reorderSubtasks(ids);
                  ref.invalidate(tasksProvider);
                },
                children: task.subtasks.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final subtask = entry.value;
                  return SubtaskItem(
                    key: ValueKey(subtask.id),
                    subtask: subtask,
                    parentTask: task,
                    subtaskIndex: idx,
                    onToggle: () => _toggleSubtask(ref, subtask),
                    onDelete: () => _deleteSubtask(ref, subtask),
                    onBlock: () => _blockSubtask(context, ref, subtask),
                    onEdit: () => _editSubtask(context, ref, subtask),
                    onPromote: () => _promoteSubtask(ref, subtask),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleComplete(WidgetRef ref) async {
    await ref.read(taskServiceProvider).toggleComplete(task.id, task.isCompleted);
    ref.invalidate(tasksProvider);
  }

  void _onMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'edit':
        _showEditDialog(context, ref);
      case 'block':
        _showBlockDialog(context, ref);
      case 'postpone':
        _showPostponeDialog(context, ref);
      case 'delete':
        _deleteTask(ref);
    }
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController(text: task.title);
    final descController = TextEditingController(text: task.description ?? '');

    Future<void> saveEdit(BuildContext dialogContext) async {
      final descText = descController.text.trim();
      final lines = descText.split('\n');
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

      await ref.read(taskServiceProvider).updateTask(task.id, {
        'title': titleController.text.trim(),
        'description': cleanDesc.isEmpty ? null : cleanDesc,
      });

      for (final st in subtaskTitles) {
        if (st.isNotEmpty) {
          await ref.read(taskServiceProvider).createSubtask(
            taskId: task.id,
            title: st,
          );
        }
      }

      ref.invalidate(tasksProvider);
      if (dialogContext.mounted) Navigator.pop(dialogContext);
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Görevi Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Başlık'),
            ),
            const SizedBox(height: 8),
            KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    HardwareKeyboard.instance.isControlPressed) {
                  saveEdit(dialogContext);
                }
              },
              child: TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  hintText: '* ile yeni alt görev ekle\nCtrl+Enter ile kaydet',
                ),
                maxLines: 5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => saveEdit(dialogContext),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Görevi Bloke Et'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Bloke sebebi',
            hintText: 'Neden bloke edildi?',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(taskServiceProvider).blockTask(
                task.id,
                reasonController.text.trim(),
              );
              ref.invalidate(tasksProvider);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.blockedColor),
            child: const Text('Bloke Et'),
          ),
        ],
      ),
    );
  }

  void _showPostponeDialog(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.read(selectedDateProvider);
    final tomorrow = selectedDate.add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Görevi Ertele'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('Yarına ertele'),
              onTap: () async {
                await ref.read(taskServiceProvider).postponeTask(task.id, tomorrow);
                ref.invalidate(tasksProvider);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Tarih seç'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await showDatePicker(
                  context: context,
                  initialDate: tomorrow,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                  locale: const Locale('tr', 'TR'),
                );
                if (picked != null) {
                  await ref.read(taskServiceProvider).postponeTask(task.id, picked);
                  ref.invalidate(tasksProvider);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTask(WidgetRef ref) async {
    await ref.read(taskServiceProvider).deleteTask(task.id);
    ref.invalidate(tasksProvider);
  }

  // Subtask actions
  void _toggleSubtask(WidgetRef ref, Subtask subtask) async {
    await ref.read(taskServiceProvider).toggleSubtaskComplete(
      subtask.id,
      subtask.isCompleted,
    );
    // Check auto-complete
    await ref.read(taskServiceProvider).checkAutoComplete(task.id);
    ref.invalidate(tasksProvider);
  }

  void _deleteSubtask(WidgetRef ref, Subtask subtask) async {
    await ref.read(taskServiceProvider).deleteSubtask(subtask.id);
    ref.invalidate(tasksProvider);
  }

  void _blockSubtask(BuildContext context, WidgetRef ref, Subtask subtask) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alt Görevi Bloke Et'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Sebep'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(taskServiceProvider).blockSubtask(
                subtask.id,
                reasonController.text.trim(),
              );
              ref.invalidate(tasksProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Bloke Et'),
          ),
        ],
      ),
    );
  }

  void _editSubtask(BuildContext context, WidgetRef ref, Subtask subtask) {
    final titleController = TextEditingController(text: subtask.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alt Görevi Düzenle'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Başlık'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(taskServiceProvider).updateSubtask(
                subtask.id,
                {'title': titleController.text.trim()},
              );
              ref.invalidate(tasksProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _promoteSubtask(WidgetRef ref, Subtask subtask) async {
    final owner = ref.read(ownerContextProvider);
    final user = ref.read(currentUserProvider);
    final date = ref.read(selectedDateProvider);

    if (owner == null || user == null) return;

    await ref.read(taskServiceProvider).promoteSubtask(
      subtaskId: subtask.id,
      taskId: task.id,
      ownerId: owner.ownerId,
      ownerType: owner.ownerType,
      date: date,
      createdBy: user.id,
    );
    ref.invalidate(tasksProvider);
  }
}
