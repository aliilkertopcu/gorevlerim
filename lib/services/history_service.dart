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

  HistoryEntry({
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
      userName: json['user_name'] as String? ?? '',
      action: json['action'] as String,
      details: json['details'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class HistoryService {
  final _supabase = Supabase.instance.client;

  /// Fetch all history entries for a task (including subtask events).
  Future<List<HistoryEntry>> getTaskHistory(String taskId) async {
    final data = await _supabase
        .from('task_history')
        .select()
        .eq('task_id', taskId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => HistoryEntry.fromJson(e)).toList();
  }

  /// Fetch history entries for a specific subtask.
  Future<List<HistoryEntry>> getSubtaskHistory(String taskId, String subtaskId) async {
    final data = await _supabase
        .from('task_history')
        .select()
        .eq('task_id', taskId)
        .eq('subtask_id', subtaskId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => HistoryEntry.fromJson(e)).toList();
  }
}
