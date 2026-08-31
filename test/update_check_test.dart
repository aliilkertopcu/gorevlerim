import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todo_app/providers/update_provider.dart';
import 'package:todo_app/version.dart';

ProviderContainer _containerServing(String body, {int status = 200}) {
  final container = ProviderContainer(overrides: [
    updateHttpClientProvider.overrideWithValue(
      MockClient((request) async {
        // The request must be cache-busted, or a stale cache could answer it.
        expect(request.url.queryParameters.containsKey('ts'), isTrue);
        expect(request.url.path, endsWith('app_version.json'));
        return http.Response(body, status);
      }),
    ),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('flags an update when the deployed version differs', () async {
    final container = _containerServing('{"version":"99.0.0"}');
    await container.read(updateAvailableProvider.notifier).check();

    expect(container.read(updateAvailableProvider), isTrue);
  });

  test('stays quiet while the deployed version matches this build', () async {
    final container = _containerServing('{"version":"$appVersion"}');
    await container.read(updateAvailableProvider.notifier).check();

    expect(container.read(updateAvailableProvider), isFalse);
  });

  test('stays quiet when the stamp is missing or unreadable', () async {
    final missing = _containerServing('not found', status: 404);
    await missing.read(updateAvailableProvider.notifier).check();
    expect(missing.read(updateAvailableProvider), isFalse);

    final garbage = _containerServing('<html>oops</html>');
    await garbage.read(updateAvailableProvider.notifier).check();
    expect(garbage.read(updateAvailableProvider), isFalse);
  });
}
