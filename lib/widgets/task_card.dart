import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
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
    final isGroupTask = ref.watch(ownerContextProvider)?.ownerType == 'group';
    final group = ref.watch(currentGroupProvider);
    final permissionMode = group?.settings['task_edit_permission'] as String? ?? 'allow';
    final editable = canEditTask(ref, task);

    return _PressableCard(
      bgColor: bgColor,
      statusColor: statusColor,
      child: CustomDelayDragStartListener(
        index: index,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
                child: Row(
                  children: [
                    // Checkbox
                    GestureDetector(
                      onTap: editable ? () => _toggleComplete(ref) : null,
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
                    // Title + badges (tap to expand/collapse)
                    Expanded(
                      child: GestureDetector(
                        onTap: hasExpandableContent
                            ? () {
                                final notifier = ref.read(collapsedTasksProvider.notifier);
                                final current = ref.read(collapsedTasksProvider);
                                if (current.contains(task.id)) {
                                  notifier.update({...current}..remove(task.id));
                                } else {
                                  notifier.update({...current, task.id});
                                }
                              }
                            : null,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                        children: [
                          // Lock icon badge
                          if (task.locked && isGroupTask && permissionMode == 'per_task') ...[
                            Icon(Icons.lock, size: 14, color: Colors.orange[700]),
                            const SizedBox(width: 4),
                          ],
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
                              color: ref.watch(currentOwnerColorProvider).withValues(alpha: 0.6),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Menu (hidden when not editable, unless lock toggle is available)
                  if (editable || _hasLockToggle(ref))
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                      itemBuilder: (context) => _buildMenuItems(ref),
                      onSelected: (value) => _onMenuAction(context, ref, value),
                    )
                  else
                    const SizedBox(width: 8),
                ],
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
                child: editable
                  ? ReorderableListView(
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
                    )
                  : Column(
                      children: task.subtasks.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final subtask = entry.value;
                        return SubtaskItem(
                          key: ValueKey(subtask.id),
                          subtask: subtask,
                          parentTask: task,
                          subtaskIndex: idx,
                          editable: false,
                          onToggle: () {},
                          onDelete: () {},
                          onBlock: () {},
                          onEdit: () {},
                          onPromote: () {},
                        );
                      }).toList(),
                    ),
              ),
          ],
        ],
      ),
      ),
    );
  }

  bool _hasLockToggle(WidgetRef ref) {
    final isGroupTask = ref.read(ownerContextProvider)?.ownerType == 'group';
    final group = ref.read(currentGroupProvider);
    final user = ref.read(currentUserProvider);
    final permissionMode = group?.settings['task_edit_permission'] as String? ?? 'allow';
    final isCreator = group != null && user != null && group.createdBy == user.id;
    final isTaskOwner = user != null && task.createdBy == user.id;
    return isGroupTask && permissionMode == 'per_task' && (isTaskOwner || isCreator);
  }

  List<PopupMenuEntry<String>> _buildMenuItems(WidgetRef ref) {
    final editable = canEditTask(ref, task);
    final isGroupTask = ref.read(ownerContextProvider)?.ownerType == 'group';
    final group = ref.read(currentGroupProvider);
    final user = ref.read(currentUserProvider);
    final permissionMode = group?.settings['task_edit_permission'] as String? ?? 'allow';
    final isCreator = group != null && user != null && group.createdBy == user.id;
    final isTaskOwner = user != null && task.createdBy == user.id;
    final showLockToggle = isGroupTask && permissionMode == 'per_task' && (isTaskOwner || isCreator);

    final items = <PopupMenuEntry<String>>[];

    if (editable) {
      items.add(const PopupMenuItem(value: 'edit', child: Text('Düzenle')));
      items.add(PopupMenuItem(
        value: task.isBlocked ? 'unblock' : 'block',
        child: Text(task.isBlocked ? 'Blokeyi Kaldır' : 'Bloke Et'),
      ));
      items.add(const PopupMenuItem(value: 'postpone', child: Text('Ertele')));
    }

    if (showLockToggle) {
      if (items.isNotEmpty) items.add(const PopupMenuDivider());
      items.add(PopupMenuItem(
        value: 'toggle_lock',
        child: Row(
          children: [
            Icon(task.locked ? Icons.lock_open : Icons.lock, size: 18),
            const SizedBox(width: 8),
            Text(task.locked ? 'Kilidi Aç' : 'Kilitle'),
          ],
        ),
      ));
    }

    if (editable) {
      items.add(const PopupMenuDivider());
      items.add(const PopupMenuItem(
        value: 'delete',
        child: Text('Sil', style: TextStyle(color: Colors.red)),
      ));
    }

    if (items.isEmpty) {
      items.add(const PopupMenuItem(
        enabled: false,
        value: '',
        child: Text('Düzenleme izniniz yok', style: TextStyle(color: Colors.grey)),
      ));
    }

    return items;
  }

  void _toggleComplete(WidgetRef ref) {
    ref.read(tasksNotifierProvider.notifier).optimisticToggleComplete(task.id);
    ref.read(taskServiceProvider).toggleComplete(task.id, task.isCompleted);
    _logIfGroupTask(ref, task.isCompleted ? 'task_uncompleted' : 'task_completed', '"${task.title}"');
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
      case 'toggle_lock':
        _toggleLock(ref);
    }
  }

  void _toggleLock(WidgetRef ref) {
    ref.read(tasksNotifierProvider.notifier).optimisticToggleLock(task.id);
    ref.read(taskServiceProvider).toggleTaskLock(task.id, task.locked);
    _logIfGroupTask(ref, task.locked ? 'task_unlocked' : 'task_locked', '"${task.title}"');
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

      _logIfGroupTask(ref, 'task_edited', '"${task.title}"');

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
              maxLines: null,
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
          style: ElevatedButton.styleFrom(backgroundColor: ref.read(currentOwnerColorProvider)),
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
      _logIfGroupTask(ref, 'task_blocked', '"${task.title}"');
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
              _logIfGroupTask(ref, 'task_postponed', '"${task.title}"');
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
                _logIfGroupTask(ref, 'task_postponed', '"${task.title}"');
              }
            },
          ),
        ],
      ),
      actions: [],
    );
  }

  void _deleteTask(WidgetRef ref) {
    _logIfGroupTask(ref, 'task_deleted', '"${task.title}"');
    ref.read(tasksNotifierProvider.notifier).optimisticDeleteTask(task.id);
    ref.read(taskServiceProvider).deleteTask(task.id);
  }

  void _unblockTask(WidgetRef ref) {
    ref.read(tasksNotifierProvider.notifier).optimisticUnblockTask(task.id);
    ref.read(taskServiceProvider).updateTask(task.id, {
      'status': 'pending',
      'block_reason': null,
    });
    _logIfGroupTask(ref, 'task_unblocked', '"${task.title}"');
  }

  void _toggleSubtask(WidgetRef ref, Subtask subtask) {
    ref.read(tasksNotifierProvider.notifier).optimisticToggleSubtask(task.id, subtask.id);
    ref.read(taskServiceProvider).toggleSubtaskComplete(subtask.id, subtask.isCompleted);
    ref.read(taskServiceProvider).checkAutoComplete(task.id);
    _logIfGroupTask(ref, subtask.isCompleted ? 'subtask_uncompleted' : 'subtask_completed', '"${subtask.title}"');
  }

  void _deleteSubtask(WidgetRef ref, Subtask subtask) {
    ref.read(tasksNotifierProvider.notifier).optimisticDeleteSubtask(task.id, subtask.id);
    ref.read(taskServiceProvider).deleteSubtask(subtask.id);
    _logIfGroupTask(ref, 'subtask_deleted', '"${subtask.title}"');
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
            _logIfGroupTask(ref, 'subtask_blocked', '"${subtask.title}"');
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.blockedColor),
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
        maxLines: null,
        minLines: 2,
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
            _logIfGroupTask(ref, 'subtask_edited', '"${subtask.title}"');
          },
          style: ElevatedButton.styleFrom(backgroundColor: ref.read(currentOwnerColorProvider)),
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

    _logIfGroupTask(ref, 'subtask_promoted', '"${subtask.title}"');
  }

  /// Log activity if this is a group task
  void _logIfGroupTask(WidgetRef ref, String action, String details) {
    final owner = ref.read(ownerContextProvider);
    final user = ref.read(currentUserProvider);
    if (owner == null || user == null || owner.ownerType != 'group') return;

    ref.read(groupServiceProvider).logActivity(
      groupId: owner.ownerId,
      userId: user.id,
      action: action,
      details: details,
    );
  }
}

/// Wrapper that provides 3-phase press-and-hold animation for task cards:
/// Phase 1 (0–100ms): Threshold — no visual change
/// Phase 2 (100–500ms): Gradual scale 1.0→1.04 + subtle shadow, pushes neighbors
/// Phase 3 (500ms+): Drag mode takes over via proxyDecorator (70% opacity + heavy shadow)
class _PressableCard extends StatefulWidget {
  final Widget child;
  final Color bgColor;
  final Color statusColor;

  const _PressableCard({
    required this.child,
    required this.bgColor,
    required this.statusColor,
  });

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  Timer? _thresholdTimer;
  late AnimationController _pressController;
  Offset? _initialPosition;
  bool _movementCancelled = false;

  static const _moveThreshold = 10.0;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _thresholdTimer?.cancel();
    _pressController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _initialPosition = event.position;
    _movementCancelled = false;
    _thresholdTimer?.cancel();
    _thresholdTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && !_movementCancelled) {
        _pressController.forward();
      }
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_initialPosition != null && !_movementCancelled) {
      final distance = (event.position - _initialPosition!).distance;
      if (distance > _moveThreshold) {
        _movementCancelled = true;
        _cancelPress();
      }
    }
  }

  void _cancelPress() {
    _thresholdTimer?.cancel();
    _initialPosition = null;
    if (_pressController.isAnimating || _pressController.value > 0) {
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (_) => _cancelPress(),
      onPointerCancel: (_) => _cancelPress(),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) {
          setState(() => _isHovered = false);
          _cancelPress();
        },
        child: AnimatedBuilder(
          animation: _pressController,
          builder: (context, child) {
            final t = Curves.easeOutCubic.transform(_pressController.value);
            final scale = 1.0 + (0.04 * t);
            final extraMargin = 2.0 * t;
            final bgColor = _isHovered
                ? Color.lerp(widget.bgColor, Colors.grey, 0.08)!
                : widget.bgColor;

            return Container(
              margin: EdgeInsets.only(
                top: extraMargin,
                bottom: 4 + extraMargin,
              ),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(color: widget.statusColor, width: 4),
                    ),
                    boxShadow: t > 0.01
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06 + 0.10 * t),
                              blurRadius: 2 + 8 * t,
                              offset: Offset(0, 1 + 3 * t),
                            ),
                          ]
                        : null,
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
