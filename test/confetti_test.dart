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

    expect(find.byType(IgnorePointer).evaluate().length, greaterThan(0));
    // The burst paints via a dedicated CustomPaint in the overlay
    final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
    expect(paints.any((p) => p.painter.runtimeType.toString() == '_ConfettiPainter'), isTrue);

    // After its lifetime the entry removes itself
    await tester.pump(const Duration(seconds: 5));
    final after = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
    expect(after.any((p) => p.painter.runtimeType.toString() == '_ConfettiPainter'), isFalse);
  });

  testWidgets('reduced motion still celebrates, calmer and shorter', (tester) async {
    await tester.pumpWidget(_host(disableAnimations: true, onBuild: (c) => () => showConfetti(c)));
    await tester.tap(find.text('fire'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
    expect(paints.any((p) => p.painter.runtimeType.toString() == '_ConfettiPainter'), isTrue,
        reason: 'celebration must still happen under reduced motion');

    // Calm variant is shorter than the standard 4.2 s burst
    await tester.pump(const Duration(milliseconds: 3600));
    final after = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
    expect(after.any((p) => p.painter.runtimeType.toString() == '_ConfettiPainter'), isFalse);
  });
}
