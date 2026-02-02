import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/date_nav.dart';
import '../widgets/task_card.dart';
import '../widgets/task_form.dart';
import '../widgets/group_selector.dart';
import '../widgets/group_manager.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            const GroupSelector(),
            const SizedBox(width: 8),
            tasksAsync.when(
              data: (tasks) {
                final completed = tasks.where((t) => t.status == 'completed').length;
                return Text(
                  '($completed/${tasks.length})',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w400,
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, st) => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Grup Yönetimi',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const GroupManagerDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış',
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
          children: [
            const DateNav(),
            const SizedBox(height: 8),
            const TaskForm(),
            const SizedBox(height: 8),
            Expanded(
              child: tasksAsync.when(
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.task_alt,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Bu gün için görev yok',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Yukarıdan yeni görev ekleyebilirsin',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: tasks.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) newIndex--;
                      final taskIds = tasks.map((t) => t.id).toList();
                      final movedId = taskIds.removeAt(oldIndex);
                      taskIds.insert(newIndex, movedId);
                      await ref.read(taskServiceProvider).reorderTasks(taskIds);
                      ref.invalidate(tasksProvider);
                    },
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return TaskCard(
                        key: ValueKey(task.id),
                        task: task,
                        index: index,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Hata: $error'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(tasksProvider),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}
