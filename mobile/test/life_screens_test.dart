import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near/api.dart';
import 'package:near/app_state.dart';
import 'package:near/life_screens.dart';
import 'package:near/animations.dart';
import 'rituals_test.dart' as fixtures;

class LifeApi extends Api {
  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (path.startsWith('recap/')) {
      return {
        'complete': true,
        'daily_photos': 24,
        'photo_days': 12,
        'answers': 20,
        'memories': 3,
        'dreams': 1,
        'days': {'apart': 20, 'together': 10}
      };
    }
    return {'results': [], 'next': null};
  }
}

void main() {
  testWidgets('New date, recap, report and mode screens fit 320px phones',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = AppState(LifeApi())
      ..me = {'id': 1}
      ..life = {
        'mode': 'together',
        'since': '2026-09-01',
        'days': {'together': 20, 'apart': 5},
        'history': [],
        'notifications': [
          {'title': 'Our two months', 'days': 0}
        ]
      };
    for (final screen in <Widget>[
      const ImportantDatesScreen(),
      const RecapScreen(),
      const DateEditor(),
      const WishReport(row: {'id': 1, 'title': 'See the ocean'}),
      const LifeCard(),
      const HugDialog()
    ]) {
      await tester.pumpWidget(fixtures.app(state, screen));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: screen.runtimeType.toString());
    }
  });
}
