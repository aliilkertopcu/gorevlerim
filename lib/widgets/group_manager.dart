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
  List<Map<String, dynamic>>? _activityLog;
  bool _isLoadingMembers = true;
  bool _isLoadingLog = false;
  bool _isLoading = false;
  late String _currentColor;
  late String _currentName;
  late String _currentDescription;
  bool _isEditingName = false;
  bool _isEditingDescription = false;
  bool _showActivityLog = false;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.group.color;
    _currentName = widget.group.name;
    _currentDescription = widget.group.description ?? '';
    _nameController = TextEditingController(text: _currentName);
    _descriptionController = TextEditingController(text: _currentDescription);
    _loadMembers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
    setState(() => _isLoadingLog = true);
    try {
      final logs = await ref.read(groupServiceProvider).getActivityLog(widget.group.id);
      if (mounted) {
        setState(() {
          _activityLog = logs;
          _isLoadingLog = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLog = false);
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
                    // Invite code
                    _buildInviteCode(),
                    const SizedBox(height: 16),
                    // Description
                    _buildDescription(),
                    const SizedBox(height: 16),
                    // Color picker (creator only)
                    if (_isCreator) ...[
                      _buildColorPicker(groupColor),
                      const SizedBox(height: 16),
                    ],
                    // Members
                    _buildMembersList(),
                    const SizedBox(height: 16),
                    // Settings section (creator only)
                    if (_isCreator) ...[
                      _buildSettingsSection(),
                      const SizedBox(height: 16),
                    ],
                    // Activity log
                    if (_canViewActivityLog) ...[
                      _buildActivityLog(),
                      const SizedBox(height: 16),
                    ],
                    // Leave / Delete
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
              hintText: 'Grup açıklaması ekleyin...',
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
          'Grup Rengi',
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
          else if (_activityLog == null || _activityLog!.isEmpty)
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
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Theme.of(context).hintColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: _activityLog!.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = _activityLog![index];
                  final profiles = log['profiles'] as Map<String, dynamic>?;
                  final name = profiles?['display_name'] as String? ?? '?';
                  final action = log['action'] as String? ?? '';
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

  Widget _buildActionButtons() {
    if (_isCreator) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isLoading ? null : _confirmDeleteGroup,
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          label: Text(
            'Grubu Sil',
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
            'Gruptan Ayrıl',
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

  Future<void> _updateLogVisibility(String visibility) async {
    final newSettings = {...widget.group.settings, 'activity_log_visibility': visibility};
    try {
      await ref.read(groupServiceProvider).updateGroupSettings(
        groupId: widget.group.id,
        settings: newSettings,
      );
      widget.onGroupUpdated(widget.group.copyWith(settings: newSettings));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ayar güncellenemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmRemoveMember(String userId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Üyeyi Çıkar'),
        content: Text('"$name" grubunuzdan çıkarılsın mı?'),
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

    setState(() => _isLoading = true);
    try {
      await ref.read(groupServiceProvider).removeMember(
        groupId: widget.group.id,
        userId: userId,
      );
      await _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Üye gruptan çıkarıldı')),
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
        title: const Text('Grubu Sil'),
        content: Text('"${widget.group.name}" grubu ve tüm görevleri kalıcı olarak silinecek. Emin misiniz?'),
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
      // If currently viewing this group's tasks, switch back to personal
      final owner = ref.read(ownerContextProvider);
      if (owner?.ownerId == widget.group.id) {
        final user = ref.read(currentUserProvider);
        if (user != null) {
          ref.read(ownerContextProvider.notifier).state = OwnerContext(
            ownerId: user.id,
            ownerType: 'user',
          );
          ref.invalidate(tasksStreamProvider);
        }
      }

      await ref.read(groupServiceProvider).deleteGroup(widget.group.id);
      widget.onGroupDeleted();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grup silindi')),
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
        title: const Text('Gruptan Ayrıl'),
        content: Text('"${widget.group.name}" grubundan ayrılmak istediğinize emin misiniz?'),
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

      // If currently viewing this group's tasks, switch back to personal
      final owner = ref.read(ownerContextProvider);
      if (owner?.ownerId == widget.group.id) {
        ref.read(ownerContextProvider.notifier).state = OwnerContext(
          ownerId: user.id,
          ownerType: 'user',
        );
        ref.invalidate(tasksStreamProvider);
      }

      await ref.read(groupServiceProvider).leaveGroup(
        groupId: widget.group.id,
        userId: user.id,
      );
      widget.onGroupDeleted();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gruptan ayrıldınız')),
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
