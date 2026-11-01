import 'dart:async';

import 'package:bitree/core/async/cancelable_request.dart';
import 'package:bitree/core/async/read_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Concurrent reads share work; a refresh replaces the saved result',
    () async {
      final cache = ReadCache<String, int>(maxAge: const Duration(minutes: 5));
      final response = Completer<int>();
      var calls = 0;
      Future<int> load() {
        calls++;
        return response.future;
      }

      final first = cache.read('account', load);
      final second = cache.read('account', load);
      response.complete(1);
      expect(await Future.wait([first, second]), [1, 1]);
      expect(calls, 1);
      expect(await cache.read('account', () async => 2), 1);
      expect(await cache.read('account', () async => 2, refresh: true), 2);
      expect(await cache.read('account', () async => 3), 2);
    },
  );

  test(
    'Clearing a pending cache read prevents it from repopulating saved data',
    () async {
      final cache = ReadCache<String, int>(maxAge: const Duration(minutes: 5));
      final response = Completer<int>();
      final old = cache.read('account', () => response.future);
      cache.clear();
      expect(await cache.read('account', () async => 2), 2);
      response.complete(1);
      expect(await old, 1);
      expect(await cache.read('account', () async => 3), 2);
    },
  );

  test('Cancelled queries close before replacements run and cannot publish stale results', () async {
    final requests = LatestRequest();
    final started = Completer<void>();
    final closed = Completer<void>();
    var cancelled = false;
    var replacementStarted = false;
    final old = requests.run((signal) async {
      signal.onCancel(() => cancelled = true);
      started.complete();
      await closed.future;
      return 1;
    });
    await started.future;
    final latest = requests.run((_) async {
      replacementStarted = true;
      return 2;
    });
    expect(cancelled, isTrue);
    expect(replacementStarted, isFalse);
    closed.complete();
    await expectLater(old, throwsA(isA<RequestCancelled>()));
    expect(await latest, 2);
    expect(replacementStarted, isTrue);
  });

  test('A null result is not treated as cancellation', () async {
    final requests = LatestRequest();

    expect(await requests.run<int?>((_) async => null), isNull);
  });
}
