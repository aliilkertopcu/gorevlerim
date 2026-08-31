import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/widgets/confetti_burst.dart';

Widget _host({bool disableAnimations = false, required VoidCallback Function(BuildContext) onBuild}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: onBuild(context),
            child: const Text('fire'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('confetti overlay appears and cleans itself up', (tester) async {
    await tester.pumpWidget(_host(onBuild: (c) => () => showConfetti(c)));
    await tester.tap(find.text('fire'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(confettiKey), findsOneWidget);

    // Runs at most 8 s, with a 12 s safety net; either way it must be gone.
    await tester.pump(const Duration(seconds: 13));
    await tester.pump();
    expect(find.byKey(confettiKey), findsNothing);
  });

  testWidgets('celebrate() shows confetti even when audio is unavailable', (tester) async {
    // No audio plugin in the test environment: the chime must fail silently.
    await tester.pumpWidget(_host(onBuild: (c) => () => celebrate(c)));
    await tester.tap(find.text('fire'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(confettiKey), findsOneWidget);

    await tester.pump(const Duration(seconds: 13));
    await tester.pump();
    expect(find.byKey(confettiKey), findsNothing);
  });

  testWidgets('reduced motion still celebrates', (tester) async {
    await tester.pumpWidget(_host(disableAnimations: true, onBuild: (c) => () => showConfetti(c)));
    await tester.tap(find.text('fire'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(confettiKey), findsOneWidget,
        reason: 'celebration must still happen under reduced motion');

    await tester.pump(const Duration(seconds: 13));
    await tester.pump();
    expect(find.byKey(confettiKey), findsNothing);
  });
}
