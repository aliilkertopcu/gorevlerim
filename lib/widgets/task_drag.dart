import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../theme/animation_constants.dart';

/// Drag payload for a whole task card.
class TaskDragData {
  final Task task;
  final int sourceIndex;
  const TaskDragData({required this.task, required this.sourceIndex});
}

/// Drag payload for a subtask row (carries source position for reorder).
class SubtaskDragData {
  final Subtask subtask;
  final int sourceIndex;
  const SubtaskDragData({required this.subtask, required this.sourceIndex});
}

/// Where a pointer is hovering relative to a drop target.
enum DropZone { before, into, after }

/// Touch platforms need a short hold so drags don't fight with scrolling.
/// Desktop (mouse) gets standard immediate drag.
bool get isTouchPlatform =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.fuchsia;

const Duration touchDragDelay = Duration(milliseconds: 180);

/// Platform-adaptive draggable: immediate on desktop, short long-press on touch.
Widget adaptiveDraggable<T extends Object>({
  required T data,
  required Widget feedback,
  required Widget child,
  Widget? childWhenDragging,
  VoidCallback? onDragStarted,
  void Function(DragUpdateDetails)? onDragUpdate,
  void Function(DraggableDetails)? onDragEnd,
}) {
  void started() {
    HapticFeedback.mediumImpact();
    onDragStarted?.call();
  }

  if (isTouchPlatform) {
    return LongPressDraggable<T>(
      data: data,
      delay: touchDragDelay,
      hapticFeedbackOnStart: false,
      feedback: feedback,
      childWhenDragging: childWhenDragging,
      onDragStarted: started,
      onDragUpdate: onDragUpdate,
      onDragEnd: onDragEnd,
      child: child,
    );
  }
  return Draggable<T>(
    data: data,
    feedback: feedback,
    childWhenDragging: childWhenDragging,
    onDragStarted: started,
    onDragUpdate: onDragUpdate,
    onDragEnd: onDragEnd,
    child: child,
  );
}

/// Compute the drop zone from the pointer's vertical position inside [box].
/// Edge bands (top/bottom quarter) mean "before"/"after"; the middle means
/// "into" when [allowInto] is set, otherwise the nearest edge.
DropZone dropZoneFor(RenderBox box, Offset globalOffset, {required bool allowInto}) {
  final local = box.globalToLocal(globalOffset);
  final f = (local.dy / box.size.height).clamp(0.0, 1.0);
  if (allowInto) {
    if (f < 0.25) return DropZone.before;
    if (f > 0.75) return DropZone.after;
    return DropZone.into;
  }
  return f < 0.5 ? DropZone.before : DropZone.after;
}

/// Scrolls a ScrollController while a drag hovers near the viewport edges.
class DragAutoScroller {
  final ScrollController? Function() controller;
  Timer? _timer;

  DragAutoScroller(this.controller);

  void update(BuildContext context, Offset globalPosition) {
    _timer?.cancel();
    final y = globalPosition.dy;
    final screenHeight = MediaQuery.of(context).size.height;
    const zone = 80.0;
    const maxSpeed = 12.0;

    double? speed;
    if (y < zone) {
      speed = -(1.0 - y / zone) * maxSpeed;
    } else if (y > screenHeight - zone) {
      speed = ((y - (screenHeight - zone)) / zone) * maxSpeed;
    }
    if (speed == null) return;

    final c = controller();
    if (c == null || !c.hasClients) return;
    final s = speed;
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final ctrl = controller();
      if (ctrl == null || !ctrl.hasClients) {
        stop();
        return;
      }
      final pos = ctrl.position;
      pos.jumpTo((pos.pixels + s).clamp(pos.minScrollExtent, pos.maxScrollExtent));
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();
}

/// Thin accent line shown between items while dragging.
class DropIndicatorLine extends StatelessWidget {
  final Color color;
  const DropIndicatorLine({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }
}

/// Drop target around a task card. Accepts other tasks (reorder / nest as
/// subtask) and subtasks (move into / promote before-after).
class TaskDropTarget extends StatefulWidget {
  final Task task;
  final Color accentColor;
  final Widget child;
  final void Function(TaskDragData data, DropZone zone) onTaskDrop;
  final void Function(SubtaskDragData data, DropZone zone) onSubtaskDrop;

  const TaskDropTarget({
    super.key,
    required this.task,
    required this.accentColor,
    required this.child,
    required this.onTaskDrop,
    required this.onSubtaskDrop,
  });

  @override
  State<TaskDropTarget> createState() => _TaskDropTargetState();
}

class _TaskDropTargetState extends State<TaskDropTarget> {
  final _boxKey = GlobalKey();
  DropZone? _zone;

  bool _accepts(Object? data) {
    if (data is TaskDragData) return data.task.id != widget.task.id;
    if (data is SubtaskDragData) return true;
    return false;
  }

  void _updateZone(Offset offset, Object data) {
    final rb = _boxKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    // A subtask hovering its own parent can only be promoted (before/after).
    final allowInto = !(data is SubtaskDragData && data.subtask.taskId == widget.task.id);
    final z = dropZoneFor(rb, offset, allowInto: allowInto);
    if (z != _zone) setState(() => _zone = z);
  }

  void _clear() {
    if (_zone != null) setState(() => _zone = null);
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (d) => _accepts(d.data),
      onMove: (d) {
        if (_accepts(d.data)) _updateZone(d.offset, d.data);
      },
      onLeave: (_) => _clear(),
      onAcceptWithDetails: (d) {
        final zone = _zone ?? DropZone.after;
        _clear();
        final data = d.data;
        if (data is TaskDragData) widget.onTaskDrop(data, zone);
        if (data is SubtaskDragData) widget.onSubtaskDrop(data, zone);
      },
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty && _zone != null;
        final into = hovering && _zone == DropZone.into;
        final isTask = candidates.firstOrNull is TaskDragData;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hovering && _zone == DropZone.before) DropIndicatorLine(color: widget.accentColor),
            Stack(
              key: _boxKey,
              children: [
                AnimatedContainer(
                  duration: Anim.fast,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: into ? Border.all(color: widget.accentColor, width: 2) : null,
                    color: into ? widget.accentColor.withValues(alpha: 0.06) : null,
                  ),
                  child: widget.child,
                ),
                if (into)
                  Positioned(
                    right: 12,
                    top: 8,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.accentColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isTask ? 'Alt görev yap' : 'Buraya taşı',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (hovering && _zone == DropZone.after) DropIndicatorLine(color: widget.accentColor),
          ],
        );
      },
    );
  }
}
