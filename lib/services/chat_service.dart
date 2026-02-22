import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';

class ChatService {
  final SupabaseClient _client;

  ChatService(this._client);

  Stream<List<ChatMessage>> streamTaskMessages(String taskId) {
    return _client
        .from('task_messages')
        .stream(primaryKey: ['id'])
        .eq('task_id', taskId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map((r) => ChatMessage.fromJson(r)).toList());
  }

  Stream<List<ChatMessage>> streamSubtaskMessages(String subtaskId) {
    return _client
        .from('task_messages')
        .stream(primaryKey: ['id'])
        .eq('subtask_id', subtaskId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map((r) => ChatMessage.fromJson(r)).toList());
  }

  Future<void> sendMessage({
    String? taskId,
    String? subtaskId,
    required String content,
    required String userId,
    String? userName,
  }) async {
    await _client.from('task_messages').insert({
      if (taskId != null) 'task_id': taskId,
      if (subtaskId != null) 'subtask_id': subtaskId,
      'user_id': userId,
      'user_name': userName,
      'content': content,
    });
  }

  Future<int> getMessageCount({String? taskId, String? subtaskId}) async {
    if (taskId != null) {
      final result = await _client
          .from('task_messages')
          .select()
          .eq('task_id', taskId)
          .count(CountOption.exact);
      return result.count;
    } else if (subtaskId != null) {
      final result = await _client
          .from('task_messages')
          .select()
          .eq('subtask_id', subtaskId)
          .count(CountOption.exact);
      return result.count;
    }
    return 0;
  }
}
