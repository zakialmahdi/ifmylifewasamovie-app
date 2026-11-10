import 'dart:async';

import 'package:flutter/material.dart' hide Ink;

import '../router.dart';
import '../sketch.dart';
import '../state.dart';

/// Hosts the in-app daily reminder banner on top of every page.
///
/// * Slides a sketch-style banner down from the top whenever
///   [AppState.inAppReminder] gets a message (reminder time hit while the app
///   is open, or "send test reminder" in settings).
/// * Asks for notification permission after the first frame (the reminder is
///   on by default, so the user may never have been prompted).
/// * Re-plans reminders whenever the app returns to the foreground.
class ReminderBannerHost extends StatefulWidget {
  final Widget child;
  const ReminderBannerHost({super.key, required this.child});

  @override
  State<ReminderBannerHost> createState() => _ReminderBannerHostState();
}

class _ReminderBannerHostState extends State<ReminderBannerHost>
    with WidgetsBindingObserver {
  Timer? _autoHide;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    app.inAppReminder.addListener(_onReminder);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(app.ensureReminderPermission());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      app.onAppResumed();
    }
  }

  void _onReminder() {
    _autoHide?.cancel();
    if (app.inAppReminder.value != null) {
      _autoHide = Timer(const Duration(seconds: 8), app.dismissInAppReminder);
    }
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    app.inAppReminder.removeListener(_onReminder);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onBannerTap() {
    final msg = app.inAppReminder.value ?? '';
    app.dismissInAppReminder();
    final isReel = msg.toLowerCase().contains('reel') || msg.toLowerCase().contains('co-star');
    if (isReel) {
      app.setTab(2);
      appRouter.go('/friends');
    } else {
      app.setTab(0);
      appRouter.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ValueListenableBuilder<String?>(
          valueListenable: app.inAppReminder,
          builder: (context, msg, _) {
            final visible = msg != null;
            final isReel = (msg ?? '').toLowerCase().contains('reel') ||
                (msg ?? '').toLowerCase().contains('co-star');
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              left: 14,
              right: 14,
              top: visible ? MediaQuery.paddingOf(context).top + 10 : -160,
              child: IgnorePointer(
                ignoring: !visible,
                child: Material(
                  type: MaterialType.transparency,
                  child: SketchTap(
                    onTap: _onBannerTap,
                    child: SketchBox(
                      seed: 88,
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      child: Row(
                        children: [
                          Icon(
                            isReel ? Icons.confirmation_number_outlined : Icons.movie_filter_outlined,
                            size: 26,
                            color: Ink.ink,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isReel ? 'REEL INVITE' : 'DAILY REMINDER', style: T.head(14)),
                                const SizedBox(height: 2),
                                Text(
                                  msg ?? '',
                                  style: T.body(13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: app.dismissInAppReminder,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close, size: 18, color: Ink.soft),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
