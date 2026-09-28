import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:near/api.dart';
import 'package:near/app_state.dart';
import 'package:near/screens.dart';
import 'package:near/theme.dart';

AppState fixture() => AppState(Api())
  ..starting = false
  ..me = {'id': 1, 'full_name': 'Alikhan', 'couple': 1}
  ..home = {
    'day': '2026-09-24',
    'days_together': 128,
    'days_apart': 42,
    'days_until_meeting': 12,
    'meeting': {
      'title': 'Finally, you & me',
      'location': 'Almaty',
      'target_date': '2026-10-06'
    },
    'couple': {
      'user_1': {'id': 1, 'full_name': 'Alikhan'},
      'user_2': {'id': 2, 'full_name': 'Dilnaz'},
      'distance_km': 3870
    },
    'photo_prompt': 'Show me your morning.',
    'photos': [],
    'photos_revealed': false,
    'question': {
      'question_text': 'What do you want us to do together?',
      'category': 'future'
    },
    'answers': [
      {'user': 1, 'answer_text': 'Watch the northern lights'},
      {'user': 2, 'answer_text': 'A road trip with you'}
    ],
    'answers_revealed': true,
  };
Widget app(AppState state, Widget child) => ChangeNotifierProvider.value(
    value: state,
    child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: nearTheme(),
        home: Scaffold(body: child)));
void main() {
  testWidgets('Both answers remain hidden until Reveal is tapped',
      (tester) async {
    final state = fixture();
    await tester
        .pumpWidget(app(state, QuestionCard(data: state.home!, today: true)));
    expect(find.textContaining('northern lights'), findsNothing);
    expect(find.textContaining('road trip'), findsNothing);
    await tester.tap(find.text('Reveal our answers'));
    await tester.pump();
    expect(find.textContaining('northern lights'), findsOneWidget);
    expect(find.textContaining('road trip'), findsOneWidget);
  });
  testWidgets('Waiting answers do not have a Reveal button', (tester) async {
    final state = fixture();
    state.home!['answers_revealed'] = false;
    state.home!['answers'] = [
      {'user': 1, 'answer_text': 'Saved answer'}
    ];
    await tester
        .pumpWidget(app(state, QuestionCard(data: state.home!, today: true)));
    expect(find.text('Reveal our answers'), findsNothing);
    expect(find.textContaining('Waiting for your person'), findsOneWidget);
  });
  testWidgets('All five sections work at narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(fixture(), const MainShell()));
    for (final label in [
      'Daily Photo',
      'Dates',
      'Countdown',
      'Questions',
      'Home'
    ]) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Home design preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final font = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await tester.runAsync(() => loader.load());
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(() => icons.load());
    final key = GlobalKey();
    await tester.pumpWidget(
        RepaintBoundary(key: key, child: app(fixture(), const MainShell())));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/mascots/hearts-moods.png'),
        key.currentContext!));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('preview').createSync();
      File('preview/near-home.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  });
}
