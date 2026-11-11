import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:if_my_life_was_a_movie/router.dart';
import 'package:if_my_life_was_a_movie/state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeBuildContext extends Fake implements BuildContext {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fakeContext = _FakeBuildContext();

  test('Unauthenticated user is redirected to /auth', () {
    app.user = null;
    app.demoMode = false;
    app.isRecoveringPassword = false;

    expect(app.isAuthenticated, isFalse);

    final state = GoRouterState(
      appRouter.configuration,
      uri: Uri.parse('/calendar'),
      matchedLocation: '/calendar',
      fullPath: '/calendar',
      pathParameters: const <String, String>{},
      pageKey: const ValueKey('calendar'),
    );

    final redirectResult = authRedirect(fakeContext, state);
    expect(redirectResult, equals('/auth?from=%2Fcalendar'));
  });

  test('Password recovery event redirects to /reset-password', () {
    app.isRecoveringPassword = true;

    final state = GoRouterState(
      appRouter.configuration,
      uri: Uri.parse('/auth'),
      matchedLocation: '/auth',
      fullPath: '/auth',
      pathParameters: const <String, String>{},
      pageKey: const ValueKey('auth'),
    );

    final redirectResult = authRedirect(fakeContext, state);
    expect(redirectResult, equals('/reset-password'));
  });

  test('Authenticated user on /auth is redirected to /', () {
    app.isRecoveringPassword = false;
    app.demoMode = true; // Simulates authenticated mode
    expect(app.isAuthenticated, isTrue);

    final state = GoRouterState(
      appRouter.configuration,
      uri: Uri.parse('/auth'),
      matchedLocation: '/auth',
      fullPath: '/auth',
      pathParameters: const <String, String>{},
      pageKey: const ValueKey('auth'),
    );

    final redirectResult = authRedirect(fakeContext, state);
    expect(redirectResult, equals('/'));
  });

  test('Authenticated user on /auth with target is redirected to original destination', () {
    app.isRecoveringPassword = false;
    app.demoMode = true;
    expect(app.isAuthenticated, isTrue);

    final state = GoRouterState(
      appRouter.configuration,
      uri: Uri.parse('/auth?from=%2Fcalendar'),
      matchedLocation: '/auth',
      fullPath: '/auth',
      pathParameters: const <String, String>{},
      pageKey: const ValueKey('auth'),
    );

    final redirectResult = authRedirect(fakeContext, state);
    expect(redirectResult, equals('/calendar'));
  });

  test('Authenticated user with percent character in from does not crash and safely redirects', () {
    app.isRecoveringPassword = false;
    app.demoMode = true;

    final state = GoRouterState(
      appRouter.configuration,
      uri: Uri.parse('/auth?from=%2Fcalendar%3Ftag%3D100%25'),
      matchedLocation: '/auth',
      fullPath: '/auth',
      pathParameters: const <String, String>{},
      pageKey: const ValueKey('auth'),
    );

    final redirectResult = authRedirect(fakeContext, state);
    expect(redirectResult, equals('/calendar?tag=100%'));
  });

  test('Open redirect attempts to external or protocol-relative URLs fall back safely to /', () {
    app.isRecoveringPassword = false;
    app.demoMode = true;

    final externalState = GoRouterState(
      appRouter.configuration,
      uri: Uri.parse('/auth?from=https%3A%2F%2Fevil.com'),
      matchedLocation: '/auth',
      fullPath: '/auth',
      pathParameters: const <String, String>{},
      pageKey: const ValueKey('auth'),
    );
    expect(authRedirect(fakeContext, externalState), equals('/'));

    final protocolRelativeState = GoRouterState(
      appRouter.configuration,
      uri: Uri.parse('/auth?from=%2F%2Fevil.com'),
      matchedLocation: '/auth',
      fullPath: '/auth',
      pathParameters: const <String, String>{},
      pageKey: const ValueKey('auth'),
    );
    expect(authRedirect(fakeContext, protocolRelativeState), equals('/'));
  });

  test('Demo mode account deletion clears state and resets to unauthenticated', () async {
    app.enterDemoMode();
    expect(app.isAuthenticated, isTrue);
    expect(app.demoMode, isTrue);

    await app.deleteAccount();

    expect(app.isAuthenticated, isFalse);
    expect(app.demoMode, isFalse);
    expect(app.user, isNull);
  });

  test('Authenticated user who has not seen intro is redirected to /intro before /', () {
    app.isRecoveringPassword = false;
    app.demoMode = false;
    app.user = const User(
      id: 'test-user-id',
      appMetadata: <String, dynamic>{},
      userMetadata: <String, dynamic>{},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    );
    app.hasSeenIntro = false;
    expect(app.isAuthenticated, isTrue);
    expect(app.hasSeenIntro, isFalse);

    final homeState = GoRouterState(
      appRouter.configuration,
      uri: Uri.parse('/'),
      matchedLocation: '/',
      fullPath: '/',
      pathParameters: const <String, String>{},
      pageKey: const ValueKey('home'),
    );
    expect(authRedirect(fakeContext, homeState), equals('/intro'));
    app.user = null;
  });

  test('Authenticated user who has completed intro accesses / directly', () {
    app.isRecoveringPassword = false;
    app.enterDemoMode();
    app.hasSeenIntro = true;
    expect(app.isAuthenticated, isTrue);
    expect(app.hasSeenIntro, isTrue);

    final homeState = GoRouterState(
      appRouter.configuration,
      uri: Uri.parse('/'),
      matchedLocation: '/',
      fullPath: '/',
      pathParameters: const <String, String>{},
      pageKey: const ValueKey('home'),
    );
    expect(authRedirect(fakeContext, homeState), isNull);
  });

  test('Intro replay is allowed for authenticated user', () {
    app.isRecoveringPassword = false;
    app.enterDemoMode();
    app.hasSeenIntro = true;

    final introState = GoRouterState(
      appRouter.configuration,
      uri: Uri.parse('/intro?replay=true'),
      matchedLocation: '/intro',
      fullPath: '/intro',
      pathParameters: const <String, String>{},
      pageKey: const ValueKey('intro'),
    );
    expect(authRedirect(fakeContext, introState), isNull);
  });

  test('Existing non-demo user accesses / directly without seeing intro', () {
    app.isRecoveringPassword = false;
    app.demoMode = false;
    app.user = const User(
      id: 'returning-user-id',
      appMetadata: <String, dynamic>{},
      userMetadata: <String, dynamic>{},
      aud: 'authenticated',
      createdAt: '2025-01-01T00:00:00Z',
      lastSignInAt: '2026-11-11T00:00:00Z',
    );
    app.hasSeenIntro = true;

    final homeState = GoRouterState(
      appRouter.configuration,
      uri: Uri.parse('/'),
      matchedLocation: '/',
      fullPath: '/',
      pathParameters: const <String, String>{},
      pageKey: const ValueKey('home'),
    );
    expect(authRedirect(fakeContext, homeState), isNull);
    app.user = null;
  });
}
