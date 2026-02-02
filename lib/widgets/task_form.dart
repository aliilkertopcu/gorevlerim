import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class TaskForm extends ConsumerStatefulWidget {
  const TaskForm({super.key});

  @override
  ConsumerState<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<TaskForm> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isExpanded = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final description = _descController.text.trim();
    final owner = ref.read(ownerContextProvider);
    final user = ref.read(currentUserProvider);
    final date = ref.read(selectedDateProvider);

    if (owner == null || user == null) return;

    setState(() => _isLoading = true);

    try {
      // Parse subtasks from description lines starting with "* "
      final lines = description.split('\n');
      final subtaskTitles = <String>[];
      final descLines = <String>[];

      for (final line in lines) {
        if (line.trimLeft().startsWith('* ')) {
          subtaskTitles.add(line.trimLeft().substring(2).trim());
        } else {
          descLines.add(line);
        }
      }

      final cleanDesc = descLines.join('\n').trim();

      await ref.read(taskServiceProvider).createTask(
        ownerId: owner.ownerId,
        ownerType: owner.ownerType,
        date: date,
        title: title,
        description: cleanDesc.isEmpty ? null : cleanDesc,
        createdBy: user.id,
        subtaskTitles: subtaskTitles,
      );

      _titleController.clear();
      _descController.clear();
      setState(() => _isExpanded = false);

      // Refresh tasks
      ref.invalidate(tasksProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.add_circle_outline,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Yeni Görev Ekle',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Görev başlığı',
                    ),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      if (_descController.text.isEmpty) {
                        _addTask();
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          HardwareKeyboard.instance.isControlPressed) {
                        _addTask();
                      }
                    },
                    child: TextField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        hintText: 'Açıklama (opsiyonel)\n* ile alt görev ekle\nCtrl+Enter ile ekle',
                      ),
                      maxLines: 4,
                      minLines: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _addTask,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Ekle'),
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
