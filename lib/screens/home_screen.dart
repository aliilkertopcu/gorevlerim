import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
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
    final currentTheme = ref.watch(themeNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            // Swipe threshold
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity!.abs() < 300) return;

            final currentDate = ref.read(selectedDateProvider);
            if (details.primaryVelocity! > 0) {
              // Swipe right → previous day
              ref.read(selectedDateProvider.notifier).state =
                  currentDate.subtract(const Duration(days: 1));
            } else {
              // Swipe left → next day
              ref.read(selectedDateProvider.notifier).state =
                  currentDate.add(const Duration(days: 1));
            }
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Custom AppBar - same width as content
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
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
                          const Spacer(),
                          // Hamburger Menu
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            tooltip: 'Menü',
                            onSelected: (value) => _onMenuAction(context, ref, value),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'groups',
                                child: Row(
                                  children: [
                                    Icon(Icons.group),
                                    SizedBox(width: 12),
                                    Text('Grup Yönetimi'),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'theme',
                                child: Row(
                                  children: [
                                    Icon(_getThemeIcon(currentTheme)),
                                    const SizedBox(width: 12),
                                    const Text('Tema'),
                                    const Spacer(),
                                    Text(
                                      _getThemeLabel(currentTheme),
                                      style: TextStyle(
                                        color: Theme.of(context).hintColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    Icon(Icons.logout, color: Colors.red),
                                    SizedBox(width: 12),
                                    Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const DateNav(),
                    const SizedBox(height: 8),
                    const TaskForm(),
                    const SizedBox(height: 8),
                    // Task list content
                    tasksAsync.when(
                      data: (tasks) {
                        if (tasks.isEmpty) {
                          return Column(
                            children: [
                              const SizedBox(height: 80),
                              Icon(
                                Icons.task_alt,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Bu gün için görev yok',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Yukarıdan yeni görev ekleyebilirsin',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 80),
                              _buildFooter(context),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              itemCount: tasks.length,
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) newIndex--;
                                ref.read(tasksNotifierProvider.notifier).optimisticReorderTasks(oldIndex, newIndex);
                                final movedId = tasks[oldIndex].id;
                                final taskIds = tasks.map((t) => t.id).toList();
                                taskIds.removeAt(oldIndex);
                                taskIds.insert(newIndex, movedId);
                                ref.read(taskServiceProvider).reorderTasks(
                                  taskIds,
                                  movedTaskId: movedId,
                                  oldIndex: oldIndex,
                                  newIndex: newIndex,
                                );
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
                            ),
                            _buildFooter(context),
                          ],
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text('Hata: $error'),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => ref.invalidate(tasksStreamProvider),
                              child: const Text('Tekrar Dene'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'groups':
        showDialog(
          context: context,
          builder: (_) => const GroupManagerDialog(),
        );
      case 'theme':
        _showThemeDialog(context, ref);
      case 'logout':
        ref.read(authServiceProvider).signOut();
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.read(themeNotifierProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tema Seçimi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
              context, ref,
              AppThemeMode.light,
              'Açık',
              Icons.light_mode,
              currentTheme,
            ),
            _buildThemeOption(
              context, ref,
              AppThemeMode.dark,
              'Koyu',
              Icons.dark_mode,
              currentTheme,
            ),
            _buildThemeOption(
              context, ref,
              AppThemeMode.system,
              'Otomatik',
              Icons.brightness_auto,
              currentTheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode mode,
    String label,
    IconData icon,
    AppThemeMode currentTheme,
  ) {
    final isSelected = currentTheme == mode;

    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).primaryColor : null),
      title: Text(label),
      trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
      onTap: () {
        ref.read(themeNotifierProvider.notifier).setTheme(mode);
        Navigator.pop(context);
      },
    );
  }

  IconData _getThemeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  String _getThemeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Açık';
      case AppThemeMode.dark:
        return 'Koyu';
      case AppThemeMode.system:
        return 'Oto';
    }
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Column(
        children: [
          Text(
            'made with curiosity \u{1F9E0}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).hintColor,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '@izmir 2026',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).hintColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}
