import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import 'desktop_dialog.dart';

final _historyServiceProvider = Provider<HistoryService>((ref) {
  return HistoryService(ref.watch(supabaseProvider));
});

/// Shows task history dialog. If [subtaskId] is provided, shows only that subtask's history.
void showTaskHistoryDialog(
  BuildContext context,
  WidgetRef ref, {
  required String taskId,
  String? subtaskId,
  required String title,
}) {
  showAppDialog(
    context: context,
    title: Text(subtaskId != null ? 'Alt Görev Geçmişi' : 'Görev Geçmişi'),
    content: _TaskHistoryContent(
      ref: ref,
      taskId: taskId,
      subtaskId: subtaskId,
      title: title,
    ),
    actions: [],
  );
}

class _TaskHistoryContent extends StatefulWidget {
  final WidgetRef ref;
  final String taskId;
  final String? subtaskId;
  final String title;

  const _TaskHistoryContent({
    required this.ref,
    required this.taskId,
    this.subtaskId,
    required this.title,
  });

  @override
  State<_TaskHistoryContent> createState() => _TaskHistoryContentState();
}

class _TaskHistoryContentState extends State<_TaskHistoryContent> {
  List<HistoryEntry>? _entries;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final service = widget.ref.read(_historyServiceProvider);
      final entries = widget.subtaskId != null
          ? await service.getSubtaskHistory(widget.taskId, widget.subtaskId!)
          : await service.getTaskHistory(widget.taskId);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ownerColor = widget.ref.read(currentOwnerColorProvider);

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Hata: $_error', style: const TextStyle(color: Colors.red)),
      );
    }

    final entries = _entries!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Task/subtask title
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: ownerColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ownerColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Henüz geçmiş kaydı yok',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _HistoryTile(
                  entry: entry,
                  isDark: isDark,
                  accentColor: ownerColor,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  final bool isDark;
  final Color accentColor;

  const _HistoryTile({
    required this.entry,
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final actionInfo = _actionInfo(entry.action);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: actionInfo.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // User avatar
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: accentColor.withValues(alpha: 0.2),
                        child: Text(
                          entry.userName.isNotEmpty ? entry.userName[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: accentColor),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // User name
                      Expanded(
                        child: Text(
                          entry.userName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Timestamp
                      Text(
                        _formatTime(entry.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Action
                  Row(
                    children: [
                      Icon(actionInfo.icon, size: 14, color: actionInfo.color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          actionInfo.label,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  // Details
                  if (entry.details != null && entry.details!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: Text(
                        entry.details!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
    if (diff.inHours < 24) return '${diff.inHours}sa önce';
    if (diff.inDays < 7) return '${diff.inDays}g önce';

    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  ({IconData icon, String label, Color color}) _actionInfo(String action) {
    return switch (action) {
      'task_created'           => (icon: Icons.add_circle,         label: 'Görev oluşturuldu',           color: Colors.green),
      'task_completed'         => (icon: Icons.check_circle,       label: 'Görev tamamlandı',            color: AppTheme.completedColor),
      'task_uncompleted'       => (icon: Icons.radio_button_unchecked, label: 'Görev tamamlanmadı olarak işaretlendi', color: Colors.orange),
      'task_edited'            => (icon: Icons.edit,               label: 'Görev düzenlendi',            color: Colors.blue),
      'task_blocked'           => (icon: Icons.block,              label: 'Görev bloke edildi',          color: AppTheme.blockedColor),
      'task_unblocked'         => (icon: Icons.check,              label: 'Bloke kaldırıldı',           color: Colors.teal),
      'task_deleted'           => (icon: Icons.delete,             label: 'Görev silindi',               color: Colors.red),
      'task_moved'             => (icon: Icons.move_down,          label: 'Görev taşındı',              color: Colors.purple),
      'task_postponed'         => (icon: Icons.schedule,           label: 'Görev ertelendi',            color: Colors.deepOrange),
      'task_locked'            => (icon: Icons.lock,               label: 'Görev kilitlendi',           color: Colors.orange),
      'task_unlocked'          => (icon: Icons.lock_open,          label: 'Kilit açıldı',               color: Colors.teal),
      'subtask_created'        => (icon: Icons.add,                label: 'Alt görev oluşturuldu',       color: Colors.green),
      'subtask_completed'      => (icon: Icons.check_circle,       label: 'Alt görev tamamlandı',        color: AppTheme.completedColor),
      'subtask_uncompleted'    => (icon: Icons.radio_button_unchecked, label: 'Alt görev tamamlanmadı olarak işaretlendi', color: Colors.orange),
      'subtask_edited'         => (icon: Icons.edit,               label: 'Alt görev düzenlendi',        color: Colors.blue),
      'subtask_blocked'        => (icon: Icons.block,              label: 'Alt görev bloke edildi',      color: AppTheme.blockedColor),
      'subtask_unblocked'      => (icon: Icons.check,              label: 'Bloke kaldırıldı',           color: Colors.teal),
      'subtask_deleted'        => (icon: Icons.delete,             label: 'Alt görev silindi',           color: Colors.red),
      'subtask_promoted'       => (icon: Icons.arrow_upward,       label: 'Ana göreve dönüştürüldü',    color: Colors.indigo),
      'subtask_moved'          => (icon: Icons.swap_horiz,         label: 'Başka göreve taşındı',        color: Colors.purple),
      _                        => (icon: Icons.info,               label: action,                         color: Colors.grey),
    };
  }
}
