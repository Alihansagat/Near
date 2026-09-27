import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near/api.dart';
import 'package:near/app_state.dart';
import 'package:near/screens.dart';
import 'rituals_test.dart' as fixtures;

class CountdownApi extends Api {
  final event = <String, dynamic>{
    'id': 8,
    'title': 'Next meeting',
    'location': 'Almaty',
    'kind': 'meeting',
    'target_date': '2026-10-06'
  };
  bool deleted = false;
  bool fail = false;
  final calls = <String>[];
  @override
  Future<void> patch(String path, Map<String, dynamic> data) async {
    if (fail) throw StateError('Offline');
    calls.add('PATCH $path');
    event.addAll(data);
  }

  @override
  Future<void> delete(String path) async {
    if (fail) throw StateError('Offline');
    calls.add('DELETE $path');
    deleted = true;
  }
}

class CountdownState extends AppState {
  final CountdownApi fake;
  CountdownState(this.fake) : super(fake) {
    final fixture = fixtures.fixture();
    me = fixture.me;
    home = fixture.home;
    sync();
  }
  void sync() {
    countdowns = fake.deleted ? [] : [Map<String, dynamic>.from(fake.event)];
    home!['meeting'] =
        fake.deleted ? null : Map<String, dynamic>.from(fake.event);
  }

  @override
  Future<void> reload() async {
    sync();
    notifyListeners();
  }
}

void main() {
  testWidgets('Edit updates the existing countdown without creating another',
      (tester) async {
    final api = CountdownApi();
    final state = CountdownState(api);
    await tester.pumpWidget(fixtures.app(state, const CountdownsScreen()));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit countdown'), findsOneWidget);
    expect(find.text('Almaty'), findsWidgets);
    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Our holiday');
    await tester.enterText(
        find.widgetWithText(TextField, 'Place (optional)'), 'Paris');
    await tester.tap(find.widgetWithText(ChoiceChip, '✈ Our trip'));
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(api.calls, ['PATCH meetings/8/']);
    expect(api.event['title'], 'Our holiday');
    expect(api.event['location'], 'Paris');
    expect(api.event['kind'], 'trip');
    expect(state.countdowns.length, 1);
    expect(find.text('Our holiday'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Delete can be cancelled and confirmed deletion refreshes home',
      (tester) async {
    final api = CountdownApi();
    final state = CountdownState(api);
    await tester.pumpWidget(fixtures.app(state, const CountdownsScreen()));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(api.calls, ['DELETE meetings/8/']);
    expect(state.countdowns, isEmpty);
    expect(state.home!['meeting'], isNull);
    expect(find.text('Next meeting'), findsNothing);
  });

  testWidgets('Failed update keeps the form and saved event intact',
      (tester) async {
    final api = CountdownApi()..fail = true;
    await tester.pumpWidget(
        fixtures.app(CountdownState(api), const CountdownsScreen()));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'New title');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Edit countdown'), findsOneWidget);
    expect(
        find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(api.event['title'], 'Next meeting');
  });

  testWidgets('Past countdown date can be edited without a date picker error',
      (tester) async {
    final api = CountdownApi();
    api.event['target_date'] = '2025-01-16';
    await tester.pumpWidget(
        fixtures.app(CountdownState(api), const CountdownsScreen()));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(OutlinedButton, 'January 16, 2025'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'January 16, 2025'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
