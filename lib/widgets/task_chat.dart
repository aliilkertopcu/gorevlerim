import 'dart:async';
import 'dart:math' show sin, pi;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';

/// Inline chat panel shown inside a task or subtask card.
/// [taskId] or [subtaskId] must be provided (not both).
class TaskChatWidget extends ConsumerStatefulWidget {
  final String? taskId;
  final String? subtaskId;
  final Color accentColor;

  const TaskChatWidget({
    super.key,
    this.taskId,
    this.subtaskId,
    required this.accentColor,
  }) : assert(
          (taskId != null) != (subtaskId != null),
          'Exactly one of taskId or subtaskId must be provided',
        );

  @override
  ConsumerState<TaskChatWidget> createState() => _TaskChatWidgetState();
}

class _TaskChatWidgetState extends ConsumerState<TaskChatWidget> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  // Typing broadcast state
  RealtimeChannel? _typingChannel;
  // userId → {name, lastTyped}
  final Map<String, ({String name, DateTime lastTyped})> _typingUsers = {};
  DateTime? _lastBroadcast;
  static const _broadcastIntervalMs = 2000; // broadcast at most every 2s
  static const _typingTimeoutMs = 3500;     // remove indicator after 3.5s

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onTextChanged);
    _initTypingChannel();
  }

  void _initTypingChannel() {
    final channelKey = widget.taskId != null
        ? 'typing:task:${widget.taskId}'
        : 'typing:subtask:${widget.subtaskId}';

    _typingChannel = Supabase.instance.client.channel(channelKey);
    _typingChannel!
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final userId = payload['user_id'] as String?;
            final userName = payload['user_name'] as String? ?? '?';
            if (userId == null) return;
            // Ignore own events
            final me = ref.read(currentUserProvider);
            if (userId == me?.id) return;

            if (!mounted) return;
            setState(() {
              _typingUsers[userId] = (name: userName, lastTyped: DateTime.now());
            });

            // Auto-clear after timeout
            Future.delayed(const Duration(milliseconds: _typingTimeoutMs), () {
              if (!mounted) return;
              final entry = _typingUsers[userId];
              if (entry == null) return;
              final elapsed = DateTime.now().difference(entry.lastTyped).inMilliseconds;
              if (elapsed >= _typingTimeoutMs - 200) {
                setState(() => _typingUsers.remove(userId));
              }
            });
          },
        )
        .subscribe();
  }

  void _onTextChanged() {
    if (_inputController.text.trim().isNotEmpty) {
      _maybeBroadcastTyping();
    }
  }

  void _maybeBroadcastTyping() {
    final now = DateTime.now();
    if (_lastBroadcast != null &&
        now.difference(_lastBroadcast!).inMilliseconds < _broadcastIntervalMs) {
      return;
    }
    _lastBroadcast = now;
    _broadcastTyping();
  }

  Future<void> _broadcastTyping() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _typingChannel == null) return;
    final name = user.userMetadata?['display_name'] as String? ?? user.email ?? '?';
    await _typingChannel!.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': user.id, 'user_name': name},
    );
  }

  @override
  void dispose() {
    _inputController.removeListener(_onTextChanged);
    _inputController.dispose();
    _scrollController.dispose();
    _typingChannel?.unsubscribe();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isSending = true);
    _inputController.clear();

    try {
      await ref.read(chatServiceProvider).sendMessage(
            taskId: widget.taskId,
            subtaskId: widget.subtaskId,
            content: text,
            userId: user.id,
            userName: user.userMetadata?['display_name'] as String? ?? user.email,
          );
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = widget.taskId != null
        ? ref.watch(taskMessagesProvider(widget.taskId!))
        : ref.watch(subtaskMessagesProvider(widget.subtaskId!));
    final currentUser = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Scroll to bottom when new messages arrive
    messagesAsync.whenData((msgs) {
      if (msgs.isNotEmpty) _scrollToBottom();
    });

    return Container(
      margin: const EdgeInsets.fromLTRB(42, 4, 8, 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Messages list
          messagesAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Henüz mesaj yok. İlk mesajı gönder!',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  controller: _scrollController,
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.userId == currentUser?.id;
                    return _MessageBubble(
                      message: msg,
                      isMe: isMe,
                      accentColor: widget.accentColor,
                    );
                  },
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Hata: $e', style: TextStyle(fontSize: 11, color: Colors.red[400])),
            ),
          ),
          // Realtime typing indicator — shows other users typing
          if (_typingUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 8, 4),
              child: Row(
                children: [
                  // Stacked avatars (max 3)
                  SizedBox(
                    width: (_typingUsers.length.clamp(1, 3) * 16 + 4).toDouble(),
                    height: 20,
                    child: Stack(
                      children: _typingUsers.entries.take(3).toList().asMap().entries.map((e) {
                        final idx = e.key;
                        final name = e.value.value.name;
                        return Positioned(
                          left: idx * 12.0,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: widget.accentColor.withValues(alpha: 0.25),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 9,
                                color: widget.accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TypingDotsWidget(color: theme.hintColor),
                ],
              ),
            ),
          // Input area
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: widget.accentColor.withValues(alpha: 0.15)),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Mesaj yaz...',
                      hintStyle: TextStyle(fontSize: 13, color: theme.hintColor),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 4),
                _isSending
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: _sendMessage,
                        icon: Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: widget.accentColor,
                        ),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated "..." dots for typing indicator (public — used in task card header too)
class TypingDotsWidget extends StatefulWidget {
  final Color color;
  const TypingDotsWidget({super.key, required this.color});

  @override
  State<TypingDotsWidget> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDotsWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(3, (i) {
            // Each dot offset by 1/3 of the cycle — no clamp, always smooth
            final phase = (_controller.value + i / 3) % 1.0;
            final sine = sin(phase * 2 * pi); // -1.0 → 1.0, perfectly continuous
            final translateY = sine * 3.5;    // max ±3.5px vertical
            final opacity = 0.35 + (1 + sine) / 2 * 0.65; // 0.35 → 1.0
            return Transform.translate(
              offset: Offset(0, -translateY),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final Color accentColor;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 12,
              backgroundColor: accentColor.withValues(alpha: 0.2),
              child: Text(
                (message.userName?.isNotEmpty == true
                    ? message.userName![0]
                    : '?'),
                style: TextStyle(
                  fontSize: 11,
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && message.userName != null)
                  Text(
                    message.userName!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isMe
                        ? accentColor.withValues(alpha: isDark ? 0.3 : 0.15)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(2),
                      bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
