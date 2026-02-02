import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';

class GroupSelector extends ConsumerWidget {
  const GroupSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsProvider);
    final owner = ref.watch(ownerContextProvider);
    final user = ref.watch(currentUserProvider);

    return groupsAsync.when(
      data: (groups) {
        final items = <_SelectorItem>[
          _SelectorItem(
            id: user?.id ?? '',
            name: '\u{1F4CB} Günlük Görevler',
            type: 'user',
            color: AppTheme.primaryColor,
          ),
          ...groups.map((g) => _SelectorItem(
            id: g.id,
            name: g.name,
            type: 'group',
            color: _parseColor(g.color),
          )),
        ];

        final selectedId = owner?.ownerId ?? user?.id ?? '';

        return PopupMenuButton<String>(
          onSelected: (id) {
            final item = items.firstWhere((i) => i.id == id);
            ref.read(ownerContextProvider.notifier).state = OwnerContext(
              ownerId: item.id,
              ownerType: item.type,
            );
            ref.invalidate(tasksProvider);
          },
          itemBuilder: (context) => items.map((item) {
            return PopupMenuItem<String>(
              value: item.id,
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(item.name),
                  if (item.id == selectedId) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 18, color: AppTheme.primaryColor),
                  ],
                ],
              ),
            );
          }).toList(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                items.firstWhere((i) => i.id == selectedId, orElse: () => items.first).name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.white),
            ],
          ),
        );
      },
      loading: () => const Text('...', style: TextStyle(color: Colors.white)),
      error: (e, st) => const Text('Hata', style: TextStyle(color: Colors.white)),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

class _SelectorItem {
  final String id;
  final String name;
  final String type;
  final Color color;

  _SelectorItem({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
  });
}
