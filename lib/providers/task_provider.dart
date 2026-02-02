import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:riverpod/legacy.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import 'auth_provider.dart';

final taskServiceProvider = Provider<TaskService>((ref) {
  return TaskService(ref.watch(supabaseProvider));
});

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Current owner context: user's own tasks or a group's tasks
class OwnerContext {
  final String ownerId;
  final String ownerType; // 'user' or 'group'

  const OwnerContext({required this.ownerId, required this.ownerType});
}

final ownerContextProvider = StateProvider<OwnerContext?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return OwnerContext(ownerId: user.id, ownerType: 'user');
});

final tasksProvider = FutureProvider.autoDispose<List<Task>>((ref) async {
  final taskService = ref.watch(taskServiceProvider);
  final owner = ref.watch(ownerContextProvider);
  final date = ref.watch(selectedDateProvider);

  if (owner == null) return [];

  return taskService.fetchTasks(
    ownerId: owner.ownerId,
    ownerType: owner.ownerType,
    date: date,
  );
});
