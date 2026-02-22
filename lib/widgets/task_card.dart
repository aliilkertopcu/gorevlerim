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
import 'desktop_dialog.dart';
import 'subtask_item.dart';
import 'task_chat.dart';

/// Data payload for draggable subtasks (carries source position for reorder).
class _SubtaskDragData {
  final Subtask subtask;
  final int sourceIndex;
  const _SubtaskDragData({required this.subtask, required this.sourceIndex});
}

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
    final ownerColor = ref.watch(currentOwnerColorProvider);

    // Chat state
    final chatOpenTasks = ref.watch(chatOpenTasksProvider);
    final isChatOpen = chatOpenTasks.contains(task.id);

    // Title row extracted so we can wrap with ReorderableDelayedDragStartListener when editable
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
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted ? Colors.grey : null,
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
                style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (hasExpandableContent) ...[
            const SizedBox(width: 4),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: ownerColor.withValues(alpha: 0.6),
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
                    // Title + badges (tap to expand/collapse, long press to drag)
                    Expanded(
                      child: editable
                          ? ReorderableDelayedDragStartListener(
                              index: index,
                              child: titleGesture,
                            )
                          : titleGesture,
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
            // Typing indicator — only for group tasks, only when expanded (avoids idle channel overhead)
            if (isGroupTask)
              _HeaderTypingIndicator(
                taskId: task.id,
                accentColor: ownerColor,
                currentUserId: ref.watch(currentUserProvider)?.id,
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
        ],
      ),
    );

    // Always wrap with DragTarget for cross-task subtask drops.
    // onWillAcceptWithDetails filters out same-task drags.
    // No provider update needed during drag — avoids rebuild-during-drag stack overflow.
    return DragTarget<_SubtaskDragData>(
      onWillAcceptWithDetails: (details) => details.data.subtask.taskId != task.id,
      onAcceptWithDetails: (details) {
        _receiveSubtaskDrop(ref, details.data.subtask);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isHovering
                ? Border.all(color: ownerColor, width: 2)
                : null,
          ),
          child: cardContent,
        );
      },
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
      case 'move':
        _showMoveDialog(context, ref);
      case 'delete':
        _deleteTask(ref);
      case 'focus':
        showFocusMode(context, ref, task);
      case 'toggle_lock':
        _toggleLock(ref);
      case 'chat':
        _toggleChat(ref);
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

/// Always-active typing indicator for the task card header.
/// Subscribes to the Realtime broadcast channel independently of the chat panel.
class _HeaderTypingIndicator extends StatefulWidget {
  final String taskId;
  final Color accentColor;
  final String? currentUserId;

  const _HeaderTypingIndicator({
    required this.taskId,
    required this.accentColor,
    this.currentUserId,
  });

  @override
  State<_HeaderTypingIndicator> createState() => _HeaderTypingIndicatorState();
}

class _HeaderTypingIndicatorState extends State<_HeaderTypingIndicator> {
  RealtimeChannel? _channel;
  final Map<String, ({String name, DateTime lastTyped})> _typingUsers = {};
  static const _timeoutMs = 3500;

  @override
  void initState() {
    super.initState();
    _channel = Supabase.instance.client.channel('typing:task:${widget.taskId}');
    _channel!
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final userId = payload['user_id'] as String?;
            final userName = payload['user_name'] as String? ?? '?';
            if (userId == null || userId == widget.currentUserId) return;
            if (!mounted) return;
            setState(() {
              _typingUsers[userId] = (name: userName, lastTyped: DateTime.now());
            });
            Future.delayed(const Duration(milliseconds: _timeoutMs), () {
              if (!mounted) return;
              final entry = _typingUsers[userId];
              if (entry == null) return;
              if (DateTime.now().difference(entry.lastTyped).inMilliseconds >= _timeoutMs - 200) {
                setState(() => _typingUsers.remove(userId));
              }
            });
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_typingUsers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stacked avatars (max 2 in header to save space)
          ...(_typingUsers.entries.take(2).map((e) => Container(
            margin: const EdgeInsets.only(right: 2),
            child: CircleAvatar(
              radius: 9,
              backgroundColor: widget.accentColor.withValues(alpha: 0.25),
              child: Text(
                e.value.name.isNotEmpty ? e.value.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 8,
                  color: widget.accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ))),
          const SizedBox(width: 3),
          TypingDotsWidget(color: Colors.grey.shade400),
        ],
      ),
    );
  }
}

/// Hover-effect card wrapper. Shows subtle tint on desktop mouse hover.
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

class _PressableCardState extends State<_PressableCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _isHovered
        ? Color.lerp(widget.bgColor, Colors.grey, 0.06)!
        : widget.bgColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: widget.statusColor, width: 4),
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Subtask list with LongPressDraggable.
/// Hovering over a subtask shows a drop indicator above or below based on
/// which half of the item the pointer is in — no need to aim at a tiny gap.
class _DraggableSubtaskList extends ConsumerStatefulWidget {
  final Task task;
  final Color accentColor;
  final bool editable;
  final void Function(Subtask) onToggle;
  final void Function(Subtask) onDelete;
  final void Function(BuildContext, Subtask) onBlock;
  final void Function(Subtask) onUnblock;
  final void Function(BuildContext, Subtask) onEdit;
  final void Function(Subtask) onPromote;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(Subtask subtask, int insertAt) onReceiveDrop;

  const _DraggableSubtaskList({
    required this.task,
    required this.accentColor,
    required this.editable,
    required this.onToggle,
    required this.onDelete,
    required this.onBlock,
    required this.onUnblock,
    required this.onEdit,
    required this.onPromote,
    required this.onReorder,
    required this.onReceiveDrop,
  });

  @override
  ConsumerState<_DraggableSubtaskList> createState() => _DraggableSubtaskListState();
}

class _DraggableSubtaskListState extends ConsumerState<_DraggableSubtaskList> {
  Timer? _autoScrollTimer;
  String? _hoveredId;      // subtask.id currently hovered
  bool   _hoverIsTop = true; // true → insert above, false → insert below
  final Map<String, GlobalKey> _targetKeys = {};

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _startAutoScroll(DragUpdateDetails details) {
    _autoScrollTimer?.cancel();

    final y = details.globalPosition.dy;
    final screenHeight = MediaQuery.of(context).size.height;
    const zone = 80.0;
    const maxSpeed = 12.0;

    double? speed;
    if (y < zone) {
      speed = -(1.0 - y / zone) * maxSpeed;
    } else if (y > screenHeight - zone) {
      speed = ((y - (screenHeight - zone)) / zone) * maxSpeed;
    }
    if (speed == null) return;

    // Use the home screen's ScrollController directly — avoids picking up
    // ReorderableListView's internal NeverScrollableScrollPhysics scrollable.
    final controller = ref.read(homeScrollControllerProvider);
    if (controller == null || !controller.hasClients) return;

    final targetSpeed = speed;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) {
        _autoScrollTimer?.cancel();
        return;
      }
      final pos = controller.position;
      pos.jumpTo(
        (pos.pixels + targetSpeed).clamp(pos.minScrollExtent, pos.maxScrollExtent),
      );
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  Widget _buildDropIndicator() {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: widget.accentColor,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtasks = widget.task.subtasks;

    if (!widget.editable) {
      return Column(
        children: subtasks.asMap().entries.map((e) {
          return SubtaskItem(
            key: ValueKey(e.value.id),
            subtask: e.value,
            parentTask: widget.task,
            subtaskIndex: e.key,
            editable: false,
            onToggle: () {},
            onDelete: () {},
            onBlock: () {},
            onEdit: () {},
            onPromote: () {},
          );
        }).toList(),
      );
    }

    return Column(
      children: List.generate(subtasks.length, (i) {
        final subtask = subtasks[i];
        final targetKey = _targetKeys.putIfAbsent(subtask.id, () => GlobalKey());

        final subtaskWidget = SubtaskItem(
          key: ValueKey(subtask.id),
          subtask: subtask,
          parentTask: widget.task,
          subtaskIndex: i,
          onToggle: () => widget.onToggle(subtask),
          onDelete: () => widget.onDelete(subtask),
          onBlock: () => widget.onBlock(context, subtask),
          onUnblock: () => widget.onUnblock(subtask),
          onEdit: () => widget.onEdit(context, subtask),
          onPromote: () => widget.onPromote(subtask),
        );

        final draggable = LongPressDraggable<_SubtaskDragData>(
          data: _SubtaskDragData(subtask: subtask, sourceIndex: i),
          delay: const Duration(milliseconds: 350),
          feedback: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(6),
            color: Theme.of(context).colorScheme.surface,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                subtask.title,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: SubtaskItem(
              subtask: subtask,
              parentTask: widget.task,
              subtaskIndex: i,
              onToggle: () {},
              onDelete: () {},
              onBlock: () {},
              onEdit: () {},
              onPromote: () {},
            ),
          ),
          onDragStarted: () => HapticFeedback.mediumImpact(),
          onDragUpdate: _startAutoScroll,
          onDragEnd: (_) => _stopAutoScroll(),
          child: subtaskWidget,
        );

        return DragTarget<_SubtaskDragData>(
          key: targetKey,
          onWillAcceptWithDetails: (_) => true,
          onMove: (details) {
            // Measure this item's render box to decide top/bottom half
            final rb = targetKey.currentContext?.findRenderObject() as RenderBox?;
            if (rb == null) return;
            final local = rb.globalToLocal(details.offset);
            final isTop = local.dy < rb.size.height / 2;
            if (_hoveredId != subtask.id || _hoverIsTop != isTop) {
              setState(() {
                _hoveredId = subtask.id;
                _hoverIsTop = isTop;
              });
            }
          },
          onLeave: (_) {
            if (_hoveredId == subtask.id) setState(() => _hoveredId = null);
          },
          onAcceptWithDetails: (details) {
            _stopAutoScroll();
            final savedIsTop = _hoverIsTop;
            setState(() => _hoveredId = null);
            final data = details.data;
            // insertAt: above item = index i, below item = index i+1
            final insertAt = savedIsTop ? i : i + 1;
            if (data.subtask.taskId == widget.task.id) {
              var newIdx = insertAt;
              if (newIdx > data.sourceIndex) newIdx--;
              if (newIdx != data.sourceIndex) {
                widget.onReorder(data.sourceIndex, newIdx);
              }
            } else {
              widget.onReceiveDrop(data.subtask, insertAt);
            }
          },
          builder: (ctx, candidateData, _) {
            final dragData = candidateData.firstOrNull;
            bool showIndicator = _hoveredId == subtask.id && dragData != null;

            // Suppress indicator when the drop would result in no positional change
            // (hovering the bottom half of the item above, or the top half of item below)
            if (showIndicator && dragData.subtask.taskId == widget.task.id) {
              final insertAt = _hoverIsTop ? i : i + 1;
              var newIdx = insertAt;
              if (newIdx > dragData.sourceIndex) newIdx--;
              if (newIdx == dragData.sourceIndex) showIndicator = false;
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showIndicator && _hoverIsTop) _buildDropIndicator(),
                draggable,
                if (showIndicator && !_hoverIsTop) _buildDropIndicator(),
              ],
            );
          },
        );
      }),
    );
  }
}

/// Inline "add subtask" row — shows a button, expands to a text field on tap.
class _AddSubtaskRow extends ConsumerStatefulWidget {
  final String taskId;
  final Color accentColor;

  const _AddSubtaskRow({required this.taskId, required this.accentColor});

  @override
  ConsumerState<_AddSubtaskRow> createState() => _AddSubtaskRowState();
}

class _AddSubtaskRowState extends ConsumerState<_AddSubtaskRow> {
  bool _isAdding = false;
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _ctrl.text.trim();
    _ctrl.clear();
    setState(() => _isAdding = false);
    if (title.isEmpty) return;
    await ref.read(taskServiceProvider).createSubtask(taskId: widget.taskId, title: title);
    ref.invalidate(tasksStreamProvider);
  }

  void _cancel() {
    _ctrl.clear();
    setState(() => _isAdding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdding) {
      return GestureDetector(
        onTap: () {
          setState(() => _isAdding = true);
          WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 14, color: widget.accentColor.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(
                'Alt görev ekle',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.accentColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            focusNode: _focusNode,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Alt görev adı...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
            onSubmitted: (_) => _submit(),
            textInputAction: TextInputAction.done,
          ),
        ),
        TextButton(
          onPressed: _submit,
          style: TextButton.styleFrom(
            foregroundColor: widget.accentColor,
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('Ekle', style: TextStyle(fontSize: 12)),
        ),
        TextButton(
          onPressed: _cancel,
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey,
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: const Text('İptal', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
