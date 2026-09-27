import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near/api.dart';
import 'package:near/app_state.dart';
import 'package:near/mascot.dart';
import 'package:near/screens.dart';
import 'rituals_test.dart' as fixtures;

class ProfileApi extends Api {
  bool fail = false;
  Map<String, dynamic>? saved;
  @override
  Future<void> patch(String path, Map<String, dynamic> data) async {
    expect(path, 'me/');
    if (fail) throw StateError('Offline');
    saved = data;
  }
}

void main() {
  testWidgets('Mood save persists selection; partner keeps their own avatar',
      (tester) async {
    final api = ProfileApi();
    final fixture = fixtures.fixture();
    final state = AppState(api)
      ..me = fixture.me
      ..home = fixture.home;
    await tester.binding.setSurfaceSize(const Size(320, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(fixtures.app(state, const HomeScreen()));
    await tester.tap(find.text('Set mood'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Female'));
    await tester.tap(find.text('😔 Sad'));
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.saved, {'mascot': 'female', 'mood': 'sad'});
    expect(find.text('How are you feeling today?'), findsNothing);
    expect(find.text('😔 Sad'), findsOneWidget);
    final avatars =
        tester.widgetList<HeartMascot>(find.byType(HeartMascot)).toList();
    expect(avatars.first.character, 'female');
    expect(avatars.first.mood, HeartMood.sad);
    expect(avatars.last.mood, HeartMood.joyful);
    expect(state.home!['couple']['user_1']['mood'], 'sad');
    expect(state.home!['couple']['user_2']['mood'], isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed save keeps picker open and does not change profile',
      (tester) async {
    final api = ProfileApi()..fail = true;
    final fixture = fixtures.fixture();
    final state = AppState(api)
      ..me = fixture.me
      ..home = fixture.home;
    await tester.pumpWidget(fixtures.app(state, const HomeScreen()));
    await tester.tap(find.text('Set mood'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('😴 Tired'));
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('How are you feeling today?'), findsWidgets);
    expect(state.me!['mood'], isNull);
    expect(
        find.text('Something went wrong. Please try again.'), findsOneWidget);
    api.fail = false;
    await tester.tap(find.text('Keep mood private'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.saved!['mood'], '');
    expect(find.text('Set mood'), findsOneWidget);
  });

  test('Default characters are stable when partners switch viewers', () {
    final couple = fixtures.fixture().home!['couple'] as Map;
    expect(mascotFor(couple['user_1'] as Map, couple), 'male');
    expect(mascotFor(couple['user_2'] as Map, couple), 'female');
    couple['user_1']['mascot'] = 'female';
    expect(mascotFor(couple['user_1'] as Map, couple), 'female');
  });
}
