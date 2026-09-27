import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near/api.dart';
import 'package:near/app_state.dart';
import 'package:near/screens.dart';
import 'rituals_test.dart' as fixtures;

class CategoryApi extends Api {
  final Map<String, dynamic> data;
  final List<String> selected = [];
  bool fail = false;
  CategoryApi(this.data);
  @override
  Future<void> post(String path, [Map<String, dynamic>? body]) async {
    expect(path, 'daily/question/category/');
    if (fail) throw StateError('offline');
    final category = body!['category'] as String;
    selected.add(category);
    data['question'] = {
      'id': 7,
      'category': category,
      'question_text': 'A $category question'
    };
  }

  @override
  Future<Map<String, dynamic>> get(String path) async {
    expect(path, 'home/');
    return Map<String, dynamic>.from(data);
  }
}

void main() {
  testWidgets('Each category changes the question and selected chip',
      (tester) async {
    final fixture = fixtures.fixture();
    fixture.home!['answers'] = [];
    fixture.home!['answers_revealed'] = false;
    final api = CategoryApi(Map<String, dynamic>.from(fixture.home!));
    final state = AppState(api)
      ..me = fixture.me
      ..home = fixture.home;
    await tester.pumpWidget(fixtures.app(state, const QuestionsScreen()));
    for (final label in ['Deep', 'Fun', 'Random', 'Future']) {
      await tester.tap(find.widgetWithText(ChoiceChip, label));
      await tester.pumpAndSettle();
      expect(find.text('A ${label.toLowerCase()} question'), findsOneWidget);
      expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
              .selected,
          isTrue);
    }
    expect(api.selected, ['deep', 'fun', 'random', 'future']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Answered question explains why its category cannot change',
      (tester) async {
    final fixture = fixtures.fixture();
    final api = CategoryApi(Map<String, dynamic>.from(fixture.home!));
    final state = AppState(api)
      ..me = fixture.me
      ..home = fixture.home;
    await tester.pumpWidget(fixtures.app(state, const QuestionsScreen()));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Deep'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'A partner has already answered. Choose a new category tomorrow.'),
        findsOneWidget);
    expect(api.selected, isEmpty);
  });

  testWidgets('Failed switch keeps current question and reports error',
      (tester) async {
    final fixture = fixtures.fixture();
    fixture.home!['answers'] = [];
    final api = CategoryApi(Map<String, dynamic>.from(fixture.home!))
      ..fail = true;
    final state = AppState(api)
      ..me = fixture.me
      ..home = fixture.home;
    await tester.pumpWidget(fixtures.app(state, const QuestionsScreen()));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Deep'));
    await tester.pumpAndSettle();
    expect(state.home!['question']['category'], 'future');
    expect(
        find.text('Something went wrong. Please try again.'), findsOneWidget);
  });
}
