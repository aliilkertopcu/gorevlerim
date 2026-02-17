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

/// Optimistic state for tasks - allows instant UI updates
class TasksNotifier extends StateNotifier<List<Task>> {
  TasksNotifier() : super([]);

  DateTime? _lastOptimisticUpdate;
  static const _debounceMs = 800; // Ignore stream updates for 800ms after optimistic change

  void setTasks(List<Task> tasks) {
    // If we recently did an optimistic update, ignore stream data briefly
    if (_lastOptimisticUpdate != null) {
      final elapsed = DateTime.now().difference(_lastOptimisticUpdate!).inMilliseconds;
      if (elapsed < _debounceMs) {
        return; // Skip this stream update
      }
      _lastOptimisticUpdate = null;
    }
    state = tasks;
  }

  void _markOptimisticUpdate() {
    _lastOptimisticUpdate = DateTime.now();
  }

  /// Optimistic toggle complete - also updates non-deleted subtasks
  void optimisticToggleComplete(String taskId) {
    _markOptimisticUpdate();
    state = state.map((task) {
      if (task.id == taskId) {
        final newStatus = task.isCompleted ? 'pending' : 'completed';
        // Update all non-deleted subtasks to match parent status
        final updatedSubtasks = task.subtasks.map((s) {
          if (s.status != 'deleted') {
            return s.copyWith(status: newStatus);
          }
          return s;
        }).toList();
        return task.copyWith(
          status: newStatus,
          subtasks: updatedSubtasks,
        );
      }
      return task;
    }).toList();
  }

  /// Optimistic toggle subtask complete
  void optimisticToggleSubtask(String taskId, String subtaskId) {
    _markOptimisticUpdate();
    state = state.map((task) {
      if (task.id == taskId) {
        final updatedSubtasks = task.subtasks.map((s) {
          if (s.id == subtaskId) {
            return s.copyWith(
              status: s.isCompleted ? 'pending' : 'completed',
            );
          }
          return s;
        }).toList();
        return task.copyWith(subtasks: updatedSubtasks);
      }
      return task;
    }).toList();
  }

  /// Optimistic delete task
  void optimisticDeleteTask(String taskId) {
    _markOptimisticUpdate();
    state = state.where((task) => task.id != taskId).toList();
  }

  /// Optimistic delete subtask
  void optimisticDeleteSubtask(String taskId, String subtaskId) {
    _markOptimisticUpdate();
    state = state.map((task) {
      if (task.id == taskId) {
        final updatedSubtasks = task.subtasks.where((s) => s.id != subtaskId).toList();
        return task.copyWith(subtasks: updatedSubtasks);
      }
      return task;
    }).toList();
  }

  /// Optimistic block task
  void optimisticBlockTask(String taskId, String? reason) {
    _markOptimisticUpdate();
    state = state.map((task) {
      if (task.id == taskId) {
        return task.copyWith(status: 'blocked', blockReason: reason);
      }
      return task;
    }).toList();
  }

  /// Optimistic unblock task
  void optimisticUnblockTask(String taskId) {
    _markOptimisticUpdate();
    state = state.map((task) {
      if (task.id == taskId) {
        return task.copyWith(status: 'pending', blockReason: null);
      }
      return task;
    }).toList();
  }

  /// Optimistic block subtask
  void optimisticBlockSubtask(String taskId, String subtaskId, String? reason) {
    _markOptimisticUpdate();
    state = state.map((task) {
      if (task.id == taskId) {
        final updatedSubtasks = task.subtasks.map((s) {
          if (s.id == subtaskId) {
            return s.copyWith(status: 'blocked', blockReason: reason);
          }
          return s;
        }).toList();
        return task.copyWith(subtasks: updatedSubtasks);
      }
      return task;
    }).toList();
  }

  /// Optimistic update task
  void optimisticUpdateTask(String taskId, {String? title, String? description}) {
    _markOptimisticUpdate();
    state = state.map((task) {
      if (task.id == taskId) {
        return task.copyWith(
          title: title ?? task.title,
          description: description,
        );
      }
      return task;
    }).toList();
  }

  /// Optimistic update subtask
  void optimisticUpdateSubtask(String taskId, String subtaskId, String title) {
    _markOptimisticUpdate();
    state = state.map((task) {
      if (task.id == taskId) {
        final updatedSubtasks = task.subtasks.map((s) {
          if (s.id == subtaskId) {
            return s.copyWith(title: title);
          }
          return s;
        }).toList();
        return task.copyWith(subtasks: updatedSubtasks);
      }
      return task;
    }).toList();
  }

  /// Optimistic reorder tasks
  void optimisticReorderTasks(int oldIndex, int newIndex) {
    _markOptimisticUpdate();
    final tasks = [...state];
    final task = tasks.removeAt(oldIndex);
    tasks.insert(newIndex, task);
    state = tasks;
  }

  /// Optimistic reorder subtasks
  void optimisticReorderSubtasks(String taskId, int oldIndex, int newIndex) {
    _markOptimisticUpdate();
    state = state.map((task) {
      if (task.id == taskId) {
        final subtasks = [...task.subtasks];
        final subtask = subtasks.removeAt(oldIndex);
        subtasks.insert(newIndex, subtask);
        return task.copyWith(subtasks: subtasks);
      }
      return task;
    }).toList();
  }
}

final tasksNotifierProvider = StateNotifierProvider<TasksNotifier, List<Task>>((ref) {
  return TasksNotifier();
});

/// Stream that syncs server data to local state
final tasksStreamProvider = StreamProvider.autoDispose<List<Task>>((ref) {
  final taskService = ref.watch(taskServiceProvider);
  final owner = ref.watch(ownerContextProvider);
  final date = ref.watch(selectedDateProvider);
  final notifier = ref.watch(tasksNotifierProvider.notifier);

  if (owner == null) {
    return Stream.value([]);
  }

  return taskService
      .streamTasksWithSubtasks(
        ownerId: owner.ownerId,
        ownerType: owner.ownerType,
        date: date,
      )
      .map((tasks) {
    // Sync server data to local state
    notifier.setTasks(tasks);
    return tasks;
  });
});

/// Tracks which tasks are collapsed. Empty set = all expanded (default).
final collapsedTasksProvider = StateProvider<Set<String>>((ref) => {});

/// Main provider to use in UI - uses local state with stream sync
final tasksProvider = Provider.autoDispose<AsyncValue<List<Task>>>((ref) {
  // Subscribe to stream to trigger updates
  final streamAsync = ref.watch(tasksStreamProvider);
  // Get optimistic local state
  final localTasks = ref.watch(tasksNotifierProvider);

  // If we have local data, use it (optimistic) — even if stream temporarily errors
  // This prevents flashing an error screen when app resumes from background
  if (localTasks.isNotEmpty) {
    return AsyncValue.data(localTasks);
  }

  // If stream has error and no local data, show loading and auto-retry
  if (streamAsync.hasError) {
    Future.delayed(const Duration(seconds: 2), () {
      ref.invalidate(tasksStreamProvider);
    });
    return const AsyncValue.loading();
  }

  // If stream is loading and no local data, show loading
  if (streamAsync.isLoading) {
    return const AsyncValue.loading();
  }

  // Stream has data, use it
  return AsyncValue.data(streamAsync.value ?? []);
});
