import 'pwa_install_service.dart';

PwaInstallService createPwaInstallService() => _PwaInstallServiceStub();

class _PwaInstallServiceStub extends PwaInstallService {
  @override
  bool get isWebSupported => false;

  @override
  bool get isSmartphone => false;

  @override
  bool get isIos => false;

  @override
  bool get isStandalone => false;

  @override
  bool get canPromptNatively => false;

  @override
  Future<String> triggerInstall() async => 'manual';
}
