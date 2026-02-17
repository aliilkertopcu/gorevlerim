import 'package:flutter/material.dart';

/// Shows a dialog that is draggable and resizable on desktop (width > 600),
/// and a standard AlertDialog on mobile.
///
/// For dialogs that need internal state (e.g. loading indicators),
/// use [contentBuilder] and [actionsBuilder] instead of [content] and [actions].
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required Widget title,
  Widget? content,
  List<Widget>? actions,
  Widget Function(BuildContext ctx, StateSetter setState)? contentBuilder,
  List<Widget> Function(BuildContext ctx, StateSetter setState)? actionsBuilder,
  double initialWidth = 450,
  double minWidth = 320,
  double minHeight = 200,
}) {
  assert(
    content != null || contentBuilder != null,
    'Either content or contentBuilder must be provided',
  );

  final screenSize = MediaQuery.of(context).size;
  final isDesktop = screenSize.width > 600;

  if (!isDesktop) {
    if (contentBuilder != null || actionsBuilder != null) {
      return showDialog<T>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: title,
            content: SizedBox(
              width: double.maxFinite,
              child: contentBuilder?.call(ctx, setDialogState) ?? content!,
            ),
            actions: actionsBuilder?.call(ctx, setDialogState) ?? actions ?? [],
          ),
        ),
      );
    }
    return showDialog<T>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: title,
        content: SizedBox(
          width: double.maxFinite,
          child: content!,
        ),
        actions: actions ?? [],
      ),
    );
  }

  return showDialog<T>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _DesktopDialog(
      title: title,
      content: content,
      actions: actions,
      contentBuilder: contentBuilder,
      actionsBuilder: actionsBuilder,
      initialWidth: initialWidth,
      minWidth: minWidth,
      minHeight: minHeight,
      screenSize: screenSize,
    ),
  );
}

class _DesktopDialog extends StatefulWidget {
  final Widget title;
  final Widget? content;
  final List<Widget>? actions;
  final Widget Function(BuildContext ctx, StateSetter setState)? contentBuilder;
  final List<Widget> Function(BuildContext ctx, StateSetter setState)? actionsBuilder;
  final double initialWidth;
  final double minWidth;
  final double minHeight;
  final Size screenSize;

  const _DesktopDialog({
    required this.title,
    this.content,
    this.actions,
    this.contentBuilder,
    this.actionsBuilder,
    required this.initialWidth,
    required this.minWidth,
    required this.minHeight,
    required this.screenSize,
  });

  @override
  State<_DesktopDialog> createState() => _DesktopDialogState();
}

class _DesktopDialogState extends State<_DesktopDialog> {
  late Offset _offset;
  late double _width;
  double? _height;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth;
    _offset = Offset(
      (widget.screenSize.width - _width) / 2,
      widget.screenSize.height * 0.15,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contentWidget = widget.contentBuilder?.call(context, setState) ?? widget.content!;
    final actionsWidgets = widget.actionsBuilder?.call(context, setState) ?? widget.actions ?? [];

    return Stack(
      children: [
        // Dismiss on outside tap
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(color: Colors.transparent),
        ),
        Positioned(
          left: _offset.dx,
          top: _offset.dy,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: widget.minWidth,
              maxWidth: widget.screenSize.width - 40,
              minHeight: widget.minHeight,
              maxHeight: widget.screenSize.height * 0.85,
            ),
            child: SizedBox(
              width: _width,
              height: _height,
              child: Material(
                elevation: 24,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: _height == null ? MainAxisSize.min : MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Draggable title bar
                    MouseRegion(
                      cursor: _isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
                      child: GestureDetector(
                        onPanStart: (_) => setState(() => _isDragging = true),
                        onPanUpdate: (details) {
                          setState(() {
                            _offset += details.delta;
                            _offset = Offset(
                              _offset.dx.clamp(0, widget.screenSize.width - 100),
                              _offset.dy.clamp(0, widget.screenSize.height - 60),
                            );
                          });
                        },
                        onPanEnd: (_) => setState(() => _isDragging = false),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(24, 16, 8, 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            border: Border(
                              bottom: BorderSide(
                                color: theme.dividerColor.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: DefaultTextStyle(
                                style: theme.textTheme.titleLarge!,
                                child: widget.title,
                              )),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () => Navigator.pop(context),
                                splashRadius: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: contentWidget,
                      ),
                    ),
                    // Actions
                    if (actionsWidgets.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: actionsWidgets
                              .expand((w) => [w, const SizedBox(width: 8)])
                              .toList()
                            ..removeLast(),
                        ),
                      ),
                    // Resize handle
                    Align(
                      alignment: Alignment.bottomRight,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeDownRight,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              _width = (_width + details.delta.dx)
                                  .clamp(widget.minWidth, widget.screenSize.width - 40);
                              final currentHeight = _height ?? widget.minHeight;
                              _height = (currentHeight + details.delta.dy)
                                  .clamp(widget.minHeight, widget.screenSize.height * 0.85);
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4, bottom: 4),
                            child: Icon(
                              Icons.drag_handle,
                              size: 16,
                              color: theme.hintColor.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
