import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:if_my_life_was_a_movie/pages/intro_page.dart';
import 'package:if_my_life_was_a_movie/state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('IntroPage navigates through carousel, shows YouTube setup and skip consequence', (tester) async {
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

    // Slide 1
    expect(find.text('YOUR LIFE IS A MOVIE'), findsOneWidget);
    expect(find.text('ACT I · THE CONCEPT'), findsOneWidget);

    // Tap NEXT -> Slide 2
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('SCORE EVERY SCENE'), findsOneWidget);
    expect(find.text('ACT II · THE SOUNDTRACK'), findsOneWidget);

    // Tap NEXT -> Slide 3
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('THE CAST & TIMELINE'), findsOneWidget);
    expect(find.text('ACT III · THE CAST & REEL'), findsOneWidget);

    // Tap NEXT -> Slide 4 (YouTube Setup & Skip consequence)
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('SEAMLESS PLAYBACK'), findsOneWidget);
    expect(find.text('CONNECT YOUTUBE ACCOUNT'), findsWidgets);
    expect(find.text('CAN I SKIP THIS STEP?'), findsOneWidget);
    expect(find.text('Consequence if you skip:'), findsOneWidget);
    expect(find.text('SKIP FOR NOW & ENTER APP'), findsOneWidget);

    // Tap Skip -> should mark intro seen and navigate to Home
    await tester.ensureVisible(find.text('SKIP FOR NOW & ENTER APP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SKIP FOR NOW & ENTER APP'));
    await tester.pumpAndSettle();

    expect(app.hasSeenIntro, isTrue);
    expect(find.text('HOME SCREEN'), findsOneWidget);
  });
}
