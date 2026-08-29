// Group detail: mutations and confirm dialogs (part of group_manager.dart).
part of 'group_manager.dart';

extension _GroupDetailActions on _GroupDetailViewState {
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
      _refresh(() => _isEditingName = false);
      return;
    }

    _refresh(() {
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
        _refresh(() => _currentName = widget.group.name);
        _nameController.text = widget.group.name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İsim değiştirilemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveDescription() async {
    final newDesc = _descriptionController.text.trim();
    _refresh(() {
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
        _refresh(() => _currentDescription = widget.group.description ?? '');
        _descriptionController.text = _currentDescription;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Açıklama kaydedilemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onColorSelected(String hex) async {
    _refresh(() => _currentColor = hex);
    try {
      await ref.read(groupServiceProvider).updateGroupColor(
        groupId: widget.group.id,
        color: hex,
      );
      _logActivity('group_color_changed');
      widget.onGroupUpdated(widget.group.copyWith(color: hex));
    } catch (e) {
      if (mounted) {
        _refresh(() => _currentColor = widget.group.color);
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
              RadioGroup<String>(
                groupValue: selectedDuration,
                onChanged: (v) => setDialogState(() => selectedDuration = v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in ['1d', '7d', '30d', 'unlimited'])
                      RadioListTile<String>(
                        title: Text(switch (option) {
                          '1d' => '1 Gün',
                          '7d' => '7 Gün',
                          '30d' => '30 Gün',
                          'unlimited' => 'Süresiz',
                          _ => option,
                        }),
                        value: option,
                        dense: true,
                      ),
                  ],
                ),
              ),
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

    _refresh(() => _isLoading = true);
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
      if (mounted) _refresh(() => _isLoading = false);
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

    _refresh(() => _isLoading = true);
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
      if (mounted) _refresh(() => _isLoading = false);
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

    _refresh(() => _isLoading = true);
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
      if (mounted) _refresh(() => _isLoading = false);
    }
  }
}
