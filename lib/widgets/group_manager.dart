import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';

part 'group_detail_members.dart';
part 'group_detail_settings.dart';
part 'group_detail_activity.dart';
part 'group_detail_actions.dart';

/// Preset colors for group color picker
const _groupColors = [
  '#667eea', // purple (default)
  '#e53e3e', // red
  '#dd6b20', // orange
  '#38a169', // green
  '#3182ce', // blue
  '#805ad5', // violet
  '#d53f8c', // pink
  '#718096', // gray
];

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

  // For group detail view
  Group? _selectedGroup;

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
    // If a group is selected, show group detail view
    if (_selectedGroup != null) {
      return _GroupDetailView(
        group: _selectedGroup!,
        onBack: () => setState(() => _selectedGroup = null),
        onGroupUpdated: (updatedGroup) {
          ref.invalidate(userGroupsProvider);
          if (updatedGroup != null) {
            setState(() => _selectedGroup = updatedGroup);
          }
        },
        onGroupDeleted: () {
          setState(() => _selectedGroup = null);
          ref.invalidate(userGroupsProvider);
        },
      );
    }

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
                    'Liste Yönetimi',
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
                Tab(text: 'Listelerim'),
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
                          child: Text('Henüz bir listeniz yok'),
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
                            subtitle: group.isPersonal
                                ? const Text('Kişisel liste')
                                : Text('Davet kodu: ${group.inviteCode}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              setState(() => _selectedGroup = group);
                            },
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
                          'Yeni Liste Oluştur',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _groupNameController,
                          decoration: const InputDecoration(
                            hintText: 'Liste adı (ör. Ev İşleri)',
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
                          'Listeye Katıl',
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
          const SnackBar(content: Text('Liste oluşturuldu')),
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
          const SnackBar(content: Text('Listeye katıldınız')),
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

// ─────────────────────────────────────────────
// Group Detail View
// ─────────────────────────────────────────────

class _GroupDetailView extends ConsumerStatefulWidget {
  final Group group;
  final VoidCallback onBack;
  final void Function(Group? updatedGroup) onGroupUpdated;
  final VoidCallback onGroupDeleted;

  const _GroupDetailView({
    required this.group,
    required this.onBack,
    required this.onGroupUpdated,
    required this.onGroupDeleted,
  });

  @override
  ConsumerState<_GroupDetailView> createState() => _GroupDetailViewState();
}

class _GroupDetailViewState extends ConsumerState<_GroupDetailView> {
  /// setState wrapper callable from the extension parts (setState is @protected).
  void _refresh(VoidCallback fn) => setState(fn);
  List<Map<String, dynamic>>? _members;
  List<Map<String, dynamic>> _activityLog = [];
  List<Map<String, dynamic>>? _invites;
  bool _isLoadingMembers = true;
  bool _isLoadingLog = false;
  bool _isLoadingMoreLog = false;
  bool _hasMoreLog = true;
  bool _isLoading = false;
  bool _isLoadingInvites = false;
  late String _currentColor;
  late String _currentName;
  late String _currentDescription;
  bool _isEditingName = false;
  bool _isEditingDescription = false;
  bool _showActivityLog = false;
  bool _showInvites = false;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentColor = widget.group.color;
    _currentName = widget.group.name;
    _currentDescription = widget.group.description ?? '';
    _nameController = TextEditingController(text: _currentName);
    _descriptionController = TextEditingController(text: _currentDescription);
    if (!widget.group.isPersonal) {
      _loadMembers();
    } else {
      _isLoadingMembers = false;
    }
    _logScrollController.addListener(_onLogScroll);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  void _onLogScroll() {
    if (_logScrollController.position.pixels >=
            _logScrollController.position.maxScrollExtent - 50 &&
        !_isLoadingMoreLog &&
        _hasMoreLog) {
      _loadMoreActivityLog();
    }
  }

  Future<void> _loadMembers() async {
    try {
      final members = await ref.read(groupServiceProvider).getGroupMembers(widget.group.id);
      if (mounted) {
        setState(() {
          _members = members;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  Future<void> _loadActivityLog() async {
    setState(() {
      _isLoadingLog = true;
      _activityLog = [];
      _hasMoreLog = true;
    });
    try {
      final logs = await ref.read(groupServiceProvider).getActivityLog(
        widget.group.id,
        limit: 20,
        offset: 0,
      );
      if (mounted) {
        setState(() {
          _activityLog = logs;
          _isLoadingLog = false;
          _hasMoreLog = logs.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLog = false);
      }
    }
  }

  Future<void> _loadMoreActivityLog() async {
    if (_isLoadingMoreLog || !_hasMoreLog) return;
    setState(() => _isLoadingMoreLog = true);
    try {
      final logs = await ref.read(groupServiceProvider).getActivityLog(
        widget.group.id,
        limit: 20,
        offset: _activityLog.length,
      );
      if (mounted) {
        setState(() {
          _activityLog.addAll(logs);
          _isLoadingMoreLog = false;
          _hasMoreLog = logs.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMoreLog = false);
      }
    }
  }

  Future<void> _loadInvites() async {
    setState(() => _isLoadingInvites = true);
    try {
      final invites = await ref.read(groupServiceProvider).getGroupInvites(widget.group.id);
      if (mounted) {
        setState(() {
          _invites = invites;
          _isLoadingInvites = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingInvites = false);
      }
    }
  }

  bool get _isCreator {
    final user = ref.read(currentUserProvider);
    return user != null && user.id == widget.group.createdBy;
  }

  /// Check if activity log is visible to current user
  bool get _canViewActivityLog {
    if (_isCreator) return true;
    final visibility = widget.group.settings['activity_log_visibility'] as String?;
    return visibility == 'all_members';
  }

  @override
  Widget build(BuildContext context) {
    final groupColor = _parseColor(_currentColor);

    return Dialog(
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with group color
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: groupColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: widget.onBack,
                    borderRadius: BorderRadius.circular(20),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isEditingName
                        ? TextField(
                            controller: _nameController,
                            autofocus: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _saveName(),
                          )
                        : GestureDetector(
                            onTap: _isCreator ? () => setState(() => _isEditingName = true) : null,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _currentName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_isCreator) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                  if (_isEditingName)
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.white),
                      onPressed: _saveName,
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Invite code (not for personal groups)
                    if (!widget.group.isPersonal) ...[
                      _buildInviteCode(),
                      const SizedBox(height: 16),
                    ],
                    // Description
                    _buildDescription(),
                    const SizedBox(height: 16),
                    // Color picker (creator only)
                    if (_isCreator) ...[
                      _buildColorPicker(groupColor),
                      const SizedBox(height: 16),
                    ],
                    // Members (not for personal groups)
                    if (!widget.group.isPersonal) ...[
                      _buildMembersList(),
                      const SizedBox(height: 16),
                    ],
                    // Settings section (creator only)
                    if (_isCreator) ...[
                      _buildSettingsSection(),
                      const SizedBox(height: 16),
                    ],
                    // Invite links (creator only, not for personal groups)
                    if (_isCreator && !widget.group.isPersonal) ...[
                      _buildInviteLinksSection(),
                      const SizedBox(height: 16),
                    ],
                    // Activity log (not for personal groups)
                    if (!widget.group.isPersonal && _canViewActivityLog) ...[
                      _buildActivityLog(),
                      const SizedBox(height: 16),
                    ],
                    // Leave / Delete (not for personal groups)
                    if (!widget.group.isPersonal)
                      _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isCreator) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isLoading ? null : _confirmDeleteGroup,
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          label: Text(
            'Listeyi Sil',
            style: TextStyle(color: Colors.red[400]),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.red[300]!),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isLoading ? null : _confirmLeaveGroup,
          icon: Icon(Icons.exit_to_app, color: Colors.orange[700]),
          label: Text(
            'Listeden Ayrıl',
            style: TextStyle(color: Colors.orange[700]),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.orange[300]!),
          ),
        ),
      );
    }
  }

  // ─── Actions ───────────────────────────────

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
