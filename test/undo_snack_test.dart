import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/widgets/undo_snack.dart';

Widget _host({bool disableAnimations = false, VoidCallback? onUndo}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showUndoSnack(
              ScaffoldMessenger.of(context),
              message: '"Test" silindi',
              onUndo: onUndo ?? () {},
            ),
            child: const Text('sil'),
          ),
        ),
      ),
    ),
  );
}

double _widthFactor(WidgetTester tester) {
  return tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor!;
}

void main() {
  testWidgets('countdown line shrinks over the undo window', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('sil'));
    await tester.pump();

    expect(find.text('"Test" silindi'), findsOneWidget);
    expect(_widthFactor(tester), 1.0);

    await tester.pump(const Duration(milliseconds: 2500));
    expect(_widthFactor(tester), closeTo(0.5, 0.05));

    await tester.pump(const Duration(milliseconds: 2500));
    expect(_widthFactor(tester), closeTo(0.0, 0.05));

    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion does not speed up the countdown', (tester) async {
    // AnimationController shrinks its duration 20x under reduce-motion unless
    // it preserves behaviour — that would make the line lie about the window.
    await tester.pumpWidget(_host(disableAnimations: true));
    await tester.tap(find.text('sil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));

    expect(_widthFactor(tester), closeTo(0.5, 0.05));
    await tester.pumpAndSettle();
  });

  testWidgets('undo action fires and dismisses the bar', (tester) async {
    var undone = false;
    await tester.pumpWidget(_host(onUndo: () => undone = true));
    await tester.tap(find.text('sil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // snack bar slides in

    await tester.tap(find.text('Geri Al'));
    await tester.pumpAndSettle();

    expect(undone, isTrue);
    expect(find.text('"Test" silindi'), findsNothing);
  });
}
