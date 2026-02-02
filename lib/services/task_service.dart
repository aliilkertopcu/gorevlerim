import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';

class TaskService {
  final SupabaseClient _client;

  TaskService(this._client);

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Fetch tasks for a specific date and owner
  Future<List<Task>> fetchTasks({
    required String ownerId,
    required String ownerType,
    required DateTime date,
  }) async {
    final dateStr = _dateKey(date);

    final tasksData = await _client
        .from('tasks')
        .select()
        .eq('owner_id', ownerId)
        .eq('owner_type', ownerType)
        .eq('date', dateStr)
        .neq('status', 'deleted')
        .order('sort_order', ascending: true);

    final tasks = <Task>[];
    for (final taskJson in tasksData) {
      final subtasksData = await _client
          .from('subtasks')
          .select()
          .eq('task_id', taskJson['id'])
          .order('sort_order', ascending: true);

      final subtasks = subtasksData
          .map((s) => Subtask.fromJson(s))
          .toList();

      tasks.add(Task.fromJson(taskJson, subtasks: subtasks));
    }

    return tasks;
  }

  /// Realtime stream for tasks - uses Supabase stream() which handles INSERT/UPDATE/DELETE
  Stream<List<Task>> streamTasksWithSubtasks({
    required String ownerId,
    required String ownerType,
    required DateTime date,
  }) {
    final dateStr = _dateKey(date);

    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('owner_id', ownerId)
        .asyncMap((rows) async {
          // Filter by date, exclude deleted, and sort
          final filtered = rows
              .where((r) => r['date'] == dateStr && r['status'] != 'deleted')
              .toList()
            ..sort((a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int));

          if (filtered.isEmpty) return <Task>[];

          // Get all task IDs
          final taskIds = filtered.map((r) => r['id'] as String).toList();

          // Fetch ALL subtasks for ALL tasks in a single query
          final allSubtasksData = await _client
              .from('subtasks')
              .select()
              .inFilter('task_id', taskIds)
              .neq('status', 'deleted')
              .order('sort_order', ascending: true);

          // Group subtasks by task_id
          final subtasksByTaskId = <String, List<Subtask>>{};
          for (final s in allSubtasksData) {
            final taskId = s['task_id'] as String;
            subtasksByTaskId.putIfAbsent(taskId, () => []);
            subtasksByTaskId[taskId]!.add(Subtask.fromJson(s));
          }

          // Build tasks with their subtasks
          final tasks = filtered.map((taskJson) {
            final taskId = taskJson['id'] as String;
            final subtasks = subtasksByTaskId[taskId] ?? [];
            return Task.fromJson(taskJson, subtasks: subtasks);
          }).toList();

          return tasks;
        });
  }

  /// Legacy stream method (kept for compatibility)
  Stream<List<Map<String, dynamic>>> streamTasks({
    required String ownerId,
    required String ownerType,
    required DateTime date,
  }) {
    final dateStr = _dateKey(date);

    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('owner_id', ownerId)
        .map((rows) => rows
            .where((r) => r['date'] == dateStr)
            .toList()
          ..sort((a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int)));
  }

  /// Create a new task with optional subtasks
  Future<Task> createTask({
    required String ownerId,
    required String ownerType,
    required DateTime date,
    required String title,
    String? description,
    required String createdBy,
    List<String> subtaskTitles = const [],
  }) async {
    // Get max sort_order for this date
    final existing = await _client
        .from('tasks')
        .select('sort_order')
        .eq('owner_id', ownerId)
        .eq('owner_type', ownerType)
        .eq('date', _dateKey(date))
        .order('sort_order', ascending: false)
        .limit(1);

    final nextOrder = existing.isEmpty ? 0 : (existing[0]['sort_order'] as int) + 1;

    final taskData = await _client.from('tasks').insert({
      'owner_id': ownerId,
      'owner_type': ownerType,
      'date': _dateKey(date),
      'title': title,
      'description': description,
      'status': 'pending',
      'sort_order': nextOrder,
      'created_by': createdBy,
    }).select().single();

    final task = Task.fromJson(taskData);

    // Create subtasks
    if (subtaskTitles.isNotEmpty) {
      final subtaskInserts = subtaskTitles.asMap().entries.map((e) => {
        'task_id': task.id,
        'title': e.value,
        'status': 'pending',
        'sort_order': e.key,
      }).toList();

      await _client.from('subtasks').insert(subtaskInserts);
    }

    return task;
  }

  /// Update task fields
  Future<void> updateTask(String taskId, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('tasks').update(updates).eq('id', taskId);
  }

  /// Toggle task completion (cascades to non-deleted subtasks)
  Future<void> toggleComplete(String taskId, bool isCurrentlyCompleted) async {
    final newStatus = isCurrentlyCompleted ? 'pending' : 'completed';

    // Cascade to non-deleted subtasks only
    final subtasks = await _client
        .from('subtasks')
        .select('id')
        .eq('task_id', taskId)
        .neq('status', 'deleted');

    // Update subtasks in parallel
    final futures = subtasks.map((s) => _client
        .from('subtasks')
        .update({'status': newStatus})
        .eq('id', s['id']));
    await Future.wait(futures);

    // Update task LAST - this triggers stream refresh AFTER subtasks are updated
    await updateTask(taskId, {'status': newStatus});
  }

  /// Block a task
  Future<void> blockTask(String taskId, String reason) async {
    await updateTask(taskId, {
      'status': 'blocked',
      'block_reason': reason,
    });
  }

  /// Postpone a task to another date
  Future<void> postponeTask(String taskId, DateTime targetDate) async {
    // Get current task
    final taskData = await _client
        .from('tasks')
        .select()
        .eq('id', taskId)
        .single();

    final task = Task.fromJson(taskData);

    // Get max sort_order for target date
    final existing = await _client
        .from('tasks')
        .select('sort_order')
        .eq('owner_id', task.ownerId)
        .eq('owner_type', task.ownerType)
        .eq('date', _dateKey(targetDate))
        .order('sort_order', ascending: false)
        .limit(1);

    final nextOrder = existing.isEmpty ? 0 : (existing[0]['sort_order'] as int) + 1;

    await updateTask(taskId, {
      'status': 'pending',
      'date': _dateKey(targetDate),
      'sort_order': nextOrder,
      'postponed_to': null,
    });
  }

  /// Soft delete a task (marks as deleted instead of removing)
  Future<void> deleteTask(String taskId) async {
    await updateTask(taskId, {'status': 'deleted'});
  }

  /// Smart reorder - only updates the single moved task
  /// Uses fractional positioning between neighbors
  Future<void> reorderTasks(List<String> newOrderIds, {String? movedTaskId, int? oldIndex, int? newIndex}) async {
    // If we have move info, only update the moved task
    if (movedTaskId != null && oldIndex != null && newIndex != null) {
      final movedIdx = newIndex;

      int newSortOrder;

      if (newOrderIds.length == 1) {
        newSortOrder = 1000;
      } else if (movedIdx == 0) {
        // Moved to first - get next task's sort_order
        final nextTask = await _client
            .from('tasks')
            .select('sort_order')
            .eq('id', newOrderIds[1])
            .single();
        final nextOrder = nextTask['sort_order'] as int;
        newSortOrder = nextOrder - 1000;
      } else if (movedIdx == newOrderIds.length - 1) {
        // Moved to last - get prev task's sort_order
        final prevTask = await _client
            .from('tasks')
            .select('sort_order')
            .eq('id', newOrderIds[movedIdx - 1])
            .single();
        final prevOrder = prevTask['sort_order'] as int;
        newSortOrder = prevOrder + 1000;
      } else {
        // Moved to middle - midpoint between neighbors
        final prevTask = await _client
            .from('tasks')
            .select('sort_order')
            .eq('id', newOrderIds[movedIdx - 1])
            .single();
        final nextTask = await _client
            .from('tasks')
            .select('sort_order')
            .eq('id', newOrderIds[movedIdx + 1])
            .single();
        final prevOrder = prevTask['sort_order'] as int;
        final nextOrder = nextTask['sort_order'] as int;
        newSortOrder = (prevOrder + nextOrder) ~/ 2;

        // If no room, fallback to full rebalance
        if (newSortOrder == prevOrder || newSortOrder == nextOrder) {
          await _rebalanceAllTasks(newOrderIds);
          return;
        }
      }

      await _client
          .from('tasks')
          .update({
            'sort_order': newSortOrder,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', movedTaskId);
    } else {
      // Fallback: update all tasks
      await _rebalanceAllTasks(newOrderIds);
    }
  }

  /// Rebalance all tasks with proper spacing
  Future<void> _rebalanceAllTasks(List<String> taskIds) async {
    final now = DateTime.now().toIso8601String();
    final futures = <Future>[];
    for (int i = 0; i < taskIds.length; i++) {
      futures.add(
        _client
            .from('tasks')
            .update({'sort_order': (i + 1) * 1000, 'updated_at': now})
            .eq('id', taskIds[i]),
      );
    }
    await Future.wait(futures);
  }

  // === Subtask operations ===

  /// Fetch subtasks for a specific task
  Future<List<Subtask>> fetchSubtasks(String taskId) async {
    final data = await _client
        .from('subtasks')
        .select()
        .eq('task_id', taskId)
        .neq('status', 'deleted')
        .order('sort_order', ascending: true);

    return data.map((s) => Subtask.fromJson(s)).toList();
  }

  Future<Subtask> createSubtask({
    required String taskId,
    required String title,
  }) async {
    final existing = await _client
        .from('subtasks')
        .select('sort_order')
        .eq('task_id', taskId)
        .order('sort_order', ascending: false)
        .limit(1);

    final nextOrder = existing.isEmpty ? 0 : (existing[0]['sort_order'] as int) + 1;

    final data = await _client.from('subtasks').insert({
      'task_id': taskId,
      'title': title,
      'status': 'pending',
      'sort_order': nextOrder,
    }).select().single();

    return Subtask.fromJson(data);
  }

  Future<void> updateSubtask(String subtaskId, Map<String, dynamic> updates) async {
    // Get the task_id first
    final subtask = await _client
        .from('subtasks')
        .select('task_id')
        .eq('id', subtaskId)
        .single();

    // Update subtask
    await _client.from('subtasks').update(updates).eq('id', subtaskId);

    // Touch parent task to trigger stream refresh
    await _client
        .from('tasks')
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', subtask['task_id']);
  }

  Future<void> toggleSubtaskComplete(String subtaskId, bool isCurrentlyCompleted) async {
    await updateSubtask(subtaskId, {
      'status': isCurrentlyCompleted ? 'pending' : 'completed',
    });
  }

  Future<void> blockSubtask(String subtaskId, String reason) async {
    await updateSubtask(subtaskId, {
      'status': 'blocked',
      'block_reason': reason,
    });
  }

  Future<void> deleteSubtask(String subtaskId) async {
    await updateSubtask(subtaskId, {'status': 'deleted'});
  }

  /// Smart reorder subtasks - only updates the moved subtask
  Future<void> reorderSubtasks(List<String> newOrderIds, {String? movedSubtaskId, int? oldIndex, int? newIndex}) async {
    if (movedSubtaskId != null && oldIndex != null && newIndex != null) {
      final movedIdx = newIndex;

      int newSortOrder;

      if (newOrderIds.length == 1) {
        newSortOrder = 1000;
      } else if (movedIdx == 0) {
        final nextSubtask = await _client
            .from('subtasks')
            .select('sort_order')
            .eq('id', newOrderIds[1])
            .single();
        final nextOrder = nextSubtask['sort_order'] as int;
        newSortOrder = nextOrder - 1000;
      } else if (movedIdx == newOrderIds.length - 1) {
        final prevSubtask = await _client
            .from('subtasks')
            .select('sort_order')
            .eq('id', newOrderIds[movedIdx - 1])
            .single();
        final prevOrder = prevSubtask['sort_order'] as int;
        newSortOrder = prevOrder + 1000;
      } else {
        final prevSubtask = await _client
            .from('subtasks')
            .select('sort_order')
            .eq('id', newOrderIds[movedIdx - 1])
            .single();
        final nextSubtask = await _client
            .from('subtasks')
            .select('sort_order')
            .eq('id', newOrderIds[movedIdx + 1])
            .single();
        final prevOrder = prevSubtask['sort_order'] as int;
        final nextOrder = nextSubtask['sort_order'] as int;
        newSortOrder = (prevOrder + nextOrder) ~/ 2;

        if (newSortOrder == prevOrder || newSortOrder == nextOrder) {
          await _rebalanceAllSubtasks(newOrderIds);
          return;
        }
      }

      await _client
          .from('subtasks')
          .update({'sort_order': newSortOrder})
          .eq('id', movedSubtaskId);
    } else {
      await _rebalanceAllSubtasks(newOrderIds);
    }
  }

  Future<void> _rebalanceAllSubtasks(List<String> subtaskIds) async {
    final futures = <Future>[];
    for (int i = 0; i < subtaskIds.length; i++) {
      futures.add(
        _client
            .from('subtasks')
            .update({'sort_order': (i + 1) * 1000})
            .eq('id', subtaskIds[i]),
      );
    }
    await Future.wait(futures);
  }

  /// Promote subtask to main task
  Future<void> promoteSubtask({
    required String subtaskId,
    required String taskId,
    required String ownerId,
    required String ownerType,
    required DateTime date,
    required String createdBy,
  }) async {
    final subtaskData = await _client
        .from('subtasks')
        .select()
        .eq('id', subtaskId)
        .single();

    final subtask = Subtask.fromJson(subtaskData);

    // Create new task
    await createTask(
      ownerId: ownerId,
      ownerType: ownerType,
      date: date,
      title: subtask.title,
      createdBy: createdBy,
    );

    // Delete subtask
    await deleteSubtask(subtaskId);
  }

  /// Check subtask states and update parent accordingly
  Future<void> checkAutoComplete(String taskId) async {
    final subtasks = await _client
        .from('subtasks')
        .select()
        .eq('task_id', taskId);

    if (subtasks.isEmpty) return;

    final allCompleted = subtasks.every((s) => s['status'] == 'completed');
    final anyNotCompleted = subtasks.any((s) => s['status'] != 'completed');

    if (allCompleted) {
      await updateTask(taskId, {'status': 'completed'});
    } else if (anyNotCompleted) {
      // If parent is completed but a subtask was unchecked, revert parent to pending
      final taskData = await _client
          .from('tasks')
          .select('status')
          .eq('id', taskId)
          .single();
      if (taskData['status'] == 'completed') {
        await updateTask(taskId, {'status': 'pending'});
      }
    }
  }
}
