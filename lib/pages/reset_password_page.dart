import 'package:flutter/material.dart' hide Ink;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../sketch.dart';
import '../state.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _passCtl = TextEditingController();
  final TextEditingController _confirmCtl = TextEditingController();

  late final AnimationController _reelSpin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool _obscurePass = true;
  bool _busy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passCtl.dispose();
    _confirmCtl.dispose();
    _reelSpin.dispose();
    super.dispose();
  }

  void _setBusy(bool value) {
    if (!mounted) return;
    setState(() => _busy = value);
    if (value) {
      _reelSpin.repeat();
    } else {
      _reelSpin.stop();
      _reelSpin.value = 0;
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();

    final password = _passCtl.text;
    final confirm = _confirmCtl.text;

    setState(() => _errorMessage = null);

    if (password.length < 6) {
      setState(() => _errorMessage = 'password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'passwords do not match – check the second take.');
      return;
    }

    _setBusy(true);
    try {
      await app.updatePassword(password);
      if (!mounted) return;
      showNote(context, 'new password saved – welcome back, ${app.name}! ✓');
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is AuthException) {
          _errorMessage = e.message.toLowerCase();
        } else {
          _errorMessage = 'could not update password – please try again.';
        }
      });
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    await app.signOut();
    if (!mounted) return;
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Text(
              'take two • recovery pass',
              style: T.note(15, c: Ink.soft),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'NEW PASSWORD',
              style: T.head(28),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'type a fresh password to secure your director account.',
              style: T.body(14, c: Ink.soft),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),
          SketchBox(
            seed: 42,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('NEW PASSWORD (MIN 6 CHARS)', style: T.note(13, c: Ink.soft)),
                const SizedBox(height: 6),
                SketchBox(
                  shadow: false,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _passCtl,
                          obscureText: _obscurePass,
                          style: T.body(16),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: '••••••••',
                            hintStyle: T.body(16, c: Ink.faint),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        icon: Icon(
                          _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 19,
                          color: Ink.soft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('CONFIRM NEW PASSWORD', style: T.note(13, c: Ink.soft)),
                const SizedBox(height: 6),
                SketchBox(
                  shadow: false,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: TextField(
                    controller: _confirmCtl,
                    obscureText: _obscurePass,
                    style: T.body(16),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '••••••••',
                      hintStyle: T.body(16, c: Ink.faint),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Ink.grey.withAlpha(50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: Ink.ink),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: T.note(13, c: Ink.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SketchButton(
                  primary: true,
                  onTap: _busy ? null : _submit,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_busy) ...[
                        RotationTransition(
                          turns: _reelSpin,
                          child: const Icon(Icons.album_outlined, size: 18, color: Ink.paper),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _busy ? 'saving take...' : 'save new password ✓',
                        style: T.body(16, c: Ink.paper),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: SketchTextButton(
              'cancel & return to sign in',
              onTap: _cancel,
            ),
          ),
        ],
      ),
    );
  }
}
