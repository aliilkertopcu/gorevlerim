// Group detail: settings and invite links (part of group_manager.dart).
part of 'group_manager.dart';

extension _GroupDetailSettings on _GroupDetailViewState {
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
            _refresh(() => _showInvites = !_showInvites);
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
}
