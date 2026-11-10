import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the local "pick today's song" daily reminder notifications.
///
/// Instead of one repeating alarm, the next [_daysAhead] days are scheduled as
/// individual one-shot notifications. This lets us skip *today's* reminder
/// once the user has already saved today's scene, and we simply re-plan the
/// window every time the app opens, a scene is saved, or settings change.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const int _baseId = 4200;
  static const int _daysAhead = 14;
  static const String _channelId = 'daily_reminder';
  static const String _channelName = 'Daily reminder';

  static const String _reelChannelId = 'reel_invites';
  static const String _reelChannelName = 'Reel invites';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initFuture;

  /// Callback invoked when user taps a notification banner on their phone.
  void Function(String? payload)? onNotificationTapped;

  static const List<String> _messages = <String>[
    'what\'s today\'s soundtrack? pick a song before the credits roll.',
    'scene unfilmed – one song, one line, and today\'s in the reel.',
    'the director is waiting… what song scored your day?',
    'roll camera: today\'s scene still needs a soundtrack.',
    'before the lights go out – what did today sound like?',
  ];

  /// Only mobile/macOS support scheduled local notifications here.
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> init() {
    if (!isSupported) return Future<void>.value();
    return _initFuture ??= _doInit();
  }

  Future<void> _doInit() async {
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        // Fall back to UTC offset-less local if the zone id is unknown.
      }

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          onNotificationTapped?.call(response.payload);
        },
      );

      // Pre-create notification channels on Android so categories exist in system settings
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (android != null) {
          await android.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: 'A nightly nudge to pick today\'s song',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
          await android.createNotificationChannel(
            const AndroidNotificationChannel(
              _reelChannelId,
              _reelChannelName,
              description: 'Notifications when co-stars invite you to swap reels',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
        }
      }

      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  /// Checks if the app was launched by tapping a notification banner.
  Future<NotificationAppLaunchDetails?> getLaunchDetails() async {
    if (!isSupported) return null;
    await init();
    if (!_initialized) return null;
    try {
      return await _plugin.getNotificationAppLaunchDetails();
    } catch (_) {
      return null;
    }
  }

  /// Asks the OS for notification permission. Returns `true` if granted
  /// (or if the platform doesn't require a runtime prompt).
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await init();
    if (!_initialized) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission();
        return granted ?? true;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await ios?.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final mac = _plugin.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
        final granted = await mac?.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
    } catch (_) {}
    return false;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      defaultTargetPlatform == TargetPlatform.android
          ? _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          : null;

  /// Whether the OS currently allows this app to post notifications.
  Future<bool> notificationsEnabled() async {
    if (!isSupported) return false;
    await init();
    if (!_initialized) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _android?.areNotificationsEnabled() ?? true;
      }
    } catch (_) {}
    return true;
  }

  /// Whether Android lets us fire at the exact minute (Android 12+ gate).
  Future<bool> canScheduleExact() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    await init();
    try {
      return await _android?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the Android "Alarms & reminders" system page so the reminder can
  /// fire at the exact minute instead of being batched/delayed by Doze.
  Future<bool> requestExactAlarms() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    await init();
    try {
      if (await canScheduleExact()) return true;
      return await _android?.requestExactAlarmsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'A nightly nudge to pick today\'s song',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      ticker: 'pick today\'s song',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    ),
    macOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    ),
  );

  static String messageFor(DateTime when) =>
      _messages[(when.day + when.month) % _messages.length];

  /// Posts the reminder notification right now (used when the reminder time
  /// hits while the app is open, and for the "send test reminder" button).
  Future<bool> showNow({String? body}) async {
    if (!isSupported) return false;
    await init();
    if (!_initialized) return false;
    try {
      await _plugin.show(
        id: _baseId + 99,
        title: 'IF MY LIFE WAS A MOVIE…',
        body: body ?? messageFor(DateTime.now()),
        notificationDetails: _details,
        payload: 'daily_reminder',
      );
      return true;
    } catch (e) {
      debugPrint('ReminderService.showNow failed: $e');
      return false;
    }
  }

  static const NotificationDetails _reelInviteDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _reelChannelId,
      _reelChannelName,
      channelDescription: 'Notifications when co-stars invite you to swap reels',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.social,
      visibility: NotificationVisibility.public,
      ticker: 'new reel invite',
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
      presentBadge: true,
    ),
    macOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
      presentBadge: true,
    ),
  );

  /// Posts a system phone notification alerting the user of a new reel invite.
  Future<bool> showReelInviteNotification({
    required String inviterName,
    required String inviterHandle,
    int? inviteId,
  }) async {
    if (!isSupported) return false;
    await init();
    if (!_initialized) return false;
    try {
      final notifId = inviteId != null
          ? (_baseId + 1000 + (inviteId % 5000))
          : (_baseId + 1000);
      await _plugin.show(
        id: notifId,
        title: 'IF MY LIFE WAS A MOVIE…',
        body: '$inviterName ($inviterHandle) invited you to swap reels!',
        notificationDetails: _reelInviteDetails,
        payload: 'reel_invite',
      );
      return true;
    } catch (e) {
      debugPrint('ReminderService.showReelInviteNotification failed: $e');
      return false;
    }
  }

  /// Posts a system phone notification when a co-star has accepted the user's invite.
  Future<bool> showReelAcceptedNotification({
    required String friendName,
    required String friendHandle,
  }) async {
    if (!isSupported) return false;
    await init();
    if (!_initialized) return false;
    try {
      await _plugin.show(
        id: _baseId + 1999,
        title: 'CO-STAR CONNECTED',
        body: '$friendName ($friendHandle) joined your reel ✓',
        notificationDetails: _reelInviteDetails,
        payload: 'reel_invite',
      );
      return true;
    } catch (e) {
      debugPrint('ReminderService.showReelAcceptedNotification failed: $e');
      return false;
    }
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await android?.canScheduleExactNotifications();
      if (canExact == true) return AndroidScheduleMode.exactAllowWhileIdle;
    } catch (_) {}
    // Without exact-alarm permission Android may deliver a few minutes late.
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> cancelAll() async {
    if (!isSupported) return;
    await init();
    if (!_initialized) return;
    for (var i = 0; i < _daysAhead; i++) {
      try {
        await _plugin.cancel(id: _baseId + i);
      } catch (_) {}
    }
  }

  /// Cancels and re-plans the next [_daysAhead] reminders at [hour]:[minute]
  /// local time. If [skipToday] is true (today's scene already saved), the
  /// reminder for today is not scheduled.
  Future<void> reschedule({
    required bool enabled,
    required int hour,
    required int minute,
    required bool skipToday,
  }) async {
    if (!isSupported) return;
    await init();
    if (!_initialized) return;

    await cancelAll();
    if (!enabled) return;

    const details = _details;

    final mode = await _scheduleMode();
    final now = tz.TZDateTime.now(tz.local);

    for (var i = 0; i < _daysAhead; i++) {
      final when = tz.TZDateTime(tz.local, now.year, now.month, now.day + i, hour, minute);
      if (!when.isAfter(now)) continue;
      if (i == 0 && skipToday) continue;
      try {
        await _plugin.zonedSchedule(
          id: _baseId + i,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: mode,
          title: 'IF MY LIFE WAS A MOVIE…',
          body: messageFor(when),
          payload: 'daily_reminder',
        );
      } catch (e) {
        // Exact alarm denied mid-flight etc. – retry inexact, keep going.
        debugPrint('ReminderService.zonedSchedule failed ($when): $e');
        if (mode != AndroidScheduleMode.inexactAllowWhileIdle) {
          try {
            await _plugin.zonedSchedule(
              id: _baseId + i,
              scheduledDate: when,
              notificationDetails: details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              title: 'IF MY LIFE WAS A MOVIE…',
              body: messageFor(when),
              payload: 'daily_reminder',
            );
          } catch (_) {}
        }
      }
    }
  }
}
