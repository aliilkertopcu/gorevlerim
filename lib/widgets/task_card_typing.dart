// Typing indicator shown in the task card header (part of task_card.dart).
part of 'task_card.dart';

/// Always-active typing indicator for the task card header.
/// Subscribes to the Realtime broadcast channel independently of the chat panel.
class _HeaderTypingIndicator extends StatefulWidget {
  final String taskId;
  final Color accentColor;
  final String? currentUserId;

  const _HeaderTypingIndicator({
    required this.taskId,
    required this.accentColor,
    this.currentUserId,
  });

  @override
  State<_HeaderTypingIndicator> createState() => _HeaderTypingIndicatorState();
}

class _HeaderTypingIndicatorState extends State<_HeaderTypingIndicator> {
  RealtimeChannel? _channel;
  final Map<String, ({String name, DateTime lastTyped})> _typingUsers = {};
  static const _timeoutMs = 3500;

  @override
  void initState() {
    super.initState();
    _channel = Supabase.instance.client.channel('typing:task:${widget.taskId}');
    _channel!
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final userId = payload['user_id'] as String?;
            final userName = payload['user_name'] as String? ?? '?';
            if (userId == null || userId == widget.currentUserId) return;
            if (!mounted) return;
            setState(() {
              _typingUsers[userId] = (name: userName, lastTyped: DateTime.now());
            });
            Future.delayed(const Duration(milliseconds: _timeoutMs), () {
              if (!mounted) return;
              final entry = _typingUsers[userId];
              if (entry == null) return;
              if (DateTime.now().difference(entry.lastTyped).inMilliseconds >= _timeoutMs - 200) {
                setState(() => _typingUsers.remove(userId));
              }
            });
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_typingUsers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stacked avatars (max 2 in header to save space)
          ...(_typingUsers.entries.take(2).map((e) => Container(
            margin: const EdgeInsets.only(right: 2),
            child: CircleAvatar(
              radius: 9,
              backgroundColor: widget.accentColor.withValues(alpha: 0.25),
              child: Text(
                e.value.name.isNotEmpty ? e.value.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 8,
                  color: widget.accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ))),
          const SizedBox(width: 3),
          TypingDotsWidget(color: Colors.grey.shade400),
        ],
      ),
    );
  }
}
