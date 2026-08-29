// Visual chrome for the task card: press/hover shell and drag feedback (part of task_card.dart).
part of 'task_card.dart';

/// Hover-effect card wrapper. Shows subtle tint on desktop mouse hover.
/// Compact floating preview shown while dragging a task card.
class _TaskDragFeedback extends StatelessWidget {
  final Task task;
  final Color accentColor;
  const _TaskDragFeedback({required this.task, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: accentColor, width: 4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                task.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (task.subtasks.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text('${task.subtasks.length} alt', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ],
        ),
      ),
    );
  }
}

class _PressableCard extends StatefulWidget {
  final Widget child;
  final Color bgColor;
  final Color statusColor;

  const _PressableCard({
    required this.child,
    required this.bgColor,
    required this.statusColor,
  });

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _isHovered
        ? Color.lerp(widget.bgColor, Colors.grey, 0.06)!
        : widget.bgColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? Anim.pressedScale : 1.0,
        duration: Anim.fast,
        curve: Anim.defaultCurve,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() { _isHovered = false; _isPressed = false; }),
          child: AnimatedContainer(
            duration: Anim.fast,
            curve: Anim.defaultCurve,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(color: widget.statusColor, width: 4),
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
