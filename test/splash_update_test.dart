import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:if_my_life_was_a_movie/main.dart';
import 'package:if_my_life_was_a_movie/services/app_version_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppVersion', () {
    test('compares SemVer pre-releases and build numbers accurately', () {
      final beta1 = AppVersion.tryParse('1.0.0-beta', explicitBuildNumber: 1)!;
      final beta1Same = AppVersion.tryParse('v1.0.0-beta+1')!;
      final beta2 = AppVersion.tryParse('1.0.0-beta', explicitBuildNumber: 2)!;
      final betaDot2 = AppVersion.tryParse('1.0.0-beta.2', explicitBuildNumber: 1)!;
      final stable = AppVersion.tryParse('1.0.0', explicitBuildNumber: 1)!;
      final patch = AppVersion.tryParse('v1.0.1', explicitBuildNumber: 1)!;
      final alpha = AppVersion.tryParse('1.0.0-alpha', explicitBuildNumber: 9)!;
      final devHigher = AppVersion.tryParse('1.1.0', explicitBuildNumber: 1)!;

      expect(beta1Same.compareTo(beta1), equals(0));
      expect(beta2.compareTo(beta1), greaterThan(0));
      expect(betaDot2.compareTo(beta1), greaterThan(0));
      expect(stable.compareTo(beta1), greaterThan(0));
      expect(patch.compareTo(beta1), greaterThan(0));
      expect(alpha.compareTo(beta1), lessThan(0));
      expect(beta2.compareTo(devHigher), lessThan(0));
      expect(AppVersion.tryParse('not-a-version'), isNull);
    });
  });

  group('AppVersionService', () {
    test('returns null when installed version is already up to date', () async {
      final service = AppVersionService(
        platformOverride: 'android',
        readCurrentVersion: () async => (version: '1.0.0-beta', buildNumber: 1),
        fetchReleases: (_) async => [
          {
            'platform': 'all',
            'latest_version': '1.0.0-beta',
            'latest_build_number': 1,
            'release_notes': 'Current beta.',
            'download_url': 'https://example.com/releases/latest',
            'force_update': false,
          },
        ],
      );

      expect(await service.checkForUpdate(), isNull);
    });

    test('returns newer release and prefers matching platform on tie', () async {
      final service = AppVersionService(
        platformOverride: 'android',
        readCurrentVersion: () async => (version: '1.0.0-beta', buildNumber: 1),
        fetchReleases: (_) async => [
          {
            'platform': 'all',
            'latest_version': '1.0.1',
            'latest_build_number': 2,
            'release_notes': 'All platforms release notes',
            'download_url': 'https://example.com/all.apk',
            'force_update': false,
          },
          {
            'platform': 'android',
            'latest_version': '1.0.1',
            'latest_build_number': 2,
            'release_notes': 'Android APK bugfixes & calendar toggle',
            'download_url': 'https://example.com/android.apk',
            'force_update': true,
          },
        ],
      );

      final update = await service.checkForUpdate();
      expect(update, isNotNull);
      expect(update!.latestVersion, equals('1.0.1'));
      expect(update.platform, equals('android'));
      expect(update.downloadUrl, equals('https://example.com/android.apk'));
      expect(update.forceUpdate, isTrue);
    });

    test('returns null safely when Supabase fetch fails', () async {
      final service = AppVersionService(
        platformOverride: 'android',
        readCurrentVersion: () async => (version: '1.0.0-beta', buildNumber: 1),
        fetchReleases: (_) async => throw Exception('offline'),
      );

      expect(await service.checkForUpdate(), isNull);
    });
  });

  group('SplashGate version check', () {
    testWidgets('proceeds smoothly when no update is available', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashGate(
            checkForUpdate: () async => null,
            child: const Scaffold(body: Text('APP HOME')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('APP HOME'), findsOneWidget);
      expect(find.text('NEW UPDATE READY'), findsNothing);
    });

    testWidgets('prompts on splash when optional update is available and dismisses cleanly', (tester) async {
      Uri? launchedUri;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashGate(
            checkForUpdate: () async => const AppUpdateInfo(
              currentVersion: '1.0.0-beta',
              currentBuildNumber: 1,
              latestVersion: '1.0.1',
              latestBuildNumber: 2,
              releaseNotes: 'Smoother playback & calendar album covers.',
              downloadUrl: 'https://github.com/zakialmahdi/ifmylifewasamovie-app/releases/latest',
              forceUpdate: false,
              platform: 'android',
            ),
            updateLauncher: (uri) async {
              launchedUri = uri;
              return true;
            },
            child: const Scaffold(body: Text('APP HOME')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('NEW UPDATE READY'), findsOneWidget);
      expect(find.text('V1.0.1'), findsOneWidget);
      expect(find.text('your version: v1.0.0-beta'), findsOneWidget);
      expect(find.text('Smoother playback & calendar album covers.'), findsOneWidget);

      await tester.tap(find.text('UPDATE NOW →'));
      await tester.pumpAndSettle();
      expect(
        launchedUri,
        equals(Uri.parse('https://github.com/zakialmahdi/ifmylifewasamovie-app/releases/latest')),
      );

      await tester.tap(find.text('LATER'));
      await tester.pumpAndSettle();

      expect(find.text('NEW UPDATE READY'), findsNothing);
      expect(find.text('APP HOME'), findsOneWidget);
    });

    testWidgets('enforces force update without later button or barrier dismiss', (tester) async {
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SplashGate(
            checkForUpdate: () async => const AppUpdateInfo(
              currentVersion: '1.0.0-beta',
              currentBuildNumber: 1,
              latestVersion: '2.0.0',
              latestBuildNumber: 10,
              releaseNotes: 'Critical sync schema update.',
              downloadUrl: 'https://github.com/zakialmahdi/ifmylifewasamovie-app/releases/latest',
              forceUpdate: true,
              platform: 'all',
            ),
            updateLauncher: (_) async => false,
            child: const Scaffold(body: Text('APP HOME')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('UPDATE REQUIRED'), findsOneWidget);
      expect(find.text('LATER'), findsNothing);

      // Tapping outside barrier must not dismiss force update.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('UPDATE REQUIRED'), findsOneWidget);

      // Failed browser launch surfaces clipboard fallback note inline.
      await tester.tap(find.text('UPDATE NOW →'));
      await tester.pumpAndSettle();
      expect(
        copiedText,
        equals('https://github.com/zakialmahdi/ifmylifewasamovie-app/releases/latest'),
      );
      expect(find.text('couldn\'t open link — release URL copied'), findsOneWidget);
    });

    testWidgets('still prompts if Supabase version check completes after splash was skipped', (tester) async {
      final completer = Completer<AppUpdateInfo?>();

      await tester.pumpWidget(
        MaterialApp(
          home: SplashGate(
            checkForUpdate: () => completer.future,
            child: const Scaffold(body: Text('APP HOME')),
          ),
        ),
      );

      // Tap splash screen to skip animation before remote check completes.
      await tester.tapAt(const Offset(200, 200));
      await tester.pumpAndSettle();
      expect(find.text('APP HOME'), findsOneWidget);
      expect(find.text('NEW UPDATE READY'), findsNothing);

      // Delayed remote response arrives -> update prompt still appears over app.
      completer.complete(
        const AppUpdateInfo(
          currentVersion: '1.0.0-beta',
          currentBuildNumber: 1,
          latestVersion: '1.0.2',
          latestBuildNumber: 3,
          releaseNotes: 'Late network check still prompts.',
          downloadUrl: 'https://github.com/zakialmahdi/ifmylifewasamovie-app/releases/latest',
          forceUpdate: false,
          platform: 'all',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NEW UPDATE READY'), findsOneWidget);
      expect(find.text('V1.0.2'), findsOneWidget);
    });
  });
}
