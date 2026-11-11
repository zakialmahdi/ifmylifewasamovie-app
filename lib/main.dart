import 'dart:async';

import 'package:flutter/material.dart' hide Ink;
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'router.dart';
import 'services/app_version_service.dart';
import 'sketch.dart';
import 'state.dart';
import 'widgets/app_update_dialog.dart';
import 'widgets/privacy_lock_widgets.dart';
import 'widgets/reminder_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  await Supabase.initialize(
    url: 'https://lwsmapszfcwzauoohvhc.supabase.co',
    publishableKey: 'sb_publishable_1FxYrbBMj7XIN6Xk56Nt-g_CimD9JEz',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  await app.init();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const MovieApp());
}

class MovieApp extends StatelessWidget {
  const MovieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'If My Life Was a Movie',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(seedColor: Ink.ink, brightness: Brightness.light),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        textSelectionTheme:
            const TextSelectionThemeData(cursorColor: Ink.ink, selectionColor: Ink.grey),
      ),
      routerConfig: appRouter,
      builder: (context, child) => SplashGate(
        child: PrivacyLockGate(
          child: ReminderBannerHost(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

class SplashGate extends StatefulWidget {
  final Widget child;
  final Future<AppUpdateInfo?> Function()? checkForUpdate;
  final UpdateUrlLauncher? updateLauncher;

  const SplashGate({
    super.key,
    required this.child,
    this.checkForUpdate,
    this.updateLauncher,
  });

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1850),
  );

  double _clapTurns = 0;
  bool _done = false;
  AppUpdateInfo? _availableUpdate;
  bool _promptDismissed = false;

  bool get _showingUpdatePrompt => _availableUpdate != null && !_promptDismissed;

  @override
  void initState() {
    super.initState();
    _ctl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && !_showingUpdatePrompt) {
        setState(() => _done = true);
      }
    });
    _ctl.forward();
    unawaited(_checkForUpdate());

    // Trigger signature clapper rotation snap at 300ms
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_done) {
        setState(() => _clapTurns = 1.0);
      }
    });
  }

  Future<void> _checkForUpdate() async {
    final update =
        await (widget.checkForUpdate ?? AppVersionService.instance.checkForUpdate)();
    if (!mounted || update == null) return;
    setState(() {
      _availableUpdate = update;
      if (_ctl.isAnimating) {
        _ctl.stop();
      }
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _skip() {
    if (_done || _showingUpdatePrompt) return;
    _ctl.stop();
    setState(() => _done = true);
  }

  void _dismissUpdate() {
    _ctl.stop();
    setState(() {
      _promptDismissed = true;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showPrompt = _showingUpdatePrompt;
    if (_done && !showPrompt) return widget.child;

    return Stack(
      children: [
        widget.child,
        if (!_done)
          Positioned.fill(
            child: GestureDetector(
              onTap: _skip,
              behavior: HitTestBehavior.opaque,
              child: AnimatedBuilder(
                animation: _ctl,
                builder: (context, _) {
                  final t = _ctl.value;
                  final fadeOut = showPrompt
                      ? 1.0
                      : (t < 0.78 ? 1.0 : ((1.0 - t) / 0.22).clamp(0.0, 1.0));

                return Opacity(
                  opacity: fadeOut,
                  child: Stack(
                    children: [
                      // Real PaperPainter background matching the app UI
                      Positioned.fill(
                        child: CustomPaint(
                          isComplex: true,
                          painter: PaperPainter(app.paper),
                        ),
                      ),
                      Scaffold(
                        backgroundColor: Colors.transparent,
                        body: SafeArea(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 380),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Main handwritten TagBox card in exact app UI style
                                    TagBox(
                                      label: 'opening credits',
                                      seed: 19,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Dedicated high-resolution splash emblem (sleeve + spinning vinyl)
                                            _SplashEmblem(
                                              clapTurns: _clapTurns,
                                              spinAnimation: _ctl,
                                            ),
                                            const SizedBox(height: 18),
                                            const Note('daily soundtrack diary', size: 16),
                                            const SizedBox(height: 4),
                                            Text(
                                              'IF MY LIFE\nWAS A MOVIE...',
                                              textAlign: TextAlign.center,
                                              style: T.head(30),
                                            ),
                                            const SizedBox(height: 16),
                                            const DashedLine(),
                                            const SizedBox(height: 14),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                RotationTransition(
                                                  turns: _ctl,
                                                  child: const Icon(
                                                    Icons.album_outlined,
                                                    size: 17,
                                                    color: Ink.ink,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    'ROLLING REEL · TAKE 1',
                                                    style: T.head(13, c: Ink.soft),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'DIRECTED & DEVELOPED BY ZAKIALMAHDI\n· LONE DEVELOPER ·',
                                              textAlign: TextAlign.center,
                                              style: T.head(11, c: Ink.soft),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    const Note(
                                      'IF MY LIFE WAS A MOVIE...',
                                      size: 16,
                                    ),
                                    const SizedBox(height: 2),
                                    const Note(
                                      'lone developer: zakialmahdi · v${AppVersionService.kFallbackVersion}',
                                      size: 14,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'tap anywhere to start →',
                                      style: T.note(13, c: Ink.faint),
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
            ),
          ),
        ),
        if (showPrompt)
          AppUpdateDialogOverlay(
            update: _availableUpdate!,
            onLater: _availableUpdate!.forceUpdate ? null : _dismissUpdate,
            urlLauncher: widget.updateLauncher,
          ),
      ],
    );
  }
}

class _SplashEmblem extends StatelessWidget {
  final double clapTurns;
  final Animation<double> spinAnimation;

  const _SplashEmblem({
    required this.clapTurns,
    required this.spinAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 126,
      height: 88,
      child: Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: [
          // Sliding vinyl record emerging from the right side of the sleeve
          Positioned(
            right: 2,
            top: 8,
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Ink.ink,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: RotationTransition(
                turns: spinAnimation,
                child: const RepaintBoundary(
                  child: CustomPaint(painter: _SplashVinylPainter()),
                ),
              ),
            ),
          ),
          // Zine album sleeve with clapperboard + soundtrack eighth-notes
          Positioned(
            left: 4,
            top: 2,
            child: AnimatedRotation(
              turns: clapTurns,
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutBack,
              child: SketchBox(
                padding: EdgeInsets.zero,
                seed: 4,
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const HatchSwatch(
                        Hatch.cross,
                        size: 84,
                        gap: 4.2,
                      ),
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Ink.paper,
                          border: Border.all(color: Ink.ink, width: 1.5),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const CustomPaint(
                          painter: _SplashClapperPainter(),
                        ),
                      ),
                    ],
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

class _SplashVinylPainter extends CustomPainter {
  const _SplashVinylPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // Paper outer rim + dark ink disc
    canvas.drawCircle(c, r, Paint()..color = Ink.paper);
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..color = Ink.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(c, r - 2.2, Paint()..color = Ink.ink);

    // Concentric vinyl grooves
    final groovePaint = Paint()
      ..color = Ink.paper.withAlpha(85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final factor in const <double>[0.82, 0.70, 0.58, 0.46]) {
      canvas.drawCircle(c, r * factor, groovePaint);
    }

    // Glossy reflection arcs
    final sheenPaint = Paint()
      ..color = Ink.paper.withAlpha(165)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.76),
      -0.85,
      0.7,
      false,
      sheenPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.64),
      2.25,
      0.65,
      false,
      sheenPaint,
    );

    // Center label + spindle hole
    canvas.drawCircle(c, r * 0.32, Paint()..color = Ink.grey);
    canvas.drawCircle(
      c,
      r * 0.32,
      Paint()
        ..color = Ink.paper
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    canvas.drawCircle(c, r * 0.08, Paint()..color = Ink.ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SplashClapperPainter extends CustomPainter {
  const _SplashClapperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final inkFill = Paint()..color = Ink.ink;
    final paperFill = Paint()..color = Ink.paper;
    final inkStroke = Paint()
      ..color = Ink.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Lower slate body
    final slateRect = Rect.fromLTWH(w * 0.08, h * 0.34, w * 0.84, h * 0.58);
    canvas.drawRect(slateRect, paperFill);
    canvas.drawRect(slateRect, inkStroke);

    // Lower clap bar with angled paper stripes
    final lowerBar = Rect.fromLTWH(w * 0.08, h * 0.34, w * 0.84, h * 0.13);
    canvas.save();
    canvas.clipRect(lowerBar);
    canvas.drawRect(lowerBar, inkFill);
    final stripePaint = Paint()
      ..color = Ink.paper
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    for (final frac in const <double>[0.24, 0.46, 0.68, 0.88]) {
      canvas.drawLine(
        Offset(w * (frac - 0.05), lowerBar.bottom),
        Offset(w * (frac + 0.04), lowerBar.top),
        stripePaint,
      );
    }
    canvas.restore();
    canvas.drawLine(lowerBar.bottomLeft, lowerBar.bottomRight, inkStroke);

    // Tilted open upper clapper stick
    canvas.save();
    canvas.translate(w * 0.08, h * 0.32);
    canvas.rotate(-0.16);
    final upperBar = Rect.fromLTWH(0, -h * 0.13, w * 0.84, h * 0.13);
    canvas.save();
    canvas.clipRect(upperBar);
    canvas.drawRect(upperBar, inkFill);
    for (final frac in const <double>[0.18, 0.40, 0.62, 0.82]) {
      canvas.drawLine(
        Offset(w * (frac - 0.04), upperBar.top),
        Offset(w * (frac + 0.04), upperBar.bottom),
        stripePaint,
      );
    }
    canvas.restore();
    canvas.drawRect(
      upperBar,
      Paint()
        ..color = Ink.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.restore();

    // Beamed eighth-notes (♫) centered on slate
    final leftHead = Offset(w * 0.39, h * 0.76);
    final rightHead = Offset(w * 0.63, h * 0.72);
    for (final center in <Offset>[leftHead, rightHead]) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-0.32);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * 0.17, height: h * 0.12),
        inkFill,
      );
      canvas.restore();
    }

    final stemX1 = leftHead.dx + w * 0.068;
    final stemX2 = rightHead.dx + w * 0.068;
    final stemTop1 = h * 0.54;
    final stemTop2 = h * 0.50;
    canvas.drawLine(Offset(stemX1, leftHead.dy), Offset(stemX1, stemTop1), inkStroke);
    canvas.drawLine(Offset(stemX2, rightHead.dy), Offset(stemX2, stemTop2), inkStroke);

    final beam = Path()
      ..moveTo(stemX1 - 0.6, stemTop1)
      ..lineTo(stemX2 + 0.6, stemTop2)
      ..lineTo(stemX2 + 0.6, stemTop2 + h * 0.065)
      ..lineTo(stemX1 - 0.6, stemTop1 + h * 0.065)
      ..close();
    canvas.drawPath(beam, inkFill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
