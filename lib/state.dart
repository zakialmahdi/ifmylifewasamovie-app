import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/reminder_service.dart';
import 'services/youtube_music_service.dart';

const kGoogleWebClientId =
    '472839838495-re1kna3130b98r25laqti642et5e7o1d.apps.googleusercontent.com';

/// Resolves the platform-appropriate Supabase auth redirect URL.
/// Returns `io.supabase.flutter://auth-callback` on mobile/desktop and
/// `<origin><webPath>` on web HTTP(S) origins so deployments like Netlify
/// redirect back to the live site instead of Supabase's localhost default.
String? resolveAuthRedirectUrl({
  required bool isWeb,
  required Uri baseUri,
  String webPath = '/',
}) {
  if (!isWeb) return 'io.supabase.flutter://auth-callback';
  if (baseUri.scheme != 'http' && baseUri.scheme != 'https') return null;
  return '${baseUri.origin}$webPath';
}

enum Hatch {
  solid,
  diagonal,
  cross,
  lines,
  dots,
  vertical,
  waves,
  zigzag,
  grid,
  rings,
  checker,
}

Hatch hatchFromName(String? raw, [Hatch fallback = Hatch.diagonal]) {
  if (raw == null) return fallback;
  for (final h in Hatch.values) {
    if (h.name == raw) return h;
  }
  return fallback;
}

class Song {
  final String title;
  final String artist;
  final int seconds;
  final Hatch art;
  final String? videoId;
  final String? coverUrl;
  final String? previewUrl;

  const Song(
    this.title,
    this.artist,
    this.seconds,
    this.art, {
    this.videoId,
    this.coverUrl,
    this.previewUrl,
  });

  Song copyWith({
    String? title,
    String? artist,
    int? seconds,
    Hatch? art,
    String? videoId,
    String? coverUrl,
    String? previewUrl,
  }) =>
      Song(
        title ?? this.title,
        artist ?? this.artist,
        seconds ?? this.seconds,
        art ?? this.art,
        videoId: videoId ?? this.videoId,
        coverUrl: coverUrl ?? this.coverUrl,
        previewUrl: previewUrl ?? this.previewUrl,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Song &&
          other.title == title &&
          other.artist == artist &&
          other.seconds == seconds &&
          other.art == art &&
          other.videoId == videoId &&
          other.coverUrl == coverUrl &&
          other.previewUrl == previewUrl);

  @override
  int get hashCode => Object.hash(
        title,
        artist,
        seconds,
        art,
        videoId,
        coverUrl,
        previewUrl,
      );
}

class Mood {
  final String name;
  final Hatch hatch;

  const Mood(this.name, this.hatch);

  Mood copyWith({String? name, Hatch? hatch}) =>
      Mood(name ?? this.name, hatch ?? this.hatch);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Mood &&
          other.name.trim().toLowerCase() == name.trim().toLowerCase());

  @override
  int get hashCode => name.trim().toLowerCase().hashCode;
}

class Entry {
  final int? dbId;
  final DateTime date;
  final Song song;
  final Mood mood;
  final String note;
  final int scene;
  final int cheers;
  final bool cheeredByMe;
  final List<String> cheeredByNames;

  const Entry({
    this.dbId,
    required this.date,
    required this.song,
    required this.mood,
    required this.note,
    required this.scene,
    this.cheers = 0,
    this.cheeredByMe = false,
    this.cheeredByNames = const [],
  });

  Entry copyWith({
    int? dbId,
    Song? song,
    Mood? mood,
    String? note,
    int? scene,
    int? cheers,
    bool? cheeredByMe,
    List<String>? cheeredByNames,
  }) => Entry(
        dbId: dbId ?? this.dbId,
        date: date,
        song: song ?? this.song,
        mood: mood ?? this.mood,
        note: note ?? this.note,
        scene: scene ?? this.scene,
        cheers: cheers ?? this.cheers,
        cheeredByMe: cheeredByMe ?? this.cheeredByMe,
        cheeredByNames: cheeredByNames ?? this.cheeredByNames,
      );
}

class Friend {
  final String id;
  final String name;
  final String handle;
  final Hatch avatar;
  final String? avatarUrl;
  final Map<String, Entry> entries;
  final bool sharingEnabled;
  final int? friendshipId;
  bool cheeredToday;
  int cheers;

  Friend({
    required this.id,
    required this.name,
    required this.handle,
    required this.avatar,
    this.avatarUrl,
    required this.entries,
    this.sharingEnabled = true,
    this.friendshipId,
    this.cheeredToday = false,
    this.cheers = 0,
  });

  Entry? entryFor(DateTime d) => entries[dayKey(d)];

  List<Mood> get moods {
    final seen = <String>{};
    final list = <Mood>[];
    for (final e in entries.values) {
      final key = '${e.mood.name}_${e.mood.hatch.name}';
      if (seen.add(key)) {
        list.add(e.mood);
      }
    }
    return list;
  }

  int streakFrom(DateTime today) {
    var count = 0;
    var offset = entries.containsKey(dayKey(today)) ? 0 : 1;
    while (true) {
      final d = DateTime(today.year, today.month, today.day - offset);
      if (entries.containsKey(dayKey(d))) {
        count++;
        offset++;
      } else {
        break;
      }
    }
    return count;
  }
}

class FriendInvite {
  final String id;
  final int? friendshipId;
  final String name;
  final String handle;
  final Hatch avatar;
  final String? avatarUrl;
  final List<(int, int, Mood, String)> seedScenes;

  const FriendInvite({
    required this.id,
    required this.name,
    required this.handle,
    required this.avatar,
    this.avatarUrl,
    this.friendshipId,
    this.seedScenes = const <(int, int, Mood, String)>[],
  });
}

const hopeful = Mood('hopeful', Hatch.diagonal);
const restless = Mood('restless', Hatch.cross);
const dreamy = Mood('dreamy', Hatch.dots);
const tired = Mood('tired', Hatch.lines);

const catalog = <Song>[
  Song('Motion Sickness', 'Phoebe Bridgers', 229, Hatch.cross),
  Song('Space Song', 'Beach House', 320, Hatch.dots),
  Song('Pink + White', 'Frank Ocean', 184, Hatch.diagonal),
  Song('Mystery of Love', 'Sufjan Stevens', 248, Hatch.lines),
  Song('My Love Mine All Mine', 'Mitski', 137, Hatch.dots),
  Song('Ribs', 'Lorde', 258, Hatch.cross),
  Song('Apocalypse', 'Cigarettes After Sex', 290, Hatch.lines),
  Song('Weird Fishes / Arpeggi', 'Radiohead', 318, Hatch.diagonal),
  Song('Fade Into You', 'Mazzy Star', 295, Hatch.dots),
  Song('Kokomo, IN', 'Japanese Breakfast', 218, Hatch.diagonal),
  Song('Holocene', 'Bon Iver', 336, Hatch.lines),
  Song('Bags', 'Clairo', 260, Hatch.cross),
];

const monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _shortMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String weekday(DateTime d) => _weekdays[d.weekday - 1];

String dayLabel(DateTime d) => '${weekday(d)}, ${_shortMonths[d.month - 1]} ${d.day}';

int sceneNo(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(d.year, 1, 1)).inDays + 1;

String fmtTime(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final m = s ~/ 60;
  final rem = (s % 60).toString().padLeft(2, '0');
  return '$m:$rem';
}

class AppState extends ChangeNotifier {
  AppState() {
    final now = DateTime.now();
    today = DateTime(now.year, now.month, now.day);
    viewMonth = DateTime(today.year, today.month, 1);
    selected = today;
    friendViewMonth = DateTime(today.year, today.month, 1);
    friendSelectedDate = today;
    draftSong = catalog.first;
    draftMood = hopeful;
    noteCtl = TextEditingController(text: '');
  }

  SupabaseClient get _sb => Supabase.instance.client;
  StreamSubscription<AuthState>? _authSub;
  RealtimeChannel? _friendshipsChannel;
  RealtimeChannel? _cheersChannel;
  final Set<int> _notifiedInviteIds = <int>{};
  final Set<String> _notifiedCheerKeys = <String>{};

  User? user;
  bool demoMode = false;
  bool syncing = false;
  bool dbReady = false;
  bool isRecoveringPassword = false;

  String? _dbHandle;
  String? _dbInviteCode;

  bool get isAuthenticated => user != null || demoMode;
  String? get email => user?.email;

  late final DateTime today;
  late DateTime viewMonth;
  late DateTime selected;

  late DateTime friendViewMonth;
  late DateTime friendSelectedDate;
  String activeFriendId = 'jules';
  bool sharingEnabled = true;
  String sharingAudience = 'all'; // 'all' or 'specific'
  Set<String> sharedFriendIds = <String>{};
  bool compareCalendar = true;

  int get sharedFriendsCount {
    if (sharingAudience == 'all') return friends.length;
    return sharedFriendIds.where((id) => friends.any((f) => f.id == id)).length;
  }

  bool isSharedWith(String friendId) {
    if (!sharingEnabled) return false;
    if (sharingAudience == 'all') return true;
    return sharedFriendIds.contains(friendId);
  }

  int tab = 0;
  String name = 'maya';
  Hatch avatarHatch = Hatch.cross;
  String? avatarUrl;
  Uint8List? avatarMemoryBytes;
  String paper = 'lined';

  bool dailyReminder = true;
  int reminderHour = 21;
  int reminderMinute = 0;
  bool moodPrompts = true;
  bool privacyLock = false;
  String? _privacyPin;
  bool isPrivacyUnlocked = false;
  bool _hasSeenIntro = true;
  bool _pendingSignUpIntro = false;
  bool _suppressIntroOnSignIn = false;
  final Set<String> _seenIntroUsers = <String>{};
  bool get hasSeenIntro => _hasSeenIntro || demoMode;
  set hasSeenIntro(bool v) => _hasSeenIntro = v;

  bool get hasPrivacyPin => _privacyPin != null && _privacyPin!.length == 4;
  bool get isPrivacyLocked => privacyLock && hasPrivacyPin && !isPrivacyUnlocked;

  int? _lastSongSavedAtMillis;

  final List<Mood> moods = <Mood>[hopeful, restless, dreamy, tired];
  late Song draftSong;
  late Mood draftMood;
  late final TextEditingController noteCtl;

  final Map<String, Entry> _entries = <String, Entry>{};
  final Map<String, int> _sceneOpSeq = <String, int>{};
  final List<Friend> friends = <Friend>[];
  final List<FriendInvite> invites = <FriendInvite>[];

  static String _slug(String input) {
    final s = input.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    return s.isEmpty ? 'reel' : s;
  }

  String _shortUserCode() {
    final uid = user?.id;
    if (uid == null || uid.isEmpty) return '402';
    final hex = uid.replaceAll('-', '').toUpperCase();
    return hex.substring(0, math.min<int>(hex.length, 4));
  }

  String get handle {
    if (_dbHandle != null && _dbHandle!.isNotEmpty) return _dbHandle!;
    final slug = _slug(name);
    final head = slug.substring(0, math.min<int>(slug.length, 12));
    if (user == null) return '@$head';
    return '@${head}_${_shortUserCode().toLowerCase()}';
  }

  String get inviteCode {
    if (_dbInviteCode != null && _dbInviteCode!.isNotEmpty) return _dbInviteCode!;
    final slug = _slug(name).toUpperCase();
    final head = slug.substring(0, math.min<int>(slug.length, 6));
    return '$head-${_shortUserCode()}';
  }

  Friend? get activeFriend {
    if (friends.isEmpty) return null;
    return friends.where((f) => f.id == activeFriendId).firstOrNull ?? friends.first;
  }

  // ── initialization & Supabase auth lifecycle ──

  Future<void> init() async {
    musicService.onPlaybackSongChanged = onSongPlayed;
    ReminderService.instance.onNotificationTapped = (payload) {
      if (payload == 'reel_invite' || payload == 'friends') {
        setTab(2);
      } else if (payload == 'daily_reminder') {
        setTab(0);
      } else if (payload == 'scene_cheer') {
        setTab(1);
      }
    };

    final launch = await ReminderService.instance.getLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final payload = launch?.notificationResponse?.payload;
      if (payload == 'reel_invite' || payload == 'friends') {
        tab = 2;
      } else if (payload == 'daily_reminder') {
        tab = 0;
      } else if (payload == 'scene_cheer') {
        tab = 1;
      }
    }

    await _loadLocalPrivacySettings();
    await _loadLastSong();
    await _loadLocalMoods();
    await _loadReminderSettings();
    await _loadSharingSettings();
    await _loadNotifiedInvites();
    await _loadNotifiedCheers();
    await _loadIntroSettings();
    unawaited(_rescheduleReminders());

    await _authSub?.cancel();
    final initialUser = _sb.auth.currentSession?.user;
    if (initialUser != null) {
      _applyUser(initialUser, isInitialSession: true);
      unawaited(loadFromDatabase());
    }
    _authSub = _sb.auth.onAuthStateChange.listen((data) {
      final nextUser = data.session?.user;
      if (data.event == AuthChangeEvent.passwordRecovery) {
        isRecoveringPassword = true;
      }
      if (nextUser != null) {
        final switchedUser = user?.id != nextUser.id;
        _applyUser(
          nextUser,
          isInitialSession: data.event == AuthChangeEvent.initialSession,
        );
        notifyListeners();
        if (switchedUser) {
          unawaited(loadFromDatabase());
        }
      } else if (user != null) {
        _clearToLoggedOut();
        notifyListeners();
      }
    });
  }

  bool _isNewlyRegisteredUser(User u) {
    if (_seenIntroUsers.contains(u.id)) return false;
    if (_pendingSignUpIntro) return true;
    final created = DateTime.tryParse(u.createdAt);
    final lastSignIn =
        u.lastSignInAt != null ? DateTime.tryParse(u.lastSignInAt!) : null;
    if (created != null && lastSignIn != null) {
      return lastSignIn.difference(created).abs() <= const Duration(minutes: 2);
    }
    return false;
  }

  void _applyUser(
    User u, {
    String? preferredName,
    bool isInitialSession = false,
  }) {
    final switching = user?.id != u.id;
    user = u;
    demoMode = false;
    if (switching) {
      if (isInitialSession || _suppressIntroOnSignIn) {
        _hasSeenIntro = true;
      } else {
        _hasSeenIntro = !_isNewlyRegisteredUser(u);
      }
      _pendingSignUpIntro = false;
      unawaited(_loadIntroSettings());
    }
    final meta = u.userMetadata;
    final metaName = ((meta?['display_name'] ??
            meta?['full_name'] ??
            meta?['name']) as String?)
        ?.trim();
    final metaAvatar = ((meta?['avatar_url'] ?? meta?['picture']) as String?)?.trim();
    final fallbackEmailName = u.email?.split('@').first.trim();
    final chosen = (preferredName != null && preferredName.trim().isNotEmpty)
        ? preferredName.trim()
        : (metaName != null && metaName.isNotEmpty)
            ? metaName
            : (fallbackEmailName != null && fallbackEmailName.isNotEmpty)
                ? fallbackEmailName
                : 'director';
    if (switching) {
      name = chosen;
      avatarHatch = Hatch.cross;
      avatarUrl = (metaAvatar != null && metaAvatar.isNotEmpty) ? metaAvatar : null;
      avatarMemoryBytes = null;
      _dbHandle = null;
      _dbInviteCode = null;
      _entries.clear();
      friends.clear();
      invites.clear();
      moods
        ..clear()
        ..addAll(const <Mood>[hopeful, restless, dreamy, tired]);
      draftMood = hopeful;
      tab = 0;
    }
  }

  void _clearToLoggedOut() {
    _unsubscribeFromFriendships();
    unawaited(musicService.stop());
    unawaited(ReminderService.instance.cancelAll());
    user = null;
    demoMode = false;
    _hasSeenIntro = true;
    _pendingSignUpIntro = false;
    _suppressIntroOnSignIn = false;
    syncing = false;
    dbReady = false;
    isRecoveringPassword = false;
    isPrivacyUnlocked = false;
    avatarHatch = Hatch.cross;
    avatarUrl = null;
    avatarMemoryBytes = null;
    _dbHandle = null;
    _dbInviteCode = null;
    tab = 0;
    _entries.clear();
    friends.clear();
    invites.clear();
    _notifiedInviteIds.clear();
    _notifiedCheerKeys.clear();
    moods
      ..clear()
      ..addAll(const <Mood>[hopeful, restless, dreamy, tired]);
    draftMood = hopeful;
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _suppressIntroOnSignIn = true;
    try {
      final res = await _sb.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (res.user != null) {
        _applyUser(res.user!);
        _hasSeenIntro = true;
        notifyListeners();
        await loadFromDatabase();
      }
    } finally {
      _suppressIntroOnSignIn = false;
    }
  }

  Future<({bool needsEmailConfirmation, String email})> signUp({
    required String email,
    required String password,
    required String directorName,
  }) async {
    final cleanEmail = email.trim();
    final cleanName = directorName.trim().isEmpty
        ? cleanEmail.split('@').first
        : directorName.trim();

    _pendingSignUpIntro = true;
    try {
      final res = await _sb.auth.signUp(
        email: cleanEmail,
        password: password,
        data: <String, dynamic>{'display_name': cleanName},
        emailRedirectTo: resolveAuthRedirectUrl(
          isWeb: kIsWeb,
          baseUri: Uri.base,
        ),
      );

      final identities = res.user?.identities;
      if (identities != null && identities.isEmpty) {
        throw const AuthException(
          'This email is already registered – switch to Sign In instead.',
        );
      }

      if (res.session != null && res.user != null) {
        _applyUser(res.user!, preferredName: cleanName);
        notifyListeners();
        await loadFromDatabase(preferredName: cleanName);
        return (needsEmailConfirmation: false, email: cleanEmail);
      }

      return (needsEmailConfirmation: true, email: cleanEmail);
    } finally {
      _pendingSignUpIntro = false;
    }
  }

  Future<void> verifySignupOtp({
    required String email,
    required String token,
    String? directorName,
  }) async {
    _pendingSignUpIntro = true;
    try {
      final res = await _sb.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.signup,
      );
      if (res.user != null) {
        _applyUser(res.user!, preferredName: directorName);
        notifyListeners();
        await loadFromDatabase(preferredName: directorName);
      }
    } finally {
      _pendingSignUpIntro = false;
    }
  }

  Future<void> resendSignupOtp(String email) async {
    await _sb.auth.resend(
      email: email.trim(),
      type: OtpType.signup,
    );
  }

  bool _googleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? kGoogleWebClientId : null,
      serverClientId: kIsWeb ? null : kGoogleWebClientId,
    );
    _googleSignInInitialized = true;
  }

  Future<bool> signInWithGoogle() async {
    if (!kIsWeb && GoogleSignIn.instance.supportsAuthenticate()) {
      await _ensureGoogleSignInInitialized();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const <String>['email', 'profile'],
      );
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthException('No ID token received from Google Sign-In.');
      }
      final authz = await account.authorizationClient.authorizationForScopes(
        const <String>['email', 'profile'],
      );
      final res = await _sb.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authz?.accessToken,
      );
      if (res.user != null) {
        _applyUser(res.user!, preferredName: account.displayName);
        notifyListeners();
        await loadFromDatabase(preferredName: account.displayName);
      }
      return true;
    }

    return _sb.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: resolveAuthRedirectUrl(
        isWeb: kIsWeb,
        baseUri: Uri.base,
      ),
      queryParams: const <String, String>{
        'access_type': 'offline',
        'prompt': 'select_account',
      },
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _sb.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: resolveAuthRedirectUrl(
        isWeb: kIsWeb,
        baseUri: Uri.base,
        webPath: '/reset-password',
      ),
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _sb.auth.updateUser(
      UserAttributes(password: newPassword.trim()),
    );
    isRecoveringPassword = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (_googleSignInInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    if (user != null) {
      await _sb.auth.signOut();
    }
    _clearToLoggedOut();
    notifyListeners();
  }

  Future<void> _wipeLocalUserData() async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final fileNames = <String>[
        'privacy_lock.json',
        'last_song.json',
        'sharing_settings.json',
        'notified_invites.json',
        'notified_cheers.json',
        'reminder_settings.json',
        'intro_seen.json',
      ];
      for (final fileName in fileNames) {
        final f = File('${docs.path}/$fileName');
        if (await f.exists()) {
          await f.delete();
        }
      }
      final cacheDir = Directory('${docs.path}/audio_cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> deleteAccount() async {
    final uid = user?.id;

    if (demoMode) {
      await _wipeLocalUserData();
      _clearToLoggedOut();
      notifyListeners();
      return;
    }

    if (uid != null) {
      bool rpcSucceeded = false;

      // 1. Try server-side RPC first (cleans auth.users + public tables in one transaction)
      try {
        await _sb.rpc('delete_my_account');
        rpcSucceeded = true;
      } catch (e) {
        debugPrint('delete_my_account RPC initial attempt failed ($e), falling back to client-side RLS purge');
      }

      // 2. Fallback: If RPC failed or is not installed, directly purge user rows via authenticated RLS
      if (!rpcSucceeded) {
        // Purge scenes
        try {
          await _sb.from('scenes').delete().eq('user_id', uid);
        } catch (e) {
          debugPrint('Client fallback delete scenes error: $e');
        }

        // Purge friendships
        try {
          await _sb.from('friendships').delete().or('requester_id.eq.$uid,addressee_id.eq.$uid');
        } catch (e) {
          debugPrint('Client fallback delete friendships error: $e');
        }

        // Purge scene cheers
        try {
          await _sb.from('scene_cheers').delete().eq('user_id', uid);
        } catch (e) {
          debugPrint('Client fallback delete cheers error: $e');
        }

        // Purge suggestions
        try {
          await _sb.from('suggestions').delete().eq('user_id', uid);
        } catch (e) {
          debugPrint('Client fallback delete suggestions error: $e');
        }

        // Purge storage avatar files
        try {
          final files = await _sb.storage.from('avatars').list(path: uid);
          if (files.isNotEmpty) {
            final paths = files.map((f) => '$uid/${f.name}').toList();
            await _sb.storage.from('avatars').remove(paths);
          }
        } catch (e) {
          debugPrint('Client fallback delete avatars error: $e');
        }

        // Purge profile row
        try {
          await _sb.from('profiles').delete().eq('id', uid);
        } catch (e) {
          debugPrint('Client fallback delete profile error: $e');
        }

        // Retry RPC now that foreign keys and storage files are cleared
        try {
          await _sb.rpc('delete_my_account');
          rpcSucceeded = true;
        } catch (e) {
          debugPrint('delete_my_account RPC retry failed ($e) – user data purged via RLS');
        }
      }

      // 3. Sign out of Supabase Auth
      try {
        await _sb.auth.signOut();
      } catch (e) {
        debugPrint('SignOut after delete error: $e');
      }
    }

    if (_googleSignInInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }

    await _wipeLocalUserData();
    _clearToLoggedOut();
    notifyListeners();
  }

  void enterDemoMode() {
    user = null;
    demoMode = true;
    hasSeenIntro = true;
    dbReady = false;
    tab = 0;
    name = 'maya';
    avatarHatch = Hatch.cross;
    avatarUrl = null;
    avatarMemoryBytes = null;
    _dbHandle = '@maya';
    _dbInviteCode = 'MAYA-402';
    _entries.clear();
    friends.clear();
    invites.clear();
    _notifiedInviteIds.clear();
    _notifiedCheerKeys.clear();
    moods
      ..clear()
      ..addAll(const <Mood>[hopeful, restless, dreamy, tired]);
    draftMood = hopeful;
    _seed();
    _seedFriends();
    notifyListeners();
  }

  // ── Supabase Postgres synchronization ──

  bool _isMissingSchemaError(PostgrestException e) {
    final code = e.code ?? '';
    return code == 'PGRST205' ||
        code == '42P01' ||
        e.message.contains('Could not find the table');
  }

  Entry _entryFromRow(Map<String, dynamic> row, {bool isOwnScene = false}) {
    final rawDate = row['scene_date'] as String;
    final parts = rawDate.split('-');
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final rawVid = (row['song_video_id'] as String?)?.trim();
    final rawCover = (row['song_cover_url'] as String?)?.trim();
    final cleanCover = (rawCover != null &&
            rawCover.isNotEmpty &&
            !YouTubeMusicService.isYouTubeThumbnail(rawCover))
        ? rawCover
        : null;
    final song = Song(
      (row['song_title'] as String?) ?? catalog.first.title,
      (row['song_artist'] as String?) ?? catalog.first.artist,
      (row['song_seconds'] as num?)?.toInt() ?? 180,
      hatchFromName(row['song_art'] as String?, Hatch.diagonal),
      videoId: (rawVid != null && rawVid.isNotEmpty) ? rawVid : null,
      coverUrl: cleanCover,
    );
    final moodName = ((row['mood_name'] as String?) ?? 'hopeful').trim().toLowerCase();
    final moodHatch = hatchFromName(row['mood_hatch'] as String?, Hatch.diagonal);

    Mood mood;
    if (isOwnScene) {
      final existingMood = moods.where((m) => m.name.toLowerCase() == moodName).firstOrNull;
      if (existingMood != null) {
        mood = existingMood;
      } else {
        mood = Mood(moodName, moodHatch);
      }
    } else {
      // Connected friends' scenes preserve that friend's own feeling and hatch pattern.
      // Must NEVER pollute or leak into the current user's personal app.moods list.
      mood = Mood(moodName, moodHatch);
    }
    return Entry(
      dbId: (row['id'] as num?)?.toInt(),
      date: date,
      song: song,
      mood: mood,
      note: (row['note'] as String?) ?? '',
      scene: (row['scene_no'] as num?)?.toInt() ?? sceneNo(date),
    );
  }

  Future<Map<String, dynamic>?> _ensureProfileExists(String uid, {String? preferredName}) async {
    try {
      var profile = await _sb
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (profile != null) return profile;

      final seedName = (preferredName != null && preferredName.trim().isNotEmpty)
          ? preferredName.trim()
          : name;
      final slug = _slug(seedName);
      final short = _shortUserCode();
      final genHandle =
          '@${slug.substring(0, math.min<int>(slug.length, 12))}_${short.toLowerCase()}';
      final genCode =
          '${slug.toUpperCase().substring(0, math.min<int>(slug.length, 6))}-$short';

      profile = await _sb
          .from('profiles')
          .upsert(
            <String, dynamic>{
              'id': uid,
              'display_name': seedName,
              'handle': genHandle,
              'invite_code': genCode,
              'paper': paper,
              'daily_reminder': dailyReminder,
              'mood_prompts': moodPrompts,
              'privacy_lock': privacyLock,
              'sharing_enabled': sharingEnabled,
              'sharing_audience': sharingAudience,
              'shared_friend_ids': sharedFriendIds.toList(),
            },
            onConflict: 'id',
          )
          .select()
          .maybeSingle();
      return profile;
    } catch (e) {
      debugPrint('ensureProfileExists error: $e');
      return null;
    }
  }

  Future<void> loadFromDatabase({String? preferredName}) async {
    final current = user;
    if (current == null) return;
    final uid = current.id;

    syncing = true;
    notifyListeners();

    try {
      // 1. Ensure profile exists & load preferences
      var profile = await _ensureProfileExists(uid, preferredName: preferredName);
      if (profile == null && !_seenIntroUsers.contains(uid) && !_suppressIntroOnSignIn) {
        _hasSeenIntro = false;
        notifyListeners();
      }

      dbReady = true;

      if (profile != null) {
        name = (profile['display_name'] as String?) ?? name;
        _dbHandle = profile['handle'] as String?;
        _dbInviteCode = profile['invite_code'] as String?;
        avatarHatch = hatchFromName(profile['avatar_hatch'] as String?, avatarHatch);
        final dbAvatarUrl = (profile['avatar_url'] as String?)?.trim();
        if (dbAvatarUrl != null && dbAvatarUrl.isNotEmpty) {
          avatarUrl = dbAvatarUrl;
        }
        paper = (profile['paper'] as String?) ?? paper;
        dailyReminder = (profile['daily_reminder'] as bool?) ?? dailyReminder;
        moodPrompts = (profile['mood_prompts'] as bool?) ?? moodPrompts;
        privacyLock = (profile['privacy_lock'] as bool?) ?? privacyLock;
        sharingEnabled = (profile['sharing_enabled'] as bool?) ?? sharingEnabled;
        sharingAudience = (profile['sharing_audience'] as String?) ?? sharingAudience;
        final rawSharedIds = profile['shared_friend_ids'];
        if (rawSharedIds is List) {
          sharedFriendIds = rawSharedIds.whereType<String>().toSet();
        }
        final rawCustomMoods = profile['custom_moods'];
        if (rawCustomMoods is List && rawCustomMoods.isNotEmpty) {
          moods.clear();
          final seenNames = <String>{};
          for (final item in rawCustomMoods) {
            if (item is Map) {
              final mName = (item['name'] as String?)?.trim().toLowerCase();
              final mHatch = hatchFromName(item['hatch'] as String?, Hatch.diagonal);
              if (mName != null && mName.isNotEmpty && seenNames.add(mName)) {
                moods.add(Mood(mName, mHatch));
              }
            }
          }
          if (moods.isEmpty) {
            moods.addAll(const <Mood>[hopeful, restless, dreamy, tired]);
          }
          unawaited(_persistLocalMoods());
        }
      }

      // 2. Load user's own scenes
      final sceneRows = await _sb
          .from('scenes')
          .select()
          .eq('user_id', uid)
          .order('scene_date', ascending: false);

      if (user?.id != uid) return;
      final loadedKeys = <String>{};
      for (final raw in sceneRows) {
        final e = _entryFromRow(raw, isOwnScene: true);
        final k = dayKey(e.date);
        loadedKeys.add(k);
        _entries[k] = e;
      }

      // Preserve any locally recorded scenes that have not finished syncing yet
      for (final localKey in _entries.keys.toList()) {
        if (!loadedKeys.contains(localKey)) {
          final localEntry = _entries[localKey];
          if (localEntry != null) {
            final seq = (_sceneOpSeq[localKey] ?? 0) + 1;
            _sceneOpSeq[localKey] = seq;
            unawaited(_persistScene(uid, localKey, localEntry, seq));
          }
        }
      }

      final todaySaved = _entries[dayKey(today)];
      if (todaySaved != null) {
        if (_lastSongSavedAtMillis == null) {
          draftSong = todaySaved.song;
        }
        draftMood = todaySaved.mood;
        if (noteCtl.text.isEmpty) {
          noteCtl.text = todaySaved.note;
        }
      }

      // 3. Load friendships, pending invites, shared calendars & cheers
      await _loadFriendsFromDb(uid);
      _subscribeToFriendships(uid);
    } on PostgrestException catch (e) {
      if (_isMissingSchemaError(e)) {
        dbReady = false;
      }
    } catch (_) {
      // Offline or transient network error: keep responsive in-memory state.
    } finally {
      syncing = false;
      notifyListeners();
      unawaited(_rescheduleReminders());
    }
  }

  Future<void> refreshFriends() async {
    final uid = user?.id;
    if (uid == null || !dbReady) return;
    try {
      await _loadFriendsFromDb(uid);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadFriendsFromDb(String uid) async {
    final rels = await _sb
        .from('friendships')
        .select()
        .or('requester_id.eq.$uid,addressee_id.eq.$uid')
        .order('created_at', ascending: false);

    final incomingPending = <int, String>{}; // friendshipId -> requesterId
    final acceptedPeerIds = <String>[];
    final peerFriendshipId = <String, int>{};

    for (final r in rels) {
      final status = r['status'] as String?;
      final reqId = r['requester_id'] as String?;
      final addId = r['addressee_id'] as String?;
      final relId = (r['id'] as num?)?.toInt();
      if (reqId == null || addId == null) continue;

      if (status == 'accepted') {
        final peer = reqId == uid ? addId : reqId;
        if (!acceptedPeerIds.contains(peer)) {
          acceptedPeerIds.add(peer);
          if (relId != null) peerFriendshipId[peer] = relId;
        }
      } else if (status == 'pending' && addId == uid && relId != null) {
        incomingPending[relId] = reqId;
      }
    }

    final allLookupIds = <String>{
      ...acceptedPeerIds,
      ...incomingPending.values,
    }.toList();

    final profileById = <String, Map<String, dynamic>>{};
    if (allLookupIds.isNotEmpty) {
      final profRows = await _sb
          .from('profiles')
          .select()
          .inFilter('id', allLookupIds);
      for (final p in profRows) {
        final id = p['id'] as String?;
        if (id != null) profileById[id] = p;
      }
    }

    // Build incoming invites list
    final nextInvites = <FriendInvite>[];
    incomingPending.forEach((relId, reqId) {
      final p = profileById[reqId];
      if (p != null) {
        final rawAvatar = (p['avatar_url'] as String?)?.trim();
        nextInvites.add(
          FriendInvite(
            id: reqId,
            friendshipId: relId,
            name: (p['display_name'] as String?) ?? 'co-star',
            handle: (p['handle'] as String?) ?? '@costar',
            avatar: hatchFromName(p['avatar_hatch'] as String?, Hatch.cross),
            avatarUrl: (rawAvatar != null && rawAvatar.isNotEmpty) ? rawAvatar : null,
          ),
        );
      }
    });

    // Build accepted friends + their shared scenes + all scene cheers
    final scenesByUser = <String, Map<String, Entry>>{};
    final allPeerSceneIds = <int>[];
    if (acceptedPeerIds.isNotEmpty) {
      final peerSceneRows = await _sb
          .from('scenes')
          .select()
          .inFilter('user_id', acceptedPeerIds)
          .order('scene_date', ascending: false);

      for (final row in peerSceneRows) {
        final ownerId = row['user_id'] as String?;
        if (ownerId == null) continue;
        final entry = _entryFromRow(row, isOwnScene: false);
        (scenesByUser[ownerId] ??= <String, Entry>{})[dayKey(entry.date)] = entry;
        if (entry.dbId != null) {
          allPeerSceneIds.add(entry.dbId!);
        }
      }
    }

    final mySceneIds = _entries.values.map((e) => e.dbId).whereType<int>().toList();
    final allSceneIds = <int>{...allPeerSceneIds, ...mySceneIds}.toList();

    final cheerCounts = <int, int>{};
    final cheeredByMe = <int>{};
    final cheerUserIdsByScene = <int, List<String>>{};
    final allCheerUserIds = <String>{};

    if (allSceneIds.isNotEmpty) {
      final cheerRows = await _sb
          .from('scene_cheers')
          .select()
          .inFilter('scene_id', allSceneIds);
      for (final c in cheerRows) {
        final sid = (c['scene_id'] as num?)?.toInt();
        final cid = c['user_id'] as String?;
        if (sid == null || cid == null) continue;
        cheerCounts[sid] = (cheerCounts[sid] ?? 0) + 1;
        if (cid == uid) cheeredByMe.add(sid);
        (cheerUserIdsByScene[sid] ??= <String>[]).add(cid);
        allCheerUserIds.add(cid);
      }
    }

    final missingProfileIds = allCheerUserIds.where((id) => !profileById.containsKey(id)).toList();
    if (missingProfileIds.isNotEmpty) {
      try {
        final missingProfRows = await _sb
            .from('profiles')
            .select()
            .inFilter('id', missingProfileIds);
        for (final p in missingProfRows) {
          final id = p['id'] as String?;
          if (id != null) profileById[id] = p;
        }
      } catch (_) {}
    }

    final cheerNamesByScene = <int, List<String>>{};
    cheerUserIdsByScene.forEach((sid, userIds) {
      final names = <String>[];
      for (final uId in userIds) {
        final prof = profileById[uId];
        final dName = (prof?['display_name'] as String?)?.trim();
        final dHandle = (prof?['handle'] as String?)?.trim();
        if (dName != null && dName.isNotEmpty) {
          names.add(dName);
        } else if (dHandle != null && dHandle.isNotEmpty) {
          names.add(dHandle);
        } else if (uId == uid) {
          names.add(name);
        } else {
          names.add('a co-star');
        }
      }
      cheerNamesByScene[sid] = names;
    });

    for (final userEntries in scenesByUser.values) {
      for (final key in userEntries.keys.toList()) {
        final entry = userEntries[key]!;
        final sid = entry.dbId;
        if (sid != null) {
          userEntries[key] = entry.copyWith(
            cheers: cheerCounts[sid] ?? 0,
            cheeredByMe: cheeredByMe.contains(sid),
            cheeredByNames: cheerNamesByScene[sid] ?? const [],
          );
        }
      }
    }

    // Also update current user's personal journal scenes with their cheers and cheerer names
    for (final key in _entries.keys.toList()) {
      final entry = _entries[key]!;
      final sid = entry.dbId;
      if (sid != null) {
        _entries[key] = entry.copyWith(
          cheers: cheerCounts[sid] ?? 0,
          cheeredByMe: cheeredByMe.contains(sid),
          cheeredByNames: cheerNamesByScene[sid] ?? const [],
        );
      }
    }

    // Register existing cheers on user's own journal scenes without spamming banners on startup.
    // Live cheers received while the app is running are handled in real-time by _cheersChannel.
    var newlyDiscoveredCheers = false;
    for (final sid in mySceneIds) {
      final userIds = cheerUserIdsByScene[sid] ?? const [];
      final myEntry = _entries.values.where((e) => e.dbId == sid).firstOrNull;
      if (myEntry == null) continue;
      for (final cid in userIds) {
        if (cid == uid) continue;
        final cheerKey = '${sid}_$cid';
        if (!_notifiedCheerKeys.contains(cheerKey)) {
          _notifiedCheerKeys.add(cheerKey);
          newlyDiscoveredCheers = true;
        }
      }
    }
    if (newlyDiscoveredCheers) {
      unawaited(_persistNotifiedCheers());
    }

    final nextFriends = <Friend>[];
    for (final peerId in acceptedPeerIds) {
      final p = profileById[peerId];
      final peerEntries = scenesByUser[peerId] ?? <String, Entry>{};
      final todayEntry = peerEntries[dayKey(today)];
      final rawName = (p?['display_name'] as String?)?.trim();
      final rawHandle = (p?['handle'] as String?)?.trim();
      final rawAvatar = (p?['avatar_url'] as String?)?.trim();
      final friendSharing = (p?['sharing_enabled'] as bool?) ?? true;
      final friendAudience = (p?['sharing_audience'] as String?) ?? 'all';
      final rawPeerSharedIds = p?['shared_friend_ids'];
      final peerSharedSet = (rawPeerSharedIds is List)
          ? rawPeerSharedIds.whereType<String>().toSet()
          : <String>{};
      final peerAllowsMe = friendSharing &&
          (friendAudience == 'all' || peerSharedSet.contains(uid));
      final shortPeer = peerId.replaceAll('-', '');
      final shortHex = shortPeer.substring(0, math.min<int>(shortPeer.length, 4)).toLowerCase();

      nextFriends.add(
        Friend(
          id: peerId,
          name: (rawName != null && rawName.isNotEmpty) ? rawName : 'co-star',
          handle: (rawHandle != null && rawHandle.isNotEmpty)
              ? rawHandle
              : '@costar_$shortHex',
          avatar: hatchFromName(p?['avatar_hatch'] as String?, Hatch.diagonal),
          avatarUrl: (rawAvatar != null && rawAvatar.isNotEmpty) ? rawAvatar : null,
          entries: peerEntries,
          sharingEnabled: peerAllowsMe,
          friendshipId: peerFriendshipId[peerId],
          cheeredToday: todayEntry?.cheeredByMe ?? false,
          cheers: todayEntry?.cheers ?? 0,
        ),
      );
    }

    if (user?.id != uid) return;
    invites
      ..clear()
      ..addAll(nextInvites);
    friends
      ..clear()
      ..addAll(nextFriends);
    if (friends.isNotEmpty && !friends.any((f) => f.id == activeFriendId)) {
      activeFriendId = friends.first.id;
    }

    // Check for newly discovered incoming reel invites to alert the user
    for (final inv in nextInvites) {
      final fId = inv.friendshipId;
      if (fId != null && !_notifiedInviteIds.contains(fId)) {
        _notifiedInviteIds.add(fId);
        unawaited(_persistNotifiedInvites());
        unawaited(ReminderService.instance.showReelInviteNotification(
          inviterName: inv.name,
          inviterHandle: inv.handle,
          inviteId: fId,
        ));
      }
    }
  }

  void _unsubscribeFromFriendships() {
    if (_friendshipsChannel != null) {
      try {
        _sb.removeChannel(_friendshipsChannel!);
      } catch (_) {}
      _friendshipsChannel = null;
    }
    if (_cheersChannel != null) {
      try {
        _sb.removeChannel(_cheersChannel!);
      } catch (_) {}
      _cheersChannel = null;
    }
  }

  void _subscribeToFriendships(String uid) {
    if (!dbReady && user == null) return;
    _unsubscribeFromFriendships();

    try {
      _friendshipsChannel = _sb
          .channel('public:friendships:$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'friendships',
            callback: (PostgresChangePayload payload) async {
              final event = payload.eventType;
              final newRecord = payload.newRecord;
              final addresseeId = newRecord['addressee_id'] as String?;
              final requesterId = newRecord['requester_id'] as String?;
              final status = newRecord['status'] as String?;
              final relId = (newRecord['id'] as num?)?.toInt();

              if (event == PostgresChangeEvent.insert &&
                  addresseeId == uid &&
                  status == 'pending') {
                // A new reel invite just arrived in real-time!
                String inviterName = 'co-star';
                String inviterHandle = '@costar';
                if (requesterId != null) {
                  try {
                    final p = await _sb
                        .from('profiles')
                        .select()
                        .eq('id', requesterId)
                        .maybeSingle();
                    if (p != null) {
                      inviterName = (p['display_name'] as String?) ?? inviterName;
                      inviterHandle = (p['handle'] as String?) ?? inviterHandle;
                    }
                  } catch (_) {}
                }

                if (relId != null && !_notifiedInviteIds.contains(relId)) {
                  _notifiedInviteIds.add(relId);
                  unawaited(_persistNotifiedInvites());
                }

                unawaited(ReminderService.instance.showReelInviteNotification(
                  inviterName: inviterName,
                  inviterHandle: inviterHandle,
                  inviteId: relId,
                ));

                inAppReminder.value =
                    'reel invite: $inviterName ($inviterHandle) wants to swap reels!';

                await _loadFriendsFromDb(uid);
                notifyListeners();
              } else if (event == PostgresChangeEvent.update &&
                  requesterId == uid &&
                  status == 'accepted') {
                // The friend accepted our reel invite!
                String friendName = 'co-star';
                String friendHandle = '@costar';
                if (addresseeId != null) {
                  try {
                    final p = await _sb
                        .from('profiles')
                        .select()
                        .eq('id', addresseeId)
                        .maybeSingle();
                    if (p != null) {
                      friendName = (p['display_name'] as String?) ?? friendName;
                      friendHandle = (p['handle'] as String?) ?? friendHandle;
                    }
                  } catch (_) {}
                }

                unawaited(ReminderService.instance.showReelAcceptedNotification(
                  friendName: friendName,
                  friendHandle: friendHandle,
                ));

                inAppReminder.value =
                    '$friendName ($friendHandle) joined your reel ✓';

                await _loadFriendsFromDb(uid);
                notifyListeners();
              } else {
                await _loadFriendsFromDb(uid);
                notifyListeners();
              }
            },
          )
          .subscribe();
    } catch (_) {}

    try {
      _cheersChannel = _sb
          .channel('public:scene_cheers:$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'scene_cheers',
            callback: (PostgresChangePayload payload) async {
              final event = payload.eventType;
              final newRecord = payload.newRecord;
              final sid = (newRecord['scene_id'] as num?)?.toInt();
              final cheererId = newRecord['user_id'] as String?;

              if (event == PostgresChangeEvent.insert && sid != null && cheererId != null && cheererId != uid) {
                var myEntry = _entries.values.where((e) => e.dbId == sid).firstOrNull;
                if (myEntry == null) {
                  try {
                    final sRow = await _sb.from('scenes').select('id, user_id, scene_date').eq('id', sid).maybeSingle();
                    if (sRow != null && sRow['user_id'] == uid) {
                      final dateStr = sRow['scene_date'] as String?;
                      if (dateStr != null) {
                        final parts = dateStr.split('-');
                        final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                        myEntry = _entries[dayKey(d)];
                      }
                    }
                  } catch (_) {}
                }

                if (myEntry != null) {
                  final cheerKey = '${sid}_$cheererId';
                  if (!_notifiedCheerKeys.contains(cheerKey)) {
                    _notifiedCheerKeys.add(cheerKey);
                    unawaited(_persistNotifiedCheers());

                    String cheererName = 'a co-star';
                    String cheererHandle = '';
                    final friend = friends.where((f) => f.id == cheererId).firstOrNull;
                    if (friend != null) {
                      cheererName = friend.name;
                      cheererHandle = friend.handle;
                    } else {
                      try {
                        final p = await _sb.from('profiles').select('display_name, handle').eq('id', cheererId).maybeSingle();
                        if (p != null) {
                          cheererName = (p['display_name'] as String?)?.trim() ?? cheererName;
                          cheererHandle = (p['handle'] as String?)?.trim() ?? '';
                        }
                      } catch (_) {}
                    }

                    final dateStr = dayLabel(myEntry.date);
                    final handlePart = cheererHandle.isNotEmpty ? ' ($cheererHandle)' : '';
                    inAppReminder.value = '$cheererName$handlePart cheered your scene for $dateStr! 🍿';

                    unawaited(ReminderService.instance.showSceneCheerNotification(
                      cheererName: cheererName,
                      cheererHandle: cheererHandle,
                      sceneDate: dateStr,
                      sceneId: sid,
                    ));
                  }
                }
              }

              await _loadFriendsFromDb(uid);
              notifyListeners();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> _syncProfileFields(Map<String, dynamic> fields) async {
    final uid = user?.id;
    if (uid == null) return;
    try {
      await _sb.from('profiles').update(fields).eq('id', uid);
    } catch (_) {
      // Ignore if offline or schema not applied yet.
    }
  }

  // ── demo seeds (used in offline preview mode) ──

  Map<String, Entry> _buildSceneMap(
    List<(int, int, Mood, String)> seeds, {
    int defaultCheers = 0,
    List<String> defaultCheeredBy = const [],
  }) {
    final map = <String, Entry>{};
    for (final (daysAgo, songIdx, mood, note) in seeds) {
      final d = DateTime(today.year, today.month, today.day - daysAgo);
      final count = daysAgo == 0
          ? defaultCheers
          : (defaultCheers > 0 ? (daysAgo % (defaultCheers + 1)) : 0);
      map[dayKey(d)] = Entry(
        date: d,
        song: catalog[songIdx % catalog.length],
        mood: mood,
        note: note,
        scene: sceneNo(d),
        cheers: count,
        cheeredByNames: count > 0 ? defaultCheeredBy : const [],
      );
    }
    return map;
  }

  void _seed() {
    _entries.addAll(_buildSceneMap(
      const <(int, int, Mood, String)>[
        (1, 1, dreamy, 'stared out the bus window pretending it was an opening montage.'),
        (2, 2, hopeful, 'sunlight hit the kitchen table right as the chorus dropped.'),
        (3, 4, tired, 'coffee went cold twice before noon, but the evening felt gentle.'),
        (4, 5, restless, 'walked three extra blocks just so the outro could finish.'),
        (5, 3, dreamy, 'rain on the fire escape – pure end-credits energy.'),
        (7, 8, tired, 'slow Sunday laundry & vinyl crackle in my head.'),
        (9, 9, hopeful, 'ran for the train and actually made it before the doors closed.'),
        (12, 6, dreamy, 'midnight kitchen snack with only the fridge light on.'),
        (15, 7, restless, 'typed a long message, deleted it, kept walking.'),
      ],
      defaultCheers: 2,
      defaultCheeredBy: const ['jules', 'theo'],
    ));
  }

  void _seedFriends() {
    friends.addAll(<Friend>[
      Friend(
        id: 'jules',
        name: 'jules',
        handle: '@jules',
        avatar: Hatch.diagonal,
        cheers: 3,
        entries: _buildSceneMap(
          const <(int, int, Mood, String)>[
            (0, 1, dreamy, 'missed my stop on the tram because the synth solo hit.'),
            (1, 5, restless, 'late-night corner-store iced tea & neon on wet pavement.'),
            (2, 2, hopeful, 'sketched strangers in the park until my pencil went blunt.'),
            (3, 8, dreamy, 'clouds looked painted on all afternoon.'),
            (5, 10, tired, 'fell asleep with my glasses still on.'),
            (8, 3, hopeful, 'found an old ticket stub folded inside my jacket pocket.'),
            (12, 11, restless, 'rewound the bridge four times in a row.'),
          ],
          defaultCheers: 3,
        ),
      ),
      Friend(
        id: 'theo',
        name: 'theo',
        handle: '@theo',
        avatar: Hatch.dots,
        cheers: 2,
        entries: _buildSceneMap(
          const <(int, int, Mood, String)>[
            (0, 7, restless, 'biked home racing the storm clouds – won by two minutes.'),
            (1, 9, hopeful, 'burnt the toast, nailed the espresso anyway.'),
            (2, 0, restless, 'long train platform goodbye that felt weirdly cinematic.'),
            (4, 6, tired, 'rain tapping the skylight while I did nothing at all.'),
            (6, 4, dreamy, 'rooftop air felt like October in an indie film.'),
            (10, 2, hopeful, 'golden hour bounced off every window down 4th street.'),
          ],
          defaultCheers: 2,
        ),
      ),
      Friend(
        id: 'mina',
        name: 'mina',
        handle: '@mina',
        avatar: Hatch.lines,
        cheers: 4,
        entries: _buildSceneMap(
          const <(int, int, Mood, String)>[
            (0, 9, hopeful, 'shared wired headphones on the library steps between classes.'),
            (1, 4, dreamy, 'hummed this in the grocery aisle without noticing.'),
            (2, 11, hopeful, 'bought yellow flowers for my desk for no reason.'),
            (3, 1, dreamy, 'ferry horn in the fog + warm paper cup.'),
            (4, 8, tired, 'long exhale after turning in the final draft.'),
            (7, 5, restless, 'danced around the kitchen waiting for pasta water to boil.'),
            (11, 3, dreamy, 'postcards on the fridge catching afternoon light.'),
          ],
          defaultCheers: 4,
        ),
      ),
    ]);

    if (sharedFriendIds.isEmpty) {
      sharedFriendIds.addAll(friends.map((f) => f.id));
    }

    invites.add(
      const FriendInvite(
        id: 'sora',
        name: 'sora',
        handle: '@sora',
        avatar: Hatch.cross,
        seedScenes: <(int, int, Mood, String)>[
          (0, 8, tired, 'tea on the windowsill watching headlights blur downstairs.'),
          (1, 10, dreamy, 'quiet bookstore corner while everyone hid from the drizzle.'),
          (3, 2, hopeful, 'first crisp breeze that actually felt like sweater weather.'),
          (6, 0, restless, 'scribbled lyrics in the margin of my lecture notes.'),
        ],
      ),
    );
  }

  // ── daily scenes & calendar ──

  bool get savedToday => _entries.containsKey(dayKey(today));

  int get sceneCount => _entries.length;

  int get streak {
    var count = 0;
    var offset = savedToday ? 0 : 1;
    while (true) {
      final d = DateTime(today.year, today.month, today.day - offset);
      if (_entries.containsKey(dayKey(d))) {
        count++;
        offset++;
      } else {
        break;
      }
    }
    return count;
  }

  Entry? entryFor(DateTime d) => _entries[dayKey(d)];

  List<Entry> get allScenes {
    final list = _entries.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  List<Entry> recent(int limit) {
    final list = _entries.values
        .where((e) => !sameDay(e.date, today))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list.take(limit).toList();
  }

  void setTab(int i) {
    if (tab == i) return;
    tab = i;
    notifyListeners();
  }

  void setSong(Song s) {
    if (draftSong == s) return;
    draftSong = s;
    notifyListeners();
    unawaited(_persistLastSong(s));
    unawaited(_warmDraftSong(s));
  }

  Future<void> _warmDraftSong(Song original) async {
    final prepared = await musicService.prepareAndCacheSong(original);
    if (draftSong.title == original.title &&
        draftSong.artist == original.artist &&
        draftSong != prepared) {
      draftSong = prepared;
      notifyListeners();
    }
  }

  void setMood(Mood m) {
    if (draftMood == m) return;
    draftMood = m;
    notifyListeners();
  }

  Hatch nextUnusedHatch() {
    final used = moods.map((m) => m.hatch).toSet();
    for (final h in Hatch.values) {
      if (h == Hatch.solid) continue;
      if (!used.contains(h)) return h;
    }
    return Hatch.values[(moods.length + 1) % Hatch.values.length];
  }

  Future<void> _persistLocalMoods() async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/custom_moods.json');
      final payload = moods.map((m) => {'name': m.name, 'hatch': m.hatch.name}).toList();
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {}
  }

  Future<void> _loadLocalMoods() async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/custom_moods.json');
      if (await file.exists()) {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.isNotEmpty) {
          final loadedMoods = <Mood>[];
          final seen = <String>{};
          for (final item in decoded) {
            if (item is Map) {
              final mName = (item['name'] as String?)?.trim().toLowerCase();
              final mHatch = hatchFromName(item['hatch'] as String?, Hatch.diagonal);
              if (mName != null && mName.isNotEmpty && seen.add(mName)) {
                loadedMoods.add(Mood(mName, mHatch));
              }
            }
          }
          if (loadedMoods.isNotEmpty) {
            moods
              ..clear()
              ..addAll(loadedMoods);
            if (!moods.any((m) => m.name.toLowerCase() == draftMood.name.toLowerCase())) {
              draftMood = moods.first;
            }
            notifyListeners();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _persistMoods() async {
    unawaited(_persistLocalMoods());
    final uid = user?.id;
    if (uid == null || !dbReady) return;
    final payload = moods.map((m) => {'name': m.name, 'hatch': m.hatch.name}).toList();
    await _syncProfileFields({'custom_moods': payload});
  }

  Mood? ensureMood(String raw, [Hatch? customHatch]) {
    final clean = raw.trim().toLowerCase();
    if (clean.isEmpty) return null;
    final existing = moods.where((m) => m.name.toLowerCase() == clean).firstOrNull;
    if (existing != null) {
      if (customHatch != null && existing.hatch != customHatch) {
        updateMood(existing, newName: existing.name, newHatch: customHatch);
      }
      return existing;
    }
    final hatch = customHatch ?? nextUnusedHatch();
    final created = Mood(clean, hatch);
    moods.add(created);
    notifyListeners();
    unawaited(_persistMoods());
    return created;
  }

  void addMood(String raw, [Hatch? customHatch]) {
    final resolved = ensureMood(raw, customHatch);
    if (resolved == null || draftMood == resolved) return;
    draftMood = resolved;
    notifyListeners();
  }

  bool updateMood(Mood oldMood, {required String newName, Hatch? newHatch}) {
    final clean = newName.trim().toLowerCase();
    if (clean.isEmpty) return false;
    final idx = moods.indexWhere((m) => m.name.toLowerCase() == oldMood.name.toLowerCase());
    if (idx == -1) return false;

    final targetHatch = newHatch ?? oldMood.hatch;
    final updated = Mood(clean, targetHatch);
    moods[idx] = updated;

    if (draftMood == oldMood || draftMood.name.toLowerCase() == oldMood.name.toLowerCase()) {
      draftMood = updated;
    }

    _entries.forEach((k, v) {
      if (v.mood == oldMood || v.mood.name.toLowerCase() == oldMood.name.toLowerCase()) {
        _entries[k] = Entry(
          dbId: v.dbId,
          date: v.date,
          song: v.song,
          mood: updated,
          note: v.note,
          scene: v.scene,
          cheers: v.cheers,
          cheeredByMe: v.cheeredByMe,
        );
      }
    });

    notifyListeners();
    unawaited(_persistMoods());

    final uid = user?.id;
    if (uid != null && dbReady) {
      unawaited(() async {
        try {
          final escaped = oldMood.name.replaceAll('%', r'\%').replaceAll('_', r'\_');
          await _sb
              .from('scenes')
              .update(<String, dynamic>{
                'mood_name': clean,
                'mood_hatch': targetHatch.name,
              })
              .eq('user_id', uid)
              .ilike('mood_name', escaped);
        } catch (e) {
          debugPrint('updateMood scenes DB update error: $e');
        }
      }());
    }

    return true;
  }

  bool deleteMood(Mood mood) {
    if (moods.length <= 1) return false;
    final idx = moods.indexWhere((m) => m.name.toLowerCase() == mood.name.toLowerCase());
    if (idx == -1) return false;
    moods.removeAt(idx);

    final fallbackMood = moods.first;

    if (draftMood == mood || draftMood.name.toLowerCase() == mood.name.toLowerCase()) {
      draftMood = fallbackMood;
    }

    _entries.forEach((k, v) {
      if (v.mood == mood || v.mood.name.toLowerCase() == mood.name.toLowerCase()) {
        _entries[k] = Entry(
          dbId: v.dbId,
          date: v.date,
          song: v.song,
          mood: fallbackMood,
          note: v.note,
          scene: v.scene,
          cheers: v.cheers,
          cheeredByMe: v.cheeredByMe,
        );
      }
    });

    notifyListeners();
    unawaited(_persistMoods());

    final uid = user?.id;
    if (uid != null && dbReady) {
      unawaited(() async {
        try {
          final escaped = mood.name.replaceAll('%', r'\%').replaceAll('_', r'\_');
          await _sb
              .from('scenes')
              .update(<String, dynamic>{
                'mood_name': fallbackMood.name,
                'mood_hatch': fallbackMood.hatch.name,
              })
              .eq('user_id', uid)
              .ilike('mood_name', escaped);
        } catch (e) {
          debugPrint('deleteMood scenes DB update error: $e');
        }
      }());
    }

    return true;
  }

  Future<bool> saveToday() async {
    selected = today;
    return await saveSceneForDate(
      today,
      song: draftSong,
      mood: draftMood,
      note: noteCtl.text,
    );
  }

  Future<bool> saveSceneForDate(
    DateTime date, {
    required Song song,
    required Mood mood,
    required String note,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    var resolvedSong = song;
    if (resolvedSong.videoId == null &&
        musicService.isCurrentSong(resolvedSong) &&
        musicService.currentSong?.videoId != null) {
      resolvedSong = resolvedSong.copyWith(
        videoId: musicService.currentSong!.videoId,
        coverUrl: resolvedSong.coverUrl ?? musicService.currentSong!.coverUrl,
      );
    }

    if (!moods.any((m) => m.name.toLowerCase() == mood.name.toLowerCase())) {
      moods.add(mood);
      unawaited(_persistMoods());
    }

    final text = note.trim();
    final cleanNote = text.isEmpty
        ? 'no dialogue today – just let the soundtrack carry the scene.'
        : text;

    final key = dayKey(normalizedDate);
    final seq = (_sceneOpSeq[key] ?? 0) + 1;
    _sceneOpSeq[key] = seq;

    final prev = _entries[key];
    final entry = Entry(
      dbId: prev?.dbId,
      date: normalizedDate,
      song: resolvedSong,
      mood: mood,
      note: cleanNote,
      scene: prev?.scene ?? sceneNo(normalizedDate),
      cheers: prev?.cheers ?? 0,
      cheeredByMe: prev?.cheeredByMe ?? false,
    );
    _entries[key] = entry;

    if (sameDay(normalizedDate, today)) {
      draftSong = resolvedSong;
      draftMood = mood;
      if (noteCtl.text.trim() != cleanNote && text.isNotEmpty) {
        noteCtl.text = cleanNote;
      }
    }

    notifyListeners();
    unawaited(_persistLastSong(resolvedSong));
    if (sameDay(normalizedDate, today)) {
      unawaited(_rescheduleReminders());
    }
    return await _cacheAndSyncScene(key, entry, seq);
  }

  Future<void> deleteSceneForDate(DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final key = dayKey(normalizedDate);
    final seq = (_sceneOpSeq[key] ?? 0) + 1;
    _sceneOpSeq[key] = seq;

    final removed = _entries.remove(key);
    if (removed == null) return;
    notifyListeners();
    if (sameDay(normalizedDate, today)) {
      unawaited(_rescheduleReminders());
    }

    final uid = user?.id;
    if (uid == null) return;
    try {
      await _sb
          .from('scenes')
          .delete()
          .eq('user_id', uid)
          .eq('scene_date', key);
    } catch (e) {
      debugPrint('deleteSceneForDate error: $e');
    }
  }

  Future<bool> _cacheAndSyncScene(String key, Entry entry, int seq) async {
    if (_sceneOpSeq[key] != seq) return false;
    var currentEntry = entry;
    final uid = user?.id;
    var syncSuccess = true;
    if (uid != null) {
      syncSuccess = await _persistScene(uid, key, currentEntry, seq);
      if (_sceneOpSeq[key] != seq) return syncSuccess;
      currentEntry = _entries[key] ?? currentEntry;
    }

    // Invisibly resolve YouTube videoId (when chosen via iTunes) & download audio
    // locally so future Calendar visits load in 0ms offline.
    final preparedSong = await musicService.prepareAndCacheSong(currentEntry.song);
    if (_sceneOpSeq[key] != seq) return syncSuccess;
    if (preparedSong != currentEntry.song) {
      final latest = _entries[key];
      if (latest != null &&
          latest.song.title == currentEntry.song.title &&
          latest.song.artist == currentEntry.song.artist) {
        final updated = latest.copyWith(song: preparedSong);
        _entries[key] = updated;
        if (draftSong.title == preparedSong.title &&
            draftSong.artist == preparedSong.artist) {
          draftSong = preparedSong;
        }
        notifyListeners();
        final nextUid = user?.id;
        if (nextUid != null) {
          await _persistScene(nextUid, key, updated, seq);
        }
      }
    }
    return syncSuccess;
  }

  static const _legacyHatches = <String>{
    'solid',
    'diagonal',
    'cross',
    'lines',
    'dots',
  };

  @visibleForTesting
  static String legacySafeHatch(String raw) => _legacySafeHatch(raw);

  static String _legacySafeHatch(String raw) {
    if (_legacyHatches.contains(raw)) return raw;
    return 'diagonal';
  }

  Future<bool> _persistScene(String uid, String key, Entry entry, int seq) async {
    if (_sceneOpSeq[key] != seq) return false;

    // Ensure user profile exists so foreign key constraint scenes_user_id_fkey is satisfied
    if (!dbReady) {
      await _ensureProfileExists(uid);
    }

    final safeSongArt = entry.song.art.name;
    final safeMoodHatch = entry.mood.hatch.name;

    Map<String, dynamic> buildPayload({
      required bool includeMediaCols,
      required bool forceLegacyHatches,
    }) {
      final art = forceLegacyHatches ? _legacySafeHatch(safeSongArt) : safeSongArt;
      final hatch = forceLegacyHatches ? _legacySafeHatch(safeMoodHatch) : safeMoodHatch;
      return <String, dynamic>{
        'user_id': uid,
        'scene_date': key,
        'scene_no': entry.scene,
        'song_title': entry.song.title,
        'song_artist': entry.song.artist,
        'song_seconds': math.max(0, entry.song.seconds),
        'song_art': art,
        'mood_name': entry.mood.name,
        'mood_hatch': hatch,
        'note': entry.note,
        if (includeMediaCols && entry.song.videoId != null)
          'song_video_id': entry.song.videoId,
        if (includeMediaCols && entry.song.coverUrl != null)
          'song_cover_url': entry.song.coverUrl,
      };
    }

    Future<Map<String, dynamic>?> trySave(Map<String, dynamic> payload) async {
      // 1. If entry has an existing dbId, attempt direct update by primary key first
      if (entry.dbId != null) {
        try {
          final updated = await _sb
              .from('scenes')
              .update(payload)
              .eq('id', entry.dbId!)
              .eq('user_id', uid)
              .select('id')
              .maybeSingle();
          if (updated != null) return updated;
        } catch (e) {
          debugPrint('Update by dbId ${entry.dbId} failed, falling back: $e');
        }
      }

      // 2. Standard upsert on (user_id, scene_date)
      try {
        return await _sb
            .from('scenes')
            .upsert(payload, onConflict: 'user_id,scene_date')
            .select('id')
            .maybeSingle();
      } on PostgrestException catch (e) {
        final code = e.code ?? '';
        final isConflictMismatch = code == '42P10' ||
            code == 'PGRST100' ||
            code == '23505' ||
            e.message.contains('ON CONFLICT');

        if (isConflictMismatch) {
          // Fallback: check if row exists, then update or insert
          final existing = await _sb
              .from('scenes')
              .select('id')
              .eq('user_id', uid)
              .eq('scene_date', key)
              .maybeSingle();
          if (existing != null) {
            final sid = (existing['id'] as num?)?.toInt();
            if (sid != null) {
              return await _sb
                  .from('scenes')
                  .update(payload)
                  .eq('id', sid)
                  .eq('user_id', uid)
                  .select('id')
                  .maybeSingle();
            }
          }
          return await _sb
              .from('scenes')
              .insert(payload)
              .select('id')
              .maybeSingle();
        }
        rethrow;
      }
    }

    try {
      Map<String, dynamic>? saved;
      try {
        saved = await trySave(buildPayload(includeMediaCols: true, forceLegacyHatches: false));
      } on PostgrestException catch (e) {
        final code = e.code ?? '';
        final isMissingCol = code == 'PGRST204' ||
            code == '42703' ||
            e.message.contains('song_video_id') ||
            e.message.contains('song_cover_url');
        final isCheckViolation = code == '23514' || e.message.contains('check constraint');
        final isFkeyViolation = code == '23503' || e.message.contains('foreign key');

        if (isMissingCol) {
          saved = await trySave(buildPayload(includeMediaCols: false, forceLegacyHatches: false));
        } else if (isCheckViolation) {
          // Retry with legacy safe hatch names in case remote DB has older check constraint
          debugPrint('Check constraint encountered, retrying with legacy safe hatches: $e');
          saved = await trySave(buildPayload(includeMediaCols: true, forceLegacyHatches: true));
        } else if (isFkeyViolation) {
          // Provision profile and retry
          debugPrint('Foreign key missing for user profile, provisioning and retrying: $e');
          await _ensureProfileExists(uid);
          saved = await trySave(buildPayload(includeMediaCols: true, forceLegacyHatches: false));
        } else {
          rethrow;
        }
      }

      if (_sceneOpSeq[key] != seq) {
        // Scene was deleted while upsert was in-flight; ensure DB matches.
        if (!_entries.containsKey(key)) {
          await _sb
              .from('scenes')
              .delete()
              .eq('user_id', uid)
              .eq('scene_date', key);
        }
        return true;
      }

      final dbId = (saved?['id'] as num?)?.toInt();
      if (dbId != null && _entries[key] != null) {
        _entries[key] = _entries[key]!.copyWith(dbId: dbId);
      }
      return true;
    } catch (e) {
      debugPrint('Failed to persist scene for $key to DB: $e');
      return false;
    }
  }

  void shiftMonth(int delta) {
    viewMonth = DateTime(viewMonth.year, viewMonth.month + delta, 1);
    notifyListeners();
  }

  void select(DateTime d) {
    if (sameDay(selected, d)) return;
    selected = DateTime(d.year, d.month, d.day);
    notifyListeners();
  }

  void showDay(DateTime d) {
    selected = DateTime(d.year, d.month, d.day);
    viewMonth = DateTime(d.year, d.month, 1);
    tab = 1;
    notifyListeners();
  }

  void goToToday() {
    selected = today;
    viewMonth = DateTime(today.year, today.month, 1);
    notifyListeners();
  }

  // ── friends & shared calendars ──

  void toggleSharing() {
    sharingEnabled = !sharingEnabled;
    notifyListeners();
    unawaited(_persistSharingSettings());
    unawaited(_syncProfileFields(<String, dynamic>{
      'sharing_enabled': sharingEnabled,
      'sharing_audience': sharingAudience,
      'shared_friend_ids': sharedFriendIds.toList(),
    }));
  }

  void setSharingAudience(String audience) {
    if (audience != 'all' && audience != 'specific') return;
    sharingAudience = audience;
    if (sharingAudience == 'specific' && sharedFriendIds.isEmpty && friends.isNotEmpty) {
      sharedFriendIds = friends.map((f) => f.id).toSet();
    }
    notifyListeners();
    unawaited(_persistSharingSettings());
    unawaited(_syncProfileFields(<String, dynamic>{
      'sharing_audience': sharingAudience,
      'shared_friend_ids': sharedFriendIds.toList(),
    }));
  }

  void toggleFriendSharing(String friendId) {
    if (sharingAudience == 'all') {
      sharingAudience = 'specific';
      sharedFriendIds = friends.map((f) => f.id).toSet();
    }
    if (sharedFriendIds.contains(friendId)) {
      sharedFriendIds.remove(friendId);
    } else {
      sharedFriendIds.add(friendId);
    }
    notifyListeners();
    unawaited(_persistSharingSettings());
    unawaited(_syncProfileFields(<String, dynamic>{
      'sharing_audience': sharingAudience,
      'shared_friend_ids': sharedFriendIds.toList(),
    }));
  }

  void setFriendSharing(String friendId, bool shared) {
    if (sharingAudience == 'all') {
      sharingAudience = 'specific';
      sharedFriendIds = friends.map((f) => f.id).toSet();
    }
    if (shared) {
      sharedFriendIds.add(friendId);
    } else {
      sharedFriendIds.remove(friendId);
    }
    notifyListeners();
    unawaited(_persistSharingSettings());
    unawaited(_syncProfileFields(<String, dynamic>{
      'sharing_audience': sharingAudience,
      'shared_friend_ids': sharedFriendIds.toList(),
    }));
  }

  void shareWithAllFriends() {
    sharingAudience = 'specific';
    sharedFriendIds = friends.map((f) => f.id).toSet();
    notifyListeners();
    unawaited(_persistSharingSettings());
    unawaited(_syncProfileFields(<String, dynamic>{
      'sharing_audience': sharingAudience,
      'shared_friend_ids': sharedFriendIds.toList(),
    }));
  }

  void unshareAllFriends() {
    sharingAudience = 'specific';
    sharedFriendIds.clear();
    notifyListeners();
    unawaited(_persistSharingSettings());
    unawaited(_syncProfileFields(<String, dynamic>{
      'sharing_audience': sharingAudience,
      'shared_friend_ids': <String>[],
    }));
  }

  void toggleCompareCalendar() {
    compareCalendar = !compareCalendar;
    notifyListeners();
  }

  void selectFriend(String id) {
    if (activeFriendId == id) return;
    activeFriendId = id;
    notifyListeners();
  }

  void openFriendCalendar(String id) {
    final targetMonth = DateTime(today.year, today.month, 1);
    if (activeFriendId == id &&
        sameDay(friendSelectedDate, today) &&
        friendViewMonth == targetMonth) {
      return;
    }
    activeFriendId = id;
    friendSelectedDate = today;
    friendViewMonth = targetMonth;
    notifyListeners();
  }

  void shiftFriendMonth(int delta) {
    friendViewMonth = DateTime(friendViewMonth.year, friendViewMonth.month + delta, 1);
    notifyListeners();
  }

  void selectFriendDate(DateTime d) {
    if (sameDay(friendSelectedDate, d)) return;
    friendSelectedDate = DateTime(d.year, d.month, d.day);
    notifyListeners();
  }

  bool isSceneCheered(Friend friend, DateTime date) {
    final entry = friend.entryFor(date);
    return entry?.cheeredByMe ?? false;
  }

  int sceneCheerCount(Friend friend, DateTime date) {
    final entry = friend.entryFor(date);
    return entry?.cheers ?? 0;
  }

  void toggleCheerScene(Friend friend, DateTime date) {
    final key = dayKey(date);
    final entry = friend.entries[key];
    if (entry == null) return;

    final nextCheered = !entry.cheeredByMe;
    final nextCheers = math.max(0, entry.cheers + (nextCheered ? 1 : -1));

    friend.entries[key] = entry.copyWith(
      cheers: nextCheers,
      cheeredByMe: nextCheered,
    );

    if (sameDay(date, today)) {
      friend.cheeredToday = nextCheered;
      friend.cheers = nextCheers;
    }

    notifyListeners();

    final uid = user?.id;
    final sceneId = entry.dbId;
    if (uid != null && sceneId != null) {
      unawaited(_persistCheer(uid, sceneId, nextCheered));
    }
  }

  void toggleCheerFriend(String id) {
    final f = friends.where((e) => e.id == id).firstOrNull;
    if (f == null) return;
    toggleCheerScene(f, today);
  }

  Future<void> _persistCheer(String uid, int sceneId, bool cheered) async {
    try {
      if (cheered) {
        await _sb.from('scene_cheers').upsert(
          <String, dynamic>{'scene_id': sceneId, 'user_id': uid},
          onConflict: 'scene_id,user_id',
        );
      } else {
        await _sb
            .from('scene_cheers')
            .delete()
            .eq('scene_id', sceneId)
            .eq('user_id', uid);
      }
    } catch (_) {}
  }

  Friend? acceptInvite(String id) {
    final idx = invites.indexWhere((e) => e.id == id);
    if (idx < 0) return null;
    final inv = invites.removeAt(idx);
    final friend = Friend(
      id: inv.id,
      name: inv.name,
      handle: inv.handle,
      avatar: inv.avatar,
      avatarUrl: inv.avatarUrl,
      entries: inv.seedScenes.isEmpty ? <String, Entry>{} : _buildSceneMap(inv.seedScenes, defaultCheers: 1),
      friendshipId: inv.friendshipId,
      cheers: inv.seedScenes.isEmpty ? 0 : 1,
    );
    friends.insert(0, friend);
    activeFriendId = friend.id;
    friendViewMonth = DateTime(today.year, today.month, 1);
    friendSelectedDate = today;
    notifyListeners();

    final uid = user?.id;
    if (uid != null && inv.friendshipId != null) {
      unawaited(_acceptDbInvite(uid, inv.friendshipId!));
    }
    return friend;
  }

  Future<void> _acceptDbInvite(String uid, int friendshipId) async {
    try {
      await _sb
          .from('friendships')
          .update(<String, dynamic>{'status': 'accepted'})
          .eq('id', friendshipId);
      await _loadFriendsFromDb(uid);
      notifyListeners();
    } catch (_) {}
  }

  void dismissInvite(String id) {
    final inv = invites.where((e) => e.id == id).firstOrNull;
    if (inv == null) return;
    invites.removeWhere((e) => e.id == id);
    notifyListeners();

    if (user != null && inv.friendshipId != null) {
      unawaited(
        _sb
            .from('friendships')
            .delete()
            .eq('id', inv.friendshipId!)
            .then((_) {}, onError: (_) {}),
      );
    }
  }

  /// Removes a connected co-star, unlinks their shared soundtrack & calendar,
  /// and deletes the friendship row from Supabase if authenticated.
  Future<bool> removeFriend(String id) async {
    final idx = friends.indexWhere((f) => f.id == id);
    if (idx < 0) return false;
    final removed = friends.removeAt(idx);

    if (activeFriendId == id) {
      activeFriendId = friends.firstOrNull?.id ?? '';
    }
    if (sharedFriendIds.contains(id)) {
      sharedFriendIds.remove(id);
      unawaited(_persistSharingSettings());
      unawaited(_syncProfileFields(<String, dynamic>{
        'shared_friend_ids': sharedFriendIds.toList(),
      }));
    }
    notifyListeners();

    final uid = user?.id;
    if (uid != null && dbReady) {
      try {
        if (removed.friendshipId != null) {
          await _sb
              .from('friendships')
              .delete()
              .eq('id', removed.friendshipId!);
        }
        await _sb
            .from('friendships')
            .delete()
            .eq('requester_id', uid)
            .eq('addressee_id', id);
        await _sb
            .from('friendships')
            .delete()
            .eq('requester_id', id)
            .eq('addressee_id', uid);
      } catch (_) {}
    }
    return true;
  }

  /// Connects with a co-star via Supabase `profiles` + `friendships` when
  /// signed in with database tables active, or falls back to local preview.
  Future<String?> connectCoStar(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final uid = user?.id;
    if (uid != null && dbReady) {
      try {
        final upperCode = trimmed.toUpperCase();
        final normalizedHandle =
            trimmed.startsWith('@') ? trimmed.toLowerCase() : '@${trimmed.toLowerCase()}';

        Map<String, dynamic>? target = await _sb
            .from('profiles')
            .select()
            .eq('invite_code', upperCode)
            .maybeSingle();

        target ??= await _sb
            .from('profiles')
            .select()
            .eq('handle', normalizedHandle)
            .maybeSingle();

        if (target == null) {
          return 'no director found for "$trimmed" – check their ticket code';
        }

        final targetId = target['id'] as String;
        final targetName = (target['display_name'] as String?) ?? 'friend';
        if (targetId == uid) {
          return 'that\'s your own reel ticket!';
        }

        final existingFriend = friends.where((f) => f.id == targetId).firstOrNull;
        if (existingFriend != null) {
          activeFriendId = existingFriend.id;
          notifyListeners();
          return 'already connected with ${existingFriend.name} ✓';
        }

        final incoming = invites.where((i) => i.id == targetId).firstOrNull;
        if (incoming != null) {
          acceptInvite(incoming.id);
          return 'accepted $targetName\'s invite – calendars synced ✓';
        }

        await _sb.from('friendships').insert(<String, dynamic>{
          'requester_id': uid,
          'addressee_id': targetId,
          'status': 'pending',
        });
        return 'reel invite sent to $targetName ✓';
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          return 'invite already pending – waiting on them to accept';
        }
      } catch (_) {}
    }

    final local = addFriend(trimmed);
    return local == null ? null : 'connected with ${local.name} – calendars synced ✓';
  }

  Friend? addFriend(String raw) {
    var clean = raw.trim();
    if (clean.isEmpty) return null;
    if (clean.startsWith('@')) clean = clean.substring(1);
    if (clean.contains('-')) clean = clean.split('-').first;
    clean = clean.trim().toLowerCase();
    if (clean.isEmpty) return null;

    final existing = friends.where((f) => f.name.toLowerCase() == clean).firstOrNull;
    if (existing != null) {
      activeFriendId = existing.id;
      notifyListeners();
      return existing;
    }

    final pendingMatch = invites.where((i) => i.name.toLowerCase() == clean).firstOrNull;
    if (pendingMatch != null) {
      return acceptInvite(pendingMatch.id);
    }

    final rnd = math.Random(clean.hashCode);
    const coreMoods = <Mood>[hopeful, restless, dreamy, tired];
    const sampleNotes = <String>[
      'walked past the cinema just as the marquee lights switched on.',
      'window seat on the afternoon train – instant main-character moment.',
      'hummed the chorus all the way up the stairwell.',
      'quiet coffee break while the street outside moved in fast-forward.',
      'sunset turned the parking lot into a postcard.',
    ];
    final scenes = <(int, int, Mood, String)>[
      (
        0,
        rnd.nextInt(catalog.length),
        coreMoods[rnd.nextInt(coreMoods.length)],
        sampleNotes[rnd.nextInt(sampleNotes.length)],
      ),
      for (final d in <int>[1, 3, 5, 8, 11])
        (
          d,
          rnd.nextInt(catalog.length),
          coreMoods[rnd.nextInt(coreMoods.length)],
          sampleNotes[rnd.nextInt(sampleNotes.length)],
        ),
    ];

    const avatarChoices = <Hatch>[Hatch.diagonal, Hatch.cross, Hatch.dots, Hatch.lines];
    final created = Friend(
      id: '${clean}_${friends.length + 1}',
      name: clean,
      handle: '@$clean',
      avatar: avatarChoices[friends.length % avatarChoices.length],
      entries: _buildSceneMap(scenes),
      cheers: 1,
    );
    friends.insert(0, created);
    activeFriendId = created.id;
    friendViewMonth = DateTime(today.year, today.month, 1);
    friendSelectedDate = today;
    notifyListeners();
    return created;
  }

  // ── settings & account management ──

  void setName(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty || clean == name) return;
    name = clean;
    notifyListeners();
    unawaited(_syncProfileFields(<String, dynamic>{'display_name': clean}));
    if (user != null) {
      unawaited(
        _sb.auth
            .updateUser(UserAttributes(data: <String, dynamic>{'display_name': clean}))
            .then((_) {}, onError: (_) {}),
      );
    }
  }

  /// Updates both the display name ("director name") and unique `@handle` ("username").
  /// Returns `null` on success, or a user-facing error message if validation/uniqueness fails.
  Future<String?> updateProfile({
    required String displayName,
    required String handleInput,
  }) async {
    final cleanName = displayName.trim();
    if (cleanName.isEmpty) {
      return 'director name cannot be empty.';
    }
    if (cleanName.length > 32) {
      return 'director name must be 32 characters or fewer.';
    }

    var rawHandle = handleInput.trim().toLowerCase();
    if (rawHandle.startsWith('@')) {
      rawHandle = rawHandle.substring(1);
    }
    if (!RegExp(r'^[a-z0-9_]{2,20}$').hasMatch(rawHandle)) {
      return 'username must be 2–20 lowercase letters, numbers, or underscores.';
    }
    final normalizedHandle = '@$rawHandle';

    final uid = user?.id;
    if (uid != null && dbReady) {
      try {
        await _sb.from('profiles').update(<String, dynamic>{
          'display_name': cleanName,
          'handle': normalizedHandle,
        }).eq('id', uid);
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          return 'that username ($normalizedHandle) is already taken – try another.';
        }
        return 'couldn\'t save profile changes – please try again.';
      } catch (_) {
        return 'couldn\'t reach Supabase – check your connection.';
      }

      unawaited(
        _sb.auth
            .updateUser(
              UserAttributes(
                data: <String, dynamic>{
                  'display_name': cleanName,
                  'handle': normalizedHandle,
                },
              ),
            )
            .then((_) {}, onError: (_) {}),
      );
    }

    name = cleanName;
    _dbHandle = normalizedHandle;
    notifyListeners();
    return null;
  }

  void setAvatarHatch(Hatch hatch, {bool clearPhoto = false}) {
    avatarHatch = hatch;
    if (clearPhoto) {
      avatarUrl = null;
      avatarMemoryBytes = null;
      unawaited(
        _syncProfileFields(<String, dynamic>{
          'avatar_hatch': hatch.name,
          'avatar_url': null,
        }),
      );
    } else {
      unawaited(
        _syncProfileFields(<String, dynamic>{
          'avatar_hatch': hatch.name,
        }),
      );
    }
    notifyListeners();
  }

  Future<void> removeAvatarPhoto() async {
    avatarUrl = null;
    avatarMemoryBytes = null;
    notifyListeners();
    await _syncProfileFields(<String, dynamic>{'avatar_url': null});
    if (user != null) {
      unawaited(
        _sb.auth
            .updateUser(UserAttributes(data: <String, dynamic>{'avatar_url': null}))
            .then((_) {}, onError: (_) {}),
      );
    }
  }

  /// Uploads a profile image to Supabase Storage (`avatars` bucket) and updates `profiles.avatar_url`.
  /// Always updates [avatarMemoryBytes] immediately so the UI reflects the new photo right away.
  Future<String?> uploadAvatarBytes(Uint8List bytes, String fileExtension) async {
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      return 'image must be smaller than 5 MB.';
    }

    avatarMemoryBytes = bytes;
    notifyListeners();

    final uid = user?.id;
    if (uid == null) {
      return null;
    }

    final ext = switch (fileExtension.toLowerCase().replaceAll('.', '')) {
      'png' => 'png',
      'webp' => 'webp',
      'gif' => 'gif',
      _ => 'jpg',
    };
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
    final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

    try {
      await _sb.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime, upsert: true),
          );
      final publicUrl = _sb.storage.from('avatars').getPublicUrl(path);
      avatarUrl = publicUrl;
      notifyListeners();

      await _syncProfileFields(<String, dynamic>{'avatar_url': publicUrl});
      unawaited(
        _sb.auth
            .updateUser(UserAttributes(data: <String, dynamic>{'avatar_url': publicUrl}))
            .then((_) {}, onError: (_) {}),
      );
      return null;
    } on StorageException catch (e) {
      if (e.message.toLowerCase().contains('bucket not found')) {
        return 'photo set for this session (re-run supabase/schema.sql to create the "avatars" storage bucket).';
      }
      return 'photo set locally – cloud upload failed (${e.message}).';
    } catch (_) {
      return 'photo set locally – couldn\'t sync to cloud right now.';
    }
  }

  void toggle(String key) {
    switch (key) {
      case 'reminder':
        dailyReminder = !dailyReminder;
        unawaited(_syncProfileFields(<String, dynamic>{'daily_reminder': dailyReminder}));
        unawaited(_persistReminderSettings());
        unawaited(_rescheduleReminders());
      case 'prompts':
        moodPrompts = !moodPrompts;
        unawaited(_syncProfileFields(<String, dynamic>{'mood_prompts': moodPrompts}));
      case 'lock':
        privacyLock = !privacyLock;
        unawaited(_syncProfileFields(<String, dynamic>{'privacy_lock': privacyLock}));
    }
    notifyListeners();
  }

  void setPaper(String p) {
    if (paper == p) return;
    paper = p;
    notifyListeners();
    unawaited(_syncProfileFields(<String, dynamic>{'paper': p}));
  }

  // ── Daily Reminder (local notifications) ──

  String get reminderTimeLabel {
    final h12 = reminderHour % 12 == 0 ? 12 : reminderHour % 12;
    final mm = reminderMinute.toString().padLeft(2, '0');
    final ampm = reminderHour < 12 ? 'am' : 'pm';
    return '$h12:$mm $ampm';
  }

  /// Turns the daily reminder on/off. When enabling, asks the OS for
  /// notification permission first. Returns `false` if permission was denied.
  Future<bool> setDailyReminder(bool enabled) async {
    if (enabled && ReminderService.instance.isSupported) {
      final granted = await ReminderService.instance.requestPermission();
      if (!granted) return false;
      await ReminderService.instance.requestExactAlarms();
    }
    dailyReminder = enabled;
    notifyListeners();
    unawaited(_syncProfileFields(<String, dynamic>{'daily_reminder': enabled}));
    await _persistReminderSettings();
    await _rescheduleReminders();
    return true;
  }

  /// Returns `false` if notifications are blocked by the OS.
  Future<bool> setReminderTime(int hour, int minute) async {
    reminderHour = hour.clamp(0, 23);
    reminderMinute = minute.clamp(0, 59);
    notifyListeners();
    var granted = true;
    if (dailyReminder && ReminderService.instance.isSupported) {
      granted = await ReminderService.instance.requestPermission();
      if (granted) {
        await ReminderService.instance.requestExactAlarms();
      }
    }
    await _persistReminderSettings();
    await _rescheduleReminders();
    return granted;
  }

  Future<void> _rescheduleReminders() async {
    _planInAppReminder();
    try {
      await ReminderService.instance.reschedule(
        enabled: dailyReminder && isAuthenticated,
        hour: reminderHour,
        minute: reminderMinute,
        skipToday: savedToday,
      );
    } catch (_) {}
  }

  // ── In-app reminder banner (fires while the app is open) ──

  /// Message for the in-app reminder banner; `null` when nothing to show.
  final ValueNotifier<String?> inAppReminder = ValueNotifier<String?>(null);
  Timer? _inAppReminderTimer;
  bool _reminderPermissionAsked = false;

  void _planInAppReminder() {
    _inAppReminderTimer?.cancel();
    _inAppReminderTimer = null;
    if (!dailyReminder || !isAuthenticated) return;
    final now = DateTime.now();
    var when = DateTime(now.year, now.month, now.day, reminderHour, reminderMinute);
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    _inAppReminderTimer = Timer(when.difference(now), () {
      _inAppReminderTimer = null;
      if (dailyReminder && isAuthenticated && !savedToday) {
        inAppReminder.value = ReminderService.messageFor(DateTime.now());
      }
      _planInAppReminder();
    });
  }

  void dismissInAppReminder() => inAppReminder.value = null;

  /// Called once after the first frame: make sure OS notification permission
  /// has been requested so both daily reminders and incoming reel invites can notify.
  Future<void> ensureReminderPermission() async {
    if (_reminderPermissionAsked) return;
    _reminderPermissionAsked = true;
    if (!ReminderService.instance.isSupported) return;
    final enabled = await ReminderService.instance.notificationsEnabled();
    if (!enabled) {
      await ReminderService.instance.requestPermission();
    }
    await _rescheduleReminders();
  }

  /// Re-plan reminders and sync pending invites when returning to foreground.
  void onAppResumed() {
    unawaited(_rescheduleReminders());
    final uid = user?.id;
    if (uid != null && dbReady) {
      unawaited(refreshFriends());
    }
  }

  /// Posts a notification right now + shows the in-app banner so the user can
  /// verify reminders work. Returns `false` if notifications are blocked.
  Future<bool> sendTestReminder() async {
    final msg = ReminderService.messageFor(DateTime.now());
    inAppReminder.value = msg;
    if (!ReminderService.instance.isSupported) return true;
    var enabled = await ReminderService.instance.notificationsEnabled();
    if (!enabled) {
      enabled = await ReminderService.instance.requestPermission();
    }
    if (!enabled) return false;
    return ReminderService.instance.showNow(body: msg);
  }

  Future<void> _loadReminderSettings() async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/reminder.json');
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          reminderHour = ((decoded['hour'] as num?)?.toInt() ?? reminderHour).clamp(0, 23);
          reminderMinute = ((decoded['minute'] as num?)?.toInt() ?? reminderMinute).clamp(0, 59);
          dailyReminder = (decoded['enabled'] as bool?) ?? dailyReminder;
        }
      }
    } catch (_) {}
  }

  Future<void> _persistReminderSettings() async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/reminder.json');
      await file.writeAsString(
        jsonEncode(<String, dynamic>{
          'hour': reminderHour,
          'minute': reminderMinute,
          'enabled': dailyReminder,
        }),
        flush: true,
      );
    } catch (_) {}
  }

  Future<void> _persistSharingSettings() async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/sharing_settings.json');
      await file.writeAsString(
        jsonEncode(<String, dynamic>{
          'sharing_enabled': sharingEnabled,
          'sharing_audience': sharingAudience,
          'shared_friend_ids': sharedFriendIds.toList(),
        }),
        flush: true,
      );
    } catch (_) {}
  }

  Future<void> _loadSharingSettings() async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/sharing_settings.json');
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>?;
        if (data != null) {
          sharingEnabled = (data['sharing_enabled'] as bool?) ?? sharingEnabled;
          sharingAudience = (data['sharing_audience'] as String?) ?? sharingAudience;
          final ids = data['shared_friend_ids'];
          if (ids is List) {
            sharedFriendIds = ids.whereType<String>().toSet();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadNotifiedInvites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('notified_invite_ids');
      if (list != null && list.isNotEmpty) {
        _notifiedInviteIds.addAll(list.map((e) => int.tryParse(e)).whereType<int>());
        return;
      }
    } catch (_) {}

    if (!kIsWeb) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final file = File('${docs.path}/notified_invites.json');
        if (await file.exists()) {
          final list = jsonDecode(await file.readAsString()) as List<dynamic>?;
          if (list != null) {
            _notifiedInviteIds.addAll(list.whereType<num>().map((e) => e.toInt()));
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _persistNotifiedInvites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('notified_invite_ids', _notifiedInviteIds.map((e) => e.toString()).toList());
    } catch (_) {}

    if (!kIsWeb) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final file = File('${docs.path}/notified_invites.json');
        await file.writeAsString(jsonEncode(_notifiedInviteIds.toList()), flush: true);
      } catch (_) {}
    }
  }

  Future<void> _loadNotifiedCheers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('notified_cheer_keys');
      if (list != null && list.isNotEmpty) {
        _notifiedCheerKeys.addAll(list);
        return;
      }
    } catch (_) {}

    if (!kIsWeb) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final file = File('${docs.path}/notified_cheers.json');
        if (await file.exists()) {
          final list = jsonDecode(await file.readAsString()) as List<dynamic>?;
          if (list != null) {
            _notifiedCheerKeys.addAll(list.whereType<String>());
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _persistNotifiedCheers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('notified_cheer_keys', _notifiedCheerKeys.toList());
    } catch (_) {}

    if (!kIsWeb) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final file = File('${docs.path}/notified_cheers.json');
        await file.writeAsString(jsonEncode(_notifiedCheerKeys.toList()), flush: true);
      } catch (_) {}
    }
  }

  // ── Song Persistence across App Restarts ──

  static Map<String, dynamic> songToJson(Song s) => <String, dynamic>{
        'title': s.title,
        'artist': s.artist,
        'seconds': s.seconds,
        'art': s.art.name,
        'videoId': s.videoId,
        'coverUrl': s.coverUrl,
        'previewUrl': s.previewUrl,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      };

  static Song? songFromJson(Map<String, dynamic> json) {
    final title = (json['title'] as String?)?.trim() ?? '';
    final artist = (json['artist'] as String?)?.trim() ?? '';
    if (title.isEmpty || artist.isEmpty) return null;
    final seconds = (json['seconds'] as num?)?.toInt() ?? 180;
    final art = hatchFromName(json['art'] as String?, Hatch.diagonal);
    final videoId = (json['videoId'] as String?)?.trim();
    final coverUrl = (json['coverUrl'] as String?)?.trim();
    final previewUrl = (json['previewUrl'] as String?)?.trim();
    return Song(
      title,
      artist,
      seconds,
      art,
      videoId: (videoId != null && videoId.isNotEmpty) ? videoId : null,
      coverUrl: (coverUrl != null && coverUrl.isNotEmpty) ? coverUrl : null,
      previewUrl: (previewUrl != null && previewUrl.isNotEmpty) ? previewUrl : null,
    );
  }

  Future<void> _persistLastSong(Song s) async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/last_song.json');
      await file.writeAsString(jsonEncode(songToJson(s)), flush: true);
      _lastSongSavedAtMillis = DateTime.now().millisecondsSinceEpoch;
    } catch (_) {}
  }

  Future<void> _loadLastSong() async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/last_song.json');
      if (await file.exists()) {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final loaded = songFromJson(decoded);
          if (loaded != null) {
            _lastSongSavedAtMillis = (decoded['savedAt'] as num?)?.toInt();
            draftSong = loaded;
            notifyListeners();
            unawaited(_warmDraftSong(loaded));
          }
        }
      }
    } catch (_) {}
  }

  void onSongPlayed(Song s) {
    if (draftSong != s) {
      draftSong = s;
      notifyListeners();
    }
    unawaited(_persistLastSong(s));
  }

  // ── Privacy Lock & 4-Digit PIN ──

  Future<void> _loadLocalPrivacySettings() async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/privacy_lock.json');
      if (await file.exists()) {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final pin = decoded['pin'] as String?;
          final enabled = decoded['enabled'] as bool?;
          if (pin != null && RegExp(r'^\d{4}$').hasMatch(pin)) {
            _privacyPin = pin;
          }
          if (enabled != null) {
            privacyLock = enabled;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _persistPrivacySettings() async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/privacy_lock.json');
      final data = <String, dynamic>{
        'pin': _privacyPin,
        'enabled': privacyLock,
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {}
  }

  Future<bool> setPrivacyPin(String pin) async {
    final clean = pin.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(clean)) return false;
    _privacyPin = clean;
    privacyLock = true;
    isPrivacyUnlocked = true;
    notifyListeners();
    await _persistPrivacySettings();
    unawaited(_syncProfileFields(<String, dynamic>{'privacy_lock': true}));
    return true;
  }

  bool verifyAndUnlock(String pin) {
    if (_privacyPin == null || _privacyPin != pin.trim()) {
      return false;
    }
    isPrivacyUnlocked = true;
    notifyListeners();
    return true;
  }

  void lockPrivacy() {
    if (privacyLock && hasPrivacyPin) {
      isPrivacyUnlocked = false;
      notifyListeners();
    }
  }

  Future<bool> changePrivacyPin(String oldPin, String newPin) async {
    if (_privacyPin != null && _privacyPin != oldPin.trim()) return false;
    final clean = newPin.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(clean)) return false;
    _privacyPin = clean;
    isPrivacyUnlocked = true;
    notifyListeners();
    await _persistPrivacySettings();
    return true;
  }

  Future<void> disablePrivacyLock() async {
    privacyLock = false;
    _privacyPin = null;
    isPrivacyUnlocked = true;
    notifyListeners();
    await _persistPrivacySettings();
    unawaited(_syncProfileFields(<String, dynamic>{'privacy_lock': false}));
  }

  // ── Intro & Onboarding Carousel ──

  Future<void> _loadIntroSettings() async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/intro_seen.json');
      if (await file.exists()) {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final users = decoded['users'];
          if (users is List) {
            _seenIntroUsers.addAll(users.whereType<String>());
          }
          final currentUid = user?.id ?? _sb.auth.currentSession?.user.id;
          if (currentUid != null && _seenIntroUsers.contains(currentUid)) {
            if (!_hasSeenIntro) {
              _hasSeenIntro = true;
              notifyListeners();
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> completeIntro() async {
    _hasSeenIntro = true;
    final uid = user?.id;
    if (uid != null) {
      _seenIntroUsers.add(uid);
    }
    notifyListeners();
    unawaited(_persistIntroSeen());
  }

  Future<void> _persistIntroSeen() async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/intro_seen.json');
      final users = <String>{..._seenIntroUsers};
      if (await file.exists()) {
        try {
          final raw = await file.readAsString();
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic> && decoded['users'] is List) {
            users.addAll((decoded['users'] as List).whereType<String>());
          }
        } catch (_) {}
      }
      if (user?.id != null) {
        users.add(user!.id);
      }
      final data = <String, dynamic>{
        'seen': true,
        'users': users.toList(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {}
  }

  Future<void> resetIntro() async {
    _hasSeenIntro = false;
    _seenIntroUsers.clear();
    notifyListeners();
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/intro_seen.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

final app = AppState();
