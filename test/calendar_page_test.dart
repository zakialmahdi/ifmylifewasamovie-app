import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Ink;
import 'package:flutter_test/flutter_test.dart';
import 'package:if_my_life_was_a_movie/pages/calendar_page.dart';
import 'package:if_my_life_was_a_movie/pages/friends_page.dart';
import 'package:if_my_life_was_a_movie/widgets/scene_editor.dart';
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
        (w) => w is HatchSwatch && w.circle && w.size == 34,
      );
      final cellSongCovers = find.byWidgetPredicate(
        (w) => w is SongArtBox && w.circle && w.size == 34,
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

  testWidgets('Shared calendar in FriendsPage renders SongArtBox instead of HatchSwatch', (tester) async {
    await HttpOverrides.runZoned(() async {
      app.enterDemoMode();
      addTearDown(() => app.demoMode = false);

      app.openFriendCalendar(app.friends.first.id);

      tester.view.physicalSize = const Size(360, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FriendsPage())));
      await tester.pumpAndSettle();

      final sharedSongCovers = find.byWidgetPredicate(
        (w) => w is SongArtBox && w.circle && w.size == 34,
      );
      final sharedFeelings = find.byWidgetPredicate(
        (w) => w is HatchSwatch && w.circle && w.size == 34,
      );

      expect(sharedSongCovers, findsWidgets);
      expect(sharedFeelings, findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('song album cover'),
        300,
      );
      expect(find.textContaining('song album cover'), findsOneWidget);

      // Tapping feeling switches shared calendar to friend's feeling patterns & legend
      final feelingToggle = find.widgetWithText(SketchChip, 'feeling');
      await tester.scrollUntilVisible(feelingToggle, 300);
      expect(feelingToggle, findsOneWidget);
      await tester.tap(feelingToggle);
      await tester.pumpAndSettle();

      final switchedSharedFeelings = find.byWidgetPredicate(
        (w) => w is HatchSwatch && w.circle && w.size == 34,
      );
      expect(switchedSharedFeelings, findsWidgets);

      // Verify friend's scene detail displays their feel badge
      expect(find.text('dreamy'), findsWidgets);
    }, createHttpClient: (_) => _StubHttpClient());
  });

  testWidgets('FriendsPage renders friend photo when avatarUrl is present', (tester) async {
    await HttpOverrides.runZoned(() async {
      app.enterDemoMode();
      addTearDown(() => app.demoMode = false);

      final friendWithPhoto = Friend(
        id: 'photo_friend',
        name: 'Amelie',
        handle: '@amelie',
        avatar: Hatch.cross,
        avatarUrl: 'https://example.com/avatar.jpg',
        entries: const <String, Entry>{},
      );
      app.friends.insert(0, friendWithPhoto);

      tester.view.physicalSize = const Size(360, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FriendsPage())));
      await tester.pumpAndSettle();

      final friendImage = find.descendant(
        of: find.byType(FriendsPage),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is NetworkImage &&
              (w.image as NetworkImage).url == 'https://example.com/avatar.jpg',
        ),
      );

      expect(friendImage, findsWidgets);
    }, createHttpClient: (_) => _StubHttpClient());
  });

  testWidgets('Cheer button is removed from friend mood card and works on friends scene detail', (tester) async {
    await HttpOverrides.runZoned(() async {
      app.enterDemoMode();
      addTearDown(() => app.demoMode = false);

      tester.view.physicalSize = const Size(360, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FriendsPage())));
      await tester.pumpAndSettle();

      // Jules is the first friend in demo mode.
      final jules = app.friends.firstWhere((f) => f.id == 'jules');

      // 1. Verify cheer is NOT in the mood card when friend calendar is not open
      // (Jules starts with calendar closed if activeFriendId is different or reset)
      // Even with active friend, _FriendMoodCard should NOT have any cheer buttons.
      final moodSection = find.text("TODAY'S MOODS");
      expect(moodSection, findsOneWidget);

      // Verify no cheer buttons exist inside the mood cards:
      // In _SharedSceneDetail, the cheer button exists, but inside _FriendMoodCard it is gone.
      // We can open the calendar for Jules:
      app.openFriendCalendar('jules');
      await tester.pumpAndSettle();

      // Find the cheer button on Jules's scene detail for today:
      final initialCount = app.sceneCheerCount(jules, app.today);
      expect(app.isSceneCheered(jules, app.today), isFalse);

      final cheerBtnFinder = find.widgetWithText(SketchTap, 'cheer · $initialCount');
      await tester.scrollUntilVisible(cheerBtnFinder, 300);
      expect(cheerBtnFinder, findsOneWidget);

      // Verify the heart icon is outline
      expect(find.byIcon(Icons.favorite_border), findsWidgets);

      // 2. Tap cheer on Jules's scene:
      await tester.tap(cheerBtnFinder);
      await tester.pumpAndSettle();

      // Should now be cheered with incremented count
      expect(app.isSceneCheered(jules, app.today), isTrue);
      expect(app.sceneCheerCount(jules, app.today), initialCount + 1);
      final cheeredBtnFinder = find.widgetWithText(SketchTap, 'cheered · ${initialCount + 1}');
      expect(cheeredBtnFinder, findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsWidgets);

      // 3. Tap again to uncheer:
      await tester.tap(cheeredBtnFinder);
      await tester.pumpAndSettle();

      expect(app.isSceneCheered(jules, app.today), isFalse);
      expect(app.sceneCheerCount(jules, app.today), initialCount);
      expect(find.widgetWithText(SketchTap, 'cheer · $initialCount'), findsOneWidget);

      // 4. Test another scene date (e.g. yesterday - 1 day ago):
      final yesterday = DateTime(app.today.year, app.today.month, app.today.day - 1);
      if (jules.entryFor(yesterday) != null) {
        app.selectFriendDate(yesterday);
        await tester.pumpAndSettle();

        final yesterdayInitial = app.sceneCheerCount(jules, yesterday);
        final yesterdayCheerFinder = find.widgetWithText(SketchTap, 'cheer · $yesterdayInitial');
        await tester.scrollUntilVisible(yesterdayCheerFinder, 300);
        expect(yesterdayCheerFinder, findsOneWidget);

        await tester.tap(yesterdayCheerFinder);
        await tester.pumpAndSettle();

        expect(app.isSceneCheered(jules, yesterday), isTrue);
        expect(app.sceneCheerCount(jules, yesterday), yesterdayInitial + 1);
        expect(find.widgetWithText(SketchTap, 'cheered · ${yesterdayInitial + 1}'), findsOneWidget);
      }
    }, createHttpClient: (_) => _StubHttpClient());
  });

  test('AppState legacySafeHatch maps newer hatches to diagonal and preserves legacy hatches', () {
    const legacy = {'solid', 'diagonal', 'cross', 'lines', 'dots'};
    for (final h in Hatch.values) {
      final mapped = AppState.legacySafeHatch(h.name);
      if (legacy.contains(h.name)) {
        expect(mapped, h.name);
      } else {
        expect(mapped, 'diagonal');
      }
    }
  });

  test('AppState saveSceneForDate and saveToday persist entries locally and support dbId', () {
    app.enterDemoMode();
    addTearDown(() => app.demoMode = false);

    final targetDate = DateTime(2026, 11, 20);
    const testSong = Song('Test Title', 'Test Artist', 210, Hatch.waves);
    const testMood = Mood('ecstatic', Hatch.zigzag);

    app.saveSceneForDate(
      targetDate,
      song: testSong,
      mood: testMood,
      note: 'testing scene persistence',
    );

    final saved = app.entryFor(targetDate);
    expect(saved, isNotNull);
    expect(saved!.song.title, 'Test Title');
    expect(saved.mood.name, 'ecstatic');
    expect(saved.note, 'testing scene persistence');
    expect(saved.dbId, isNull);

    // Verify copyWith works with dbId
    final withDbId = saved.copyWith(dbId: 101);
    expect(withDbId.dbId, 101);
    expect(withDbId.song.title, 'Test Title');
    expect(withDbId.mood.name, 'ecstatic');
    expect(withDbId.note, 'testing scene persistence');

    // Update the same scene date
    app.saveSceneForDate(
      targetDate,
      song: testSong,
      mood: testMood,
      note: 'updated scene note',
    );
    final updated = app.entryFor(targetDate);
    expect(updated!.note, 'updated scene note');

    // Verify saveToday updates draft state and today entry
    app.draftSong = testSong;
    app.draftMood = testMood;
    app.noteCtl.text = 'today was cinematic';
    app.saveToday();

    final todayEntry = app.entryFor(app.today);
    expect(todayEntry, isNotNull);
    expect(todayEntry!.song.title, 'Test Title');
    expect(todayEntry.mood.name, 'ecstatic');
    expect(todayEntry.note, 'today was cinematic');
  });

  test('Friend.moods correctly extracts unique feelings without touching app.moods', () {
    app.enterDemoMode();
    addTearDown(() => app.demoMode = false);

    final initialUserMoodCount = app.moods.length;

    final friend = Friend(
      id: 'friend_test',
      name: 'Sam',
      handle: '@sam',
      avatar: Hatch.waves,
      entries: <String, Entry>{
        '2026-11-01': Entry(
          date: DateTime(2026, 11, 1),
          song: catalog.first,
          mood: const Mood('cosmic', Hatch.rings),
          note: 'friend feel 1',
          scene: 1,
        ),
        '2026-11-02': Entry(
          date: DateTime(2026, 11, 2),
          song: catalog[1],
          mood: const Mood('cosmic', Hatch.rings), // duplicate feeling
          note: 'friend feel duplicate',
          scene: 2,
        ),
        '2026-11-03': Entry(
          date: DateTime(2026, 11, 3),
          song: catalog[2],
          mood: const Mood('serene', Hatch.checker),
          note: 'friend feel 2',
          scene: 3,
        ),
      },
    );

    // Friend moods list has exactly the 2 unique moods
    expect(friend.moods.length, 2);
    expect(friend.moods.map((m) => m.name), containsAll(['cosmic', 'serene']));
    expect(friend.moods.firstWhere((m) => m.name == 'cosmic').hatch, Hatch.rings);
    expect(friend.moods.firstWhere((m) => m.name == 'serene').hatch, Hatch.checker);

    // Current user's own mood list was not mutated by friend feelings
    expect(app.moods.length, initialUserMoodCount);
    expect(app.moods.any((m) => m.name == 'cosmic'), isFalse);
    expect(app.moods.any((m) => m.name == 'serene'), isFalse);
  });

  testWidgets('Updating a scene from CalendarPage allows adding a new feel with pattern selection', (tester) async {
    await HttpOverrides.runZoned(() async {
      app.enterDemoMode();
      addTearDown(() => app.demoMode = false);

      final targetDate = DateTime(2026, 11, 10);
      final initialEntry = Entry(
        date: targetDate,
        song: catalog.first,
        mood: hopeful,
        note: 'journal scene to update',
        scene: 1,
      );

      tester.view.physicalSize = const Size(360, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => openSceneEditor(ctx, targetDate, initialEntry: initialEntry),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Inside SceneEditorSheet, find '+ add' feeling button
      final addFeelChip = find.widgetWithText(SketchChip, '+ add');
      expect(addFeelChip, findsOneWidget);
      await tester.ensureVisible(addFeelChip);
      await tester.pumpAndSettle();
      await tester.tap(addFeelChip);
      await tester.pumpAndSettle();

      // Verify the dialog contains 'ADD A FEELING' and 'calendar pattern swatch'
      expect(find.text('ADD A FEELING'), findsOneWidget);
      expect(find.text('calendar pattern swatch'), findsOneWidget);

      // Select a specific hatch pattern (e.g., vertical)
      final verticalSwatchFinder = find.byWidgetPredicate(
        (w) => w is HatchSwatch && w.hatch == Hatch.vertical && w.circle,
      );
      expect(verticalSwatchFinder, findsOneWidget);
      await tester.tap(verticalSwatchFinder);
      await tester.pumpAndSettle();

      // Enter the new feeling name
      await tester.enterText(find.byType(TextField).last, 'whimsical');
      await tester.pumpAndSettle();

      // Tap 'ADD' in the dialog
      final addBtnFinder = find.widgetWithText(SketchTextButton, 'ADD');
      await tester.tap(addBtnFinder);
      await tester.pumpAndSettle();

      // Verify 'whimsical' is now present in the mood choices with Hatch.vertical
      final whimsicalMood = app.moods.where((m) => m.name == 'whimsical').firstOrNull;
      expect(whimsicalMood, isNotNull);
      expect(whimsicalMood!.hatch, Hatch.vertical);
    }, createHttpClient: (_) => _StubHttpClient());
  });
}
