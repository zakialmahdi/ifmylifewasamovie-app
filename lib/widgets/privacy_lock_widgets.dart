import 'dart:math' as math;

import 'package:flutter/material.dart' hide Ink;

import '../sketch.dart';
import '../state.dart';

class SketchPinDots extends StatelessWidget {
  final int pinLength;
  const SketchPinDots({super.key, required this.pinLength});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          SketchBox(
            seed: 20 + i,
            shadow: false,
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: i < pinLength
                    ? Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Ink.ink,
                        ),
                      )
                    : Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Ink.grey, width: 1.5),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class SketchNumpad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const SketchNumpad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  Widget _keyBtn(Widget child, VoidCallback onTap, {int seed = 1}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SketchTap(
          onTap: onTap,
          child: SketchBox(
            fill: Ink.paper,
            seed: seed,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _keyBtn(Text('1', style: T.head(22)), () => onDigit('1'), seed: 1),
            _keyBtn(Text('2', style: T.head(22)), () => onDigit('2'), seed: 2),
            _keyBtn(Text('3', style: T.head(22)), () => onDigit('3'), seed: 3),
          ],
        ),
        Row(
          children: [
            _keyBtn(Text('4', style: T.head(22)), () => onDigit('4'), seed: 4),
            _keyBtn(Text('5', style: T.head(22)), () => onDigit('5'), seed: 5),
            _keyBtn(Text('6', style: T.head(22)), () => onDigit('6'), seed: 6),
          ],
        ),
        Row(
          children: [
            _keyBtn(Text('7', style: T.head(22)), () => onDigit('7'), seed: 7),
            _keyBtn(Text('8', style: T.head(22)), () => onDigit('8'), seed: 8),
            _keyBtn(Text('9', style: T.head(22)), () => onDigit('9'), seed: 9),
          ],
        ),
        Row(
          children: [
            _keyBtn(Text('CLR', style: T.head(15, c: Ink.soft)), onClear, seed: 10),
            _keyBtn(Text('0', style: T.head(22)), () => onDigit('0'), seed: 11),
            _keyBtn(
              const Icon(Icons.backspace_outlined, size: 20, color: Ink.ink),
              onBackspace,
              seed: 12,
            ),
          ],
        ),
      ],
    );
  }
}

class PrivacyLockGate extends StatefulWidget {
  final Widget child;
  const PrivacyLockGate({super.key, required this.child});

  @override
  State<PrivacyLockGate> createState() => _PrivacyLockGateState();
}

class _PrivacyLockGateState extends State<PrivacyLockGate>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final List<String> _digits = <String>[];
  String? _errorText;
  late final AnimationController _shakeCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shakeCtl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      app.lockPrivacy();
    }
  }

  void _onDigit(String d) {
    if (_digits.length >= 4) return;
    setState(() {
      _digits.add(d);
      _errorText = null;
    });

    if (_digits.length == 4) {
      final pin = _digits.join();
      if (app.verifyAndUnlock(pin)) {
        setState(() {
          _digits.clear();
          _errorText = null;
        });
      } else {
        _shakeCtl.forward(from: 0);
        setState(() {
          _errorText = 'incorrect pin · try again';
        });
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && app.isPrivacyLocked) {
            setState(() {
              _digits.clear();
            });
          }
        });
      }
    }
  }

  void _onBackspace() {
    if (_digits.isNotEmpty) {
      setState(() {
        _digits.removeLast();
        _errorText = null;
      });
    }
  }

  void _onClear() {
    setState(() {
      _digits.clear();
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (!app.isPrivacyLocked) {
          return widget.child;
        }

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
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
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: AnimatedBuilder(
                        animation: _shakeCtl,
                        builder: (context, child) {
                          final offset =
                              math.sin(_shakeCtl.value * math.pi * 4) * 8 * (1 - _shakeCtl.value);
                          return Transform.translate(
                            offset: Offset(offset, 0),
                            child: child,
                          );
                        },
                        child: TagBox(
                          label: 'director\'s archive',
                          seed: 14,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.lock_outline, size: 20, color: Ink.ink),
                                    const SizedBox(width: 8),
                                    Text('PRIVACY LOCK', style: T.head(22)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Note(
                                  'enter 4-digit PIN to open today\'s reel',
                                  size: 15,
                                ),
                                const SizedBox(height: 18),
                                SketchPinDots(pinLength: _digits.length),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 22,
                                  child: Center(
                                    child: _errorText != null
                                        ? Text(
                                            _errorText!,
                                            style: T.body(14, c: Ink.ink, w: FontWeight.w700),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SketchNumpad(
                                  onDigit: _onDigit,
                                  onBackspace: _onBackspace,
                                  onClear: _onClear,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
