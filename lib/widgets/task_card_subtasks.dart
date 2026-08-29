// Subtask list with drag-and-drop and the inline add-subtask row (part of task_card.dart).
part of 'task_card.dart';

/// Subtask list with LongPressDraggable.
/// Hovering over a subtask shows a drop indicator above or below based on
/// which half of the item the pointer is in — no need to aim at a tiny gap.
class _DraggableSubtaskList extends ConsumerStatefulWidget {
  final Task task;
  final Color accentColor;
  final bool editable;
  final void Function(Subtask) onToggle;
  final void Function(Subtask) onDelete;
  final void Function(BuildContext, Subtask) onBlock;
  final void Function(Subtask) onUnblock;
  final void Function(BuildContext, Subtask) onEdit;
  final void Function(Subtask) onPromote;
  final void Function(Subtask) onHistory;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(Subtask subtask, int insertAt) onReceiveDrop;

  const _DraggableSubtaskList({
    required this.task,
    required this.accentColor,
    required this.editable,
    required this.onToggle,
    required this.onDelete,
    required this.onBlock,
    required this.onUnblock,
    required this.onEdit,
    required this.onPromote,
    required this.onHistory,
    required this.onReorder,
    required this.onReceiveDrop,
  });

  @override
  ConsumerState<_DraggableSubtaskList> createState() => _DraggableSubtaskListState();
}

class _DraggableSubtaskListState extends ConsumerState<_DraggableSubtaskList> {
  Timer? _autoScrollTimer;
  String? _hoveredId;      // subtask.id currently hovered
  bool   _hoverIsTop = true; // true → insert above, false → insert below
  final Map<String, GlobalKey> _targetKeys = {};

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _startAutoScroll(DragUpdateDetails details) {
    _autoScrollTimer?.cancel();

    final y = details.globalPosition.dy;
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

    // Use the home screen's ScrollController directly — avoids picking up
    // ReorderableListView's internal NeverScrollableScrollPhysics scrollable.
    final controller = ref.read(homeScrollControllerProvider);
    if (controller == null || !controller.hasClients) return;

    final targetSpeed = speed;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) {
        _autoScrollTimer?.cancel();
        return;
      }
      final pos = controller.position;
      pos.jumpTo(
        (pos.pixels + targetSpeed).clamp(pos.minScrollExtent, pos.maxScrollExtent),
      );
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  Widget _buildDropIndicator() {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: widget.accentColor,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtasks = widget.task.subtasks;

    if (!widget.editable) {
      return Column(
        children: subtasks.asMap().entries.map((e) {
          return SubtaskItem(
            key: ValueKey(e.value.id),
            subtask: e.value,
            parentTask: widget.task,
            subtaskIndex: e.key,
            editable: false,
            onToggle: () {},
            onDelete: () {},
            onBlock: () {},
            onEdit: () {},
            onPromote: () {},
            onHistory: () => widget.onHistory(e.value),
          );
        }).toList(),
      );
    }

    return Column(
      children: List.generate(subtasks.length, (i) {
        final subtask = subtasks[i];
        final targetKey = _targetKeys.putIfAbsent(subtask.id, () => GlobalKey());

        final subtaskWidget = SubtaskItem(
          key: ValueKey(subtask.id),
          subtask: subtask,
          parentTask: widget.task,
          subtaskIndex: i,
          onToggle: () => widget.onToggle(subtask),
          onDelete: () => widget.onDelete(subtask),
          onBlock: () => widget.onBlock(context, subtask),
          onUnblock: () => widget.onUnblock(subtask),
          onEdit: () => widget.onEdit(context, subtask),
          onPromote: () => widget.onPromote(subtask),
          onHistory: () => widget.onHistory(subtask),
        );

        final draggable = adaptiveDraggable<SubtaskDragData>(
          data: SubtaskDragData(subtask: subtask, sourceIndex: i),
          feedback: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(6),
            color: Theme.of(context).colorScheme.surface,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                subtask.title,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: SubtaskItem(
              subtask: subtask,
              parentTask: widget.task,
              subtaskIndex: i,
              onToggle: () {},
              onDelete: () {},
              onBlock: () {},
              onEdit: () {},
              onPromote: () {},
              onHistory: () {},
            ),
          ),
          onDragUpdate: _startAutoScroll,
          onDragEnd: (_) => _stopAutoScroll(),
          child: subtaskWidget,
        );

        return DragTarget<SubtaskDragData>(
          key: targetKey,
          onWillAcceptWithDetails: (_) => true,
          onMove: (details) {
            // Measure this item's render box to decide top/bottom half
            final rb = targetKey.currentContext?.findRenderObject() as RenderBox?;
            if (rb == null) return;
            final local = rb.globalToLocal(details.offset);
            final isTop = local.dy < rb.size.height / 2;
            if (_hoveredId != subtask.id || _hoverIsTop != isTop) {
              setState(() {
                _hoveredId = subtask.id;
                _hoverIsTop = isTop;
              });
            }
          },
          onLeave: (_) {
            if (_hoveredId == subtask.id) setState(() => _hoveredId = null);
          },
          onAcceptWithDetails: (details) {
            _stopAutoScroll();
            final savedIsTop = _hoverIsTop;
            setState(() => _hoveredId = null);
            final data = details.data;
            // insertAt: above item = index i, below item = index i+1
            final insertAt = savedIsTop ? i : i + 1;
            if (data.subtask.taskId == widget.task.id) {
              var newIdx = insertAt;
              if (newIdx > data.sourceIndex) newIdx--;
              if (newIdx != data.sourceIndex) {
                widget.onReorder(data.sourceIndex, newIdx);
              }
            } else {
              widget.onReceiveDrop(data.subtask, insertAt);
            }
          },
          builder: (ctx, candidateData, _) {
            final dragData = candidateData.firstOrNull;
            bool showIndicator = _hoveredId == subtask.id && dragData != null;

            // Suppress indicator when the drop would result in no positional change
            // (hovering the bottom half of the item above, or the top half of item below)
            if (showIndicator && dragData.subtask.taskId == widget.task.id) {
              final insertAt = _hoverIsTop ? i : i + 1;
              var newIdx = insertAt;
              if (newIdx > dragData.sourceIndex) newIdx--;
              if (newIdx == dragData.sourceIndex) showIndicator = false;
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showIndicator && _hoverIsTop) _buildDropIndicator(),
                draggable,
                if (showIndicator && !_hoverIsTop) _buildDropIndicator(),
              ],
            );
          },
        );
      }),
    );
  }
}

/// Inline "add subtask" row — shows a button, expands to a text field on tap.
class _AddSubtaskRow extends ConsumerStatefulWidget {
  final String taskId;
  final Color accentColor;

  const _AddSubtaskRow({required this.taskId, required this.accentColor});

  @override
  ConsumerState<_AddSubtaskRow> createState() => _AddSubtaskRowState();
}

class _AddSubtaskRowState extends ConsumerState<_AddSubtaskRow> {
  bool _isAdding = false;
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _ctrl.text.trim();
    _ctrl.clear();
    setState(() => _isAdding = false);
    if (title.isEmpty) return;
    await ref.read(taskServiceProvider).createSubtask(taskId: widget.taskId, title: title);
    ref.invalidate(tasksStreamProvider);
  }

  void _cancel() {
    _ctrl.clear();
    setState(() => _isAdding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdding) {
      return GestureDetector(
        onTap: () {
          setState(() => _isAdding = true);
          WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 14, color: widget.accentColor.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(
                'Alt görev ekle',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.accentColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            focusNode: _focusNode,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Alt görev adı...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
            onSubmitted: (_) => _submit(),
            textInputAction: TextInputAction.done,
          ),
        ),
        TextButton(
          onPressed: _submit,
          style: TextButton.styleFrom(
            foregroundColor: widget.accentColor,
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('Ekle', style: TextStyle(fontSize: 12)),
        ),
        TextButton(
          onPressed: _cancel,
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey,
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: const Text('İptal', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
