import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../theme/app_theme.dart';

class GroupManagerDialog extends ConsumerStatefulWidget {
  const GroupManagerDialog({super.key});

  @override
  ConsumerState<GroupManagerDialog> createState() => _GroupManagerDialogState();
}

class _GroupManagerDialogState extends ConsumerState<GroupManagerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _groupNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _groupNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(userGroupsProvider);

    return Dialog(
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.group, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'Grup Yönetimi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Gruplarım'),
                Tab(text: 'Oluştur / Katıl'),
              ],
            ),
            // Tab content
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // My Groups
                  groupsAsync.when(
                    data: (groups) {
                      if (groups.isEmpty) {
                        return const Center(
                          child: Text('Henüz bir grubunuz yok'),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _parseColor(group.color),
                              child: Text(
                                group.name[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(group.name),
                            subtitle: Text('Davet kodu: ${group.inviteCode}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              tooltip: 'Kodu kopyala',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: group.inviteCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Davet kodu kopyalandı')),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Hata: $e')),
                  ),
                  // Create / Join
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Yeni Grup Oluştur',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _groupNameController,
                          decoration: const InputDecoration(
                            hintText: 'Grup adı (ör. Ev İşleri)',
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _createGroup,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Oluştur'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          'Gruba Katıl',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _inviteCodeController,
                          decoration: const InputDecoration(
                            hintText: 'Davet kodu',
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _joinGroup,
                            child: const Text('Katıl'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(groupServiceProvider).createGroup(
        name: name,
        createdBy: user.id,
      );
      _groupNameController.clear();
      ref.invalidate(userGroupsProvider);
      _tabController.animateTo(0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grup oluşturuldu')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGroup() async {
    final code = _inviteCodeController.text.trim();
    if (code.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(groupServiceProvider).joinGroup(
        inviteCode: code,
        userId: user.id,
      );
      _inviteCodeController.clear();
      ref.invalidate(userGroupsProvider);
      _tabController.animateTo(0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gruba katıldınız')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
