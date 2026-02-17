import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import 'auth_provider.dart';
import 'group_provider.dart';

final taskServiceProvider = Provider<TaskService>((ref) {
  return TaskService(ref.watch(supabaseProvider));
});

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Current owner context: always a group (personal or shared)
class OwnerContext {
  final String ownerId;
  final String ownerType; // always 'group' after migration

  const OwnerContext({required this.ownerId, required this.ownerType});
}

final ownerContextProvider = StateProvider<OwnerContext?>((ref) {
  // Default is null — viewStateInitProvider sets the actual value on startup
  return null;
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

  /// Optimistic toggle lock
  void optimisticToggleLock(String taskId) {
    _markOptimisticUpdate();
    state = state.map((task) {
      if (task.id == taskId) {
        return task.copyWith(locked: !task.locked);
      }
      return task;
    }).toList();
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

  // Check group's show_past_incomplete setting
  final group = ref.watch(currentGroupProvider);
  final showPastIncomplete = group?.settings['show_past_incomplete'] as bool? ?? false;

  return taskService
      .streamTasksWithSubtasks(
        ownerId: owner.ownerId,
        ownerType: owner.ownerType,
        date: date,
        showPastIncomplete: showPastIncomplete,
      )
      .map((tasks) {
    // Sync server data to local state
    notifier.setTasks(tasks);
    return tasks;
  });
});

/// Tracks which tasks are collapsed. Empty set = all expanded (default).
/// Auto-persists to SharedPreferences.
class CollapsedTasksNotifier extends StateNotifier<Set<String>> {
  CollapsedTasksNotifier() : super({}) {
    _load();
  }

  static const _key = 'view_collapsed_tasks';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key);
    if (list != null && list.isNotEmpty) state = list.toSet();
  }

  void update(Set<String> newState) {
    state = newState;
    _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.toList());
  }
}

final collapsedTasksProvider = StateNotifierProvider<CollapsedTasksNotifier, Set<String>>((ref) {
  return CollapsedTasksNotifier();
});

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

/// Persistence helpers for owner context
class ViewStatePersistence {
  static const _ownerIdKey = 'view_owner_id';
  static const _ownerTypeKey = 'view_owner_type';

  static Future<void> saveOwnerContext(OwnerContext owner) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ownerIdKey, owner.ownerId);
    await prefs.setString(_ownerTypeKey, owner.ownerType);
  }

  static Future<OwnerContext?> loadOwnerContext() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_ownerIdKey);
    final type = prefs.getString(_ownerTypeKey);
    if (id != null && type != null) {
      return OwnerContext(ownerId: id, ownerType: type);
    }
    return null;
  }
}

/// Restores persisted view state on app start.
/// Falls back to the personal group if no saved state or saved group no longer exists.
final viewStateInitProvider = FutureProvider<void>((ref) async {
  final groups = await ref.read(userGroupsProvider.future);
  if (groups.isEmpty) return;

  final saved = await ViewStatePersistence.loadOwnerContext();

  // Try to restore saved group
  if (saved != null) {
    final groupExists = groups.any((g) => g.id == saved.ownerId);
    if (groupExists) {
      ref.read(ownerContextProvider.notifier).state = saved;
      return;
    }
  }

  // Default to personal group
  final personalGroup = groups.where((g) => g.isPersonal).firstOrNull;
  if (personalGroup != null) {
    final owner = OwnerContext(ownerId: personalGroup.id, ownerType: 'group');
    ref.read(ownerContextProvider.notifier).state = owner;
  } else if (groups.isNotEmpty) {
    // Fallback: first available group
    final owner = OwnerContext(ownerId: groups.first.id, ownerType: 'group');
    ref.read(ownerContextProvider.notifier).state = owner;
  }
});

/// Check if current user can edit/delete a task based on group permission settings
bool canEditTask(WidgetRef ref, Task task) {
  final user = ref.read(currentUserProvider);
  if (user == null) return false;

  final group = ref.read(currentGroupProvider);
  if (group == null) return true;

  // Personal group — always editable
  if (group.isPersonal) return true;

  // Group creator bypasses all restrictions
  if (group.createdBy == user.id) return true;

  final permission = group.settings['task_edit_permission'] as String? ?? 'allow';

  switch (permission) {
    case 'allow':
      return true;
    case 'deny':
      return task.createdBy == user.id;
    case 'per_task':
      if (task.locked && task.createdBy != user.id) return false;
      return true;
    default:
      return true;
  }
}
