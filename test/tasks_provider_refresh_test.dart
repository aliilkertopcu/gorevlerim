import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/task.dart';
import 'package:todo_app/providers/task_provider.dart';

Task _task(String id, {int sortOrder = 0}) => Task(
      id: id,
      ownerId: 'g1',
      ownerType: 'group',
      date: DateTime(2026, 8, 30),
      title: 'Task $id',
      sortOrder: sortOrder,
    );

void main() {
  group('tasksProvider loading vs refreshing', () {
    test('initial load with no local data → loading', () async {
      final container = ProviderContainer(overrides: [
        tasksStreamProvider.overrideWith((ref) => const Stream<List<Task>>.empty()),
      ]);
      addTearDown(container.dispose);

      expect(container.read(tasksProvider).isLoading, isTrue);
    });

    test('manual refresh keeps local data visible (no spinner)', () async {
      final controller = StreamController<List<Task>>.broadcast();
      addTearDown(controller.close);
      final container = ProviderContainer(overrides: [
        tasksStreamProvider.overrideWith((ref) => controller.stream),
      ]);
      addTearDown(container.dispose);

      // Keep the stream alive and seed data
      final sub = container.listen(tasksStreamProvider, (_, _) {});
      addTearDown(sub.close);
      final tasks = [_task('a'), _task('b')];
      controller.add(tasks);
      await Future<void>.delayed(Duration.zero);
      container.read(tasksNotifierProvider.notifier).setTasks(tasks);
      expect(container.read(tasksProvider).value, tasks);

      // Post-write refresh: stream restarts but the UI must keep the list
      // same steps as refreshTasks(ref)
      container.read(tasksNotifierProvider.notifier).clearOptimisticWindow();
      container.invalidate(tasksStreamProvider);
      final during = container.read(tasksProvider);
      expect(during.isLoading, isFalse, reason: 'refresh must not show a spinner');
      expect(during.value, tasks);
    });
  });

  group('TasksNotifier optimistic ops', () {
    test('optimisticInsertTask inserts at index and clamps', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(tasksNotifierProvider.notifier);
      n.setTasks([_task('a'), _task('b')]);
      n.optimisticInsertTask(_task('x'), 1);
      expect(container.read(tasksNotifierProvider).map((t) => t.id), ['a', 'x', 'b']);
      n.optimisticInsertTask(_task('y'), 99);
      expect(container.read(tasksNotifierProvider).last.id, 'y');
    });

    test('optimisticDemoteTask moves task + its subtasks under target', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(tasksNotifierProvider.notifier);
      final source = _task('s').copyWith(
        description: 'detay',
        subtasks: [Subtask(id: 's1', taskId: 's', title: 'child')],
      );
      n.setTasks([source, _task('t')]);
      n.optimisticDemoteTask('s', 't');
      final state = container.read(tasksNotifierProvider);
      expect(state.map((t) => t.id), ['t']);
      expect(state.first.subtasks.map((s) => s.title), ['Task s — detay', 'child']);
      expect(state.first.subtasks.every((s) => s.taskId == 't'), isTrue);
    });
  });
}
