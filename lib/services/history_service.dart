import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryEntry {
  final String id;
  final String taskId;
  final String? subtaskId;
  final String userId;
  final String userName;
  final String action;
  final String? details;
  final DateTime createdAt;

  const HistoryEntry({
    required this.id,
    required this.taskId,
    this.subtaskId,
    required this.userId,
    required this.userName,
    required this.action,
    this.details,
    required this.createdAt,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      subtaskId: json['subtask_id'] as String?,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? '?',
      action: json['action'] as String,
      details: json['details'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class HistoryService {
  final SupabaseClient _client;

  HistoryService(this._client);

  /// Log a history event for a task or subtask.
  Future<void> log({
    required String taskId,
    String? subtaskId,
    required String userId,
    required String userName,
    required String action,
    String? details,
  }) async {
    await _client.from('task_history').insert({
      'task_id': taskId,
      'subtask_id': subtaskId,
      'user_id': userId,
      'user_name': userName,
      'action': action,
      'details': details,
    });
  }

  /// Fetch history for a task (all events including subtask events).
  Future<List<HistoryEntry>> getTaskHistory(String taskId) async {
    final data = await _client
        .from('task_history')
        .select()
        .eq('task_id', taskId)
        .order('created_at', ascending: false);
    return data.map((e) => HistoryEntry.fromJson(e)).toList();
  }

  /// Fetch history for a specific subtask only.
  Future<List<HistoryEntry>> getSubtaskHistory(String taskId, String subtaskId) async {
    final data = await _client
        .from('task_history')
        .select()
        .eq('task_id', taskId)
        .eq('subtask_id', subtaskId)
        .order('created_at', ascending: false);
    return data.map((e) => HistoryEntry.fromJson(e)).toList();
  }
}
