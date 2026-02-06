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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = AppTheme.statusColor(task.status);
    final bgColor = AppTheme.statusBackground(task.status, isDark: isDark);

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
                    PopupMenuItem(
                      value: task.isBlocked ? 'unblock' : 'block',
                      child: Text(task.isBlocked ? 'Blokeyi Kaldır' : 'Bloke Et'),
                    ),
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
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  // Optimistic reorder
                  ref.read(tasksNotifierProvider.notifier).optimisticReorderSubtasks(task.id, oldIndex, newIndex);
                  // Sync with server - only update moved subtask
                  final movedId = task.subtasks[oldIndex].id;
                  final ids = task.subtasks.map((s) => s.id).toList();
                  ids.removeAt(oldIndex);
                  ids.insert(newIndex, movedId);
                  ref.read(taskServiceProvider).reorderSubtasks(
                    ids,
                    movedSubtaskId: movedId,
                    oldIndex: oldIndex,
                    newIndex: newIndex,
                  );
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

  void _toggleComplete(WidgetRef ref) {
    // Optimistic update - instant UI change
    ref.read(tasksNotifierProvider.notifier).optimisticToggleComplete(task.id);
    // Then sync with server (no await needed)
    ref.read(taskServiceProvider).toggleComplete(task.id, task.isCompleted);
  }

  void _onMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'edit':
        _showEditDialog(context, ref);
      case 'block':
        _showBlockDialog(context, ref);
      case 'unblock':
        _unblockTask(ref);
      case 'postpone':
        _showPostponeDialog(context, ref);
      case 'delete':
        _deleteTask(ref);
    }
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController(text: task.title);
    final descController = TextEditingController(text: task.description ?? '');
    final descFocusNode = FocusNode();

    void saveEdit(BuildContext dialogContext) {
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
      final newTitle = titleController.text.trim();

      Navigator.pop(dialogContext);

      // Optimistic update
      ref.read(tasksNotifierProvider.notifier).optimisticUpdateTask(
        task.id,
        title: newTitle,
        description: cleanDesc.isEmpty ? null : cleanDesc,
      );

      // Sync with server
      ref.read(taskServiceProvider).updateTask(task.id, {
        'title': newTitle,
        'description': cleanDesc.isEmpty ? null : cleanDesc,
      });

      // Create subtasks (these will be synced via stream)
      for (final st in subtaskTitles) {
        if (st.isNotEmpty) {
          ref.read(taskServiceProvider).createSubtask(
            taskId: task.id,
            title: st,
          );
        }
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Görevi Düzenle'),
        content: KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter &&
                HardwareKeyboard.instance.isControlPressed) {
              saveEdit(dialogContext);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Başlık'),
                autofocus: true,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => descFocusNode.requestFocus(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                focusNode: descFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  hintText: '* ile yeni alt görev ekle\nCtrl+Enter ile kaydet',
                ),
                maxLines: 5,
              ),
            ],
          ),
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

    void doBlock(BuildContext dialogContext) {
      final reason = reasonController.text.trim();
      Navigator.pop(dialogContext);
      // Optimistic block
      ref.read(tasksNotifierProvider.notifier).optimisticBlockTask(task.id, reason.isEmpty ? null : reason);
      ref.read(taskServiceProvider).blockTask(task.id, reason);
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Görevi Bloke Et'),
        content: KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter &&
                HardwareKeyboard.instance.isControlPressed) {
              doBlock(dialogContext);
            }
          },
          child: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'Bloke sebebi',
              hintText: 'Neden bloke edildi?\nCtrl+Enter ile kaydet',
            ),
            maxLines: 2,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => doBlock(dialogContext),
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
              onTap: () {
                Navigator.pop(context);
                // Optimistic - remove from current day's list
                ref.read(tasksNotifierProvider.notifier).optimisticDeleteTask(task.id);
                ref.read(taskServiceProvider).postponeTask(task.id, tomorrow);
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
                  // Optimistic - remove from current day's list
                  ref.read(tasksNotifierProvider.notifier).optimisticDeleteTask(task.id);
                  ref.read(taskServiceProvider).postponeTask(task.id, picked);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTask(WidgetRef ref) {
    // Optimistic delete
    ref.read(tasksNotifierProvider.notifier).optimisticDeleteTask(task.id);
    ref.read(taskServiceProvider).deleteTask(task.id);
  }

  void _unblockTask(WidgetRef ref) {
    // Optimistic unblock
    ref.read(tasksNotifierProvider.notifier).optimisticUnblockTask(task.id);
    ref.read(taskServiceProvider).updateTask(task.id, {
      'status': 'pending',
      'block_reason': null,
    });
  }

  // Subtask actions
  void _toggleSubtask(WidgetRef ref, Subtask subtask) {
    // Optimistic toggle
    ref.read(tasksNotifierProvider.notifier).optimisticToggleSubtask(task.id, subtask.id);
    // Sync with server
    ref.read(taskServiceProvider).toggleSubtaskComplete(subtask.id, subtask.isCompleted);
    ref.read(taskServiceProvider).checkAutoComplete(task.id);
  }

  void _deleteSubtask(WidgetRef ref, Subtask subtask) {
    // Optimistic delete
    ref.read(tasksNotifierProvider.notifier).optimisticDeleteSubtask(task.id, subtask.id);
    ref.read(taskServiceProvider).deleteSubtask(subtask.id);
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
            onPressed: () {
              final reason = reasonController.text.trim();
              Navigator.pop(context);
              // Optimistic block
              ref.read(tasksNotifierProvider.notifier).optimisticBlockSubtask(task.id, subtask.id, reason.isEmpty ? null : reason);
              ref.read(taskServiceProvider).blockSubtask(subtask.id, reason);
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
            onPressed: () {
              final newTitle = titleController.text.trim();
              Navigator.pop(context);
              // Optimistic update
              ref.read(tasksNotifierProvider.notifier).optimisticUpdateSubtask(task.id, subtask.id, newTitle);
              ref.read(taskServiceProvider).updateSubtask(subtask.id, {'title': newTitle});
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _promoteSubtask(WidgetRef ref, Subtask subtask) {
    final owner = ref.read(ownerContextProvider);
    final user = ref.read(currentUserProvider);
    final date = ref.read(selectedDateProvider);

    if (owner == null || user == null) return;

    // Optimistic - remove subtask from parent (new task will appear via stream)
    ref.read(tasksNotifierProvider.notifier).optimisticDeleteSubtask(task.id, subtask.id);

    ref.read(taskServiceProvider).promoteSubtask(
      subtaskId: subtask.id,
      taskId: task.id,
      ownerId: owner.ownerId,
      ownerType: owner.ownerType,
      date: date,
      createdBy: user.id,
    );
  }
}
