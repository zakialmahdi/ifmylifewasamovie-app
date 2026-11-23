import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pwa_install_service_stub.dart'
    if (dart.library.js_interop) 'pwa_install_service_web.dart';

abstract class PwaInstallService extends ChangeNotifier {
  static final PwaInstallService instance = createPwaInstallService();

  /// Version-scoped preference key so devices opening the latest update on a
  /// smartphone for the first time see the "Add to Home Screen" prompt once.
  static const String kPromptSeenPrefKey = 'pwa_homescreen_prompt_seen_v1_1_4';

  bool get isWebSupported;
  bool get isSmartphone;
  bool get isIos;
  bool get isStandalone;
  bool get canPromptNatively;

  /// Triggers the browser's native install prompt (`navigator.install()` or
  /// captured `beforeinstallprompt`). Must be called directly from a user tap.
  /// Returns `'accepted'`, `'dismissed'`, `'installed'`, `'manual'`, or `'busy'`.
  Future<String> triggerInstall();

  /// Returns `true` only when running on a smartphone browser (never on
  /// laptops/desktops or native mobile builds), not already installed to the
  /// home screen, and not yet shown on this device for the current update.
  Future<bool> shouldShowFirstOpenPrompt() async {
    if (!isWebSupported || !isSmartphone || isStandalone) {
      return false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(kPromptSeenPrefKey) ?? false;
      return !seen;
    } catch (_) {
      return false;
    }
  }

  Future<void> markPromptSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPromptSeenPrefKey, true);
    } catch (_) {}
  }
}
