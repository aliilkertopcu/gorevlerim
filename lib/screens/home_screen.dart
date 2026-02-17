import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../providers/task_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/date_nav.dart';
import '../widgets/task_card.dart';
import '../widgets/task_form.dart';
import '../widgets/group_selector.dart';
import '../widgets/group_manager.dart';
import '../widgets/ai_setup_dialog.dart';
import '../widgets/desktop_dialog.dart';
import '../version.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    final currentTheme = ref.watch(themeNotifierProvider);
    final ownerColor = ref.watch(currentOwnerColorProvider);

    // Restore persisted view state (last viewed group) on first build
    ref.watch(viewStateInitProvider);

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragOffset += details.delta.dx;
              _dragOffset = _dragOffset.clamp(-60.0, 60.0);
            });
          },
          onHorizontalDragEnd: (details) {
            // Swipe threshold
            if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 300) {
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
            }
            setState(() => _dragOffset = 0);
          },
          onHorizontalDragCancel: () {
            setState(() => _dragOffset = 0);
          },
          child: Stack(
            children: [
              // Swipe direction indicators
              if (_dragOffset > 15)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Opacity(
                      opacity: ((_dragOffset - 15) / 45).clamp(0.0, 1.0),
                      child: Icon(Icons.chevron_left, size: 28, color: ownerColor.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              if (_dragOffset < -15)
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Opacity(
                      opacity: ((-_dragOffset - 15) / 45).clamp(0.0, 1.0),
                      child: Icon(Icons.chevron_right, size: 28, color: ownerColor.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              // Main content with drag offset
              AnimatedSlide(
                offset: Offset(_dragOffset / MediaQuery.of(context).size.width, 0),
                duration: _dragOffset == 0 ? const Duration(milliseconds: 200) : Duration.zero,
                curve: Curves.easeOutCubic,
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(tasksStreamProvider);
                    try {
                      await ref.read(tasksStreamProvider.future);
                    } catch (_) {}
                  },
                  child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          children: [
                            // Custom AppBar - same width as content
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: ownerColor,
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
                                    onSelected: (value) => _onMenuAction(context, value),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'ai',
                                        child: Row(
                                          children: [
                                            Icon(Icons.smart_toy),
                                            SizedBox(width: 12),
                                            Text('AI Entegrasyonu'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'groups',
                                        child: Row(
                                          children: [
                                            Icon(Icons.group),
                                            SizedBox(width: 12),
                                            Text('Gruplar'),
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
                                        value: 'onboarding',
                                        child: Row(
                                          children: [
                                            Icon(Icons.new_releases_outlined),
                                            SizedBox(width: 12),
                                            Text('Neler Yeni?'),
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
                            const SizedBox(height: 4),
                            // Expand/Collapse all button
                            tasksAsync.when(
                              data: (tasks) {
                                final hasExpandable = tasks.any((t) =>
                                    t.subtasks.isNotEmpty ||
                                    (t.description != null && t.description!.isNotEmpty) ||
                                    (t.isBlocked && t.blockReason != null));
                                if (!hasExpandable || tasks.isEmpty) return const SizedBox.shrink();
                                final collapsed = ref.watch(collapsedTasksProvider);
                                final allCollapsed = tasks.every((t) => collapsed.contains(t.id));
                                return Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      if (allCollapsed) {
                                        ref.read(collapsedTasksProvider.notifier).update({});
                                      } else {
                                        ref.read(collapsedTasksProvider.notifier).update(
                                            tasks.map((t) => t.id).toSet());
                                      }
                                    },
                                    icon: Icon(
                                      allCollapsed ? Icons.unfold_more : Icons.unfold_less,
                                      size: 18,
                                    ),
                                    label: Text(
                                      allCollapsed ? 'Tümünü Aç' : 'Tümünü Kapat',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: ownerColor,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: const Size(0, 32),
                                    ),
                                  ),
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const SizedBox.shrink(),
                            ),
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
                                    ],
                                  );
                                }

                                return ReorderableListView.builder(
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
                                    return AnimatedBuilder(
                                      animation: animation,
                                      builder: (context, child) => Opacity(
                                        opacity: 0.85,
                                        child: Material(
                                          elevation: 8,
                                          borderRadius: BorderRadius.circular(8),
                                          color: Colors.transparent,
                                          child: child,
                                        ),
                                      ),
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
                                      style: ElevatedButton.styleFrom(backgroundColor: ownerColor),
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
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: _buildFooter(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  void _onMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'ai':
        showDialog(
          context: context,
          builder: (_) => const AISetupDialog(),
        );
      case 'groups':
        showDialog(
          context: context,
          builder: (_) => const GroupManagerDialog(),
        );
      case 'onboarding':
        GoRouter.of(context).push('/onboarding');
      case 'theme':
        _showThemeDialog(context);
      case 'logout':
        ref.read(authServiceProvider).signOut();
    }
  }

  void _showThemeDialog(BuildContext context) {
    final currentTheme = ref.read(themeNotifierProvider);

    showAppDialog(
      context: context,
      title: const Text('Tema Seçimi'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildThemeOption(
            context,
            AppThemeMode.light,
            'Açık',
            Icons.light_mode,
            currentTheme,
          ),
          _buildThemeOption(
            context,
            AppThemeMode.dark,
            'Koyu',
            Icons.dark_mode,
            currentTheme,
          ),
          _buildThemeOption(
            context,
            AppThemeMode.system,
            'Otomatik',
            Icons.brightness_auto,
            currentTheme,
          ),
        ],
      ),
      actions: [],
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
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
      child: GestureDetector(
        onTap: () => GoRouter.of(context).push('/onboarding'),
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
              'v$appVersion · @izmir 2026',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).hintColor.withValues(alpha: 0.7),
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
