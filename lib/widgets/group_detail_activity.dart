// Group detail: activity log (part of group_manager.dart).
part of 'group_manager.dart';

extension _GroupDetailActivity on _GroupDetailViewState {
  Widget _buildActivityLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (!_showActivityLog) {
              _loadActivityLog();
            }
            _refresh(() => _showActivityLog = !_showActivityLog);
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
}
