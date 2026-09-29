import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near/api.dart';
import 'package:near/app_state.dart';
import 'package:near/distance.dart';
import 'package:near/relationship_screens.dart';
import 'rituals_test.dart' as fixtures;

class RelationshipApi extends Api {
  final requests = <String>[];
  final saved = <Map<String, dynamic>>[];
  bool offline = false;
  RelationshipApi() {
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options.path);
      final body = options.data as FormData;
      saved.add(Map.fromEntries(body.fields));
      handler.resolve(
          Response(requestOptions: options, statusCode: 201, data: {}));
    }));
  }
  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (offline) throw StateError('Offline');
    final rows = switch (path) {
      'envelopes/' => [
          {
            'id': 1,
            'creator': 2,
            'title': 'Open when you miss me',
            'text': 'I am always with you.',
            'attachments': []
          },
        ],
      'story/' => [
          {
            'id': 1,
            'date': '2025-01-16',
            'emoji': '❤️',
            'text': 'We met',
            'location': 'Almaty',
            'photo_url': null
          },
          {
            'id': 2,
            'date': '2025-02-02',
            'emoji': '📍',
            'text': 'First date',
            'location': 'Our favorite café',
            'photo_url': null
          },
        ],
      'places/' => [
          {
            'id': 1,
            'title': 'First date',
            'latitude': 43.24,
            'longitude': 76.89
          },
        ],
      'wishlist/' => [
          {'id': 1, 'title': 'See the northern lights', 'completed': false},
        ],
      'messages/' => [
          {
            'id': 1,
            'sender': 2,
            'text': '🫂',
            'created_at': '2026-09-24T12:00:00Z'
          },
        ],
      _ => <Map<String, dynamic>>[],
    };
    return {'results': rows, 'next': null};
  }

  @override
  Future<void> post(String path, [Map<String, dynamic>? data]) async {
    requests.add(path);
  }

  @override
  Future<void> patch(String path, Map<String, dynamic> data) async {
    requests.add(path);
    saved.add(data);
  }
}

AppState stateWith(RelationshipApi api) {
  final fixture = fixtures.fixture();
  return AppState(api)
    ..me = fixture.me
    ..home = fixture.home;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
  });
  test('Distance handles same location, known cities and antipodes', () {
    expect(distanceKm(43, 76, 43, 76), 0);
    expect(distanceKm(40.7128, -74.006, 34.0522, -118.2437), closeTo(3936, 5));
    expect(distanceKm(0, 0, 0, 180), closeTo(20015, 1));
  });

  testWidgets('Daily check-in, exact partner status and delivered hug',
      (tester) async {
    final api = RelationshipApi();
    final state = stateWith(api);
    state.home!['couple']['user_2']
        .addAll({'mood': 'missing', 'mood_day': '2026-09-24'});
    await tester.pumpWidget(fixtures.app(
        state, const SingleChildScrollView(child: RelationshipHub())));
    expect(find.text('How are you feeling today?'), findsOneWidget);
    expect(find.text('Dilnaz is feeling 🥹 Missing you'), findsOneWidget);
    await tester.tap(find.text('Send hug 🫂'));
    await tester.pumpAndSettle();
    expect(api.requests, contains('messages/hug/'));
    expect(find.text('Hug sent 🫂'), findsOneWidget);
    await tester.tap(find.text('Share your mood'));
    await tester.pumpAndSettle();
    for (final label in [
      '😊 Happy',
      '🥰 Loved',
      '😴 Tired',
      '🥹 Missing you',
      '😔 Sad',
      '😡 Angry'
    ]) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
    }
    expect(find.widgetWithText(ChoiceChip, 'Anxious'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Daily prompt returns the next day', (tester) async {
    final state = stateWith(RelationshipApi());
    state.me!['mood_day'] = '2026-09-24';
    await tester.pumpWidget(fixtures.app(
        state, const SingleChildScrollView(child: RelationshipHub())));
    expect(find.text('How are you feeling today?'), findsNothing);
    state.home!['day'] = '2026-09-25';
    await state.run(() async {});
    await tester.pump();
    expect(find.text('How are you feeling today?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('All new screens and forms fit a narrow phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final kind in featureTitles.keys) {
      await tester.pumpWidget(fixtures.app(stateWith(RelationshipApi()),
          RelationshipScreen(key: ValueKey(kind), kind: kind)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: kind);
      await tester.pumpWidget(fixtures.app(stateWith(RelationshipApi()),
          FeatureEditor(key: ValueKey('editor-$kind'), kind: kind)));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'editor-$kind');
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Envelope opens and custom envelope saves its text',
      (tester) async {
    final api = RelationshipApi();
    await tester.pumpWidget(fixtures.app(
        stateWith(api), const RelationshipScreen(kind: 'envelopes')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open when you miss me'));
    await tester.pumpAndSettle();
    expect(find.text('I am always with you.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create envelope'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Custom trigger title'),
        'Open when you need a smile');
    await tester.enterText(find.widgetWithText(TextFormField, 'Text message'),
        'You make my world brighter.');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.saved.single, {
      'title': 'Open when you need a smile',
      'text': 'You make my world brighter.'
    });
  });

  testWidgets('Wishlist updates persist and failed loads can retry',
      (tester) async {
    final api = RelationshipApi()..offline = true;
    await tester.pumpWidget(fixtures.app(
        stateWith(api), const RelationshipScreen(kind: 'wishlist')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Retry'), findsOneWidget);
    api.offline = false;
    await tester.tap(find.textContaining('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(api.requests, contains('wishlist/1/'));
    expect(api.saved.single, {'completed': true});
  });

  testWidgets('New feature visual previews', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final font = File('assets/fonts/Inter.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Inter')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await tester.runAsync(loader.load);
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);
    await tester.runAsync(() async {
      rootBundle.evict('assets/maps/land.json');
      await rootBundle.loadString('assets/maps/land.json');
    });
    for (final kind in ['story', 'places', 'envelopes', 'wishlist']) {
      final state = stateWith(RelationshipApi());
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: fixtures.app(
              state, RelationshipScreen(key: ValueKey(kind), kind: kind))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (kind == 'places') {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pumpAndSettle();
        expect(find.text('Loading map…'), findsNothing);
        expect(find.text('Map unavailable'), findsNothing);
      }
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('preview').createSync();
        File('preview/near-$kind.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
  });
}
