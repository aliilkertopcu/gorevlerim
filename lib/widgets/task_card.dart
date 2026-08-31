import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import '../models/group.dart';
import 'focus_mode.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import '../theme/animation_constants.dart';
import 'desktop_dialog.dart';
import 'subtask_item.dart';
import 'task_chat.dart';
import 'confetti_burst.dart';
import 'task_drag.dart';
import 'task_history.dart';

part 'task_card_typing.dart';
part 'task_card_chrome.dart';
part 'task_card_subtasks.dart';

class TaskCard extends ConsumerWidget {
  final Task task;
  final int index;

  const TaskCard({super.key, required this.task, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = AppTheme.statusColor(task.status, brightness: Theme.of(context).brightness);
    final bgColor = AppTheme.statusBackground(context, task.status);
    // Use .select() to only rebuild when THIS task's collapsed state changes
    final isExpanded = !ref.watch(collapsedTasksProvider.select((s) => s.contains(task.id)));
    final hasExpandableContent = task.subtasks.isNotEmpty ||
        (task.description != null && task.description!.isNotEmpty) ||
        (task.isBlocked && task.blockReason != null);
    final isGroupTask = ref.watch(ownerContextProvider.select((o) => o?.ownerType == 'group'));
    final permissionMode = ref.watch(currentGroupProvider.select((g) => g?.settings['task_edit_permission'] as String? ?? 'allow'));
    final editable = canEditTask(ref, task);
    final ownerColor = ref.watch(currentOwnerColorProvider);

    // Use .select() to only rebuild when THIS task's chat state changes
    final isChatOpen = ref.watch(chatOpenTasksProvider.select((s) => s.contains(task.id)));

    // Title row: tap toggles expand/collapse. Whole card is the drag handle.
    final titleGesture = GestureDetector(
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
          if (task.locked && isGroupTask && permissionMode == 'per_task') ...[
            Icon(Icons.lock, size: 14, color: Colors.orange[700]),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: AnimatedDefaultTextStyle(
              duration: Anim.normal,
              curve: Anim.defaultCurve,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w500,
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    color: task.isCompleted
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurface,
                  ),
              child: Text(task.title),
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
                style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (hasExpandableContent) ...[
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0.0,
              duration: Anim.fast,
              curve: Anim.defaultCurve,
              child: Icon(
                Icons.expand_more,
                size: 18,
                color: ownerColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );

    Widget cardContent = _PressableCard(
      bgColor: bgColor,
      statusColor: statusColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
              child: Row(
                children: [
                  // Checkbox
                  InkResponse(
                      onTap: editable ? () => _toggleComplete(context, ref) : null,
                      radius: 24,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        child: Center(
                          child: AnimatedContainer(
                            duration: Anim.fast,
                            curve: Anim.defaultCurve,
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: task.isCompleted
                                    ? AppTheme.completedColor
                                    : Theme.of(context).colorScheme.outline,
                                width: 2,
                              ),
                              color: task.isCompleted ? AppTheme.completedColor : Colors.transparent,
                            ),
                            child: AnimatedScale(
                              duration: Anim.normal,
                              curve: Curves.easeOutBack,
                              scale: task.isCompleted ? 1.0 : 0.0,
                              child: const Icon(Icons.check, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Title + badges (tap to expand/collapse, long press to drag)
                    Expanded(
                      child: titleGesture,
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
          // Expandable content with animated size
          ClipRect(
            child: AnimatedSize(
              duration: Anim.normal,
              curve: Anim.defaultCurve,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        // Typing indicator — only for group tasks, only when expanded (avoids idle channel overhead)
                        if (isGroupTask)
                          _HeaderTypingIndicator(
                            taskId: task.id,
                            accentColor: ownerColor,
                            currentUserId: ref.watch(currentUserProvider.select((u) => u?.id)),
                          ),
                        // Chat panel (below description, above subtasks)
                        if (isChatOpen)
                          TaskChatWidget(
                            taskId: task.id,
                            accentColor: ownerColor,
                          ),
                        // Subtasks
                        if (task.subtasks.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(30, 0, 8, 8),
                            child: _DraggableSubtaskList(
                              task: task,
                              accentColor: ownerColor,
                              editable: editable,
                              onToggle: (s) => _toggleSubtask(ref, s),
                              onDelete: (s) => _deleteSubtask(ref, s),
                              onBlock: (ctx, s) => _blockSubtask(ctx, ref, s),
                              onUnblock: (s) => _unblockSubtask(ref, s),
                              onEdit: (ctx, s) => _editSubtask(ctx, ref, s),
                              onPromote: (s) => _promoteSubtask(ref, s),
                              onHistory: (s) => showTaskHistoryDialog(context, taskId: task.id, taskTitle: task.title, subtaskId: s.id, subtaskTitle: s.title),
                              onReorder: (oldIdx, newIdx) => _reorderSubtask(ref, oldIdx, newIdx),
                              onReceiveDrop: (s, at) => _receiveSubtaskDrop(ref, s, insertAt: at),
                            ),
                          ),
                        // Add subtask button
                        if (editable)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(30, 0, 8, 4),
                            child: _AddSubtaskRow(taskId: task.id, accentColor: ownerColor),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );

    // Whole card is draggable (desktop: immediate, touch: short hold).
    final Widget draggableCard = editable
        ? adaptiveDraggable<TaskDragData>(
            data: TaskDragData(task: task, sourceIndex: index),
            feedback: _TaskDragFeedback(task: task, accentColor: ownerColor),
            childWhenDragging: Opacity(opacity: 0.3, child: cardContent),
            onDragUpdate: (d) => _taskAutoScroller(ref).update(context, d.globalPosition),
            onDragEnd: (_) => _taskAutoScroller(ref).stop(),
            child: cardContent,
          )
        : cardContent;

    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, ref, details.globalPosition),
      child: RepaintBoundary(
        child: TaskDropTarget(
          task: task,
          accentColor: ownerColor,
          onTaskDrop: (data, zone) => _onTaskDrop(ref, data, zone),
          onSubtaskDrop: (data, zone) => _onSubtaskDrop(ref, data, zone),
          child: draggableCard,
        ),
      ),
    );
  }

  static DragAutoScroller? _scroller;
  DragAutoScroller _taskAutoScroller(WidgetRef ref) {
    return _scroller ??= DragAutoScroller(() => ref.read(homeScrollControllerProvider));
  }

  // ---------- Drop handling ----------

  /// Current visible task list (optimistic state if available).
  List<Task> _visibleTasks(WidgetRef ref) => ref.read(tasksProvider).value ?? [];

  void _onTaskDrop(WidgetRef ref, TaskDragData data, DropZone zone) {
    if (!canEditTask(ref, task)) return;
    if (zone == DropZone.into) {
      _demoteTask(ref, data.task);
      return;
    }
    final tasks = _visibleTasks(ref);
    final oldIndex = tasks.indexWhere((t) => t.id == data.task.id);
    final targetIndex = tasks.indexWhere((t) => t.id == task.id);
    if (oldIndex < 0 || targetIndex < 0) return;
    var newIndex = zone == DropZone.before ? targetIndex : targetIndex + 1;
    if (newIndex > oldIndex) newIndex--;
    if (newIndex == oldIndex) return;

    ref.read(tasksNotifierProvider.notifier).optimisticReorderTasks(oldIndex, newIndex);
    final ids = tasks.map((t) => t.id).toList();
    ids.removeAt(oldIndex);
    ids.insert(newIndex, data.task.id);
    ref.read(taskServiceProvider).reorderTasks(
      ids,
      movedTaskId: data.task.id,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
  }

  void _demoteTask(WidgetRef ref, Task source) {
    ref.read(tasksNotifierProvider.notifier).optimisticDemoteTask(source.id, task.id);
    ref.read(taskServiceProvider).demoteTaskToSubtask(source.id, task.id).then((_) {
      // Filtered realtime streams don't deliver DELETE events — refetch so the old card disappears.
      refreshTasks(ref);
    });
    _logIfGroupTask(ref, 'task_demoted', '"${source.title}" -> "${task.title}"');
  }

  void _onSubtaskDrop(WidgetRef ref, SubtaskDragData data, DropZone zone) {
    if (!canEditTask(ref, task)) return;
    if (zone == DropZone.into) {
      if (data.subtask.taskId == task.id) return;
      _receiveSubtaskDrop(ref, data.subtask);
      return;
    }
    final tasks = _visibleTasks(ref);
    final targetIndex = tasks.indexWhere((t) => t.id == task.id);
    if (targetIndex < 0) return;
    _promoteSubtaskAt(ref, data.subtask, zone == DropZone.before ? targetIndex : targetIndex + 1);
  }

  /// Promote a subtask to a task inserted at [insertAt] in the visible list.
  void _promoteSubtaskAt(WidgetRef ref, Subtask subtask, int insertAt) {
    final owner = ref.read(ownerContextProvider);
    final user = ref.read(currentUserProvider);
    final date = ref.read(selectedDateProvider);
    if (owner == null || user == null) return;

    final tasks = _visibleTasks(ref);
    // Tasks are ordered DESC by sort_order (higher = earlier).
    int sortOrder;
    bool needsRebalance = false;
    if (tasks.isEmpty) {
      sortOrder = 1000;
    } else if (insertAt <= 0) {
      sortOrder = tasks.first.sortOrder + 1000;
    } else if (insertAt >= tasks.length) {
      sortOrder = tasks.last.sortOrder - 1000;
    } else {
      final prev = tasks[insertAt - 1].sortOrder;
      final next = tasks[insertAt].sortOrder;
      sortOrder = (prev + next) ~/ 2;
      needsRebalance = sortOrder == prev || sortOrder == next;
    }

    final temp = Task(
      id: 'temp-${subtask.id}',
      ownerId: owner.ownerId,
      ownerType: owner.ownerType,
      date: date,
      title: subtask.title,
      sortOrder: sortOrder,
      createdBy: user.id,
    );
    final notifier = ref.read(tasksNotifierProvider.notifier);
    notifier.optimisticDeleteSubtask(subtask.taskId, subtask.id);
    notifier.optimisticInsertTask(temp, insertAt);

    final service = ref.read(taskServiceProvider);
    service.promoteSubtask(
      subtaskId: subtask.id,
      taskId: subtask.taskId,
      ownerId: owner.ownerId,
      ownerType: owner.ownerType,
      date: date,
      createdBy: user.id,
      sortOrder: sortOrder,
    ).then((created) async {
      if (needsRebalance) {
        final ids = tasks.map((t) => t.id).toList()..insert(insertAt, created.id);
        await service.rebalanceTasks(ids);
      }
      refreshTasks(ref);
    });
    _logIfGroupTask(ref, 'subtask_promoted', '"${subtask.title}"');
  }

  void _showContextMenu(BuildContext context, WidgetRef ref, Offset globalPosition) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: _buildMenuItems(ref),
    ).then((value) {
      if (value != null && context.mounted) {
        _onMenuAction(context, ref, value);
      }
    });
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
      items.add(const PopupMenuItem(value: 'move', child: Text('Taşı')));
      items.add(const PopupMenuItem(
        value: 'focus',
        child: Row(
          children: [
            Text('Odaklan '),
            Text('🎯', style: TextStyle(fontSize: 16)),
          ],
        ),
      ));
    }

    // Chat option (always available when task is visible)
    items.add(const PopupMenuItem(
      value: 'chat',
      child: Row(
        children: [
          Text('Sohbet '),
          Text('💬', style: TextStyle(fontSize: 14)),
        ],
      ),
    ));

    // History option (always available)
    items.add(const PopupMenuItem(
      value: 'history',
      child: Row(
        children: [
          Icon(Icons.history, size: 18),
          SizedBox(width: 8),
          Text('Geçmiş'),
        ],
      ),
    ));

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

  void _toggleComplete(BuildContext context, WidgetRef ref) {
    final completing = !task.isCompleted;
    ref.read(tasksNotifierProvider.notifier).optimisticToggleComplete(task.id);
    ref.read(taskServiceProvider).toggleComplete(task.id, task.isCompleted);
    _logIfGroupTask(ref, task.isCompleted ? 'task_uncompleted' : 'task_completed', '"${task.title}"');
    if (!completing) return;
    HapticFeedback.lightImpact();
    // Quiet celebration when this completes the whole day.
    final tasks = ref.read(tasksProvider).value ?? const <Task>[];
    final allDone = tasks.isNotEmpty && tasks.every((t) => t.isCompleted || t.isPostponed);
    if (allDone) {
      showConfetti(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('🎉 Bugünün tüm görevleri tamamlandı!'),
          duration: Duration(seconds: 3),
        ));
    }
  }

  void _onMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'edit':
        _showEditDialog(context, ref);
      case 'block':
        _showBlockDialog(context, ref);
      case 'unblock':
        _unblockTask(ref);
      case 'move':
        _showMoveDialog(context, ref);
      case 'delete':
        _deleteTask(context, ref);
      case 'focus':
        showFocusMode(context, ref, task);
      case 'toggle_lock':
        _toggleLock(ref);
      case 'chat':
        _toggleChat(ref);
      case 'history':
        showTaskHistoryDialog(context, taskId: task.id, taskTitle: task.title);
    }
  }

  void _toggleChat(WidgetRef ref) {
    final current = ref.read(chatOpenTasksProvider);
    if (current.contains(task.id)) {
      ref.read(chatOpenTasksProvider.notifier).state = <String>{...current}..remove(task.id);
    } else {
      ref.read(chatOpenTasksProvider.notifier).state = {...current, task.id};
      // Also expand the task card so chat is visible
      final collapsed = ref.read(collapsedTasksProvider);
      if (collapsed.contains(task.id)) {
        ref.read(collapsedTasksProvider.notifier).update({...collapsed}..remove(task.id));
      }
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

  void _showMoveDialog(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.read(selectedDateProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isViewingToday = selectedDate == today;
    final tomorrow = selectedDate.add(const Duration(days: 1));

    void moveToDate(DateTime targetDate) {
      Navigator.pop(context);
      ref.read(tasksNotifierProvider.notifier).optimisticDeleteTask(task.id);
      ref.read(taskServiceProvider).postponeTask(task.id, targetDate);
      _logIfGroupTask(ref, 'task_postponed', '"${task.title}"');
    }

    void moveToGroup(BuildContext ctx, Group targetGroup) {
      Navigator.pop(ctx);
      ref.read(tasksNotifierProvider.notifier).optimisticDeleteTask(task.id);
      ref.read(taskServiceProvider).moveTaskToGroup(task.id, targetGroup.id, 'group').then((_) {
        ref.invalidate(tasksStreamProvider);
      });
      _logIfGroupTask(ref, 'task_moved', '"${task.title}" → "${targetGroup.name}"');
    }

    showAppDialog(
      context: context,
      title: const Text('Görevi Taşı'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // If viewing today: show tomorrow + date picker
          // If viewing another day: show today + tomorrow
          if (isViewingToday) ...[
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('Yarına taşı'),
              onTap: () => moveToDate(tomorrow),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Belirli tarihe taşı'),
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
          ] else ...[
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('Bugüne taşı'),
              onTap: () => moveToDate(today),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Belirli tarihe taşı'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await showDatePicker(
                  context: context,
                  initialDate: today,
                  firstDate: today,
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
          const Divider(),
          // Move to another group
          Consumer(
            builder: (ctx, consumerRef, _) {
              final groups = consumerRef.watch(userGroupsProvider).value ?? [];
              final currentOwner = consumerRef.read(ownerContextProvider);
              final otherGroups = groups.where((g) => g.id != currentOwner?.ownerId).toList();
              if (otherGroups.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Text(
                      'Başka listeye taşı',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).hintColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...otherGroups.map((g) => ListTile(
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: _parseGroupColor(g.color),
                      child: Text(
                        g.name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    title: Text(g.name),
                    onTap: () => moveToGroup(context, g),
                  )),
                ],
              );
            },
          ),
        ],
      ),
      actions: [],
    );
  }

  Color _parseGroupColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  /// Optimistically hides the task and gives a 5 s undo window before the
  /// server delete actually runs.
  void _deleteTask(BuildContext context, WidgetRef ref) {
    // This card is removed from the tree immediately, so the timer/undo
    // closures must NOT touch `ref` — capture everything up front.
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = ref.read(tasksNotifierProvider.notifier);
    final service = ref.read(taskServiceProvider);
    final owner = ref.read(ownerContextProvider);
    final user = ref.read(currentUserProvider);
    final groupService = ref.read(groupServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    void refetch() {
      notifier.clearOptimisticWindow();
      container.invalidate(tasksStreamProvider);
    }

    notifier.optimisticDeleteTask(task.id);
    var undone = false;
    final timer = Timer(const Duration(seconds: 5), () {
      // Make sure the undo bar leaves the screen even if the platform kept it around.
      messenger.hideCurrentSnackBar();
      if (undone) return;
      if (owner != null && user != null && owner.ownerType == 'group') {
        groupService.logActivity(
          groupId: owner.ownerId,
          userId: user.id,
          action: 'task_deleted',
          details: '"${task.title}"',
        );
      }
      // Filtered realtime streams don't deliver DELETE events — refetch after the server confirms.
      service.deleteTask(task.id).then((_) => refetch());
    });
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('"${task.title}" silindi'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Geri Al',
          onPressed: () {
            undone = true;
            timer.cancel();
            refetch(); // server still has it — restore from truth
          },
        ),
      ));
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

    void doBlock(BuildContext ctx) {
      final reason = reasonController.text.trim();
      Navigator.pop(ctx);
      ref.read(tasksNotifierProvider.notifier).optimisticBlockSubtask(task.id, subtask.id, reason.isEmpty ? null : reason);
      ref.read(taskServiceProvider).blockSubtask(subtask.id, reason);
      _logIfGroupTask(ref, 'subtask_blocked', '"${subtask.title}"');
    }

    showAppDialog(
      context: context,
      title: const Text('Alt Görevi Bloke Et'),
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
            labelText: 'Sebep',
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

  void _unblockSubtask(WidgetRef ref, Subtask subtask) {
    ref.read(tasksNotifierProvider.notifier).optimisticUnblockSubtask(task.id, subtask.id);
    ref.read(taskServiceProvider).updateSubtask(subtask.id, {
      'status': 'pending',
      'block_reason': null,
    });
    _logIfGroupTask(ref, 'subtask_unblocked', '"${subtask.title}"');
  }

  void _editSubtask(BuildContext context, WidgetRef ref, Subtask subtask) {
    final titleController = TextEditingController(text: subtask.title);

    void doSave(BuildContext ctx) {
      final newTitle = titleController.text.trim();
      Navigator.pop(ctx);
      ref.read(tasksNotifierProvider.notifier).optimisticUpdateSubtask(task.id, subtask.id, newTitle);
      ref.read(taskServiceProvider).updateSubtask(subtask.id, {'title': newTitle});
      _logIfGroupTask(ref, 'subtask_edited', '"${subtask.title}"');
    }

    showAppDialog(
      context: context,
      title: const Text('Alt Görevi Düzenle'),
      content: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter &&
              HardwareKeyboard.instance.isControlPressed) {
            doSave(context);
          }
        },
        child: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Başlık',
            hintText: 'Ctrl+Enter ile kaydet',
          ),
          autofocus: true,
          maxLines: null,
          minLines: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () => doSave(context),
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

  void _moveSubtaskToTask(WidgetRef ref, Subtask subtask, String targetTaskId, {int? insertAt}) {
    ref.read(tasksNotifierProvider.notifier).optimisticMoveSubtaskToTask(
      subtask.taskId, subtask.id, targetTaskId, insertAt: insertAt,
    );
    ref.read(taskServiceProvider).moveSubtaskToTask(subtask.id, targetTaskId).then((_) {
      // Server appends to end — reorder to match the optimistic position
      if (insertAt != null) {
        final tasks = ref.read(tasksNotifierProvider);
        final target = tasks.where((t) => t.id == targetTaskId).firstOrNull;
        if (target != null && target.subtasks.length > 1) {
          final ids = target.subtasks.map((s) => s.id).toList();
          final clampedIdx = insertAt.clamp(0, ids.length - 1);
          ref.read(taskServiceProvider).reorderSubtasks(
            ids,
            movedSubtaskId: subtask.id,
            oldIndex: ids.length - 1,
            newIndex: clampedIdx,
          );
        }
      }
    });
    _logIfGroupTask(ref, 'subtask_moved', '"${subtask.title}"');
  }

  void _receiveSubtaskDrop(WidgetRef ref, Subtask subtask, {int? insertAt}) {
    _moveSubtaskToTask(ref, subtask, task.id, insertAt: insertAt);
  }

  void _reorderSubtask(WidgetRef ref, int oldIndex, int newIndex) {
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
