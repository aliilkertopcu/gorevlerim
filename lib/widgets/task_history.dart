import 'package:flutter/material.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import 'desktop_dialog.dart';

/// Action type metadata: Turkish label, icon, and color.
class _ActionMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _ActionMeta(this.label, this.icon, this.color);
}

_ActionMeta _metaFor(String action) {
  switch (action) {
    case 'task_created':
      return _ActionMeta('Oluşturuldu', Icons.add_circle_outline, Colors.blue);
    case 'task_completed':
      return _ActionMeta('Tamamlandı', Icons.check_circle_outline, AppTheme.completedColor);
    case 'task_uncompleted':
      return _ActionMeta('Tamamlanmadı olarak işaretlendi', Icons.undo, Colors.orange);
    case 'task_blocked':
      return _ActionMeta('Bloke edildi', Icons.block, AppTheme.blockedColor);
    case 'task_unblocked':
      return _ActionMeta('Bloke kaldırıldı', Icons.lock_open, Colors.teal);
    case 'task_deleted':
      return _ActionMeta('Silindi', Icons.delete_outline, Colors.red);
    case 'task_edited':
      return _ActionMeta('Düzenlendi', Icons.edit, Colors.deepPurple);
    case 'task_moved':
      return _ActionMeta('Taşındı', Icons.drive_file_move_outline, Colors.indigo);
    case 'task_postponed':
      return _ActionMeta('Ertelendi', Icons.schedule, Colors.amber.shade700);
    case 'task_locked':
      return _ActionMeta('Kilitlendi', Icons.lock, Colors.brown);
    case 'task_unlocked':
      return _ActionMeta('Kilit açıldı', Icons.lock_open, Colors.brown);
    case 'subtask_created':
      return _ActionMeta('Alt görev oluşturuldu', Icons.add, Colors.blue);
    case 'subtask_completed':
      return _ActionMeta('Alt görev tamamlandı', Icons.check, AppTheme.completedColor);
    case 'subtask_uncompleted':
      return _ActionMeta('Alt görev tamamlanmadı', Icons.undo, Colors.orange);
    case 'subtask_blocked':
      return _ActionMeta('Alt görev bloke edildi', Icons.block, AppTheme.blockedColor);
    case 'subtask_unblocked':
      return _ActionMeta('Alt görev bloke kaldırıldı', Icons.lock_open, Colors.teal);
    case 'subtask_edited':
      return _ActionMeta('Alt görev düzenlendi', Icons.edit, Colors.deepPurple);
    case 'subtask_moved':
      return _ActionMeta('Alt görev taşındı', Icons.drive_file_move_outline, Colors.indigo);
    case 'subtask_deleted':
      return _ActionMeta('Alt görev silindi', Icons.delete_outline, Colors.red);
    default:
      return _ActionMeta(action, Icons.info_outline, Colors.grey);
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().toUtc().difference(dt.toUtc());
  if (diff.inSeconds < 60) return 'az önce';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '${diff.inHours} saat önce';
  if (diff.inDays < 7) return '${diff.inDays} gün önce';
  final d = dt.toLocal();
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

/// Shows a task history dialog. If [subtaskId] and [subtaskTitle] are provided,
/// shows only that subtask's history.
void showTaskHistoryDialog(
  BuildContext context, {
  required String taskId,
  required String taskTitle,
  String? subtaskId,
  String? subtaskTitle,
}) {
  showAppDialog(
    context: context,
    title: Text(subtaskTitle != null ? 'Alt Görev Geçmişi' : 'Görev Geçmişi'),
    content: _HistoryContent(
      taskId: taskId,
      taskTitle: taskTitle,
      subtaskId: subtaskId,
      subtaskTitle: subtaskTitle,
    ),
  );
}

class _HistoryContent extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final String? subtaskId;
  final String? subtaskTitle;

  const _HistoryContent({
    required this.taskId,
    required this.taskTitle,
    this.subtaskId,
    this.subtaskTitle,
  });

  @override
  State<_HistoryContent> createState() => _HistoryContentState();
}

class _HistoryContentState extends State<_HistoryContent> {
  final _service = HistoryService();
  late Future<List<HistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<HistoryEntry>> _load() {
    if (widget.subtaskId != null) {
      return _service.getSubtaskHistory(widget.taskId, widget.subtaskId!);
    }
    return _service.getTaskHistory(widget.taskId);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      height: 400,
      child: FutureBuilder<List<HistoryEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return const Center(
              child: Text('Henüz geçmiş kaydı yok.', style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.builder(
            itemCount: entries.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final meta = _metaFor(entry.action);
              final isLast = index == entries.length - 1;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline line + icon
                    SizedBox(
                      width: 40,
                      child: Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: meta.color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(meta.icon, size: 14, color: meta.color),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: Colors.grey.withValues(alpha: 0.2),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  meta.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: meta.color,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _timeAgo(entry.createdAt),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                            if (entry.userName.isNotEmpty)
                              Text(
                                entry.userName,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            if (entry.details != null && entry.details!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  entry.details!,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
