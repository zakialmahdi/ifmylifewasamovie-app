import 'dart:js_interop';

import 'pwa_install_service.dart';

@JS('pwaInstallBridge')
external PwaInstallBridgeJs? get _pwaBridge;

@JS()
extension type PwaInstallBridgeJs(JSObject _) implements JSObject {
  external JSBoolean isSmartphone();
  external JSBoolean isIos();
  external JSBoolean isStandalone();
  external JSBoolean canPromptNatively();
  external JSPromise<JSString> triggerInstall();
  external JSFunction? onStateChanged;
}

PwaInstallService createPwaInstallService() => _PwaInstallServiceWeb();

class _PwaInstallServiceWeb extends PwaInstallService {
  bool _bound = false;

  _PwaInstallServiceWeb() {
    _ensureBound();
  }

  void _ensureBound() {
    if (_bound) return;
    final bridge = _pwaBridge;
    if (bridge != null) {
      void onState(JSString state) {
        notifyListeners();
      }

      bridge.onStateChanged = onState.toJS;
      _bound = true;
    }
  }

  @override
  bool get isWebSupported => true;

  @override
  bool get isSmartphone {
    _ensureBound();
    try {
      return _pwaBridge?.isSmartphone().toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get isIos {
    _ensureBound();
    try {
      return _pwaBridge?.isIos().toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get isStandalone {
    _ensureBound();
    try {
      return _pwaBridge?.isStandalone().toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get canPromptNatively {
    _ensureBound();
    try {
      return _pwaBridge?.canPromptNatively().toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> triggerInstall() async {
    _ensureBound();
    final bridge = _pwaBridge;
    if (bridge == null) return 'manual';
    try {
      final res = await bridge.triggerInstall().toDart;
      notifyListeners();
      return res.toDart;
    } catch (_) {
      return 'manual';
    }
  }
}
