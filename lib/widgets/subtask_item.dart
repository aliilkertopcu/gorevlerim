import 'package:flutter/material.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import 'custom_drag_listener.dart';

class SubtaskItem extends StatelessWidget {
  final Subtask subtask;
  final Task parentTask;
  final int subtaskIndex;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onBlock;
  final VoidCallback onEdit;
  final VoidCallback onPromote;
  final bool editable;

  const SubtaskItem({
    super.key,
    required this.subtask,
    required this.parentTask,
    required this.subtaskIndex,
    required this.onToggle,
    required this.onDelete,
    required this.onBlock,
    required this.onEdit,
    required this.onPromote,
    this.editable = true,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.statusColor(subtask.status);

    final inner = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: subtask.isBlocked
                ? AppTheme.statusBackground('blocked').withValues(alpha: 0.5)
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: editable ? onToggle : null,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: subtask.isCompleted ? AppTheme.completedColor : Colors.grey,
                      width: 2,
                    ),
                    color: subtask.isCompleted ? AppTheme.completedColor : Colors.transparent,
                  ),
                  child: subtask.isCompleted
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtask.title,
                      style: TextStyle(
                        fontSize: 13,
                        decoration: subtask.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: subtask.isCompleted
                            ? Colors.grey
                            : subtask.isBlocked
                                ? AppTheme.blockedColor
                                : null,
                      ),
                    ),
                    if (subtask.isBlocked && subtask.blockReason != null)
                      Text(
                        subtask.blockReason!,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.blockedColor.withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              // Status badge
              if (subtask.isBlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Bloke',
                    style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600),
                  ),
                ),
              // Menu (hidden when not editable)
              if (editable)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                    const PopupMenuItem(value: 'block', child: Text('Bloke Et')),
                    const PopupMenuItem(value: 'promote', child: Text('Ana Göreve Dönüştür')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Sil', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                      case 'block':
                        onBlock();
                      case 'promote':
                        onPromote();
                      case 'delete':
                        onDelete();
                    }
                  },
                ),
            ],
          ),
        );

    if (editable) {
      return CustomDelayDragStartListener(
        index: subtaskIndex,
        child: inner,
      );
    }

    return inner;
  }
}
