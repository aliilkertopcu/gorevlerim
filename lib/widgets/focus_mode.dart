import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../providers/group_provider.dart';
import '../providers/task_provider.dart';

void showFocusMode(BuildContext context, WidgetRef ref, Task task) {
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (context) => PopScope(
      canPop: false,
      child: _FocusModeDialog(task: task),
    ),
  );
}

enum _FocusState { idle, running, paused, overtime }

class _FocusModeDialog extends ConsumerStatefulWidget {
  final Task task;
  const _FocusModeDialog({required this.task});

  @override
  ConsumerState<_FocusModeDialog> createState() => _FocusModeDialogState();
}

class _FocusModeDialogState extends ConsumerState<_FocusModeDialog> {
  _FocusState _focusState = _FocusState.idle;
  int _selectedMinutes = 25;
  int _remainingSeconds = 25 * 60;
  int _overtimeSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _remainingSeconds = _selectedMinutes * 60;
      _focusState = _FocusState.running;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_focusState == _FocusState.running) {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _focusState = _FocusState.overtime;
            _overtimeSeconds++;
          }
        } else if (_focusState == _FocusState.overtime) {
          _overtimeSeconds++;
        }
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _focusState = _FocusState.paused);
  }

  void _resume() {
    setState(() {
      _focusState = _remainingSeconds > 0
          ? _FocusState.running
          : _FocusState.overtime;
    });
    _startTimer();
  }

  void _complete() {
    _timer?.cancel();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odak Tamamlandı'),
        content: const Text('Görevi de tamamlamak ister misin?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Hayır'),
          ),
          FilledButton(
            onPressed: () {
              final task = _currentTask;
              ref.read(tasksNotifierProvider.notifier)
                  .optimisticToggleComplete(task.id);
              ref.read(taskServiceProvider)
                  .toggleComplete(task.id, task.isCompleted);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Evet, Tamamla'),
          ),
        ],
      ),
    );
  }

  Task get _currentTask {
    final tasks = ref.read(tasksNotifierProvider);
    return tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );
  }

  void _toggleSubtask(Subtask subtask) {
    ref.read(tasksNotifierProvider.notifier)
        .optimisticToggleSubtask(widget.task.id, subtask.id);
    ref.read(taskServiceProvider)
        .toggleSubtaskComplete(subtask.id, subtask.isCompleted);
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = ref.watch(currentOwnerColorProvider);
    final task = _currentTask;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOvertime = _focusState == _FocusState.overtime;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1a1a2e) : const Color(0xFFF5F5FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Task title
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 40),
                  // Timer display
                  _buildTimer(accentColor, isDark, isOvertime),
                  const SizedBox(height: 32),
                  // Duration chips (only in idle)
                  if (_focusState == _FocusState.idle) ...[
                    _buildDurationChips(accentColor, isDark),
                    const SizedBox(height: 32),
                  ],
                  // Subtasks
                  if (task.subtasks.isNotEmpty) ...[
                    Expanded(child: _buildSubtasks(task, accentColor, isDark)),
                  ] else
                    const Spacer(),
                  // Action buttons
                  _buildActions(accentColor),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimer(Color accent, bool isDark, bool isOvertime) {
    final displaySeconds = isOvertime ? _overtimeSeconds : _remainingSeconds;
    final timerColor = isOvertime ? Colors.red : accent;

    return Column(
      children: [
        if (isOvertime)
          Text(
            'OVERTIME',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red[400],
              letterSpacing: 3,
            ),
          ),
        if (isOvertime) const SizedBox(height: 8),
        Text(
          isOvertime ? '+${_formatTime(displaySeconds)}' : _formatTime(displaySeconds),
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.w300,
            fontFamily: 'monospace',
            color: timerColor,
            letterSpacing: 4,
          ),
        ),
        if (_focusState != _FocusState.idle)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _focusState == _FocusState.paused ? 'Duraklatıldı' : '',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDurationChips(Color accent, bool isDark) {
    const durations = [15, 25, 45, 60];
    return Wrap(
      spacing: 12,
      children: durations.map((min) {
        final selected = _selectedMinutes == min;
        return ChoiceChip(
          label: Text('$min dk'),
          selected: selected,
          selectedColor: accent.withValues(alpha: 0.2),
          labelStyle: TextStyle(
            color: selected
                ? accent
                : (isDark ? Colors.grey[300] : Colors.grey[700]),
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
          side: BorderSide(
            color: selected ? accent : Colors.transparent,
          ),
          onSelected: (_) {
            setState(() {
              _selectedMinutes = min;
              _remainingSeconds = min * 60;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildSubtasks(Task task, Color accent, bool isDark) {
    final subtasks = task.subtasks.where((s) => !s.isBlocked).toList();
    if (subtasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alt Görevler',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: subtasks.length,
            itemBuilder: (context, index) {
              final subtask = subtasks[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Checkbox(
                  value: subtask.isCompleted,
                  activeColor: accent,
                  onChanged: (_) => _toggleSubtask(subtask),
                ),
                title: Text(
                  subtask.title,
                  style: TextStyle(
                    fontSize: 15,
                    decoration: subtask.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    color: subtask.isCompleted
                        ? (isDark ? Colors.grey[600] : Colors.grey[400])
                        : (isDark ? Colors.grey[200] : Colors.grey[800]),
                  ),
                ),
                onTap: () => _toggleSubtask(subtask),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActions(Color accent) {
    switch (_focusState) {
      case _FocusState.idle:
        return FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Başla'),
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 18),
          ),
        );
      case _FocusState.running:
      case _FocusState.overtime:
      case _FocusState.paused:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _focusState == _FocusState.paused ? _resume : _pause,
              icon: Icon(
                _focusState == _FocusState.paused ? Icons.play_arrow : Icons.pause,
              ),
              label: Text(
                _focusState == _FocusState.paused ? 'Devam' : 'Duraklat',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _complete,
              icon: const Icon(Icons.check),
              label: const Text('Tamamla'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
    }
  }
}
