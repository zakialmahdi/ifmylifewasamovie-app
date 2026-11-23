import 'dart:async';

import 'package:flutter/material.dart' hide Ink;

import '../services/pwa_install/pwa_install_service.dart';
import '../sketch.dart';

/// Opens the sketch-styled "Add to Home Screen" dialog from Settings on web.
Future<void> showPwaInstallDialog(BuildContext context) {
  var dismissed = false;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Add to Home Screen',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, _, _) => Stack(
      children: [
        PwaInstallDialogOverlay(
          onDismiss: () {
            if (dismissed || !dialogContext.mounted) return;
            dismissed = true;
            Navigator.of(dialogContext).pop();
          },
        ),
      ],
    ),
  );
}

/// Full-screen sketchbook modal overlay asking smartphone web users if they
/// want to add "If My Life A Movie" to their phone's home screen, or showing
/// step-by-step instructions when triggered from Settings.
class PwaInstallDialogOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const PwaInstallDialogOverlay({
    super.key,
    required this.onDismiss,
  });

  @override
  State<PwaInstallDialogOverlay> createState() =>
      _PwaInstallDialogOverlayState();
}

class _PwaInstallDialogOverlayState extends State<PwaInstallDialogOverlay> {
  bool _installing = false;
  bool _showManualSteps = false;
  String? _statusNote;

  Future<void> _handleInstallTap() async {
    if (_installing) return;
    final svc = PwaInstallService.instance;
    if (svc.isStandalone) {
      setState(() {
        _statusNote = 'already added to your home screen ✓';
      });
      return;
    }

    setState(() {
      _installing = true;
      _statusNote = null;
    });

    final outcome = await svc.triggerInstall();
    if (!mounted) return;

    if (outcome == 'accepted' || outcome == 'installed') {
      await svc.markPromptSeen();
      if (mounted) {
        widget.onDismiss();
      }
      return;
    }

    setState(() {
      _installing = false;
      if (outcome == 'manual') {
        _showManualSteps = true;
      } else if (outcome == 'dismissed') {
        _statusNote = 'install canceled — you can add it anytime from Settings';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = PwaInstallService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final isIos = svc.isIos;
        final showSteps = _showManualSteps;

        return Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onDismiss,
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
                          maxWidth: responsiveDialogWidth(
                            MediaQuery.sizeOf(context).width,
                          ),
                        ),
                        child: SketchDialogCard(
                          title: 'add to home screen?',
                          body: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 320),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      SketchBox(
                                        seed: 12,
                                        shadow: false,
                                        fill: Ink.grey.withAlpha(70),
                                        padding: const EdgeInsets.all(8),
                                        child: const Icon(
                                          Icons.add_to_home_screen_outlined,
                                          size: 22,
                                          color: Ink.ink,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'IF MY LIFE A MOVIE',
                                              style: T.head(19),
                                            ),
                                            const Note(
                                              'keep your soundtrack reel one tap away',
                                              size: 14,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'want to add this web app to your phone\'s home screen for a full-screen sketchbook experience?',
                                    style: T.body(14),
                                  ),
                                  if (showSteps) ...[
                                    const SizedBox(height: 12),
                                    SketchBox(
                                      seed: 47,
                                      dashed: true,
                                      padding: const EdgeInsets.all(11),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isIos
                                                ? 'HOW TO ADD ON IPHONE:'
                                                : 'HOW TO ADD ON YOUR PHONE:',
                                            style: T.head(14),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isIos
                                                ? '1. tap the Share icon (⍐) in your browser bar\n'
                                                    '2. scroll down and tap "Add to Home Screen"'
                                                : '1. tap the browser menu (⋮) at the top or bottom\n'
                                                    '2. tap "Add to Home screen" or "Install app"',
                                            style: T.body(13),
                                          ),
                                        ],
                                      ),
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
                            if (!showSteps) ...[
                              SketchTextButton(
                                'later',
                                onTap: widget.onDismiss,
                              ),
                              SketchTextButton(
                                _installing
                                    ? 'adding...'
                                    : 'add to home screen →',
                                primary: true,
                                onTap: _handleInstallTap,
                              ),
                            ] else
                              SketchTextButton(
                                'got it ✓',
                                primary: true,
                                onTap: widget.onDismiss,
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
      },
    );
  }
}
