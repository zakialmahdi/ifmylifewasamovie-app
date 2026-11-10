import 'dart:math' as math;

import 'package:flutter/material.dart' hide Ink;

import '../sketch.dart';

const List<String> kCinemaPrompts = <String>[
  'If today was a scene in your film, what would be the camera\'s final focus?',
  'What line of dialogue or passing thought from today belongs in the trailer?',
  'What was the quietest, most cinematographic moment of your day?',
  'Who or what was the unexpected co-star in today\'s plot?',
  'What lighting or weather was playing in the background of your mood?',
  'If today was a chapter in a coming-of-age movie, what would you title it?',
];

/// Presents an interactive cinema director reflection prompt before wrapping or saving a scene.
///
/// Returns:
/// - `null` if the dialog was cancelled/dismissed without confirming.
/// - `''` (empty string) if the user chose to "skip & save".
/// - non-empty `String` with the director's reflection to be appended to the scene dialogue.
Future<String?> showMoodPromptDialog(
  BuildContext context, {
  int initialIndex = 0,
}) {
  final rnd = math.Random();
  var promptIdx = initialIndex % kCinemaPrompts.length;
  if (initialIndex == 0) {
    promptIdx = rnd.nextInt(kCinemaPrompts.length);
  }
  final ctl = TextEditingController();

  return showSketchDialog<String?>(
    context,
    (c) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final currentPrompt = kCinemaPrompts[promptIdx];

        return SketchDialogCard(
          title: "director's prompt",
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Note('take ${promptIdx + 1} of ${kCinemaPrompts.length}', size: 14),
                  SketchTap(
                    onTap: () {
                      setDialogState(() {
                        promptIdx = (promptIdx + 1) % kCinemaPrompts.length;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.refresh, size: 14, color: Ink.soft),
                          const SizedBox(width: 4),
                          Text('ANOTHER PROMPT', style: T.head(12, c: Ink.soft)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SketchBox(
                seed: 47 + promptIdx,
                dashed: true,
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('“', style: T.head(24, c: Ink.soft)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        currentPrompt,
                        style: T.body(16, c: Ink.ink, w: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Note('scribble your reflection (optional)', size: 14),
              const SizedBox(height: 4),
              SketchBox(
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: TextField(
                  controller: ctl,
                  maxLines: 2,
                  style: T.body(15),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'e.g. walked past the old diner alone...',
                    hintStyle: T.body(14, c: Ink.faint),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            SketchTextButton(
              'skip & save',
              onTap: () => Navigator.pop(c, ''),
            ),
            SketchTextButton(
              'wrap scene ✓',
              primary: true,
              onTap: () => Navigator.pop(c, ctl.text.trim()),
            ),
          ],
        );
      },
    ),
  );
}
