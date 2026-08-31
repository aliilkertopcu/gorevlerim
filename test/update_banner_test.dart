import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/providers/update_provider.dart';
import 'package:todo_app/widgets/update_banner.dart';

class _FixedUpdate extends UpdateNotifier {
  _FixedUpdate(this.available);
  final bool available;

  // Skips the polling timers the real notifier starts.
  @override
  bool build() => available;
}

Widget _host(bool available) {
  return ProviderScope(
    overrides: [updateAvailableProvider.overrideWith(() => _FixedUpdate(available))],
    child: const MaterialApp(home: Scaffold(body: UpdateBanner())),
  );
}

void main() {
  testWidgets('banner stays hidden while the build is current', (tester) async {
    await tester.pumpWidget(_host(false));
    await tester.pumpAndSettle();

    expect(find.text('Yeni sürüm hazır'), findsNothing);
    expect(find.text('Yenile'), findsNothing);
  });

  testWidgets('banner offers a reload once a newer build is out', (tester) async {
    await tester.pumpWidget(_host(true));
    await tester.pumpAndSettle();

    expect(find.text('Yeni sürüm hazır'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Yenile'), findsOneWidget);
  });
}
