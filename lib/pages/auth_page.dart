import 'dart:math' as math;

import 'package:flutter/material.dart' hide Ink;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../sketch.dart';
import '../state.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  final TextEditingController _nameCtl = TextEditingController();
  final TextEditingController _emailCtl = TextEditingController();
  final TextEditingController _passCtl = TextEditingController();
  final TextEditingController _otpCtl = TextEditingController();

  late final AnimationController _reelSpin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool _isRegister = false;
  bool _awaitingOtp = false;
  bool _emailUnconfirmedHint = false;
  bool _obscurePass = true;
  bool _busy = false;
  bool _googleBusy = false;
  double _clapTurns = 0;

  String _pendingEmail = '';
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    _otpCtl.dispose();
    _reelSpin.dispose();
    super.dispose();
  }

  void _setBusy(bool value) {
    if (!mounted) return;
    setState(() => _busy = value);
    if (value) {
      _reelSpin.repeat();
    } else if (!_googleBusy) {
      _reelSpin.stop();
      _reelSpin.value = 0;
    }
  }

  void _switchMode(bool register) {
    if (_busy || _googleBusy || (_isRegister == register && !_awaitingOtp)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isRegister = register;
      _awaitingOtp = false;
      _emailUnconfirmedHint = false;
      _errorMessage = null;
      _infoMessage = null;
    });
  }

  String _friendlyAuthError(Object error) {
    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError) {
        return 'Android OAuth Client ID (package + SHA-1) isn\'t configured in Google Cloud Console yet.';
      }
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return 'Google sign-in was canceled (if you selected an account, add an Android Client ID with your debug SHA-1 in Google Cloud Console).';
      }
      return error.description ?? 'Google sign-in failed – please try again.';
    }
    if (error is AuthException) {
      final msg = error.message;
      final lower = msg.toLowerCase();
      if (lower.contains('invalid login credentials')) {
        return 'wrong email or password – check your ticket & try again.';
      }
      if (lower.contains('email not confirmed')) {
        return 'your email isn\'t confirmed yet – check your inbox or enter your code.';
      }
      if (lower.contains('already registered') || lower.contains('already exists')) {
        return 'this email is already in the cast – switch to Sign In.';
      }
      if (lower.contains('password should be at least')) {
        return 'password needs at least 6 characters.';
      }
      if (lower.contains('rate limit') || lower.contains('security purposes')) {
        return 'too many takes in a row – wait a moment and try again.';
      }
      if (lower.contains('provider is not enabled') || lower.contains('unsupported provider')) {
        return 'Google sign-in isn\'t enabled in Supabase yet – enable Google under Authentication → Providers.';
      }
      if (lower.contains('otp') || lower.contains('token has expired') || lower.contains('invalid')) {
        return msg.toLowerCase();
      }
      return msg;
    }
    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') || raw.contains('failed host lookup')) {
      return 'couldn\'t reach Supabase – check your internet connection.';
    }
    return 'something slipped off the reel – please try again.';
  }

  bool _looksLikeEmail(String s) {
    final trimmed = s.trim();
    final at = trimmed.indexOf('@');
    if (at <= 0 || at >= trimmed.length - 3) return false;
    final dot = trimmed.indexOf('.', at);
    return dot > at + 1 && dot < trimmed.length - 1;
  }

  Future<void> _submit() async {
    if (_busy || _googleBusy) return;
    FocusScope.of(context).unfocus();

    final email = _emailCtl.text.trim();
    final password = _passCtl.text;
    final director = _nameCtl.text.trim();

    setState(() {
      _errorMessage = null;
      _infoMessage = null;
      _emailUnconfirmedHint = false;
    });

    if (_isRegister && director.isEmpty) {
      setState(() => _errorMessage = 'enter a director name for your reel.');
      return;
    }
    if (!_looksLikeEmail(email)) {
      setState(() => _errorMessage = 'enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'password must be at least 6 characters.');
      return;
    }

    _setBusy(true);
    try {
      if (_isRegister) {
        final result = await app.signUp(
          email: email,
          password: password,
          directorName: director,
        );
        if (!mounted) return;
        if (result.needsEmailConfirmation) {
          setState(() {
            _pendingEmail = result.email;
            _awaitingOtp = true;
            _otpCtl.clear();
            _infoMessage = 'confirmation sent to ${result.email}';
          });
        } else {
          showNote(context, 'welcome to the set, ${app.name} ✓');
        }
      } else {
        await app.signIn(email: email, password: password);
        if (!mounted) return;
        showNote(context, 'welcome back, ${app.name} ✓');
      }
    } catch (e) {
      if (!mounted) return;
      final isUnconfirmed =
          e is AuthException && e.message.toLowerCase().contains('email not confirmed');
      setState(() {
        _errorMessage = _friendlyAuthError(e);
        _emailUnconfirmedHint = isUnconfirmed;
        if (isUnconfirmed) _pendingEmail = email;
      });
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_busy || _googleBusy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
      _emailUnconfirmedHint = false;
      _googleBusy = true;
    });
    _reelSpin.repeat();
    try {
      final launched = await app.signInWithGoogle();
      if (!mounted) return;
      if (app.user != null) {
        showNote(context, 'welcome, ${app.name} ✓');
      } else if (!launched) {
        setState(() {
          _errorMessage = 'couldn\'t open Google sign-in – check your browser settings.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyAuthError(e));
    } finally {
      if (mounted) {
        setState(() => _googleBusy = false);
        if (!_busy) {
          _reelSpin.stop();
          _reelSpin.value = 0;
        }
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_busy || _googleBusy) return;
    FocusScope.of(context).unfocus();
    final code = _otpCtl.text.trim();
    if (code.length < 6) {
      setState(() {
        _errorMessage = 'enter the 6-digit code from your email.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });

    _setBusy(true);
    try {
      await app.verifySignupOtp(
        email: _pendingEmail,
        token: code,
        directorName: _nameCtl.text.trim(),
      );
      if (!mounted) return;
      showNote(context, 'ticket verified – roll camera, ${app.name}! ✓');
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyAuthError(e));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _resendConfirmation() async {
    if (_busy || _googleBusy || _pendingEmail.isEmpty) return;
    _setBusy(true);
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await app.resendSignupOtp(_pendingEmail);
      if (!mounted) return;
      setState(() => _infoMessage = 'fresh confirmation email sent ✓');
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyAuthError(e));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _openForgotPasswordDialog() async {
    final ctl = TextEditingController(text: _emailCtl.text.trim());
    await showSketchDialog<void>(
      context,
      (c) => SketchDialogCard(
        title: 'lost your pass?',
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'enter your email and we\'ll send a reset link.',
              style: T.body(15),
            ),
            const SizedBox(height: 10),
            SketchBox(
              shadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: TextField(
                controller: ctl,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: T.body(16),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'you@cinema.club',
                  hintStyle: T.body(15, c: Ink.faint),
                ),
              ),
            ),
          ],
        ),
        actions: [
          SketchTextButton('cancel', onTap: () => Navigator.pop(c)),
          SketchTextButton(
            'send link',
            primary: true,
            onTap: () async {
              final target = ctl.text.trim();
              if (!_looksLikeEmail(target)) {
                Navigator.pop(c);
                setState(() => _errorMessage = 'enter a valid email first to reset your pass.');
                return;
              }
              Navigator.pop(c);
              _setBusy(true);
              try {
                await app.sendPasswordReset(target);
                if (!mounted) return;
                setState(() {
                  _errorMessage = null;
                  _infoMessage = 'password reset link sent to $target ✓';
                });
              } catch (e) {
                if (!mounted) return;
                setState(() => _errorMessage = _friendlyAuthError(e));
              } finally {
                _setBusy(false);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var i = 0;
    Widget r(Widget w) => Reveal(index: i++, child: w);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── header
            r(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Note('daily soundtrack diary', size: 15),
                  const SizedBox(height: 2),
                  Text('IF MY LIFE\nWAS A MOVIE...', style: T.head(29)),
                ]),
              ),
              SketchTap(
                onTap: () => setState(() => _clapTurns += 1),
                child: AnimatedRotation(
                  turns: _clapTurns,
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutBack,
                  child: SketchBox(
                    padding: EdgeInsets.zero,
                    seed: 4,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(alignment: Alignment.center, children: [
                        const HatchSwatch(Hatch.cross, size: 44, gap: 4),
                        Container(
                          width: 24,
                          height: 24,
                          color: Ink.paper,
                          child: const Icon(Icons.movie_outlined, size: 18, color: Ink.ink),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ])),
            const SizedBox(height: 22),

            // ── mode tabs (SIGN IN / REGISTER)
            if (!_awaitingOtp) ...[
              r(Row(children: [
                Expanded(
                  child: _ModeTab(
                    label: 'SIGN IN',
                    selected: !_isRegister,
                    seed: 31,
                    onTap: () => _switchMode(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModeTab(
                    label: 'REGISTER',
                    selected: _isRegister,
                    seed: 37,
                    onTap: () => _switchMode(true),
                  ),
                ),
              ])),
              const SizedBox(height: 14),
            ],

            // ── main auth card
            r(TagBox(
              label: _awaitingOtp
                  ? 'confirm email'
                  : (_isRegister ? 'new director' : 'ticket booth'),
              right: true,
              seed: 19,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _awaitingOtp ? _buildOtpBody() : _buildCredentialsBody(),
              ),
            )),

            const SizedBox(height: 18),

            // ── quiet demo link
            r(Center(
              child: GestureDetector(
                onTap: (_busy || _googleBusy) ? null : app.enterDemoMode,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'just peeking? preview demo reel →',
                    style: T.note(16, c: Ink.soft).copyWith(decoration: TextDecoration.underline),
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialsBody() {
    final actionLabel = _busy
        ? (_isRegister ? 'CREATING...' : 'SIGNING IN...')
        : (_isRegister ? 'CREATE MY REEL →' : 'ROLL CAMERA →');

    return Column(
      key: ValueKey('creds_$_isRegister'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isRegister) ...[
          Text('DIRECTOR NAME', style: T.head(13)),
          const SizedBox(height: 4),
          _SketchInput(
            controller: _nameCtl,
            hint: 'e.g. maya',
            icon: Icons.person_outline,
            seed: 41,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
        ],
        Text('EMAIL', style: T.head(13)),
        const SizedBox(height: 4),
        _SketchInput(
          controller: _emailCtl,
          hint: 'you@cinema.club',
          icon: Icons.alternate_email,
          seed: 43,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('PASSWORD', style: T.head(13)),
          if (!_isRegister)
            GestureDetector(
              onTap: (_busy || _googleBusy) ? null : _openForgotPasswordDialog,
              child: Text(
                'forgot?',
                style: T.note(14, c: Ink.soft).copyWith(decoration: TextDecoration.underline),
              ),
            )
          else
            const Note('min. 6 chars', size: 13),
        ]),
        const SizedBox(height: 4),
        _SketchInput(
          controller: _passCtl,
          hint: '••••••••',
          icon: Icons.key_outlined,
          seed: 47,
          obscureText: _obscurePass,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          trailing: GestureDetector(
            onTap: () => setState(() => _obscurePass = !_obscurePass),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18,
                color: Ink.soft,
              ),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _BannerNote(
            icon: Icons.error_outline,
            text: _errorMessage!,
            actionLabel: _emailUnconfirmedHint ? 'enter code / resend →' : null,
            onAction: _emailUnconfirmedHint
                ? () => setState(() {
                      _awaitingOtp = true;
                      _errorMessage = null;
                    })
                : null,
          ),
        ],
        if (_infoMessage != null) ...[
          const SizedBox(height: 12),
          _BannerNote(
            icon: Icons.mark_email_read_outlined,
            text: _infoMessage!,
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: SketchTap(
            onTap: (_busy || _googleBusy) ? null : _submit,
            child: SketchBox(
              fill: Ink.ink,
              seed: 59,
              padding: EdgeInsets.zero,
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_busy) ...[
                    RotationTransition(
                      turns: _reelSpin,
                      child: const Icon(Icons.album_outlined, size: 17, color: Ink.paper),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(actionLabel, style: T.head(15, c: Ink.paper)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Row(children: [
          Expanded(child: DashedLine()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Note('or', size: 14),
          ),
          Expanded(child: DashedLine()),
        ]),
        const SizedBox(height: 12),
        _GoogleSketchButton(
          busy: _googleBusy,
          spin: _reelSpin,
          onTap: (_busy || _googleBusy) ? null : _signInWithGoogle,
        ),
      ],
    );
  }

  Widget _buildOtpBody() {
    return Column(
      key: const ValueKey('otp_verify'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CHECK YOUR INBOX', style: T.head(19)),
        Note(_pendingEmail, size: 14, color: Ink.ink),
        const SizedBox(height: 8),
        Text(
          'enter the 6-digit code from your email, or click the confirmation link and sign in.',
          style: T.body(14, c: Ink.soft),
        ),
        const SizedBox(height: 12),
        _SketchInput(
          controller: _otpCtl,
          hint: '6-digit code',
          icon: Icons.confirmation_number_outlined,
          seed: 67,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _verifyOtp(),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _BannerNote(icon: Icons.error_outline, text: _errorMessage!),
        ],
        if (_infoMessage != null) ...[
          const SizedBox(height: 12),
          _BannerNote(icon: Icons.mark_email_read_outlined, text: _infoMessage!),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: SketchTap(
            onTap: _busy ? null : _verifyOtp,
            child: SketchBox(
              fill: Ink.ink,
              seed: 71,
              padding: EdgeInsets.zero,
              child: Center(
                child: Text(
                  _busy ? 'VERIFYING...' : 'VERIFY TICKET →',
                  style: T.head(15, c: Ink.paper),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(
            onTap: _busy
                ? null
                : () => setState(() {
                      _awaitingOtp = false;
                      _errorMessage = null;
                      _infoMessage = null;
                    }),
            child: Text(
              '← back',
              style: T.note(15, c: Ink.soft).copyWith(decoration: TextDecoration.underline),
            ),
          ),
          GestureDetector(
            onTap: _busy ? null : _resendConfirmation,
            child: Text(
              'resend code',
              style: T.note(15, c: Ink.ink).copyWith(decoration: TextDecoration.underline),
            ),
          ),
          GestureDetector(
            onTap: _busy
                ? null
                : () {
                    setState(() {
                      _awaitingOtp = false;
                      _isRegister = false;
                      _errorMessage = null;
                      _infoMessage = 'confirmed via link? sign right in!';
                    });
                  },
            child: Text(
              'sign in →',
              style: T.note(15, c: Ink.ink).copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ]),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final int seed;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.selected,
    required this.seed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SketchTap(
      onTap: onTap,
      pressedScale: 0.96,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: selected ? Ink.ink : Ink.paper),
        duration: const Duration(milliseconds: 180),
        builder: (_, fill, _) => SketchBox(
          fill: fill ?? Ink.paper,
          shadow: selected,
          dashed: !selected,
          seed: seed,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(
              label,
              style: T.head(15, c: selected ? Ink.paper : Ink.ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _SketchInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int seed;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  const _SketchInput({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.seed,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return SketchBox(
      seed: seed,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(children: [
        Icon(icon, size: 17, color: Ink.soft),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autocorrect: false,
            enableSuggestions: !obscureText,
            style: T.body(16),
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: InputBorder.none,
              hintText: hint,
              hintStyle: T.body(15, c: Ink.faint),
            ),
          ),
        ),
        ?trailing,
      ]),
    );
  }
}

class _BannerNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _BannerNote({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SketchBox(
      seed: 83,
      shadow: false,
      dashed: true,
      fill: Ink.bg,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: Ink.ink),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: T.body(14, c: Ink.ink))),
        ]),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: T.note(14, c: Ink.ink).copyWith(decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

class _GoogleSketchButton extends StatelessWidget {
  final bool busy;
  final Animation<double> spin;
  final VoidCallback? onTap;

  const _GoogleSketchButton({
    required this.busy,
    required this.spin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: SketchTap(
        onTap: onTap,
        pressedScale: 0.97,
        child: SketchBox(
          fill: Ink.paper,
          shadow: false,
          seed: 77,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (busy)
              RotationTransition(
                turns: spin,
                child: const Icon(Icons.album_outlined, size: 17, color: Ink.ink),
              )
            else
              SizedBox(
                width: 18,
                height: 18,
                child: CustomPaint(painter: _GoogleSketchGPainter()),
              ),
            const SizedBox(width: 8),
            Text(
              busy ? 'OPENING GOOGLE...' : 'CONTINUE WITH GOOGLE',
              style: T.head(14),
            ),
          ]),
        ),
      ),
    );
  }
}

class _GoogleSketchGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.38;
    final paint = Paint()
      ..color = Ink.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(rect, -0.55, math.pi * 1.72, false, paint);
    canvas.drawLine(
      Offset(c.dx + 0.5, c.dy),
      Offset(c.dx + r + 0.8, c.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
