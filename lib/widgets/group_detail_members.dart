// Group detail: invite code, description, color picker, members (part of group_manager.dart).
part of 'group_manager.dart';

extension _GroupDetailMembers on _GroupDetailViewState {
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
                  _refresh(() => _isEditingDescription = false);
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
                onTap: () => _refresh(() => _isEditingDescription = true),
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
            onTap: () => _refresh(() => _isEditingDescription = true),
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
}
