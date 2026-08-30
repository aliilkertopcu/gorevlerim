import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/widgets/task_drag.dart';

void main() {
  group('dropZoneFor', () {
    late RenderBox box;

    setUp(() {});

    Future<void> pump(WidgetTester tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: SizedBox(key: key, width: 200, height: 100)),
        ),
      );
      box = key.currentContext!.findRenderObject() as RenderBox;
    }

    testWidgets('top quarter → before, bottom quarter → after, middle → into',
        (tester) async {
      await pump(tester);
      final origin = box.localToGlobal(Offset.zero);
      Offset at(double fraction) => origin + Offset(10, 100 * fraction);

      expect(dropZoneFor(box, at(0.10), allowInto: true), DropZone.before);
      expect(dropZoneFor(box, at(0.50), allowInto: true), DropZone.into);
      expect(dropZoneFor(box, at(0.90), allowInto: true), DropZone.after);
    });

    testWidgets('without into, the middle splits at the half line',
        (tester) async {
      await pump(tester);
      final origin = box.localToGlobal(Offset.zero);
      Offset at(double fraction) => origin + Offset(10, 100 * fraction);

      expect(dropZoneFor(box, at(0.40), allowInto: false), DropZone.before);
      expect(dropZoneFor(box, at(0.60), allowInto: false), DropZone.after);
    });

    testWidgets('positions outside the box clamp to the nearest edge',
        (tester) async {
      await pump(tester);
      final origin = box.localToGlobal(Offset.zero);
      expect(dropZoneFor(box, origin - const Offset(0, 50), allowInto: true), DropZone.before);
      expect(dropZoneFor(box, origin + const Offset(0, 500), allowInto: true), DropZone.after);
    });
  });

  group('adaptiveDraggable', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: adaptiveDraggable<String>(
            data: 'x',
            feedback: const SizedBox(),
            child: const Text('handle'),
          ),
        ),
      );
      expect(find.text('handle'), findsOneWidget);
    });
  });
}
