import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:if_my_life_was_a_movie/pages/home_page.dart';
import 'package:if_my_life_was_a_movie/sketch.dart';
import 'package:if_my_life_was_a_movie/state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'NowPlaying uses vector Icons.play_arrow inline hint instead of Unicode ▶',
    (tester) async {
      const song = Song(
        'Midnight Train',
        'Test Artist',
        210,
        Hatch.diagonal,
        coverUrl: 'https://example.com/art.png',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: NowPlaying(song: song),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InlineIconNote), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNWidgets(2));
      expect(find.textContaining('▶'), findsNothing);
    },
  );
}
