import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';

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

  Widget _buildInviteCode() {
    return Row(
      children: [
        Icon(Icons.link, size: 18, color: Theme.of(context).hintColor),
        const SizedBox(width: 8),
        Text(
          'Davet kodu: ',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
        ),
        Text(
          widget.group.inviteCode,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          tooltip: 'Kodu kopyala',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.group.inviteCode));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Davet kodu kopyalandı')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDescription() {
    final groupColor = _parseColor(_currentColor);

    if (_isEditingDescription) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Açıklama',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Theme.of(context).hintColor,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: 'Liste açıklaması ekleyin...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  _descriptionController.text = _currentDescription;
                  setState(() => _isEditingDescription = false);
                },
                child: const Text('İptal'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveDescription,
                style: ElevatedButton.styleFrom(backgroundColor: groupColor),
                child: const Text('Kaydet'),
              ),
            ],
          ),
        ],
      );
    }

    // View mode
    final hasDescription = _currentDescription.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Açıklama',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Theme.of(context).hintColor,
              ),
            ),
            if (_isCreator) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _isEditingDescription = true),
                child: Icon(Icons.edit, size: 16, color: Theme.of(context).hintColor),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (hasDescription)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).hintColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _currentDescription,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          )
        else if (_isCreator)
          GestureDetector(
            onTap: () => setState(() => _isEditingDescription = true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).hintColor.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Açıklama ekle...',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).hintColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildColorPicker(Color currentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Liste Rengi',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Theme.of(context).hintColor,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _groupColors.map((hex) {
            final color = _parseColor(hex);
            final isSelected = hex.toLowerCase() == _currentColor.toLowerCase();
            return GestureDetector(
              onTap: () => _onColorSelected(hex),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                      : null,
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMembersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Üyeler',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Theme.of(context).hintColor,
              ),
            ),
            if (_members != null) ...[
              const SizedBox(width: 6),
              Text(
                '(${_members!.length})',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoadingMembers)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_members == null || _members!.isEmpty)
          Text(
            'Üye bulunamadı',
            style: TextStyle(color: Theme.of(context).hintColor),
          )
        else
          ...(_members!.map((member) => _buildMemberTile(member))),
      ],
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member) {
    final userId = member['user_id'] as String;
    final profiles = member['profiles'] as Map<String, dynamic>?;
    final displayName = profiles?['display_name'] as String? ?? '';
    final email = profiles?['email'] as String? ?? '';
    final isCreator = userId == widget.group.createdBy;
    final isCurrentUser = userId == ref.read(currentUserProvider)?.id;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: _parseColor(_currentColor).withValues(alpha: 0.2),
        child: Text(
          (displayName.isNotEmpty ? displayName[0] : email.isNotEmpty ? email[0] : '?')
              .toUpperCase(),
          style: TextStyle(
            color: _parseColor(_currentColor),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              displayName.isNotEmpty ? displayName : email,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCreator) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _parseColor(_currentColor).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Kurucu',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _parseColor(_currentColor),
                ),
              ),
            ),
          ],
          if (isCurrentUser && !isCreator) ...[
            const SizedBox(width: 6),
            Text(
              '(sen)',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
          ],
        ],
      ),
      subtitle: displayName.isNotEmpty && email.isNotEmpty
          ? Text(email, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor))
          : null,
      trailing: (_isCreator && !isCreator)
          ? IconButton(
              icon: Icon(Icons.person_remove, size: 18, color: Colors.red[400]),
              tooltip: 'Üyeyi çıkar',
              onPressed: () => _confirmRemoveMember(userId, displayName.isNotEmpty ? displayName : email),
            )
          : null,
    );
  }

  Widget _buildSettingsSection() {
    final logVisibility = widget.group.settings['activity_log_visibility'] as String? ?? 'creator_only';
    final taskEditPermission = widget.group.settings['task_edit_permission'] as String? ?? 'allow';
    final showPastIncomplete = widget.group.settings['show_past_incomplete'] as bool? ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ayarlar',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Theme.of(context).hintColor,
          ),
        ),
        const SizedBox(height: 8),
        // Show past incomplete tasks toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).hintColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.history_toggle_off, size: 18, color: Theme.of(context).hintColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Yapılmamış görevleri bugüne taşı',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              Switch(
                value: showPastIncomplete,
                onChanged: (value) => _updateShowPastIncomplete(value),
                activeTrackColor: _parseColor(_currentColor),
              ),
            ],
          ),
        ),
        // Task edit permission setting (not for personal groups)
        if (!widget.group.isPersonal) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).hintColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.edit_note, size: 18, color: Theme.of(context).hintColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Görev düzenleme',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
                DropdownButton<String>(
                  value: taskEditPermission,
                  underline: const SizedBox(),
                  isDense: true,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                  items: const [
                    DropdownMenuItem(value: 'allow', child: Text('Herkes')),
                    DropdownMenuItem(value: 'deny', child: Text('Sadece sahibi')),
                    DropdownMenuItem(value: 'per_task', child: Text('Görev bazlı')),
                  ],
                  onChanged: (value) {
                    if (value != null) _updateTaskEditPermission(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Activity log visibility setting
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).hintColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.history, size: 18, color: Theme.of(context).hintColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Geçmiş logu',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
                DropdownButton<String>(
                  value: logVisibility,
                  underline: const SizedBox(),
                  isDense: true,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                  items: const [
                    DropdownMenuItem(value: 'creator_only', child: Text('Sadece kurucu')),
                    DropdownMenuItem(value: 'all_members', child: Text('Tüm üyeler')),
                  ],
                  onChanged: (value) {
                    if (value != null) _updateLogVisibility(value);
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInviteLinksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (!_showInvites) {
              _loadInvites();
            }
            setState(() => _showInvites = !_showInvites);
          },
          child: Row(
            children: [
              Text(
                'Davet Bağlantıları',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _showInvites ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: Theme.of(context).hintColor,
              ),
            ],
          ),
        ),
        if (_showInvites) ...[
          const SizedBox(height: 8),
          // Create new invite button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showCreateInviteDialog,
              icon: const Icon(Icons.add_link, size: 18),
              label: const Text('Yeni Davet Oluştur'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _parseColor(_currentColor),
                side: BorderSide(color: _parseColor(_currentColor).withValues(alpha: 0.5)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_isLoadingInvites)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_invites == null || _invites!.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).hintColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Henüz davet bağlantısı yok',
                style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
              ),
            )
          else
            ...(_invites!.map((invite) => _buildInviteTile(invite))),
        ],
      ],
    );
  }

  Widget _buildInviteTile(Map<String, dynamic> invite) {
    final token = invite['token'] as String;
    final expiresAt = invite['expires_at'] != null
        ? DateTime.tryParse(invite['expires_at'] as String)
        : null;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    final base = Uri.base.toString().replaceAll(RegExp(r'#.*$'), '');
    final inviteUrl = '$base#/invite/$token';

    String expiryText;
    if (expiresAt == null) {
      expiryText = 'Süresiz';
    } else if (isExpired) {
      expiryText = 'Süresi dolmuş';
    } else {
      final diff = expiresAt.difference(DateTime.now());
      if (diff.inDays > 0) {
        expiryText = '${diff.inDays} gün kaldı';
      } else if (diff.inHours > 0) {
        expiryText = '${diff.inHours} saat kaldı';
      } else {
        expiryText = '${diff.inMinutes} dk kaldı';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).hintColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: isExpired
            ? Border.all(color: Colors.red.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          Icon(
            isExpired ? Icons.link_off : Icons.link,
            size: 16,
            color: isExpired ? Colors.red[400] : _parseColor(_currentColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '...${token.substring(token.length - 8)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: isExpired ? Colors.red[400] : null,
                  ),
                ),
                Text(
                  expiryText,
                  style: TextStyle(
                    fontSize: 11,
                    color: isExpired ? Colors.red[400] : Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
          if (!isExpired)
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Bağlantıyı kopyala',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: inviteUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Davet bağlantısı kopyalandı')),
                );
              },
            ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: Colors.red[400]),
            tooltip: 'Daveti sil',
            onPressed: () => _deleteInvite(invite['id'] as String),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (!_showActivityLog) {
              _loadActivityLog();
            }
            setState(() => _showActivityLog = !_showActivityLog);
          },
          child: Row(
            children: [
              Text(
                'Geçmiş',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _showActivityLog ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: Theme.of(context).hintColor,
              ),
            ],
          ),
        ),
        if (_showActivityLog) ...[
          const SizedBox(height: 8),
          if (_isLoadingLog)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_activityLog.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).hintColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Henüz kayıt yok',
                style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Theme.of(context).hintColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                controller: _logScrollController,
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: _activityLog.length + (_isLoadingMoreLog ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index >= _activityLog.length) {
                    return const Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  final log = _activityLog[index];
                  final profiles = log['profiles'] as Map<String, dynamic>?;
                  final name = profiles?['display_name'] as String? ?? '?';
                  final action = _localizeAction(log['action'] as String? ?? '');
                  final details = log['details'] as String?;
                  final createdAt = DateTime.tryParse(log['created_at'] as String? ?? '');
                  final timeStr = createdAt != null
                      ? '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
                      : '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).hintColor,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              children: [
                                TextSpan(
                                  text: name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                TextSpan(text: ' $action'),
                                if (details != null)
                                  TextSpan(
                                    text: ' — $details',
                                    style: TextStyle(color: Theme.of(context).hintColor),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }

  String _localizeAction(String action) {
    switch (action) {
      case 'member_joined': return 'listeye katıldı';
      case 'member_left': return 'listeden ayrıldı';
      case 'member_removed': return 'üyeyi çıkardı';
      case 'task_created': return 'görev oluşturdu';
      case 'task_deleted': return 'görevi sildi';
      case 'task_edited': return 'görevi düzenledi';
      case 'task_completed': return 'görevi tamamladı';
      case 'task_uncompleted': return 'görevi geri aldı';
      case 'task_blocked': return 'görevi bloke etti';
      case 'task_unblocked': return 'blokeyi kaldırdı';
      case 'task_postponed': return 'görevi erteledi';
      case 'task_locked': return 'görevi kilitledi';
      case 'task_unlocked': return 'kilidini açtı';
      case 'subtask_completed': return 'alt görevi tamamladı';
      case 'subtask_uncompleted': return 'alt görevi geri aldı';
      case 'subtask_deleted': return 'alt görevi sildi';
      case 'subtask_blocked': return 'alt görevi bloke etti';
      case 'subtask_edited': return 'alt görevi düzenledi';
      case 'subtask_promoted': return 'alt görevi ana görev yaptı';
      case 'group_name_changed': return 'liste adını değiştirdi';
      case 'group_color_changed': return 'liste rengini değiştirdi';
      case 'group_description_changed': return 'açıklamayı güncelledi';
      case 'settings_changed': return 'ayarları güncelledi';
      case 'invite_created': return 'davet oluşturdu';
      case 'invite_deleted': return 'daveti sildi';
      default: return action;
    }
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

  void _logActivity(String action, {String? details}) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    ref.read(groupServiceProvider).logActivity(
      groupId: widget.group.id,
      userId: user.id,
      action: action,
      details: details,
    );
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName == _currentName) {
      setState(() => _isEditingName = false);
      return;
    }

    setState(() {
      _isEditingName = false;
      _currentName = newName;
    });

    try {
      await ref.read(groupServiceProvider).updateGroupName(
        groupId: widget.group.id,
        name: newName,
      );
      _logActivity('group_name_changed', details: '"$newName"');
      widget.onGroupUpdated(widget.group.copyWith(name: newName));
    } catch (e) {
      if (mounted) {
        setState(() => _currentName = widget.group.name);
        _nameController.text = widget.group.name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İsim değiştirilemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveDescription() async {
    final newDesc = _descriptionController.text.trim();
    setState(() {
      _isEditingDescription = false;
      _currentDescription = newDesc;
    });

    try {
      await ref.read(groupServiceProvider).updateGroupDescription(
        groupId: widget.group.id,
        description: newDesc.isEmpty ? null : newDesc,
      );
      _logActivity('group_description_changed');
      widget.onGroupUpdated(widget.group.copyWith(description: newDesc));
    } catch (e) {
      if (mounted) {
        setState(() => _currentDescription = widget.group.description ?? '');
        _descriptionController.text = _currentDescription;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Açıklama kaydedilemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onColorSelected(String hex) async {
    setState(() => _currentColor = hex);
    try {
      await ref.read(groupServiceProvider).updateGroupColor(
        groupId: widget.group.id,
        color: hex,
      );
      _logActivity('group_color_changed');
      widget.onGroupUpdated(widget.group.copyWith(color: hex));
    } catch (e) {
      if (mounted) {
        setState(() => _currentColor = widget.group.color);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Renk değiştirilemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateTaskEditPermission(String permission) async {
    final newSettings = {...widget.group.settings, 'task_edit_permission': permission};
    try {
      await ref.read(groupServiceProvider).updateGroupSettings(
        groupId: widget.group.id,
        settings: newSettings,
      );
      _logActivity('settings_changed', details: 'Görev düzenleme: $permission');
      widget.onGroupUpdated(widget.group.copyWith(settings: newSettings));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ayar güncellenemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateShowPastIncomplete(bool value) async {
    final newSettings = {...widget.group.settings, 'show_past_incomplete': value};
    try {
      await ref.read(groupServiceProvider).updateGroupSettings(
        groupId: widget.group.id,
        settings: newSettings,
      );
      _logActivity('settings_changed', details: 'Yapılmamış görevleri taşı: ${value ? 'açık' : 'kapalı'}');
      widget.onGroupUpdated(widget.group.copyWith(settings: newSettings));
      ref.invalidate(userGroupsProvider);
      ref.invalidate(tasksStreamProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ayar güncellenemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateLogVisibility(String visibility) async {
    final newSettings = {...widget.group.settings, 'activity_log_visibility': visibility};
    try {
      await ref.read(groupServiceProvider).updateGroupSettings(
        groupId: widget.group.id,
        settings: newSettings,
      );
      _logActivity('settings_changed', details: 'Geçmiş logu: $visibility');
      widget.onGroupUpdated(widget.group.copyWith(settings: newSettings));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ayar güncellenemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCreateInviteDialog() {
    String? selectedDuration = '7d';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yeni Davet Oluştur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Geçerlilik süresi:'),
              const SizedBox(height: 12),
              ...['1d', '7d', '30d', 'unlimited'].map((option) {
                final label = switch (option) {
                  '1d' => '1 Gün',
                  '7d' => '7 Gün',
                  '30d' => '30 Gün',
                  'unlimited' => 'Süresiz',
                  _ => option,
                };
                return RadioListTile<String>(
                  title: Text(label),
                  value: option,
                  groupValue: selectedDuration,
                  dense: true,
                  onChanged: (v) => setDialogState(() => selectedDuration = v),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _createInvite(selectedDuration);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _parseColor(_currentColor)),
              child: const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createInvite(String? duration) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    Duration? expiresIn;
    if (duration == '1d') expiresIn = const Duration(days: 1);
    if (duration == '7d') expiresIn = const Duration(days: 7);
    if (duration == '30d') expiresIn = const Duration(days: 30);

    try {
      await ref.read(groupServiceProvider).createInvite(
        groupId: widget.group.id,
        createdBy: user.id,
        expiresIn: expiresIn,
      );
      _loadInvites();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Davet bağlantısı oluşturuldu')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteInvite(String inviteId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await ref.read(groupServiceProvider).deleteInvite(
        inviteId,
        groupId: widget.group.id,
        userId: user.id,
      );
      _loadInvites();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmRemoveMember(String userId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Üyeyi Çıkar'),
        content: Text('"$name" listenizden çıkarılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(groupServiceProvider).removeMember(
        groupId: widget.group.id,
        userId: userId,
        removedByUserId: currentUser.id,
      );
      await _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Üye listeden çıkarıldı')),
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

  Future<void> _confirmDeleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Listeyi Sil'),
        content: Text('"${widget.group.name}" listesi ve tüm görevleri kalıcı olarak silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      // If currently viewing this group's tasks, switch to personal group
      final owner = ref.read(ownerContextProvider);
      if (owner?.ownerId == widget.group.id) {
        final groups = await ref.read(userGroupsProvider.future);
        final personalGroup = groups.where((g) => g.isPersonal).firstOrNull;
        if (personalGroup != null) {
          final newOwner = OwnerContext(ownerId: personalGroup.id, ownerType: 'group');
          ref.read(ownerContextProvider.notifier).state = newOwner;
          ViewStatePersistence.saveOwnerContext(newOwner);
          ref.invalidate(tasksStreamProvider);
        }
      }

      await ref.read(groupServiceProvider).deleteGroup(widget.group.id);
      widget.onGroupDeleted();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Liste silindi')),
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

  Future<void> _confirmLeaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Listeden Ayrıl'),
        content: Text('"${widget.group.name}" listenizden ayrılmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Ayrıl', style: TextStyle(color: Colors.orange[700])),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      // If currently viewing this group's tasks, switch to personal group
      final owner = ref.read(ownerContextProvider);
      if (owner?.ownerId == widget.group.id) {
        final groups = await ref.read(userGroupsProvider.future);
        final personalGroup = groups.where((g) => g.isPersonal).firstOrNull;
        if (personalGroup != null) {
          final newOwner = OwnerContext(ownerId: personalGroup.id, ownerType: 'group');
          ref.read(ownerContextProvider.notifier).state = newOwner;
          ViewStatePersistence.saveOwnerContext(newOwner);
          ref.invalidate(tasksStreamProvider);
        }
      }

      await ref.read(groupServiceProvider).leaveGroup(
        groupId: widget.group.id,
        userId: user.id,
      );
      widget.onGroupDeleted();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listeden ayrıldınız')),
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

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
