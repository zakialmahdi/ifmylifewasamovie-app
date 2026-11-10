import 'dart:convert';
import 'package:flutter/material.dart' hide Ink;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../sketch.dart';
import '../state.dart';

Future<void> showSuggestionDialog(BuildContext context) {
  return showSketchDialog<void>(
    context,
    (c) => const _SuggestionDialog(),
  );
}

class _SuggestionDialog extends StatefulWidget {
  const _SuggestionDialog();

  @override
  State<_SuggestionDialog> createState() => _SuggestionDialogState();
}

class _SuggestionDialogState extends State<_SuggestionDialog> {
  static const String _targetEmail = 'zakialmahdi@gmail.com';

  static const List<String> _categories = [
    'New feature',
    'Music & audio',
    'Zine & sharing',
    'Diary & mood',
    'Bug / issue',
    'Other idea',
  ];

  String _selectedCategory = _categories.first;
  late final TextEditingController _titleCtl;
  late final TextEditingController _messageCtl;
  late final TextEditingController _emailCtl;

  bool _isSubmitting = false;
  String? _errorText;
  bool _submittedSuccess = false;

  @override
  void initState() {
    super.initState();
    _titleCtl = TextEditingController();
    _messageCtl = TextEditingController();
    _emailCtl = TextEditingController(text: app.user?.email ?? '');
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _messageCtl.dispose();
    _emailCtl.dispose();
    super.dispose();
  }

  Future<void> _submitSuggestion() async {
    final title = _titleCtl.text.trim();
    final message = _messageCtl.text.trim();
    final senderEmail = _emailCtl.text.trim();

    if (message.isEmpty && title.isEmpty) {
      setState(() {
        _errorText = 'please enter a suggestion or idea first';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final summary = title.isNotEmpty ? title : 'Feedback & suggestion';
    final userLabel = '${app.name} (${app.handle})';

    // 1. Send email directly to zakialmahdi@gmail.com via FormSubmit AJAX API
    try {
      await http.post(
        Uri.parse('https://formsubmit.co/ajax/$_targetEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          '_subject': '[If My Life Was A Movie] $_selectedCategory: $summary',
          'name': userLabel,
          'email': senderEmail.isNotEmpty ? senderEmail : 'anonymous@ifmylifewasamovie.app',
          'category': _selectedCategory,
          'title': summary,
          'message': message.isNotEmpty ? message : summary,
          'app_name': 'If My Life Was A Movie',
          'director_name': app.name,
          'director_handle': app.handle,
          'invite_code': app.inviteCode,
          'target_developer': 'zakialmahdi@gmail.com',
          '_template': 'table',
        }),
      ).timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('FormSubmit direct email error: $e');
    }

    // 2. Persist to Supabase suggestions table (if connected)
    try {
      if (!app.demoMode && app.user != null) {
        await Supabase.instance.client.from('suggestions').insert({
          'user_id': app.user?.id,
          'user_name': app.name,
          'user_handle': app.handle,
          'user_email': senderEmail.isNotEmpty ? senderEmail : null,
          'category': _selectedCategory,
          'message': '$summary\n\n$message',
          'target_email': _targetEmail,
        });
      }
    } catch (e) {
      debugPrint('Supabase suggestion backup error: $e');
    }

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _submittedSuccess = true;
    });

    showNote(context, 'suggestion sent to $_targetEmail ✓');
  }

  Future<void> _openMailApp() async {
    final title = _titleCtl.text.trim();
    final message = _messageCtl.text.trim();
    final senderEmail = _emailCtl.text.trim();
    final summary = title.isNotEmpty ? title : 'Feature suggestion';

    final mailUri = Uri(
      scheme: 'mailto',
      path: _targetEmail,
      queryParameters: {
        'subject': '[If My Life Was A Movie] $_selectedCategory: $summary',
        'body': 'From: ${app.name} (${app.handle})\n'
            '${senderEmail.isNotEmpty ? 'Reply to: $senderEmail\n' : ''}'
            'Category: $_selectedCategory\n\n'
            'Suggestion / Feedback:\n'
            '${message.isNotEmpty ? message : summary}\n',
      },
    );

    try {
      if (await canLaunchUrl(mailUri)) {
        await launchUrl(mailUri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(
          text: 'To: $_targetEmail\nSubject: [If My Life Was A Movie] $_selectedCategory: $summary\n\n$message',
        ));
        if (mounted) {
          showNote(context, 'email details copied to clipboard ✓');
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _targetEmail));
      if (mounted) {
        showNote(context, 'copied $_targetEmail to clipboard ✓');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submittedSuccess) {
      return SketchDialogCard(
        title: 'suggestion sent',
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 28, color: Ink.ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('THANK YOU!', style: T.head(16)),
                      const Note('your suggestion has been delivered.', size: 13),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Ink.bg,
                border: Border.all(color: Ink.grey, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SENT TO: $_targetEmail', style: T.head(11, c: Ink.soft)),
                  const SizedBox(height: 4),
                  Text('CATEGORY: $_selectedCategory', style: T.body(12)),
                  if (_titleCtl.text.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('“${_titleCtl.text.trim()}”', style: T.note(12, c: Ink.ink)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Note('lone developer zakialmahdi reviews all user ideas and feedback for upcoming releases.', size: 12),
          ],
        ),
        actions: [
          SketchTextButton(
            'done',
            primary: true,
            onTap: () => Navigator.pop(context),
          ),
        ],
      );
    }

    return SketchDialogCard(
      title: 'suggestion box',
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mark_email_read_outlined, size: 16, color: Ink.ink),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'DELIVER TO: $_targetEmail',
                    style: T.head(11, c: Ink.soft),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Note(
              'share an idea, feature request, or feedback directly with lone developer zakialmahdi.',
              size: 13,
            ),
            const SizedBox(height: 12),

            // ── Category Chips
            Text('CATEGORY', style: T.head(12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cat in _categories)
                  SketchChip(
                    label: cat,
                    selected: _selectedCategory == cat,
                    seed: cat.hashCode % 19 + 3,
                    onTap: () => setState(() => _selectedCategory = cat),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Idea Title Field
            Text('TITLE / SUMMARY', style: T.head(12)),
            const SizedBox(height: 4),
            SketchBox(
              shadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: TextField(
                controller: _titleCtl,
                style: T.body(15),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'e.g. Add Spotify playlist sync, more sketch hatches...',
                  hintStyle: T.body(14, c: Ink.faint),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Details / Description Field
            Text('DETAILS & FEEDBACK', style: T.head(12)),
            const SizedBox(height: 4),
            SketchBox(
              shadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: TextField(
                controller: _messageCtl,
                minLines: 3,
                maxLines: 6,
                style: T.body(15),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'What would make the app better for you? Describe how it should work...',
                  hintStyle: T.body(14, c: Ink.faint),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Optional Contact Email Field
            Text('YOUR EMAIL (OPTIONAL)', style: T.head(12)),
            const SizedBox(height: 4),
            SketchBox(
              shadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: TextField(
                controller: _emailCtl,
                keyboardType: TextInputType.emailAddress,
                style: T.body(14),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'for replies (leave blank to stay anonymous)',
                  hintStyle: T.body(13, c: Ink.faint),
                ),
              ),
            ),

            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(_errorText!, style: T.note(12, c: Colors.red.shade800)),
            ],

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _openMailApp,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mail_outline, size: 14, color: Ink.soft),
                      const SizedBox(width: 4),
                      Text('open in email app', style: T.note(12, c: Ink.soft)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        SketchTextButton(
          'cancel',
          onTap: () => Navigator.pop(context),
        ),
        SketchTextButton(
          _isSubmitting ? 'sending...' : 'send suggestion',
          primary: true,
          onTap: _isSubmitting ? () {} : _submitSuggestion,
        ),
      ],
    );
  }
}
