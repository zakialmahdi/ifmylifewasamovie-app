import 'package:flutter/material.dart' hide Ink;
import 'package:go_router/go_router.dart';

import 'pages/auth_page.dart';
import 'pages/calendar_page.dart';
import 'pages/friends_page.dart';
import 'pages/home_page.dart';
import 'pages/intro_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/settings_page.dart';
import 'sketch.dart';
import 'state.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

String? authRedirect(BuildContext context, GoRouterState state) {
  final authed = app.isAuthenticated;
  final location = state.matchedLocation;
  final isAuthRoute = location == '/auth';
  final isResetRoute = location == '/reset-password';
  final isIntroRoute = location == '/intro';

  // 1. Password recovery takes precedence
  if (app.isRecoveringPassword && !isResetRoute) {
    return '/reset-password';
  }

  // 2. Unauthenticated user protection:
  // Any route other than /auth, /reset-password, and /intro requires authentication.
  if (!authed) {
    if (!isAuthRoute && !isResetRoute && !isIntroRoute) {
      final target = state.uri.toString();
      if (target == '/' || target.isEmpty) {
        return '/auth';
      }
      return '/auth?from=${Uri.encodeComponent(target)}';
    }
    return null;
  }

  // 3. Authenticated user who hasn't completed onboarding/intro:
  // Show intro carousel before access to the home screen.
  if (!app.hasSeenIntro) {
    if (isAuthRoute || isResetRoute || location == '/') {
      return '/intro';
    }
  }

  // 4. Authenticated user visiting /auth or /reset-password (when not in recovery flow):
  // Redirect to requested original destination or default home (/).
  if (isAuthRoute) {
    final from = state.uri.queryParameters['from'];
    if (from != null && from.isNotEmpty && from != '/auth') {
      try {
        final decoded = Uri.decodeComponent(from);
        if (decoded.startsWith('/') && !decoded.startsWith('//')) {
          return decoded;
        }
      } catch (_) {
        if (from.startsWith('/') && !from.startsWith('//')) {
          return from;
        }
      }
    }
    return '/';
  }

  if (isResetRoute && !app.isRecoveringPassword) {
    return '/';
  }

  return null;
}

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: app,
  redirect: authRedirect,
  routes: <RouteBase>[
    // Unprotected authentication route
    GoRoute(
      path: '/auth',
      builder: (context, state) => const PaperScaffold(
        child: AuthPage(),
      ),
    ),

    // Password reset recovery route
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const PaperScaffold(
        child: ResetPasswordPage(),
      ),
    ),

    // Onboarding / Story carousel walkthrough
    GoRoute(
      path: '/intro',
      builder: (context, state) {
        final replay = state.uri.queryParameters['replay'] == 'true';
        return PaperScaffold(
          child: IntroPage(isReplay: replay),
        );
      },
    ),

    // Protected application shell with bottom SketchNav
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: <StatefulShellBranch>[
        // Branch 0: Today / Home
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),

        // Branch 1: Calendar
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const CalendarPage(),
            ),
          ],
        ),

        // Branch 2: Friends
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/friends',
              builder: (context, state) => const FriendsPage(),
            ),
          ],
        ),

        // Branch 3: Settings
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsPage(),
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => PaperScaffold(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SCENE NOT FOUND', style: T.head(24)),
            const SizedBox(height: 8),
            Text(
              'looks like this reel went missing in the editing room.',
              style: T.body(14, c: Ink.soft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SketchButton(
              primary: true,
              onTap: () => context.go('/'),
              child: Text('back to set →', style: T.body(15, c: Ink.paper)),
            ),
          ],
        ),
      ),
    ),
  ),
);

/// Reusable paper-textured container for screens outside or inside the main shell.
class PaperScaffold extends StatelessWidget {
  final Widget child;

  const PaperScaffold({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  isComplex: true,
                  painter: PaperPainter(app.paper),
                ),
              ),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              resizeToAvoidBottomInset: true,
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The main application shell hosting the 4 tab branches and the sketch navigation bar.
class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late String _paper = app.paper;

  @override
  void initState() {
    super.initState();
    app.addListener(_onAppChanged);
    // If the app requested a specific tab before the shell mounted (e.g. via notification or deep link),
    // sync the shell to app.tab post-frame without clobbering app.tab.
    if (app.tab != widget.navigationShell.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && app.tab != widget.navigationShell.currentIndex) {
          widget.navigationShell.goBranch(
            app.tab,
            initialLocation: app.tab == widget.navigationShell.currentIndex,
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex != widget.navigationShell.currentIndex) {
      final newIndex = widget.navigationShell.currentIndex;
      if (app.tab != newIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && app.tab != newIndex) {
            app.setTab(newIndex);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    app.removeListener(_onAppChanged);
    super.dispose();
  }

  void _onAppChanged() {
    if (_paper != app.paper) {
      setState(() => _paper = app.paper);
    }
    if (widget.navigationShell.currentIndex != app.tab) {
      widget.navigationShell.goBranch(
        app.tab,
        initialLocation: app.tab == widget.navigationShell.currentIndex,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              painter: PaperPainter(_paper),
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    Expanded(
                      child: widget.navigationShell,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: RepaintBoundary(
                        child: SketchNav(
                          currentIndex: widget.navigationShell.currentIndex,
                          onTabSelected: (index) {
                            app.setTab(index);
                            widget.navigationShell.goBranch(
                              index,
                              initialLocation: index == widget.navigationShell.currentIndex,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
