import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:riverpod/legacy.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import 'auth_provider.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref.watch(supabaseProvider));
});

/// Stream of messages for a task
final taskMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, taskId) {
  return ref.read(chatServiceProvider).streamTaskMessages(taskId);
});

/// Stream of messages for a subtask
final subtaskMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, subtaskId) {
  return ref.read(chatServiceProvider).streamSubtaskMessages(subtaskId);
});

/// Set of task IDs whose chat panel is open
final chatOpenTasksProvider = StateProvider<Set<String>>((ref) => <String>{});

/// Set of subtask IDs whose chat panel is open
final chatOpenSubtasksProvider = StateProvider<Set<String>>((ref) => <String>{});
