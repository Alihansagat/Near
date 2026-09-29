import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near/api.dart';
import 'package:near/app_state.dart';
import 'package:near/distance.dart';
import 'package:near/location_sharing.dart';
import 'package:near/screens.dart';
import 'rituals_test.dart' as fixtures;

class FakeLocation implements LocationSharing {
  final SharedPosition? position;
  final Object? error;
  FakeLocation.position(double latitude, double longitude)
      : position = SharedPosition(latitude, longitude),
        error = null;
  FakeLocation.error(this.error) : position = null;
  @override
  Future<SharedPosition> currentPosition() async {
    if (error != null) throw error!;
    return position!;
  }
}

class LocationApi extends Api {
  Map<String, dynamic> me;
  Map<String, dynamic> home;
  Map<String, dynamic>? saved;
  LocationApi(this.me, this.home);
  @override
  Future<void> patch(String path, Map<String, dynamic> data) async {
    expect(path, 'me/');
    saved = data;
    me = {...me, ...data};
    final users = home['couple'] as Map;
    for (final key in ['user_1', 'user_2']) {
      if (users[key]['id'] == me['id']) users[key] = {...users[key], ...data};
    }
  }

  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (path == 'life/') return {'history': [], 'days': {'apart': 0, 'together': 0}};
    if (path == 'me/') return me;
    if (path == 'home/') return home;
    if (path == 'dates/' || path == 'meetings/' || path == 'moments/') {
      return {'results': <dynamic>[], 'count': 0, 'next': null};
    }
    throw StateError(path);
  }
}

void main() {
  test('Shared distance uses both coordinates and handles missing partner', () {
    expect(
        sharedDistanceKm({'latitude': 43.2389, 'longitude': 76.8897},
            {'latitude': 51.1694, 'longitude': 71.4491}),
        closeTo(972, 2));
    expect(sharedDistanceKm({'latitude': 43.2, 'longitude': 76.8}, {}), isNull);
  });

  testWidgets('Home shares current location and replaces saved distance',
      (tester) async {
    final fixture = fixtures.fixture();
    fixture.home!['couple']['user_2']
        .addAll({'latitude': 51.1694, 'longitude': 71.4491});
    final api = LocationApi(Map<String, dynamic>.from(fixture.me!),
        Map<String, dynamic>.from(fixture.home!));
    final state = AppState(api)
      ..me = fixture.me
      ..home = fixture.home
      ..locationSharing = FakeLocation.position(43.2389, 76.8897);
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(fixtures.app(state, const HomeScreen()));
    expect(find.text('3,870 km apart'), findsOneWidget);
    await tester.ensureVisible(find.text('Share my location'));
    await tester.tap(find.text('Share my location'));
    await tester.pumpAndSettle();
    expect(api.saved, {'latitude': 43.2389, 'longitude': 76.8897});
    expect(find.text('972 km apart'), findsOneWidget);
    expect(find.text('Calculated from your shared locations'), findsOneWidget);
    expect(find.text('Update my location'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Permission failure is explained without changing distance',
      (tester) async {
    final fixture = fixtures.fixture();
    final api = LocationApi(Map<String, dynamic>.from(fixture.me!),
        Map<String, dynamic>.from(fixture.home!));
    final state = AppState(api)
      ..me = fixture.me
      ..home = fixture.home
      ..locationSharing = FakeLocation.error(const LocationSharingException(
          'Location permission is needed to share your distance.'));
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(fixtures.app(state, const HomeScreen()));
    await tester.ensureVisible(find.text('Share my location'));
    await tester.tap(find.text('Share my location'));
    await tester.pumpAndSettle();
    expect(api.saved, isNull);
    expect(find.text('Location permission is needed to share your distance.'),
        findsWidgets);
    expect(find.text('3,870 km apart'), findsOneWidget);
  });
}
