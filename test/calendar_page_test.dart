import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Ink;
import 'package:flutter_test/flutter_test.dart';
import 'package:if_my_life_was_a_movie/pages/calendar_page.dart';
import 'package:if_my_life_was_a_movie/sketch.dart';
import 'package:if_my_life_was_a_movie/state.dart';

const _kTransparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

class _StubHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _StubHttpRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _StubHttpRequest(url);

  @override
  void close({bool force = false}) {}
}

class _StubHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}
}

class _StubHttpRequest extends Fake implements HttpClientRequest {
  _StubHttpRequest(this.url);

  final Uri url;

  @override
  final HttpHeaders headers = _StubHttpHeaders();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async {
    final isMetadataApi =
        url.host.contains('itunes') || url.host.contains('deezer');
    final bytes = isMetadataApi
        ? utf8.encode('{"resultCount":0,"results":[]}')
        : _kTransparentPng;
    return _StubHttpResponse(bytes);
  }
}

class _StubHttpResponse extends Fake implements HttpClientResponse {
  _StubHttpResponse(this._bytes);

  final List<int> _bytes;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => _StubHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CalendarPage switches day circles between feeling and song album cover', (tester) async {
    await HttpOverrides.runZoned(() async {
      app.enterDemoMode();
      addTearDown(() => app.demoMode = false);
      // Ensure the visible month has at least one seeded entry (e.g. if today is the 1st).
      final hasVisibleEntry = app.allScenes.any(
        (e) =>
            e.date.year == app.viewMonth.year &&
            e.date.month == app.viewMonth.month,
      );
      if (!hasVisibleEntry) {
        app.shiftMonth(-1);
      }

      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CalendarPage())));
      await tester.pumpAndSettle();

      final cellFeelings = find.byWidgetPredicate(
        (w) => w is HatchSwatch && w.circle && w.size == 26,
      );
      final cellSongCovers = find.byWidgetPredicate(
        (w) => w is SongArtBox && w.circle && w.size == 26,
      );

      expect(find.text('MY SOUNDTRACK'), findsOneWidget);
      expect(find.text('view:'), findsOneWidget);
      expect(find.text('feeling'), findsOneWidget);
      expect(find.text('song'), findsOneWidget);
      expect(cellFeelings, findsWidgets);
      expect(cellSongCovers, findsNothing);

      await tester.tap(find.text('song'));
      await tester.pumpAndSettle();

      expect(cellSongCovers, findsWidgets);
      expect(cellFeelings, findsNothing);
      expect(find.text('each circle shows that day’s song album cover'), findsOneWidget);

      await tester.tap(find.text('feeling'));
      await tester.pumpAndSettle();

      expect(cellFeelings, findsWidgets);
      expect(cellSongCovers, findsNothing);
    }, createHttpClient: (_) => _StubHttpClient());
  });

  testWidgets('SongArtBox with circle true clips network album art into a circle', (tester) async {
    await HttpOverrides.runZoned(() async {
      const song = Song(
        'midnight city',
        'm83',
        243,
        Hatch.diagonal,
        coverUrl: 'https://example.com/album.jpg',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SongArtBox(song: song, size: 26, circle: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(SongArtBox),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);

      expect(
        find.descendant(
          of: find.byType(SongArtBox),
          matching: find.byType(ClipOval),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ClipOval),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
    }, createHttpClient: (_) => _StubHttpClient());
  });
}
