import 'package:flutter/material.dart' hide Ink;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_version_service.dart';
import '../sketch.dart';

typedef UpdateUrlLauncher = Future<bool> Function(Uri uri);

/// Sample update payload shown in demo mode to preview the update alert without
/// modifying live Supabase release metadata.
AppUpdateInfo demoAppUpdateSample() => const AppUpdateInfo(
      currentVersion: AppVersionService.kFallbackVersion,
      currentBuildNumber: AppVersionService.kFallbackBuildNumber,
      latestVersion: '1.2.0',
      latestBuildNumber: AppVersionService.kFallbackBuildNumber + 1,
      releaseNotes:
          '• smoother YouTube soundtrack buffering & offline caching\n'
          '• coming soon: Calendar Widget & printable Zine exports\n'
          '(demo preview — real notes load from Supabase on launch)',
      downloadUrl: AppVersionService.kDefaultDownloadUrl,
      forceUpdate: false,
      platform: 'android',
    );

/// Presents [AppUpdateDialogOverlay] inside a route modal so settings and demo
/// flows can preview the exact splash update alert on demand.
Future<void> showAppUpdatePreviewDialog(
  BuildContext context, {
  AppUpdateInfo? update,
  UpdateUrlLauncher? urlLauncher,
}) {
  final info = update ?? demoAppUpdateSample();
  var dismissed = false;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'App update preview',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, _, _) => PopScope(
      canPop: !info.forceUpdate,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) dismissed = true;
      },
      child: Stack(
        children: [
          AppUpdateDialogOverlay(
            update: info,
            urlLauncher: urlLauncher,
            onLater: () {
              if (dismissed || !dialogContext.mounted) return;
              dismissed = true;
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      ),
    ),
  );
}

/// Full-screen sketchbook modal overlay shown over [SplashGate] when Supabase
/// reports a newer app version. Works without requiring a [Navigator] ancestor.
class AppUpdateDialogOverlay extends StatefulWidget {
  final AppUpdateInfo update;
  final VoidCallback? onLater;
  final UpdateUrlLauncher? urlLauncher;

  const AppUpdateDialogOverlay({
    super.key,
    required this.update,
    this.onLater,
    this.urlLauncher,
  });

  @override
  State<AppUpdateDialogOverlay> createState() => _AppUpdateDialogOverlayState();
}

class _AppUpdateDialogOverlayState extends State<AppUpdateDialogOverlay> {
  bool _opening = false;
  String? _statusNote;

  Future<bool> _defaultLaunch(Uri uri) async {
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openDownloadUrl() async {
    if (_opening) return;
    final raw = widget.update.downloadUrl.trim();
    final uri = Uri.tryParse(raw);
    final validHttp =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;

    setState(() {
      _opening = true;
      _statusNote = null;
    });

    var launched = false;
    if (validHttp) {
      try {
        launched = await (widget.urlLauncher ?? _defaultLaunch)(uri);
      } catch (_) {
        launched = false;
      }
    }

    var copied = false;
    if (!launched && raw.isNotEmpty) {
      try {
        await Clipboard.setData(ClipboardData(text: raw));
        copied = true;
      } catch (_) {
        copied = false;
      }
    }

    if (!mounted) return;
    setState(() {
      _opening = false;
      if (!launched) {
        _statusNote = copied
            ? 'couldn\'t open link — release URL copied'
            : 'couldn\'t open browser automatically';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    final canDismiss = !update.forceUpdate && widget.onLater != null;

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canDismiss ? widget.onLater : null,
              child: const ColoredBox(color: Colors.black38),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Material(
                  type: MaterialType.transparency,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: responsiveDialogWidth(MediaQuery.sizeOf(context).width),
                    ),
                    child: SketchDialogCard(
                      title: update.forceUpdate ? 'update required' : 'new update ready',
                      body: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  SketchBox(
                                    seed: 9,
                                    shadow: false,
                                    fill: Ink.grey.withAlpha(70),
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(
                                      Icons.system_update_outlined,
                                      size: 22,
                                      color: Ink.ink,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'V${update.latestVersion.toUpperCase()}',
                                          style: T.head(20),
                                        ),
                                        Note('your version: v${update.currentVersion}', size: 14),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (update.releaseNotes.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                SketchBox(
                                  seed: 41,
                                  dashed: true,
                                  padding: const EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Text(update.releaseNotes, style: T.body(14)),
                                  ),
                                ),
                              ],
                              if (update.forceUpdate) ...[
                                const SizedBox(height: 10),
                                const Note(
                                  'please update to the latest version to keep using the app.',
                                  size: 13,
                                ),
                              ],
                              if (_statusNote != null) ...[
                                const SizedBox(height: 10),
                                Note(_statusNote!, size: 13),
                              ],
                            ],
                          ),
                        ),
                      ),
                      actions: [
                        if (canDismiss)
                          SketchTextButton('later', onTap: widget.onLater!),
                        SketchTextButton(
                          _opening ? 'opening...' : 'update now →',
                          primary: true,
                          onTap: _openDownloadUrl,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
