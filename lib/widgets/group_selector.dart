import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/group_provider.dart';
import '../providers/task_provider.dart';

class GroupSelector extends ConsumerWidget {
  const GroupSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsProvider);
    final owner = ref.watch(ownerContextProvider);

    return groupsAsync.when(
      data: (groups) {
        // Personal group first, then shared groups alphabetically
        final sorted = [...groups]..sort((a, b) {
          if (a.isPersonal && !b.isPersonal) return -1;
          if (!a.isPersonal && b.isPersonal) return 1;
          return a.name.compareTo(b.name);
        });

        final items = sorted.map((g) => _SelectorItem(
          id: g.id,
          name: g.name,
          color: _parseColor(g.color),
        )).toList();

        if (items.isEmpty) {
          return const Text('...', style: TextStyle(color: Colors.white));
        }

        final selectedId = owner?.ownerId ?? items.first.id;

        return PopupMenuButton<String>(
          onSelected: (id) {
            final newOwner = OwnerContext(
              ownerId: id,
              ownerType: 'group',
            );
            ref.read(ownerContextProvider.notifier).state = newOwner;
            ViewStatePersistence.saveOwnerContext(newOwner);
            ref.invalidate(tasksStreamProvider);
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
                    Icon(Icons.check, size: 18, color: item.color),
                  ],
                ],
              ),
            );
          }).toList(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                items.where((i) => i.id == selectedId).firstOrNull?.name ?? items.first.name,
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
  final Color color;

  _SelectorItem({
    required this.id,
    required this.name,
    required this.color,
  });
}
