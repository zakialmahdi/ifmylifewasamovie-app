import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' hide Ink;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../sketch.dart';

/// An in-app authentication sheet allowing the user to sign in to their
/// YouTube/Google account to extract session cookies (`LOGIN_INFO`, `SID`,
/// `VISITOR_INFO1_LIVE`). These cookies are passed to `youtube_explode_dart`
/// to bypass YouTube bot detection (`RequestLimitExceededException` / 429).
class YouTubeLoginSheet extends StatefulWidget {
  const YouTubeLoginSheet({super.key});

  @override
  State<YouTubeLoginSheet> createState() => _YouTubeLoginSheetState();
}

class _YouTubeLoginSheetState extends State<YouTubeLoginSheet> {
  final CookieManager _cookieManager = CookieManager.instance();
  final TextEditingController _pasteCtl = TextEditingController();

  int _selectedTab = 0; // 0 = In-App WebView, 1 = Manual Paste
  bool _loading = true;
  String? _statusMessage;
  bool _extracting = false;

  // Clean mobile Chrome UA without the '; wv' or 'Version/4.0' WebView markers.
  // This avoids Google's "403 disallowed_useragent" embedded browser block.
  static const String _cleanMobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.6367.113 Mobile Safari/537.36';

  static const String _initialSignInUrl =
      'https://accounts.google.com/ServiceLogin?service=youtube&uilel=3&passive=true&continue=https%3A%2F%2Fm.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue';

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    // Default to paste tab on platforms without full embedded webview support
    if (!_isMobile) {
      _selectedTab = 1;
    }
  }

  @override
  void dispose() {
    _pasteCtl.dispose();
    super.dispose();
  }

  Future<void> _checkCookiesAndComplete({bool manualTrigger = false}) async {
    if (_extracting) return;
    _extracting = true;

    try {
      final List<Cookie> allCookies = <Cookie>[];

      for (final url in [
        WebUri('https://www.youtube.com'),
        WebUri('https://m.youtube.com'),
        WebUri('https://youtube.com'),
      ]) {
        try {
          final c = await _cookieManager.getCookies(url: url);
          allCookies.addAll(c);
        } catch (_) {}
      }

      // Deduplicate by name
      final cookieMap = <String, String>{};
      for (final c in allCookies) {
        if (c.name.isNotEmpty && c.value != null) {
          cookieMap[c.name] = c.value.toString();
        }
      }

      final cookieString =
          cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');

      final hasSession = cookieString.contains('LOGIN_INFO') ||
          (cookieString.contains('SID=') && cookieString.contains('HSID='));

      if (hasSession) {
        if (mounted) {
          Navigator.pop(context, cookieString);
        }
      } else if (manualTrigger) {
        if (mounted) {
          setState(() {
            _statusMessage =
                'no active login session detected yet – please complete sign-in above.';
          });
        }
      }
    } catch (_) {
      if (manualTrigger && mounted) {
        setState(() {
          _statusMessage = 'couldn\'t read cookies – please try again.';
        });
      }
    } finally {
      _extracting = false;
    }
  }

  void _submitPastedCookies() {
    final raw = _pasteCtl.text.trim();
    if (raw.isEmpty) {
      setState(() => _statusMessage = 'please paste your cookie string above.');
      return;
    }
    if (!raw.contains('=') ||
        (!raw.contains('LOGIN_INFO') &&
            !raw.contains('VISITOR_INFO1_LIVE') &&
            !raw.contains('SID'))) {
      setState(() {
        _statusMessage =
            'cookies should contain LOGIN_INFO, VISITOR_INFO1_LIVE, or SID.';
      });
      return;
    }
    Navigator.pop(context, raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ink.paper,
      appBar: AppBar(
        backgroundColor: Ink.paper,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Ink.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('YOUTUBE SESSION BRIDGE', style: T.head(19)),
        actions: [
          if (_selectedTab == 0 && _isMobile)
            TextButton(
              onPressed: () => _checkCookiesAndComplete(manualTrigger: true),
              child: Text(
                'CHECK COOKIES',
                style: T.head(13, c: Ink.ink).copyWith(
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tab Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (_isMobile)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SketchTap(
                          onTap: () => setState(() => _selectedTab = 0),
                          child: SketchBox(
                            seed: 41,
                            fill: _selectedTab == 0 ? Ink.ink : Ink.paper,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Text(
                                'IN-APP SIGN IN',
                                style: T.head(
                                  14,
                                  c: _selectedTab == 0 ? Ink.paper : Ink.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: SketchTap(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: SketchBox(
                        seed: 42,
                        fill: _selectedTab == 1 ? Ink.ink : Ink.paper,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Text(
                            'PASTE COOKIES',
                            style: T.head(
                              14,
                              c: _selectedTab == 1 ? Ink.paper : Ink.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SketchBox(
                  seed: 43,
                  dashed: true,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Ink.ink),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_statusMessage!, style: T.body(13)),
                      ),
                    ],
                  ),
                ),
              ),

            // Tab Content
            Expanded(
              child: _selectedTab == 0 && _isMobile
                  ? Stack(
                      children: [
                        InAppWebView(
                          initialUrlRequest: URLRequest(
                            url: WebUri(_initialSignInUrl),
                          ),
                          initialSettings: InAppWebViewSettings(
                            userAgent: _cleanMobileUserAgent,
                            // Suppress X-Requested-With header to bypass Google's 403 disallowed_useragent
                            requestedWithHeaderOriginAllowList: <String>{},
                            javaScriptEnabled: true,
                            domStorageEnabled: true,
                            databaseEnabled: true,
                            cacheEnabled: true,
                            thirdPartyCookiesEnabled: true,
                            sharedCookiesEnabled: true,
                          ),
                          onLoadStart: (_, _) {
                            if (mounted) setState(() => _loading = true);
                          },
                          onLoadStop: (ctl, url) async {
                            if (mounted) setState(() => _loading = false);
                            if (url != null) {
                              final u = url.toString();
                              if (u.contains('youtube.com') ||
                                  u.contains('myaccount.google.com')) {
                                await _checkCookiesAndComplete();
                              }
                            }
                          },
                        ),
                        if (_loading)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: const LinearProgressIndicator(
                              color: Ink.ink,
                              backgroundColor: Ink.grey,
                            ),
                          ),
                      ],
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TagBox(
                            label: 'manual cookie import',
                            seed: 44,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CONNECT WITH COOKIES',
                                    style: T.head(18),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'if you already have YouTube cookies from your browser or another app, paste them below. this grants authenticated session access to bypass RequestLimitExceededException.',
                                    style: T.body(14, c: Ink.soft),
                                  ),
                                  const SizedBox(height: 14),
                                  const Note('cookie header string', size: 14),
                                  const SizedBox(height: 4),
                                  SketchBox(
                                    shadow: false,
                                    padding: const EdgeInsets.all(10),
                                    child: TextField(
                                      controller: _pasteCtl,
                                      maxLines: 5,
                                      style: T.body(13),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText:
                                            'LOGIN_INFO=...; VISITOR_INFO1_LIVE=...; SID=...',
                                        hintStyle: T.body(13, c: Ink.faint),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  SketchTextButton(
                                    'connect session ✓',
                                    primary: true,
                                    onTap: _submitPastedCookies,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Note(
                            '💡 tip: your session cookies stay strictly on this device in private storage and are never uploaded to any third party.',
                            size: 13,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
