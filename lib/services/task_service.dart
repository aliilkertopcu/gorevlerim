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

  /// Realtime stream for tasks (filtered client-side since stream only supports single eq)
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

  /// Toggle task completion (cascades to subtasks)
  Future<void> toggleComplete(String taskId, bool isCurrentlyCompleted) async {
    final newStatus = isCurrentlyCompleted ? 'pending' : 'completed';
    await updateTask(taskId, {'status': newStatus});

    // Cascade to all subtasks
    final subtasks = await _client
        .from('subtasks')
        .select('id')
        .eq('task_id', taskId);

    for (final s in subtasks) {
      await _client.from('subtasks')
          .update({'status': newStatus})
          .eq('id', s['id']);
    }
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

  /// Delete a task (cascades to subtasks)
  Future<void> deleteTask(String taskId) async {
    await _client.from('tasks').delete().eq('id', taskId);
  }

  /// Reorder tasks
  Future<void> reorderTasks(List<String> taskIds) async {
    for (int i = 0; i < taskIds.length; i++) {
      await _client
          .from('tasks')
          .update({'sort_order': i, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', taskIds[i]);
    }
  }

  // === Subtask operations ===

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
    await _client.from('subtasks').update(updates).eq('id', subtaskId);
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
    await _client.from('subtasks').delete().eq('id', subtaskId);
  }

  Future<void> reorderSubtasks(List<String> subtaskIds) async {
    for (int i = 0; i < subtaskIds.length; i++) {
      await _client
          .from('subtasks')
          .update({'sort_order': i})
          .eq('id', subtaskIds[i]);
    }
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
