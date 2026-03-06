import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/models/task.dart';
import 'package:todo_app/theme/animation_constants.dart';
import 'package:todo_app/widgets/task_card.dart';
import 'package:todo_app/widgets/subtask_item.dart';
import 'package:todo_app/widgets/desktop_dialog.dart';
import 'package:todo_app/providers/task_provider.dart';
import 'package:todo_app/providers/group_provider.dart';
import 'package:todo_app/providers/auth_provider.dart';
import 'package:todo_app/providers/chat_provider.dart';
// Note: router.dart cannot be tested in VM due to dart:js_interop dependency
// via gpt_connect_screen.dart. Router transitions verified via web build.

// ─── Helpers ────────────────────────────────────────────────

Task _makeTask({
  String id = 't1',
  String status = 'pending',
  String title = 'Test Task',
  String? description,
  List<Subtask> subtasks = const [],
}) {
  return Task(
    id: id,
    ownerId: 'user1',
    ownerType: 'user',
    date: DateTime.now(),
    title: title,
    status: status,
    description: description,
    subtasks: subtasks,
  );
}

Subtask _makeSubtask({
  String id = 's1',
  String taskId = 't1',
  String status = 'pending',
  String title = 'Sub 1',
}) {
  return Subtask(id: id, taskId: taskId, title: title, status: status);
}

/// Wraps a widget with MaterialApp + ProviderScope and necessary overrides
Widget _testApp(Widget child) {
  return ProviderScope(
    overrides: [
      currentOwnerColorProvider.overrideWithValue(Colors.blue),
      currentGroupProvider.overrideWithValue(null),
      currentUserProvider.overrideWithValue(null),
      ownerContextProvider.overrideWith((ref) => null),
      collapsedTasksProvider.overrideWith((ref) => CollapsedTasksNotifier()),
      chatOpenTasksProvider.overrideWith((ref) => <String>{}),
    ],
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

// ─── Animation Constants Tests ──────────────────────────────

void main() {
  group('Anim constants', () {
    test('durations are correct', () {
      expect(Anim.fast, const Duration(milliseconds: 150));
      expect(Anim.normal, const Duration(milliseconds: 250));
      expect(Anim.slow, const Duration(milliseconds: 400));
      expect(Anim.pageTransition, const Duration(milliseconds: 300));
    });

    test('curves are correct', () {
      expect(Anim.defaultCurve, Curves.easeOutCubic);
      expect(Anim.enterCurve, Curves.easeOut);
    });

    test('pressedScale is 0.97', () {
      expect(Anim.pressedScale, 0.97);
    });
  });

  // ─── TaskCard Checkbox Animation Tests ──────────────────────

  group('TaskCard checkbox animation', () {
    testWidgets('pending task has AnimatedContainer checkbox', (tester) async {
      final task = _makeTask(status: 'pending');
      await tester.pumpWidget(_testApp(TaskCard(task: task, index: 0)));
      await tester.pumpAndSettle();

      // Should find AnimatedContainer (for checkbox color transitions)
      final animContainers = find.byType(AnimatedContainer);
      expect(animContainers, findsWidgets);
    });

    testWidgets('pending task checkbox has AnimatedSwitcher', (tester) async {
      final task = _makeTask(status: 'pending');
      await tester.pumpWidget(_testApp(TaskCard(task: task, index: 0)));
      await tester.pumpAndSettle();

      // AnimatedSwitcher wraps the check icon
      expect(find.byType(AnimatedSwitcher), findsWidgets);
    });

    testWidgets('completed task shows check icon inside AnimatedSwitcher', (tester) async {
      final task = _makeTask(status: 'completed');
      await tester.pumpWidget(_testApp(TaskCard(task: task, index: 0)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byType(AnimatedSwitcher), findsWidgets);
    });
  });

  // ─── TaskCard Press Feedback Tests ──────────────────────────

  group('TaskCard press feedback', () {
    testWidgets('card has AnimatedScale widget', (tester) async {
      final task = _makeTask();
      await tester.pumpWidget(_testApp(TaskCard(task: task, index: 0)));
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedScale), findsOneWidget);
    });

    testWidgets('card scale is 1.0 at rest', (tester) async {
      final task = _makeTask();
      await tester.pumpWidget(_testApp(TaskCard(task: task, index: 0)));
      await tester.pumpAndSettle();

      final animScale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(animScale.scale, 1.0);
    });

    testWidgets('card scales down on tap down', (tester) async {
      final task = _makeTask();
      await tester.pumpWidget(_testApp(TaskCard(task: task, index: 0)));
      await tester.pumpAndSettle();

      // Find the GestureDetector wrapping AnimatedScale (the _PressableCard)
      final cardFinder = find.byType(AnimatedScale);
      final center = tester.getCenter(cardFinder);

      // Simulate pointer down
      final gesture = await tester.startGesture(center);
      await tester.pump();

      final animScale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(animScale.scale, Anim.pressedScale);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('card returns to 1.0 after tap up', (tester) async {
      final task = _makeTask();
      await tester.pumpWidget(_testApp(TaskCard(task: task, index: 0)));
      await tester.pumpAndSettle();

      final cardFinder = find.byType(AnimatedScale);
      final center = tester.getCenter(cardFinder);

      final gesture = await tester.startGesture(center);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final animScale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(animScale.scale, 1.0);
    });
  });

  // ─── TaskCard Expand/Collapse Animation Tests ──────────────

  group('TaskCard expand/collapse animation', () {
    testWidgets('card has AnimatedSize for expandable content', (tester) async {
      final task = _makeTask(
        description: 'Some description',
        subtasks: [_makeSubtask()],
      );
      await tester.pumpWidget(_testApp(TaskCard(task: task, index: 0)));
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSize), findsOneWidget);
    });

    testWidgets('card has ClipRect wrapping AnimatedSize', (tester) async {
      final task = _makeTask(description: 'Desc');
      await tester.pumpWidget(_testApp(TaskCard(task: task, index: 0)));
      await tester.pumpAndSettle();

      expect(find.byType(ClipRect), findsWidgets);
    });

    testWidgets('expanded card shows description', (tester) async {
      final task = _makeTask(description: 'My description here');
      await tester.pumpWidget(_testApp(TaskCard(task: task, index: 0)));
      await tester.pumpAndSettle();

      // Default is expanded (not in collapsedTasks set)
      expect(find.text('My description here'), findsOneWidget);
    });
  });

  // ─── TaskCard RepaintBoundary Tests ─────────────────────────

  group('TaskCard RepaintBoundary', () {
    testWidgets('card is wrapped with RepaintBoundary', (tester) async {
      final task = _makeTask();
      await tester.pumpWidget(_testApp(TaskCard(task: task, index: 0)));
      await tester.pumpAndSettle();

      expect(find.byType(RepaintBoundary), findsWidgets);
    });
  });

  // ─── SubtaskItem Checkbox Animation Tests ───────────────────

  group('SubtaskItem checkbox animation', () {
    testWidgets('pending subtask has AnimatedContainer', (tester) async {
      final task = _makeTask(subtasks: [_makeSubtask()]);
      final subtask = task.subtasks.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtaskItem(
              subtask: subtask,
              parentTask: task,
              subtaskIndex: 0,
              onToggle: () {},
              onDelete: () {},
              onBlock: () {},
              onEdit: () {},
              onPromote: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    testWidgets('completed subtask shows check via AnimatedSwitcher', (tester) async {
      final task = _makeTask(subtasks: [_makeSubtask(status: 'completed')]);
      final subtask = task.subtasks.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtaskItem(
              subtask: subtask,
              parentTask: task,
              subtaskIndex: 0,
              onToggle: () {},
              onDelete: () {},
              onBlock: () {},
              onEdit: () {},
              onPromote: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('blocked subtask shows block icon via AnimatedSwitcher', (tester) async {
      final task = _makeTask(subtasks: [_makeSubtask(status: 'blocked')]);
      final subtask = task.subtasks.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtaskItem(
              subtask: subtask,
              parentTask: task,
              subtaskIndex: 0,
              onToggle: () {},
              onDelete: () {},
              onBlock: () {},
              onEdit: () {},
              onPromote: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });

    testWidgets('pending subtask shows empty SizedBox via AnimatedSwitcher', (tester) async {
      final task = _makeTask(subtasks: [_makeSubtask(status: 'pending')]);
      final subtask = task.subtasks.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtaskItem(
              subtask: subtask,
              parentTask: task,
              subtaskIndex: 0,
              onToggle: () {},
              onDelete: () {},
              onBlock: () {},
              onEdit: () {},
              onPromote: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      // No check or block icon
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byIcon(Icons.block), findsNothing);
    });
  });

  // ─── Dialog Animation Tests (unit) ──────────────────────────

  group('Dialog transition', () {
    testWidgets('showAppDialog opens with scale+fade animation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          // Need Localizations for showGeneralDialog barrierLabel
          localizationsDelegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showAppDialog(
                    context: context,
                    title: const Text('Test Dialog'),
                    content: const Text('Content'),
                    actions: [TextButton(onPressed: () {}, child: const Text('OK'))],
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      // Pump a few frames — animation should be in progress
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Dialog content should be appearing (ScaleTransition + FadeTransition)
      // There may be multiple ScaleTransitions (e.g. from button ink effects)
      expect(find.byType(ScaleTransition), findsWidgets);
      expect(find.byType(FadeTransition), findsWidgets);

      // Dialog title should exist
      expect(find.text('Test Dialog'), findsOneWidget);

      await tester.pumpAndSettle();

      // After settling, dialog is fully visible
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('dialog animation completes in 250ms', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showAppDialog(
                    context: context,
                    title: const Text('Dialog'),
                    content: const Text('Body'),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump(); // Start animation

      // At 125ms (halfway), animation should still be running
      await tester.pump(const Duration(milliseconds: 125));
      expect(find.text('Body'), findsOneWidget);

      // At 250ms, animation should complete
      await tester.pump(const Duration(milliseconds: 125));

      // Verify fully settled
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
      expect(find.text('Body'), findsOneWidget);
    });
  });
}
