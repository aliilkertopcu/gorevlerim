import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'custom_drag_listener.dart';
import 'desktop_dialog.dart';
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
    final collapsedTasks = ref.watch(collapsedTasksProvider);
    final isExpanded = !collapsedTasks.contains(task.id);
    final hasExpandableContent = task.subtasks.isNotEmpty ||
        (task.description != null && task.description!.isNotEmpty) ||
        (task.isBlocked && task.blockReason != null);

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
          // Header row — long press to drag
          MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: CustomDelayDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
                child: Row(
                  children: [
                    // Checkbox
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
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
                    ),
                    const SizedBox(width: 8),
                    // Title + badges (tap to expand/collapse)
                    Expanded(
                      child: MouseRegion(
                        cursor: hasExpandableContent ? SystemMouseCursors.click : MouseCursor.defer,
                        child: GestureDetector(
                          onTap: hasExpandableContent
                              ? () {
                                  final notifier = ref.read(collapsedTasksProvider.notifier);
                                  final current = ref.read(collapsedTasksProvider);
                                  if (current.contains(task.id)) {
                                    notifier.state = {...current}..remove(task.id);
                                  } else {
                                    notifier.state = {...current, task.id};
                                  }
                                }
                              : null,
                          behavior: HitTestBehavior.opaque,
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
                          // Expand indicator
                          if (hasExpandableContent) ...[
                            const SizedBox(width: 4),
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                              color: Colors.grey[400],
                            ),
                          ],
                        ],
                      ),
                      ),
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
            ),
          ),
          // Expandable content
          if (isExpanded) ...[
            // Description
            if (task.description != null && task.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(42, 0, 12, 6),
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
                padding: const EdgeInsets.fromLTRB(42, 0, 12, 6),
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
                padding: const EdgeInsets.fromLTRB(30, 0, 8, 8),
                child: ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, idx, animation) {
                    return Opacity(
                      opacity: 0.85,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(4),
                        child: child,
                      ),
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    ref.read(tasksNotifierProvider.notifier).optimisticReorderSubtasks(task.id, oldIndex, newIndex);
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
        ],
      ),
    );
  }

  void _toggleComplete(WidgetRef ref) {
    ref.read(tasksNotifierProvider.notifier).optimisticToggleComplete(task.id);
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
    final descFocusNode = FocusNode();

    // Build initial description with existing subtasks as "* title" lines
    final parts = <String>[];
    if (task.description != null && task.description!.isNotEmpty) {
      parts.add(task.description!);
    }
    if (task.subtasks.isNotEmpty) {
      if (parts.isNotEmpty) parts.add('');
      for (final st in task.subtasks) {
        parts.add('* ${st.title}');
      }
    }
    final descController = TextEditingController(text: parts.join('\n'));


    Future<void> saveEdit(BuildContext dialogContext) async {
      final descText = descController.text.trim();
      final lines = descText.split('\n');
      final newSubtaskTitles = <String>[];
      final descLines = <String>[];

      for (final line in lines) {
        if (line.trimLeft().startsWith('* ')) {
          final title = line.trimLeft().substring(2).trim();
          if (title.isNotEmpty) newSubtaskTitles.add(title);
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

      // Sync title/description with server
      await ref.read(taskServiceProvider).updateTask(task.id, {
        'title': newTitle,
        'description': cleanDesc.isEmpty ? null : cleanDesc,
      });

      // Diff subtasks: delete removed, create new, reorder all by text position
      final availableOriginals = [...task.subtasks]; // mutable copy
      // orderedEntries tracks each subtask in text order:
      // kept entries have an ID, new entries have null ID (filled after creation)
      final orderedEntries = <({String? id, String title})>[];

      for (final newSt in newSubtaskTitles) {
        final matchIdx = availableOriginals.indexWhere((s) => s.title == newSt);
        if (matchIdx != -1) {
          orderedEntries.add((id: availableOriginals[matchIdx].id, title: newSt));
          availableOriginals.removeAt(matchIdx);
        } else {
          orderedEntries.add((id: null, title: newSt));
        }
      }

      // Delete subtasks that were removed from the list
      for (final removed in availableOriginals) {
        ref.read(tasksNotifierProvider.notifier).optimisticDeleteSubtask(task.id, removed.id);
        await ref.read(taskServiceProvider).deleteSubtask(removed.id);
      }

      // Create new subtasks and capture their IDs
      final allIds = <String>[];
      for (final entry in orderedEntries) {
        if (entry.id != null) {
          allIds.add(entry.id!);
        } else {
          final created = await ref.read(taskServiceProvider).createSubtask(
            taskId: task.id,
            title: entry.title,
          );
          allIds.add(created.id);
        }
      }

      // Reorder ALL subtasks (kept + new) to match text position
      if (allIds.length > 1) {
        await ref.read(taskServiceProvider).reorderSubtasks(
          allIds,
          movedSubtaskId: allIds.first,
          oldIndex: 0,
          newIndex: 0,
        );
      }

      // Refresh stream after all server operations complete
      if (orderedEntries.isNotEmpty || availableOriginals.isNotEmpty) {
        ref.invalidate(tasksStreamProvider);
      }
    }

    showAppDialog(
      context: context,
      title: const Text('Görevi Düzenle'),
      content: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter &&
              HardwareKeyboard.instance.isControlPressed) {
            saveEdit(context);
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
                labelText: 'Açıklama & Alt Görevler',
                hintText: '* ile alt görev ekle/düzenle\nCtrl+Enter ile kaydet',
              ),
              maxLines: 8,
              minLines: 4,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () => saveEdit(context),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }

  void _showBlockDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();

    void doBlock(BuildContext ctx) {
      final reason = reasonController.text.trim();
      Navigator.pop(ctx);
      ref.read(tasksNotifierProvider.notifier).optimisticBlockTask(task.id, reason.isEmpty ? null : reason);
      ref.read(taskServiceProvider).blockTask(task.id, reason);
    }

    showAppDialog(
      context: context,
      title: const Text('Görevi Bloke Et'),
      content: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter &&
              HardwareKeyboard.instance.isControlPressed) {
            doBlock(context);
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
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () => doBlock(context),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.blockedColor),
          child: const Text('Bloke Et'),
        ),
      ],
    );
  }

  void _showPostponeDialog(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.read(selectedDateProvider);
    final tomorrow = selectedDate.add(const Duration(days: 1));

    showAppDialog(
      context: context,
      title: const Text('Görevi Ertele'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.today),
            title: const Text('Yarına ertele'),
            onTap: () {
              Navigator.pop(context);
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
                ref.read(tasksNotifierProvider.notifier).optimisticDeleteTask(task.id);
                ref.read(taskServiceProvider).postponeTask(task.id, picked);
              }
            },
          ),
        ],
      ),
      actions: [],
    );
  }

  void _deleteTask(WidgetRef ref) {
    ref.read(tasksNotifierProvider.notifier).optimisticDeleteTask(task.id);
    ref.read(taskServiceProvider).deleteTask(task.id);
  }

  void _unblockTask(WidgetRef ref) {
    ref.read(tasksNotifierProvider.notifier).optimisticUnblockTask(task.id);
    ref.read(taskServiceProvider).updateTask(task.id, {
      'status': 'pending',
      'block_reason': null,
    });
  }

  void _toggleSubtask(WidgetRef ref, Subtask subtask) {
    ref.read(tasksNotifierProvider.notifier).optimisticToggleSubtask(task.id, subtask.id);
    ref.read(taskServiceProvider).toggleSubtaskComplete(subtask.id, subtask.isCompleted);
    ref.read(taskServiceProvider).checkAutoComplete(task.id);
  }

  void _deleteSubtask(WidgetRef ref, Subtask subtask) {
    ref.read(tasksNotifierProvider.notifier).optimisticDeleteSubtask(task.id, subtask.id);
    ref.read(taskServiceProvider).deleteSubtask(subtask.id);
  }

  void _blockSubtask(BuildContext context, WidgetRef ref, Subtask subtask) {
    final reasonController = TextEditingController();

    showAppDialog(
      context: context,
      title: const Text('Alt Görevi Bloke Et'),
      content: TextField(
        controller: reasonController,
        decoration: const InputDecoration(labelText: 'Sebep'),
        autofocus: true,
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
            ref.read(tasksNotifierProvider.notifier).optimisticBlockSubtask(task.id, subtask.id, reason.isEmpty ? null : reason);
            ref.read(taskServiceProvider).blockSubtask(subtask.id, reason);
          },
          child: const Text('Bloke Et'),
        ),
      ],
    );
  }

  void _editSubtask(BuildContext context, WidgetRef ref, Subtask subtask) {
    final titleController = TextEditingController(text: subtask.title);

    showAppDialog(
      context: context,
      title: const Text('Alt Görevi Düzenle'),
      content: TextField(
        controller: titleController,
        decoration: const InputDecoration(labelText: 'Başlık'),
        autofocus: true,
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
            ref.read(tasksNotifierProvider.notifier).optimisticUpdateSubtask(task.id, subtask.id, newTitle);
            ref.read(taskServiceProvider).updateSubtask(subtask.id, {'title': newTitle});
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }

  void _promoteSubtask(WidgetRef ref, Subtask subtask) {
    final owner = ref.read(ownerContextProvider);
    final user = ref.read(currentUserProvider);
    final date = ref.read(selectedDateProvider);

    if (owner == null || user == null) return;

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
