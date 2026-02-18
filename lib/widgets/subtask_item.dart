import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import 'custom_drag_listener.dart';

class SubtaskItem extends StatefulWidget {
  final Subtask subtask;
  final Task parentTask;
  final int subtaskIndex;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onBlock;
  final VoidCallback? onUnblock;
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
    this.onUnblock,
    required this.onEdit,
    required this.onPromote,
    this.editable = true,
  });

  @override
  State<SubtaskItem> createState() => _SubtaskItemState();
}

class _SubtaskItemState extends State<SubtaskItem> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  // Matches [label](url) first, then bare https?:// URLs.
  static final _linkRegex = RegExp(r'\[([^\]]+)\]\((https?://[^)]+)\)|(https?://\S+)');

  List<InlineSpan> _buildSpans(String text, TextStyle baseStyle) {
    for (final r in _recognizers) { r.dispose(); }
    _recognizers.clear();
    final matches = _linkRegex.allMatches(text).toList();
    if (matches.isEmpty) return [TextSpan(text: text)];

    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      // group(1) = label, group(2) = url from [label](url)
      // group(3) = bare url
      final label = match.group(1) ?? match.group(3)!;
      final url   = match.group(2) ?? match.group(3)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: label,
        style: baseStyle.copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
          decorationColor: Colors.blue,
        ),
        recognizer: recognizer,
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    return spans;
  }

  Subtask get subtask => widget.subtask;
  Task get parentTask => widget.parentTask;
  int get subtaskIndex => widget.subtaskIndex;
  bool get editable => widget.editable;
  VoidCallback get onToggle => widget.onToggle;
  VoidCallback get onDelete => widget.onDelete;
  VoidCallback get onBlock => widget.onBlock;
  VoidCallback? get onUnblock => widget.onUnblock;
  VoidCallback get onEdit => widget.onEdit;
  VoidCallback get onPromote => widget.onPromote;

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.statusColor(subtask.status);

    final blockedColor = AppTheme.blockedColor;

    final inner = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: subtask.isBlocked
                ? blockedColor.withValues(alpha: 0.08)
                : null,
            borderRadius: BorderRadius.circular(4),
            border: subtask.isBlocked
                ? Border.all(color: blockedColor.withValues(alpha: 0.25))
                : null,
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
                      color: subtask.isCompleted
                          ? AppTheme.completedColor
                          : subtask.isBlocked
                              ? blockedColor
                              : Colors.grey,
                      width: 2,
                    ),
                    color: subtask.isCompleted
                        ? AppTheme.completedColor
                        : subtask.isBlocked
                            ? blockedColor.withValues(alpha: 0.15)
                            : Colors.transparent,
                  ),
                  child: subtask.isCompleted
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : subtask.isBlocked
                          ? Icon(Icons.block, size: 10, color: blockedColor)
                          : null,
                ),
              ),
              const SizedBox(width: 8),
              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(builder: (context) {
                      final baseStyle = TextStyle(
                        fontSize: 13,
                        decoration: subtask.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: subtask.isCompleted
                            ? Colors.grey
                            : subtask.isBlocked
                                ? AppTheme.blockedColor
                                : null,
                      );
                      return Text.rich(
                        TextSpan(children: _buildSpans(subtask.title, baseStyle)),
                        style: baseStyle,
                      );
                    }),
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
                    PopupMenuItem(
                      value: subtask.isBlocked ? 'unblock' : 'block',
                      child: Text(subtask.isBlocked ? 'Blokeyi Kaldır' : 'Bloke Et'),
                    ),
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
                      case 'unblock':
                        onUnblock?.call();
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
