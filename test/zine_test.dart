import 'package:flutter/material.dart' hide Ink;
import 'package:flutter_test/flutter_test.dart';
import 'package:if_my_life_was_a_movie/state.dart';
import 'package:if_my_life_was_a_movie/widgets/zine_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testScenes = [
    Entry(
      date: DateTime(2026, 10, 1),
      song: Song('Midnight City', 'M83', 244, Hatch.diagonal),
      mood: dreamy,
      note: 'missed my stop because the synth solo hit.',
      scene: 1,
    ),
    Entry(
      date: DateTime(2026, 10, 2),
      song: Song('Motion Sickness', 'Phoebe Bridgers', 230, Hatch.cross),
      mood: restless,
      note: 'walking in the cold listening on repeat.',
      scene: 2,
    ),
  ];

  testWidgets('ZineSheet renders 9:16 Story format with album art and credits', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ZineSheet(
              format: ZineFormat.story9x16,
              scenes: testScenes,
              directorName: 'maya',
              handle: '@maya_film',
              inviteCode: 'MAYA-99',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Director
    expect(find.text('IF MY LIFE WAS A MOVIE...'), findsWidgets);
    expect(find.textContaining('DIRECTOR: MAYA'), findsWidgets);
    expect(find.textContaining('MAYA-99'), findsWidgets);

    // Verify Scene Panels & Song Titles
    expect(find.text('MIDNIGHT CITY'), findsOneWidget);
    expect(find.text('MOTION SICKNESS'), findsOneWidget);

    // Verify Album Art component is rendered
    expect(find.byType(ZineAlbumArt), findsNWidgets(2));

    // Verify Credits & Lone Developer attribution
    expect(find.textContaining('ADMIT ONE'), findsOneWidget);
    expect(find.textContaining('ZAKIALMAHDI'), findsOneWidget);
  });

  testWidgets('ZineSheet renders 4:5 Feed format with billing block', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ZineSheet(
              format: ZineFormat.feed4x5,
              scenes: testScenes,
              directorName: 'maya',
              handle: '@maya_film',
              inviteCode: 'MAYA-99',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('IF MY LIFE WAS A MOVIE...'), findsWidgets);
    expect(find.textContaining('DIRECTED BY: MAYA'), findsWidgets);
    expect(find.text('MIDNIGHT CITY'), findsOneWidget);
    expect(find.text('MOTION SICKNESS'), findsOneWidget);
    expect(find.textContaining('LONE DEVELOPER: ZAKIALMAHDI'), findsOneWidget);
  });

  testWidgets('ZineSheet renders Printable Foldable Sheet with fold guides', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ZineSheet(
              format: ZineFormat.foldableLandscape,
              scenes: testScenes,
              directorName: 'maya',
              handle: '@maya_film',
              inviteCode: 'MAYA-99',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('IF MY LIFE WAS A MOVIE...'), findsWidgets);
    expect(find.text('ROLL CREDITS'), findsOneWidget);
    expect(find.text('zakialmahdi'), findsOneWidget);
    expect(find.textContaining('ZAKIALMAHDI (LONE DEVELOPER)'), findsOneWidget);
    expect(find.textContaining('FOLD GUIDE'), findsOneWidget);
  });
}
