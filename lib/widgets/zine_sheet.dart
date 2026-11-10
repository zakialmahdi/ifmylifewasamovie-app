import 'package:flutter/material.dart' hide Ink;

import '../sketch.dart';
import '../state.dart';

/// Formats available for exporting and sharing across social platforms.
enum ZineFormat {
  story9x16(
    label: '9:16 Story',
    subtitle: 'Instagram Stories, TikTok, WhatsApp Status',
    width: 450,
    height: 800,
    pixelRatio: 3.0,
    fileTag: 'story_9x16',
  ),
  feed4x5(
    label: '4:5 Feed',
    subtitle: 'Instagram Post, Twitter/X, Threads',
    width: 600,
    height: 750,
    pixelRatio: 3.0,
    fileTag: 'feed_4x5',
  ),
  foldableLandscape(
    label: 'Printable Sheet',
    subtitle: '8-panel foldable A4/Letter mini-zine',
    width: 1040,
    height: 740,
    pixelRatio: 3.0,
    fileTag: 'foldable_sheet',
  );

  final String label;
  final String subtitle;
  final double width;
  final double height;
  final double pixelRatio;
  final String fileTag;

  const ZineFormat({
    required this.label,
    required this.subtitle,
    required this.width,
    required this.height,
    required this.pixelRatio,
    required this.fileTag,
  });
}

/// Master Zine widget that renders according to the chosen [format],
/// styled with authentic indie cinema aesthetics: 35mm filmstrip borders,
/// vinyl record album art peek, Polaroid snapshots, and retro ticket stubs.
class ZineSheet extends StatelessWidget {
  final ZineFormat format;
  final List<Entry> scenes;
  final String directorName;
  final String handle;
  final String inviteCode;

  const ZineSheet({
    super.key,
    this.format = ZineFormat.story9x16,
    required this.scenes,
    required this.directorName,
    required this.handle,
    required this.inviteCode,
  });

  @override
  Widget build(BuildContext context) {
    switch (format) {
      case ZineFormat.story9x16:
        return _ZineStoryLayout(
          scenes: scenes,
          directorName: directorName,
          handle: handle,
          inviteCode: inviteCode,
        );
      case ZineFormat.feed4x5:
        return _ZineFeedLayout(
          scenes: scenes,
          directorName: directorName,
          handle: handle,
          inviteCode: inviteCode,
        );
      case ZineFormat.foldableLandscape:
        return _ZineFoldableLayout(
          scenes: scenes,
          directorName: directorName,
          handle: handle,
          inviteCode: inviteCode,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ARTISTIC REUSABLE ZINE ELEMENTS
// ─────────────────────────────────────────────────────────────────────────────

/// Album art presented with a realistic grooved black vinyl record disc peeking out.
class ZineAlbumArt extends StatelessWidget {
  final Song song;
  final Mood mood;
  final double size;

  const ZineAlbumArt({
    super.key,
    required this.song,
    this.mood = hopeful,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    final discSize = size * 0.92;
    final peekOffset = size * 0.28;

    return SizedBox(
      width: size + peekOffset,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          // Black Vinyl Record peeking out from the jacket
          Positioned(
            left: peekOffset,
            child: Container(
              width: discSize,
              height: discSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF141414),
                border: Border.all(color: const Color(0xFF2C2C2C), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    offset: Offset(1.5, 1.5),
                    blurRadius: 2.5,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Vinyl groove circles
                  CustomPaint(
                    size: Size(discSize, discSize),
                    painter: const _VinylGroovePainter(),
                  ),
                  // Center record label matching mood hatch
                  Container(
                    width: discSize * 0.38,
                    height: discSize * 0.38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Ink.paper, width: 1.0),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: HatchSwatch(mood.hatch, size: discSize * 0.38, circle: true, gap: 2.0),
                  ),
                  // Center spindle hole
                  Container(
                    width: discSize * 0.10,
                    height: discSize * 0.10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Ink.paper,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Square Album Jacket on top
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Ink.paper,
              border: Border.all(color: Ink.ink, width: 1.6),
              boxShadow: const [
                BoxShadow(
                  color: Ink.ink,
                  offset: Offset(2.2, 2.2),
                  blurRadius: 0,
                ),
              ],
            ),
            padding: const EdgeInsets.all(1.5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: SongArtBox(
                song: song,
                size: size - 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VinylGroovePainter extends CustomPainter {
  const _VinylGroovePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final paint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.65;

    for (double r = maxR * 0.44; r < maxR * 0.94; r += 2.6) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Authentic vertical 35mm cinema filmstrip running along the layout borders.
class _FilmstripBorder extends StatelessWidget {
  final double height;
  final bool isLeft;

  const _FilmstripBorder({
    required this.height,
    this.isLeft = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: height,
      color: const Color(0xFF1C1C1C),
      child: CustomPaint(
        size: Size(22, height),
        painter: _FilmstripSprocketPainter(isLeft: isLeft),
      ),
    );
  }
}

class _FilmstripSprocketPainter extends CustomPainter {
  final bool isLeft;
  const _FilmstripSprocketPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final sprocketPaint = Paint()
      ..color = Ink.paper
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF383838)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final sprocketW = 10.0;
    final sprocketH = 14.0;
    final left = (size.width - sprocketW) / 2;

    double y = 10.0;
    while (y + sprocketH < size.height) {
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, y, sprocketW, sprocketH),
        const Radius.circular(2.4),
      );
      canvas.drawRRect(rrect, sprocketPaint);
      canvas.drawRRect(rrect, borderPaint);
      y += 24.0;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Translucent washi tape strip to give scrapbooking tactile authenticity.
class _WashiTape extends StatelessWidget {
  final double width;
  final double height;
  final double angle;

  const _WashiTape({
    this.width = 44,
    this.height = 14,
    this.angle = -0.05,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xD6DDD8C6),
          border: Border.all(color: const Color(0x669E9A8A), width: 0.8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(0, 1),
              blurRadius: 1,
            ),
          ],
        ),
        child: CustomPaint(
          painter: const _TapeTexturePainter(),
        ),
      ),
    );
  }
}

class _TapeTexturePainter extends CustomPainter {
  const _TapeTexturePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x228C8878)
      ..strokeWidth = 0.8;
    for (double x = 4; x < size.width; x += 5) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official cinema rubber stamp seal with mood hatching.
class _RubberStamp extends StatelessWidget {
  final String text;
  final Hatch hatch;

  const _RubberStamp({
    required this.text,
    required this.hatch,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.04,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
        decoration: BoxDecoration(
          border: Border.all(color: Ink.ink, width: 1.2),
          color: Ink.paper,
          boxShadow: const [
            BoxShadow(
              color: Ink.ink,
              offset: Offset(1.5, 1.5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HatchSwatch(hatch, size: 12, circle: true, gap: 1.8),
            const SizedBox(width: 3.5),
            Text(
              text.toUpperCase(),
              style: T.head(9.5, c: Ink.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vintage cinema ticket stub with notched tear borders and barcode.
class _CinemaTicketStub extends StatelessWidget {
  final String directorName;
  final String handle;
  final String inviteCode;
  final int sceneCount;

  const _CinemaTicketStub({
    required this.directorName,
    required this.handle,
    required this.inviteCode,
    required this.sceneCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Ink.paper,
        border: Border.all(color: Ink.ink, width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: Ink.ink,
            offset: Offset(2.5, 2.5),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Ink.ink,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text('ADMIT ONE', style: T.head(9, c: Ink.paper)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'CINEMA SOUNDSTAGE · $sceneCount SCENES PRESERVED',
                  style: T.head(10, c: Ink.soft),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('TICKET: $inviteCode', style: T.head(10)),
            ],
          ),
          const SizedBox(height: 5),
          const DashedLine(),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DIRECTED BY ${directorName.toUpperCase()}',
                      style: T.head(11),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'ORIGINAL SOUNDTRACK · LONE DEVELOPER: ZAKIALMAHDI',
                      style: T.note(10, c: Ink.soft),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '|||| ||| ||||| || |||||| | ||||||||',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, letterSpacing: -0.7),
                  ),
                  Text('★ CERTIFIED FILM ★', style: T.head(8, c: Ink.soft)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Iconic Hollywood movie poster billing block credits.
class _MovieBillingBlock extends StatelessWidget {
  final String directorName;
  final String inviteCode;

  const _MovieBillingBlock({
    required this.directorName,
    required this.inviteCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: Ink.ink, width: 1.2),
        color: Ink.paper,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '★ AN "IF MY LIFE WAS A MOVIE" CINEMA SOUNDTRACK PRODUCTION ★',
            style: T.head(9, c: Ink.soft),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'DIRECTED & CURATED BY ${directorName.toUpperCase()} · ORIGINAL MUSIC VIA YOUTUBE & ITUNES · ROLL NO. $inviteCode',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 8.5,
              letterSpacing: 0.5,
              color: Ink.ink,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            'WRITTEN ON SKETCH PAPER · CREATIVE DIRECTION & CODE BY LONE DEVELOPER: ZAKIALMAHDI · SOUNDTRACK DIARY v1.0',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 7.8,
              letterSpacing: 0.4,
              color: Ink.soft,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. STORY FORMAT (9:16 Vertical Reel Poster with 35mm Filmstrip Borders)
// ─────────────────────────────────────────────────────────────────────────────

class _ZineStoryLayout extends StatelessWidget {
  final List<Entry> scenes;
  final String directorName;
  final String handle;
  final String inviteCode;

  const _ZineStoryLayout({
    required this.scenes,
    required this.directorName,
    required this.handle,
    required this.inviteCode,
  });

  @override
  Widget build(BuildContext context) {
    // Feature 3 scenes for spacious, poster-grade visual storytelling
    final displayScenes = scenes.length > 3 ? scenes.sublist(scenes.length - 3) : scenes;
    final now = DateTime.now();
    final monthStr = monthNames[now.month - 1].toUpperCase();

    final albumSize = switch (displayScenes.length) {
      1 => 146.0,
      2 => 120.0,
      _ => 104.0,
    };

    return Container(
      width: ZineFormat.story9x16.width,
      height: ZineFormat.story9x16.height,
      color: const Color(0xFF141414),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left 35mm Filmstrip border with sprocket holes
          const _FilmstripBorder(height: 800, isLeft: true),

          // Center Cinema Canvas
          Expanded(
            child: Container(
              color: Ink.paper,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Clapperboard Masthead
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Ink.ink, width: 1.8),
                      color: Ink.paper,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.movie_filter, size: 18, color: Ink.ink),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'IF MY LIFE WAS A MOVIE...',
                                style: T.head(19),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                border: Border.all(color: Ink.ink, width: 1.0),
                                color: Ink.bg,
                              ),
                              child: Text('$monthStr ${now.year}', style: T.head(10)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const DashedLine(),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'DIRECTOR: ${directorName.toUpperCase()} · $handle',
                                style: T.head(11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('ROLL #$inviteCode', style: T.head(10, c: Ink.soft)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Film Scenes
                  Expanded(
                    child: displayScenes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.movie_creation_outlined, size: 40, color: Ink.soft),
                                const SizedBox(height: 8),
                                Text('SCENE IN DRAFT', style: T.head(18)),
                                const SizedBox(height: 4),
                                const Note('camera rolling · queue your first soundtrack scene', size: 14),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < displayScenes.length; i++) ...[
                                Expanded(
                                  child: _StorySceneCard(
                                    scene: displayScenes[i],
                                    index: scenes.indexOf(displayScenes[i]) + 1,
                                    size: albumSize,
                                  ),
                                ),
                                if (i < displayScenes.length - 1)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: DashedLine(),
                                  ),
                              ],
                            ],
                          ),
                  ),

                  const SizedBox(height: 8),

                  // ── Cinema Ticket Stub Footer
                  _CinemaTicketStub(
                    directorName: directorName,
                    handle: handle,
                    inviteCode: inviteCode,
                    sceneCount: scenes.length,
                  ),
                ],
              ),
            ),
          ),

          // Right 35mm Filmstrip border with sprocket holes
          const _FilmstripBorder(height: 800, isLeft: false),
        ],
      ),
    );
  }
}

class _StorySceneCard extends StatelessWidget {
  final Entry scene;
  final int index;
  final double size;

  const _StorySceneCard({
    required this.scene,
    required this.index,
    this.size = 104.0,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = dayLabel(scene.date).toUpperCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // BIG Hero Album Cover with grooved vinyl disc peeking out
        ZineAlbumArt(
          song: scene.song,
          mood: scene.mood,
          size: size,
        ),
        const SizedBox(width: 14),

        // Scene screenplay details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Scene slate & mood rubber stamp
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'SCENE ${scene.scene} · TAKE 1 · $dateStr',
                      style: T.head(11, c: Ink.soft),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _RubberStamp(
                    text: scene.mood.name,
                    hatch: scene.mood.hatch,
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Song Title & Artist
              Text(
                scene.song.title.toUpperCase(),
                style: T.head(17),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${scene.song.artist} · ${fmtTime(scene.song.seconds)}',
                style: T.body(12.5, c: Ink.soft),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Script Dialogue Quote Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Ink.bg,
                  border: Border.all(color: Ink.grey, width: 1.0),
                ),
                child: Text(
                  '“${scene.note.isNotEmpty ? scene.note : 'quiet day on set.'}”',
                  style: T.note(12, c: Ink.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. FEED / POST FORMAT (4:5 Portrait Grid with Washi Tape & Polaroids)
// ─────────────────────────────────────────────────────────────────────────────

class _ZineFeedLayout extends StatelessWidget {
  final List<Entry> scenes;
  final String directorName;
  final String handle;
  final String inviteCode;

  const _ZineFeedLayout({
    required this.scenes,
    required this.directorName,
    required this.handle,
    required this.inviteCode,
  });

  @override
  Widget build(BuildContext context) {
    final displayScenes = scenes.length > 4 ? scenes.sublist(scenes.length - 4) : scenes;
    final now = DateTime.now();
    final monthStr = monthNames[now.month - 1].toUpperCase();

    final s1 = displayScenes.isNotEmpty ? displayScenes[0] : null;
    final s2 = displayScenes.length > 1 ? displayScenes[1] : null;
    final s3 = displayScenes.length > 2 ? displayScenes[2] : null;
    final s4 = displayScenes.length > 3 ? displayScenes[3] : null;

    return Container(
      width: ZineFormat.feed4x5.width,
      height: ZineFormat.feed4x5.height,
      color: Ink.paper,
      padding: const EdgeInsets.all(14),
      child: Container(
        decoration: BoxDecoration(
          color: Ink.paper,
          border: Border.all(color: Ink.ink, width: 2.2),
          boxShadow: const [
            BoxShadow(
              color: Ink.ink,
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // ── Editorial Masthead
            Row(
              children: [
                const Icon(Icons.auto_stories, size: 20, color: Ink.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'IF MY LIFE WAS A MOVIE...',
                    style: T.head(20),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Ink.ink,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    '$monthStr ${now.year}',
                    style: T.head(10, c: Ink.paper),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'DIRECTED BY: ${directorName.toUpperCase()} · $handle',
                    style: T.head(11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text('TICKET #$inviteCode', style: T.head(10, c: Ink.soft)),
              ],
            ),
            const SizedBox(height: 6),
            const DashedLine(),
            const SizedBox(height: 8),

            // ── 2x2 Collage of Polaroid Scene Cards
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _FeedSceneCard(scene: s1, index: 1, tapeAngle: -0.06)),
                        const SizedBox(width: 10),
                        Expanded(child: _FeedSceneCard(scene: s2, index: 2, tapeAngle: 0.05)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _FeedSceneCard(scene: s3, index: 3, tapeAngle: 0.04)),
                        const SizedBox(width: 10),
                        Expanded(child: _FeedSceneCard(scene: s4, index: 4, tapeAngle: -0.05)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            const DashedLine(),
            const SizedBox(height: 6),

            // ── Cinema Billing Block Footer
            _MovieBillingBlock(
              directorName: directorName,
              inviteCode: inviteCode,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedSceneCard extends StatelessWidget {
  final Entry? scene;
  final int index;
  final double tapeAngle;

  const _FeedSceneCard({
    required this.scene,
    required this.index,
    this.tapeAngle = -0.05,
  });

  @override
  Widget build(BuildContext context) {
    if (scene == null) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Ink.ink, width: 1.2),
          color: Ink.bg,
        ),
        padding: const EdgeInsets.all(10),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('SCENE $index IN DRAFT', style: T.head(13)),
              const SizedBox(height: 4),
              const Note('film your next daily soundtrack', size: 11),
            ],
          ),
        ),
      );
    }

    final s = scene!;
    final dateStr = dayLabel(s.date).toUpperCase();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Polaroid Frame Card
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Ink.ink, width: 1.5),
            color: Ink.paper,
            boxShadow: const [
              BoxShadow(
                color: Ink.ink,
                offset: Offset(2, 2),
                blurRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Slate Tag & Mood Rubber Stamp
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'SCENE ${s.scene} · $dateStr',
                      style: T.head(10.5, c: Ink.soft),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _RubberStamp(
                    text: s.mood.name,
                    hatch: s.mood.hatch,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const DashedLine(),
              const SizedBox(height: 5),

              // BIG Hero Album Cover with Vinyl Record Peek (Centered!)
              Center(
                child: ZineAlbumArt(
                  song: s.song,
                  mood: s.mood,
                  size: 96,
                ),
              ),

              const SizedBox(height: 6),

              // Song Title & Artist
              Text(
                s.song.title.toUpperCase(),
                style: T.head(14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${s.song.artist} · ${fmtTime(s.song.seconds)}',
                style: T.body(11.5, c: Ink.soft),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 5),

              // Dialogue Quote
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Ink.soft, width: 0.8),
                    color: Ink.bg,
                  ),
                  child: Text(
                    '“${s.note.isNotEmpty ? s.note : 'quiet day on set.'}”',
                    style: T.note(11.5, c: Ink.ink),
                    overflow: TextOverflow.fade,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Washi tape in top-right corner
        Positioned(
          top: -6,
          right: 14,
          child: _WashiTape(width: 40, height: 12, angle: tapeAngle),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. FOLDABLE ZINE FORMAT (8-Panel Printable Sheet with Album Artwork)
// ─────────────────────────────────────────────────────────────────────────────

class _ZineFoldableLayout extends StatelessWidget {
  final List<Entry> scenes;
  final String directorName;
  final String handle;
  final String inviteCode;

  const _ZineFoldableLayout({
    required this.scenes,
    required this.directorName,
    required this.handle,
    required this.inviteCode,
  });

  @override
  Widget build(BuildContext context) {
    final p1 = scenes.isNotEmpty ? scenes[0] : null;
    final p2 = scenes.length > 1 ? scenes[1] : null;
    final p3 = scenes.length > 2 ? scenes[2] : null;
    final p4 = scenes.length > 3 ? scenes[3] : null;
    final p5 = scenes.length > 4 ? scenes[4] : null;
    final p6 = scenes.length > 5 ? scenes[5] : null;

    return Container(
      width: ZineFormat.foldableLandscape.width,
      height: ZineFormat.foldableLandscape.height,
      color: Ink.paper,
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: Ink.paper,
          border: Border.all(color: Ink.ink, width: 2.2),
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          children: [
            // Top Header
            Row(
              children: [
                const Icon(Icons.movie_filter_outlined, size: 16, color: Ink.ink),
                const SizedBox(width: 6),
                Text('IF MY LIFE WAS A MOVIE...', style: T.head(15)),
                const SizedBox(width: 10),
                Text('·   DAILY SOUNDTRACK MINI-ZINE   ·', style: T.head(11, c: Ink.soft)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'DIR: ${directorName.toUpperCase()}   ·   TICKET: $inviteCode   ·   ${scenes.length} SCENES',
                    style: T.head(11, c: Ink.soft),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const DashedLine(),
            const SizedBox(height: 6),

            // 8-Panel Grid
            Expanded(
              child: Column(
                children: [
                  // Row 1 (Panels 1, 2, 3, 4)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _ZineCoverPanel(
                            directorName: directorName,
                            handle: handle,
                            inviteCode: inviteCode,
                            sceneCount: scenes.length,
                          ),
                        ),
                        const _VerticalDashedDivider(),
                        Expanded(child: _ZineScenePanel(pageNo: 1, scene: p1)),
                        const _VerticalDashedDivider(),
                        Expanded(child: _ZineScenePanel(pageNo: 2, scene: p2)),
                        const _VerticalDashedDivider(),
                        Expanded(child: _ZineScenePanel(pageNo: 3, scene: p3)),
                      ],
                    ),
                  ),

                  // Center horizontal fold crease with center slit cut line
                  const _CenterSlitCrease(),

                  // Row 2 (Panels 5, 6, 7, 8)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _ZineScenePanel(pageNo: 4, scene: p4)),
                        const _VerticalDashedDivider(),
                        Expanded(child: _ZineScenePanel(pageNo: 5, scene: p5)),
                        const _VerticalDashedDivider(),
                        Expanded(child: _ZineScenePanel(pageNo: 6, scene: p6)),
                        const _VerticalDashedDivider(),
                        Expanded(
                          child: _ZineCreditsPanel(
                            directorName: directorName,
                            handle: handle,
                            inviteCode: inviteCode,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            const DashedLine(),
            const SizedBox(height: 5),

            // Bottom folding guide
            Row(
              children: [
                const Icon(Icons.content_cut, size: 14, color: Ink.ink),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'FOLD GUIDE: 1. FOLD LENGTHWISE IN HALF · 2. FOLD INTO 8THS · 3. CUT CENTER SLIT (✂) · 4. PUSH INTO 8-PAGE BOOKLET',
                    style: T.head(10, c: Ink.soft),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'DEVELOPED BY ZAKIALMAHDI (LONE DEVELOPER) · v1.0',
                  style: T.head(10, c: Ink.soft),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalDashedDivider extends StatelessWidget {
  const _VerticalDashedDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      alignment: Alignment.center,
      child: const CustomPaint(
        size: Size(1, double.infinity),
        painter: _VerticalDashedLinePainter(),
      ),
    );
  }
}

class _VerticalDashedLinePainter extends CustomPainter {
  const _VerticalDashedLinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Ink.grey
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + 4), paint);
      y += 7;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CenterSlitCrease extends StatelessWidget {
  const _CenterSlitCrease();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      alignment: Alignment.center,
      child: Row(
        children: [
          const Expanded(child: DashedLine()),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Ink.ink, width: 1.2),
              color: Ink.paper,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.content_cut, size: 12, color: Ink.ink),
                const SizedBox(width: 4),
                Text('CUT CENTER SLIT HERE ────────', style: T.head(9.5)),
                const SizedBox(width: 4),
                const Icon(Icons.content_cut, size: 12, color: Ink.ink),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Expanded(child: DashedLine()),
        ],
      ),
    );
  }
}

// ── Panel 1: Front Cover ──
class _ZineCoverPanel extends StatelessWidget {
  final String directorName;
  final String handle;
  final String inviteCode;
  final int sceneCount;

  const _ZineCoverPanel({
    required this.directorName,
    required this.handle,
    required this.inviteCode,
    required this.sceneCount,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStr = monthNames[now.month - 1].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Ink.ink, width: 1.5),
        color: Ink.paper,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '[ 1 · FRONT COVER ]',
                  style: T.head(10, c: Ink.soft),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text('$monthStr ${now.year}', style: T.head(10, c: Ink.soft)),
            ],
          ),
          const SizedBox(height: 4),
          const DashedLine(),
          const Spacer(),

          // Big cinematic title
          Text(
            'IF MY LIFE\nWAS A MOVIE...',
            textAlign: TextAlign.center,
            style: T.head(21),
          ),
          const SizedBox(height: 2),
          const Note('a daily soundtrack diary', size: 12),
          const Spacer(),

          // Central Large Vinyl LP illustration with laurel festival laurels
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF161616),
                  border: Border.all(color: Ink.ink, width: 2.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      offset: Offset(2, 2),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: const CustomPaint(
                  painter: _VinylGroovePainter(),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Ink.paper, width: 1.4),
                ),
                clipBehavior: Clip.antiAlias,
                child: const HatchSwatch(Hatch.diagonal, size: 44, circle: true, gap: 2.4),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Ink.paper,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text('★ OFFICIAL SOUNDTRACK SELECTION ★', style: T.head(9.5, c: Ink.soft)),

          const Spacer(),
          const DashedLine(),
          const SizedBox(height: 4),
          Text('DIR: ${directorName.toUpperCase()}', style: T.head(11.5)),
          Text('$handle · TICKET: $inviteCode', style: T.body(10.5, c: Ink.soft)),
          Text('VOL. 1 · $sceneCount SCENES PRESERVED', style: T.note(9.5, c: Ink.soft)),
        ],
      ),
    );
  }
}

// ── Panels 2-7: Interior Scene Pages with Album Artwork ──
class _ZineScenePanel extends StatelessWidget {
  final int pageNo;
  final Entry? scene;

  const _ZineScenePanel({
    required this.pageNo,
    required this.scene,
  });

  @override
  Widget build(BuildContext context) {
    if (scene == null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Ink.ink, width: 1.2),
          color: Ink.paper,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '[ PAGE $pageNo · IN DRAFT ]',
                    style: T.head(10, c: Ink.soft),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit_note, size: 14, color: Ink.soft),
              ],
            ),
            const SizedBox(height: 5),
            const DashedLine(),
            const Spacer(),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SCENE IN DRAFT', style: T.head(14)),
                  const SizedBox(height: 4),
                  Note(
                    'camera rolling...\nqueue your soundtrack to film scene $pageNo.',
                    size: 11,
                    align: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Spacer(),
            const DashedLine(),
            const SizedBox(height: 5),
            Text('date: _________   mood: _________', style: T.note(10.5, c: Ink.faint)),
          ],
        ),
      );
    }

    final s = scene!;
    final dateStr = dayLabel(s.date).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Ink.ink, width: 1.3),
        color: Ink.paper,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '[ P.$pageNo · SCENE ${s.scene} ]',
                  style: T.head(10, c: Ink.soft),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(dateStr, style: T.head(9.5)),
            ],
          ),
          const SizedBox(height: 4),
          const DashedLine(),
          const SizedBox(height: 5),

          // BIG Hero Album Cover with Grooved Vinyl Peek (Centered!)
          Center(
            child: ZineAlbumArt(
              song: s.song,
              mood: s.mood,
              size: 90,
            ),
          ),
          const SizedBox(height: 5),

          Text(
            s.song.title.toUpperCase(),
            style: T.head(13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  s.song.artist,
                  style: T.body(11, c: Ink.soft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              _RubberStamp(
                text: s.mood.name,
                hatch: s.mood.hatch,
              ),
            ],
          ),

          const SizedBox(height: 5),
          const DashedLine(),
          const SizedBox(height: 5),

          // Dialogue Note text
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                border: Border.all(color: Ink.soft, width: 0.8),
                color: Ink.bg,
              ),
              child: Text(
                '“${s.note.isNotEmpty ? s.note : 'quiet day on set.'}”',
                style: T.note(11, c: Ink.ink),
                overflow: TextOverflow.fade,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text('TAKE ${s.scene}', style: T.head(9, c: Ink.faint)),
              ),
              Text('♪ ${fmtTime(s.song.seconds)}', style: T.note(9, c: Ink.soft)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Panel 8: Back Cover & Credits ──
class _ZineCreditsPanel extends StatelessWidget {
  final String directorName;
  final String handle;
  final String inviteCode;

  const _ZineCreditsPanel({
    required this.directorName,
    required this.handle,
    required this.inviteCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Ink.ink, width: 1.5),
        color: Ink.paper,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '[ 8 · BACK COVER ]',
                  style: T.head(10, c: Ink.soft),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text('THE END', style: T.head(10, c: Ink.soft)),
            ],
          ),
          const SizedBox(height: 4),
          const DashedLine(),
          const SizedBox(height: 4),
          Text('ROLL CREDITS', style: T.head(15)),
          const SizedBox(height: 1),
          const Note('end of this reel', size: 10.5),
          const Spacer(),

          // Credits block
          Text('DIRECTED BY', style: T.head(8.5, c: Ink.soft)),
          Text(directorName.toUpperCase(), style: T.head(11.5)),
          Text(handle, style: T.body(9.5, c: Ink.soft)),
          const SizedBox(height: 4),

          Text('LONE DEVELOPER', style: T.head(8.5, c: Ink.soft)),
          Text('zakialmahdi', style: T.head(11.5)),
          const SizedBox(height: 4),

          Text('ORIGINAL SOUNDTRACK', style: T.head(8.5, c: Ink.soft)),
          Text('IF MY LIFE WAS A MOVIE...', style: T.body(9.5)),
          const Spacer(),

          // Barcode sketch
          const Text(
            '|||| ||| ||||| || |||||| | ||||||||',
            style: TextStyle(fontFamily: 'monospace', fontSize: 11, letterSpacing: -0.8),
          ),
          Text('$inviteCode · TAKE 1 PRINT', style: T.head(8.5, c: Ink.soft)),
          const SizedBox(height: 3),
          const DashedLine(),
          const SizedBox(height: 3),
          const Note('“every day has its own soundtrack.”', size: 9.5),
        ],
      ),
    );
  }
}
