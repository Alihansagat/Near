import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:near/api.dart';
import 'package:near/app_state.dart';

class LoadingApi extends Api {
  final pending = <String, Completer<Map<String, dynamic>>>{};
  int profiles = 0;
  @override
  Future<Map<String, dynamic>> get(String path) {
    if (path == 'me/') {
      profiles++;
      return Future.value({'id': 1, 'couple': 1});
    }
    return (pending[path] ??= Completer<Map<String, dynamic>>()).future;
  }
  void finish() {
    for (final row in pending.entries) {
      row.value.complete(row.key == 'home/' ? {'day': '2026-09-29'} : {'results': [], 'count': 0, 'next': null});
    }
  }
}
void main() {
  test('Reload fans out independent reads and coalesces duplicate reloads', () async {
    final api = LoadingApi();
    final state = AppState(api);
    final one = state.reload();
    final two = state.reload();
    await Future<void>.delayed(Duration.zero);
    expect(api.profiles, 1);
    expect(api.pending.keys.toSet(), {'home/', 'life/', 'meetings/', 'dates/', 'moments/'});
    api.finish();
    await Future.wait([one, two]);
    expect(state.home!['day'], '2026-09-29');
  });
  test('Silent refresh leaves controls unlocked and preserves data on failure', () async {
    final api = LoadingApi();
    final state = AppState(api)..me = {'id': 1, 'couple': 1}..home = {'day': 'old'};
    final refreshing = state.refreshQuietly();
    expect(state.busy, false);
    api.pending['home/']!.completeError(StateError('offline'));
    api.pending['life/']!.complete({});
    await refreshing;
    expect(state.home!['day'], 'old');
    expect(state.error, isNull);
  });
}
