import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Parsed semantic version + optional integer build number for update comparisons.
class AppVersion implements Comparable<AppVersion> {
  final int major;
  final int minor;
  final int patch;
  final List<String> preRelease;
  final int? buildNumber;
  final String normalizedVersion;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.preRelease,
    required this.buildNumber,
    required this.normalizedVersion,
  });

  static AppVersion? tryParse(String raw, {int? explicitBuildNumber}) {
    var cleaned = raw.trim();
    if (cleaned.isEmpty) return null;
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1).trim();
    }
    if (cleaned.isEmpty) return null;

    String versionPart = cleaned;
    int? parsedBuild;
    final plusIdx = cleaned.indexOf('+');
    if (plusIdx != -1) {
      versionPart = cleaned.substring(0, plusIdx).trim();
      final buildStr = cleaned.substring(plusIdx + 1).trim();
      if (buildStr.isNotEmpty) {
        parsedBuild = int.tryParse(buildStr);
      }
    }

    String corePart = versionPart;
    String prePart = '';
    final dashIdx = versionPart.indexOf('-');
    if (dashIdx != -1) {
      corePart = versionPart.substring(0, dashIdx).trim();
      prePart = versionPart.substring(dashIdx + 1).trim();
    }

    final coreSegments = corePart.split('.');
    if (coreSegments.isEmpty || coreSegments.length > 3) return null;
    final numbers = <int>[];
    for (final seg in coreSegments) {
      if (!RegExp(r'^\d+$').hasMatch(seg)) return null;
      numbers.add(int.parse(seg));
    }
    while (numbers.length < 3) {
      numbers.add(0);
    }

    final preTokens = prePart.isEmpty
        ? const <String>[]
        : prePart
            .split(RegExp(r'[.-]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);

    final effectiveBuild = explicitBuildNumber != null && parsedBuild != null
        ? math.max(explicitBuildNumber, parsedBuild)
        : (explicitBuildNumber ?? parsedBuild);

    return AppVersion(
      major: numbers[0],
      minor: numbers[1],
      patch: numbers[2],
      preRelease: preTokens,
      buildNumber: effectiveBuild,
      normalizedVersion: versionPart,
    );
  }

  /// Compares `major.minor.patch` and pre-release tags according to SemVer 2.0.0.
  int compareSemVerOnly(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;

    final len = math.min(preRelease.length, other.preRelease.length);
    for (var i = 0; i < len; i++) {
      final a = preRelease[i];
      final b = other.preRelease[i];
      final aInt = int.tryParse(a);
      final bInt = int.tryParse(b);
      if (aInt != null && bInt != null) {
        if (aInt != bInt) return aInt.compareTo(bInt);
      } else if (aInt != null) {
        return -1;
      } else if (bInt != null) {
        return 1;
      } else {
        final cmp = a.toLowerCase().compareTo(b.toLowerCase());
        if (cmp != 0) return cmp;
      }
    }
    return preRelease.length.compareTo(other.preRelease.length);
  }

  @override
  int compareTo(AppVersion other) {
    final semVerCmp = compareSemVerOnly(other);
    if (semVerCmp != 0) return semVerCmp;
    if (buildNumber != null && other.buildNumber != null) {
      return buildNumber!.compareTo(other.buildNumber!);
    }
    return 0;
  }
}

/// Update metadata returned when Supabase reports a newer release than the installed build.
class AppUpdateInfo {
  final String currentVersion;
  final int currentBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final String releaseNotes;
  final String downloadUrl;
  final bool forceUpdate;
  final String platform;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.forceUpdate,
    required this.platform,
  });
}

typedef CurrentVersionReader = Future<({String version, int buildNumber})> Function();
typedef ReleaseRowsFetcher = Future<List<Map<String, dynamic>>> Function(String platform);

/// Checks Supabase `public.app_releases` on launch / splash screen to detect updates.
class AppVersionService {
  static const String kFallbackVersion = '1.1.0';
  static const int kFallbackBuildNumber = 2;
  static const String kDefaultDownloadUrl =
      'https://github.com/zakialmahdi/ifmylifewasamovie-app/releases/latest';

  static final AppVersionService instance = AppVersionService();

  final CurrentVersionReader? readCurrentVersion;
  final ReleaseRowsFetcher? fetchReleases;
  final String? platformOverride;

  const AppVersionService({
    this.readCurrentVersion,
    this.fetchReleases,
    this.platformOverride,
  });

  String currentPlatform() {
    if (platformOverride != null) return platformOverride!;
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'all',
    };
  }

  Future<({String version, int buildNumber})> _defaultReadCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      final build = int.tryParse(info.buildNumber.trim()) ?? kFallbackBuildNumber;
      if (version.isNotEmpty) {
        return (version: version, buildNumber: build);
      }
    } on MissingPluginException {
      // Widget/unit test environments do not register native PackageInfo channels.
    } catch (_) {
      // Fall back cleanly if platform metadata is unavailable.
    }
    return (version: kFallbackVersion, buildNumber: kFallbackBuildNumber);
  }

  Future<List<Map<String, dynamic>>> _defaultFetchReleases(String platform) async {
    final client = Supabase.instance.client;
    final platforms = platform == 'all' ? const <String>['all'] : <String>[platform, 'all'];
    final rows = await client
        .from('app_releases')
        .select(
          'platform, latest_version, latest_build_number, release_notes, download_url, force_update, published_at',
        )
        .eq('is_active', true)
        .inFilter('platform', platforms)
        .order('latest_build_number', ascending: false)
        .limit(10)
        .timeout(const Duration(seconds: 5));
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Queries active release rows from Supabase and returns [AppUpdateInfo] if newer.
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final local = await (readCurrentVersion ?? _defaultReadCurrentVersion)();
      final current = AppVersion.tryParse(
        local.version,
        explicitBuildNumber: local.buildNumber,
      );
      if (current == null) return null;

      final platform = currentPlatform();
      final rows = await (fetchReleases ?? _defaultFetchReleases)(platform);
      if (rows.isEmpty) return null;

      ({AppVersion version, AppUpdateInfo info})? best;
      for (final row in rows) {
        final rawVersion = (row['latest_version'] as String?)?.trim() ?? '';
        final rawBuild = (row['latest_build_number'] as num?)?.toInt();
        final candidate = AppVersion.tryParse(
          rawVersion,
          explicitBuildNumber: rawBuild,
        );
        if (candidate == null || candidate.compareTo(current) <= 0) {
          continue;
        }

        final rowPlatform = ((row['platform'] as String?) ?? 'all').trim();
        final rawUrl = (row['download_url'] as String?)?.trim() ?? '';
        final info = AppUpdateInfo(
          currentVersion: current.normalizedVersion,
          currentBuildNumber: current.buildNumber ?? local.buildNumber,
          latestVersion: candidate.normalizedVersion,
          latestBuildNumber: candidate.buildNumber ?? rawBuild ?? 1,
          releaseNotes: ((row['release_notes'] as String?) ?? '').trim(),
          downloadUrl: rawUrl.isNotEmpty ? rawUrl : kDefaultDownloadUrl,
          forceUpdate: row['force_update'] == true,
          platform: rowPlatform,
        );

        if (best == null) {
          best = (version: candidate, info: info);
          continue;
        }
        final cmp = candidate.compareTo(best.version);
        final preferPlatformTieBreak =
            cmp == 0 && rowPlatform == platform && best.info.platform != platform;
        if (cmp > 0 || preferPlatformTieBreak) {
          best = (version: candidate, info: info);
        }
      }

      return best?.info;
    } catch (_) {
      // Never block or crash app startup if offline, timed out, or unconfigured.
      return null;
    }
  }
}
