import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:if_my_life_was_a_movie/pages/intro_page.dart';
import 'package:if_my_life_was_a_movie/state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('IntroPage navigates through streamlined slides, supports back arrow, shows YouTube setup & skip consequence', (tester) async {
    app.demoMode = false;
    app.hasSeenIntro = false;

    final router = GoRouter(
      initialLocation: '/intro',
      routes: [
        GoRoute(
          path: '/intro',
          builder: (context, state) => const IntroPage(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('HOME SCREEN')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // Slide 1: One song a day
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('ONE SONG A DAY'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    // Tap NEXT -> Slide 2: Mood & One Line
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('TAG & SCRIBBLE'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    // Test BACK arrow returns to Slide 1
    await tester.tap(find.text('BACK'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('ONE SONG A DAY'), findsOneWidget);

    // Forward to Slide 2 -> Slide 3 -> Slide 4
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 4'), findsOneWidget);
    expect(find.text('CALENDAR & CO-STARS'), findsOneWidget);

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('4 / 4'), findsOneWidget);
    expect(find.text('SEAMLESS MUSIC'), findsOneWidget);
    expect(find.text('CONNECT YOUTUBE'), findsOneWidget);
    expect(find.text('SKIP FOR NOW'), findsOneWidget);
    expect(find.textContaining('if you skip:'), findsOneWidget);

    // Tap SKIP FOR NOW -> marks intro seen & enters Home
    await tester.ensureVisible(find.text('SKIP FOR NOW'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SKIP FOR NOW'));
    await tester.pumpAndSettle();

    expect(app.hasSeenIntro, isTrue);
    expect(find.text('HOME SCREEN'), findsOneWidget);
  });
}
