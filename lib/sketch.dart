import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Ink;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/youtube_music_service.dart';
import 'state.dart';

// ───────────────────────── palette & type ─────────────────────────

class Ink {
  static const ink = Color(0xFF2A2A2A);
  static const paper = Color(0xFFF3F2EC);
  static const bg = Color(0xFFE9E7E0);
  static const grey = Color(0xFFC8C5BC);
  static const faint = Color(0xFFBDBAB1);
  static const soft = Color(0xFF6F6C65);
}

class T {
  static final TextStyle _headBase = GoogleFonts.caveatBrush(letterSpacing: 0.8, height: 1.1);
  static final TextStyle _bodyBase = GoogleFonts.patrickHand(height: 1.15);
  static final TextStyle _noteBase = GoogleFonts.caveat(fontStyle: FontStyle.italic, height: 1.1);

  static final Map<(double, int), TextStyle> _headCache = {};
  static final Map<(double, int, FontWeight?), TextStyle> _bodyCache = {};
  static final Map<(double, int), TextStyle> _noteCache = {};

  /// Marker-style headings (use UPPERCASE strings).
  static TextStyle head(double s, {Color c = Ink.ink}) =>
      _headCache.putIfAbsent((s, c.toARGB32()), () => _headBase.copyWith(fontSize: s, color: c));

  /// Handwritten body.
  static TextStyle body(double s, {Color c = Ink.ink, FontWeight? w}) =>
      _bodyCache.putIfAbsent(
        (s, c.toARGB32(), w),
        () => _bodyBase.copyWith(fontSize: s, color: c, fontWeight: w),
      );

  /// Margin annotations.
  static TextStyle note(double s, {Color c = Ink.soft}) =>
      _noteCache.putIfAbsent((s, c.toARGB32()), () => _noteBase.copyWith(fontSize: s, color: c));
}

class Note extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final TextAlign? align;
  const Note(this.text, {super.key, this.size = 15, this.color = Ink.soft, this.align});
  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: align, style: T.note(size, c: color));
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(), style: T.head(15)),
      );
}

// ───────────────────────── sketchy geometry ─────────────────────────

void drawDashed(Canvas c, Path path, Paint paint, {double dash = 4, double gap = 3.5}) {
  final out = Path();
  for (final m in path.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      out.addPath(m.extractPath(d, math.min(d + dash, m.length)), Offset.zero);
      d += dash + gap;
    }
  }
  c.drawPath(out, paint);
}

void drawDashedOval(Canvas canvas, Rect oval, Paint paint, {double dash = 3, double gap = 2.5}) {
  final rx = oval.width / 2;
  final ry = oval.height / 2;
  if (rx <= 0 || ry <= 0) return;
  final approxCircumference = math.pi * (rx + ry);
  final count = (approxCircumference / (dash + gap)).round().clamp(6, 72);
  final step = (2 * math.pi) / count;
  final sweep = step * (dash / (dash + gap));
  final out = Path();
  for (var i = 0; i < count; i++) {
    out.addArc(oval, i * step, sweep);
  }
  canvas.drawPath(out, paint);
}

/// A hand-drawn rectangle: four slightly bowed, overshooting strokes drawn twice,
/// plus an optional thick "ink" edge on the right & bottom.
class SketchBoxPainter extends CustomPainter {
  final Color fill, stroke;
  final double strokeWidth, jitter;
  final bool shadow, dashed;
  final int seed;
  SketchBoxPainter({
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
    required this.jitter,
    required this.shadow,
    required this.dashed,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = shadow ? size.width - 7 : size.width - 4;
    final h = shadow ? size.height - 7 : size.height - 4;
    if (w <= 0 || h <= 0) return;

    final r = Rect.fromLTWH(2, 2, w, h);
    final rnd = math.Random(seed);
    Offset jit(Offset o, [double k = 1]) =>
        o + Offset((rnd.nextDouble() - .5) * jitter * k, (rnd.nextDouble() - .5) * jitter * k);

    final corners = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
    final poly = Path();
    for (var i = 0; i < 4; i++) {
      final p = jit(corners[i]);
      i == 0 ? poly.moveTo(p.dx, p.dy) : poly.lineTo(p.dx, p.dy);
    }
    poly.close();
    if (fill != Colors.transparent) canvas.drawPath(poly, Paint()..color = fill);

    for (var pass = 0; pass < 2; pass++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = pass == 0 ? stroke : stroke.withAlpha(120)
        ..strokeWidth = pass == 0 ? strokeWidth : strokeWidth * .65;
      final passPath = Path();
      for (var i = 0; i < 4; i++) {
        final a = corners[i], b = corners[(i + 1) % 4];
        final len = (b - a).distance;
        if (len <= 0) continue;
        final dir = (b - a) / len;
        final over = dashed ? 0.0 : (pass == 0 ? 1 + rnd.nextDouble() * 2 : rnd.nextDouble() * 1.5);
        final s = jit(a - dir * over);
        final e = jit(b + dir * over);
        final n = Offset(-dir.dy, dir.dx);
        final c = (s + e) / 2 + n * ((rnd.nextDouble() - .5) * jitter * 1.4);
        passPath
          ..moveTo(s.dx, s.dy)
          ..quadraticBezierTo(c.dx, c.dy, e.dx, e.dy);
      }
      if (dashed) {
        drawDashed(canvas, passPath, paint);
      } else {
        canvas.drawPath(passPath, paint);
      }
    }

    if (shadow) {
      final sp = Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3.4;
      final shadowPath = Path()
        ..moveTo(r.left + 4, r.bottom + 2.5)
        ..lineTo(r.right + 2.5, r.bottom + 2.5)
        ..lineTo(r.right + 2.5, r.top + 4);
      canvas.drawPath(shadowPath, sp);
    }
  }

  @override
  bool shouldRepaint(SketchBoxPainter o) =>
      o.fill != fill ||
      o.stroke != stroke ||
      o.strokeWidth != strokeWidth ||
      o.jitter != jitter ||
      o.shadow != shadow ||
      o.dashed != dashed ||
      o.seed != seed;
}

class SketchBox extends StatelessWidget {
  final Widget? child;
  final EdgeInsets padding;
  final Color fill;
  final Color stroke;
  final double strokeWidth, jitter;
  final bool shadow, dashed;
  final int seed;
  const SketchBox({
    super.key,
    this.child,
    this.padding = const EdgeInsets.all(12),
    this.fill = Ink.paper,
    this.stroke = Ink.ink,
    this.strokeWidth = 1.8,
    this.jitter = 2.2,
    this.shadow = true,
    this.dashed = false,
    this.seed = 7,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SketchBoxPainter(
        fill: fill,
        stroke: stroke,
        strokeWidth: strokeWidth,
        jitter: jitter,
        shadow: shadow,
        dashed: dashed,
        seed: seed,
      ),
      child: Padding(
        padding: padding + EdgeInsets.fromLTRB(3, 3, shadow ? 8 : 3, shadow ? 8 : 3),
        child: child,
      ),
    );
  }
}

/// A box with a tiny annotation sitting on its top border ("draft #1", "scene 140").
class TagBox extends StatelessWidget {
  final String label;
  final bool right;
  final Widget child;
  final int seed;
  const TagBox({super.key, required this.label, required this.child, this.right = false, this.seed = 3});
  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      Padding(padding: const EdgeInsets.only(top: 9), child: SketchBox(seed: seed, child: child)),
      Positioned(
        top: 0,
        left: right ? null : 20,
        right: right ? 24 : null,
        child: Container(
          color: Ink.paper,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Note(label, size: 13),
        ),
      ),
    ]);
  }
}

// ───────────────────────── crosshatch ─────────────────────────

class HatchPainter extends CustomPainter {
  final Hatch hatch;
  final double gap;
  final bool circle, outline;
  HatchPainter(this.hatch, {this.gap = 5, this.circle = false, this.outline = true});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    if (circle) {
      canvas.clipPath(Path()..addOval(rect));
    } else {
      canvas.clipRect(rect);
    }
    canvas.drawRect(rect, Paint()..color = Ink.paper);
    final p = Paint()
      ..color = Ink.ink.withAlpha(190)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;

    void addDiagA(Path path) {
      for (var x = -h; x < w; x += gap) {
        path
          ..moveTo(x, h)
          ..lineTo(x + h, 0);
      }
    }

    void addDiagB(Path path) {
      for (var x = -h; x < w; x += gap) {
        path
          ..moveTo(x, 0)
          ..lineTo(x + h, h);
      }
    }

    switch (hatch) {
      case Hatch.solid:
        canvas.drawRect(rect, Paint()..color = Ink.grey);
      case Hatch.diagonal:
        final path = Path();
        addDiagA(path);
        canvas.drawPath(path, p);
      case Hatch.cross:
        final path = Path();
        addDiagA(path);
        addDiagB(path);
        canvas.drawPath(path, p);
      case Hatch.lines:
        final path = Path();
        for (var y = gap / 2; y < h; y += gap) {
          path
            ..moveTo(0, y)
            ..lineTo(w, y);
        }
        canvas.drawPath(path, p);
      case Hatch.dots:
        final cols = ((w - gap / 2) / gap).ceil().clamp(0, 200);
        final rows = ((h - gap / 2) / gap).ceil().clamp(0, 200);
        final pts = Float32List(cols * rows * 2);
        var idx = 0;
        for (var y = gap / 2; y < h; y += gap) {
          for (var x = gap / 2; x < w; x += gap) {
            if (idx + 1 < pts.length) {
              pts[idx++] = x;
              pts[idx++] = y;
            }
          }
        }
        final dp = Paint()
          ..color = Ink.ink.withAlpha(170)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.6;
        canvas.drawRawPoints(ui.PointMode.points, Float32List.sublistView(pts, 0, idx), dp);
      case Hatch.vertical:
        final path = Path();
        for (var x = gap / 2; x < w; x += gap) {
          path
            ..moveTo(x, 0)
            ..lineTo(x, h);
        }
        canvas.drawPath(path, p);
      case Hatch.waves:
        final path = Path();
        final waveGap = gap * 1.5;
        for (var y = gap / 2; y < h + gap; y += waveGap) {
          path.moveTo(0, y);
          for (var x = 0.0; x <= w; x += 3.5) {
            path.lineTo(x, y + math.sin(x / 3.8) * 1.8);
          }
        }
        canvas.drawPath(path, p);
      case Hatch.zigzag:
        final path = Path();
        final zigGap = gap * 1.6;
        for (var y = gap / 2; y < h + zigGap; y += zigGap) {
          path.moveTo(0, y);
          var up = true;
          for (var x = 0.0; x <= w; x += 4.5) {
            path.lineTo(x, y + (up ? -2.0 : 2.0));
            up = !up;
          }
        }
        canvas.drawPath(path, p);
      case Hatch.grid:
        final path = Path();
        for (var y = gap / 2; y < h; y += gap) {
          path
            ..moveTo(0, y)
            ..lineTo(w, y);
        }
        for (var x = gap / 2; x < w; x += gap) {
          path
            ..moveTo(x, 0)
            ..lineTo(x, h);
        }
        canvas.drawPath(path, p);
      case Hatch.rings:
        final center = Offset(w / 2, h / 2);
        final maxR = math.max(w, h);
        for (var r = gap * 0.7; r < maxR; r += gap * 1.25) {
          canvas.drawCircle(center, r, p);
        }
      case Hatch.checker:
        final blockSize = gap * 1.35;
        final fillP = Paint()..color = Ink.ink.withAlpha(150);
        for (var y = 0.0; y < h; y += blockSize) {
          final rowIdx = (y / blockSize).floor();
          for (var x = 0.0; x < w; x += blockSize) {
            final colIdx = (x / blockSize).floor();
            if ((rowIdx + colIdx) % 2 == 0) {
              canvas.drawRect(
                Rect.fromLTWH(
                  x,
                  y,
                  math.min(blockSize, w - x),
                  math.min(blockSize, h - y),
                ),
                fillP,
              );
            }
          }
        }
    }
    canvas.restore();
    if (outline) {
      final o = Paint()
        ..color = Ink.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      if (circle) {
        canvas.drawOval(rect.deflate(.8), o);
      } else {
        canvas.drawRect(rect.deflate(.8), o);
      }
    }
  }

  @override
  bool shouldRepaint(HatchPainter o) =>
      o.hatch != hatch || o.gap != gap || o.circle != circle || o.outline != outline;
}

class HatchSwatch extends StatelessWidget {
  final Hatch hatch;
  final double size;
  final bool circle;
  final bool outline;
  final double? gap;
  const HatchSwatch(
    this.hatch, {
    super.key,
    this.size = 32,
    this.circle = false,
    this.outline = true,
    this.gap,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: HatchPainter(
            hatch,
            circle: circle,
            outline: outline,
            gap: gap ?? (size > 60 ? 4.5 : 3.6),
          ),
        ),
      );
}

/// Renders a song's 1:1 iTunes album cover inside a crisp ink frame.
/// Only renders the crosshatch/dotted/lined [HatchSwatch] when the iTunes API
/// has no cover listed for the track (or if the cover image fails to load).
class SongArtBox extends StatelessWidget {
  final Song song;
  final double size;
  final double? gap;

  const SongArtBox({
    super.key,
    required this.song,
    this.size = 36,
    this.gap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: musicService,
      builder: (context, _) {
        final state = musicService.coverStateFor(song);

        if (state == CoverArtState.unavailable) {
          return HatchSwatch(song.art, size: size, gap: gap);
        }

        if (state == CoverArtState.loading) {
          musicService.ensureITunesMetadata(song);
          return SizedBox(
            width: size,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Ink.paper,
                border: Border.all(color: Ink.ink, width: 1.5),
              ),
            ),
          );
        }

        final resolvedUrl = musicService.albumCoverFor(song)!;
        return SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Ink.paper,
              border: Border.all(color: Ink.ink, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.5),
              child: Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => HatchSwatch(
                  song.art,
                  size: math.max(0, size - 3),
                  gap: gap,
                  outline: false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Hand-drawn sketch play / pause icon inspired by zine pen-and-ink aesthetics.
class SketchPlayIcon extends StatelessWidget {
  final bool playing;
  final double size;
  final Color color;

  const SketchPlayIcon({
    super.key,
    required this.playing,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SketchPlayPainter(playing: playing, color: color),
      ),
    );
  }
}

class _SketchPlayPainter extends CustomPainter {
  final bool playing;
  final Color color;

  const _SketchPlayPainter({required this.playing, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (playing) {
      // Hand-drawn sketchy dual pause bars
      final barW = math.max(2.4, w * 0.22);
      final barH = h * 0.74;
      final top = (h - barH) / 2;
      final gap = w * 0.22;
      final left1 = (w - (barW * 2 + gap)) / 2;
      final left2 = left1 + barW + gap;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final r1 = RRect.fromRectAndRadius(
        Rect.fromLTWH(left1, top, barW, barH),
        const Radius.circular(1.2),
      );
      final r2 = RRect.fromRectAndRadius(
        Rect.fromLTWH(left2, top, barW, barH),
        const Radius.circular(1.2),
      );
      canvas.drawRRect(r1, paint);
      canvas.drawRRect(r2, paint);
    } else {
      // Hand-drawn sketchy play triangle
      final left = w * 0.26;
      final right = w * 0.82;
      final top = h * 0.18;
      final bottom = h * 0.82;
      final centerY = h * 0.50;

      final path = Path()
        ..moveTo(left, top + 1.2)
        ..quadraticBezierTo(left + 0.3, top, left + 1.2, top + 0.7)
        ..lineTo(right - 1.2, centerY - 0.7)
        ..quadraticBezierTo(right + 0.8, centerY, right - 1.2, centerY + 0.7)
        ..lineTo(left + 1.2, bottom - 0.7)
        ..quadraticBezierTo(left + 0.3, bottom, left, bottom - 1.2)
        ..close();

      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      final strokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(_SketchPlayPainter old) =>
      old.playing != playing || old.color != color;
}

/// Compact sketch-styled Play / Pause / Loading button wired to [musicService].
/// Set [previewOnly] to `true` inside search pickers to play the instant iTunes
/// song preview instead of resolving the full-length stream.
class SongPlayButton extends StatelessWidget {
  final Song song;
  final double size;
  final int seed;
  final bool previewOnly;

  const SongPlayButton({
    super.key,
    required this.song,
    this.size = 32,
    this.seed = 11,
    this.previewOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: musicService,
      builder: (context, _) {
        final active = musicService.isCurrentSong(song) &&
            (previewOnly
                ? musicService.isPreviewPlayback
                : !musicService.isPreviewPlayback);
        final loading = active && musicService.isBuffering;
        final playing = active && musicService.isPlaying && !loading;

        return SketchTap(
          onTap: () => previewOnly
              ? musicService.togglePreview(song)
              : musicService.togglePlay(song),
          pressedScale: 0.86,
          child: SketchBox(
            shadow: false,
            fill: playing ? Ink.ink : Ink.paper,
            jitter: 1.2,
            strokeWidth: 1.4,
            seed: seed,
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: loading
                      ? SizedBox(
                          key: const ValueKey('buf'),
                          width: size * 0.44,
                          height: size * 0.44,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Ink.ink,
                          ),
                        )
                      : SketchPlayIcon(
                          key: ValueKey(playing),
                          playing: playing,
                          size: size * 0.52,
                          color: playing ? Ink.paper : Ink.ink,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double width;
  const DashedCirclePainter({this.color = Ink.ink, this.width = 1.4});
  @override
  void paint(Canvas canvas, Size size) {
    drawDashedOval(
      canvas,
      (Offset.zero & size).deflate(width),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
      dash: 3,
      gap: 2.5,
    );
  }

  @override
  bool shouldRepaint(DashedCirclePainter o) => o.color != color || o.width != width;
}

class DashedLine extends StatelessWidget {
  const DashedLine({super.key});
  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size(double.infinity, 2), painter: _DashLinePainter());
}

class _DashLinePainter extends CustomPainter {
  const _DashLinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    var x = 0.0;
    while (x < size.width) {
      p
        ..moveTo(x, 1)
        ..lineTo(math.min(x + 4, size.width), 1);
      x += 7;
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = Ink.soft
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ───────────────────────── paper background ─────────────────────────

class PaperPainter extends CustomPainter {
  final String kind;
  PaperPainter(this.kind);

  static const int _bucketCount = 3;
  static const int _pointsPerBucket = 300;
  static final List<Float32List> _normBuckets = _initNormBuckets();

  static Size? _cachedSize;
  static List<Float32List>? _scaledBuckets;

  static List<Float32List> _initNormBuckets() {
    final rnd = math.Random(17);
    return List<Float32List>.generate(_bucketCount, (_) {
      final list = Float32List(_pointsPerBucket * 2);
      for (var i = 0; i < list.length; i++) {
        list[i] = rnd.nextDouble();
      }
      return list;
    });
  }

  static List<Float32List> _bucketsForSize(Size size) {
    if (_cachedSize == size && _scaledBuckets != null) return _scaledBuckets!;
    final w = size.width, h = size.height;
    _cachedSize = size;
    _scaledBuckets = List<Float32List>.generate(_bucketCount, (b) {
      final src = _normBuckets[b];
      final dst = Float32List(src.length);
      for (var i = 0; i < src.length; i += 2) {
        dst[i] = src[i] * w;
        dst[i + 1] = src[i + 1] * h;
      }
      return dst;
    });
    return _scaledBuckets!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Ink.bg);
    final rnd = math.Random(11);

    // soft pencil smudges
    final smudge = Paint()
      ..color = Ink.ink.withAlpha(6)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 7; i++) {
      smudge.strokeWidth = 10 + rnd.nextDouble() * 20;
      final a = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      canvas.drawLine(a, a + Offset(rnd.nextDouble() * 120 - 60, rnd.nextDouble() * 60 - 30), smudge);
    }

    // batched paper grain (3 drawRawPoints calls instead of 3,500 drawCircle calls)
    final buckets = _bucketsForSize(size);
    const alphas = [7, 12, 17];
    final grain = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.25;
    for (var b = 0; b < _bucketCount; b++) {
      grain.color = Ink.ink.withAlpha(alphas[b]);
      canvas.drawRawPoints(ui.PointMode.points, buckets[b], grain);
    }

    if (kind == 'lined' || kind == 'grid') {
      final rules = Path();
      if (kind == 'lined') {
        for (var y = 70.0; y < size.height; y += 30) {
          rules
            ..moveTo(0, y)
            ..lineTo(size.width, y);
        }
      } else {
        for (var y = 0.0; y < size.height; y += 26) {
          rules
            ..moveTo(0, y)
            ..lineTo(size.width, y);
        }
        for (var x = 0.0; x < size.width; x += 26) {
          rules
            ..moveTo(x, 0)
            ..lineTo(x, size.height);
        }
      }
      canvas.drawPath(
        rules,
        Paint()
          ..color = const Color(0xFF7C8796).withAlpha(55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(PaperPainter o) => o.kind != kind;
}

// ───────────────────────── interaction ─────────────────────────

/// The tap animation: squishes + tilts while pressed, springs back on release.
/// Lazily allocates its AnimationController only when first touched.
class SketchTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  const SketchTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.94,
  });
  @override
  State<SketchTap> createState() => _SketchTapState();
}

class _SketchTapState extends State<SketchTap> with SingleTickerProviderStateMixin {
  AnimationController? _ctl;

  AnimationController _ensureCtl() {
    return _ctl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 150),
    )..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _ctl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _ctl == null ? 0.0 : Curves.easeOut.transform(_ctl!.value);
    final scale = 1.0 + (widget.pressedScale - 1.0) * t;
    final angle = -0.038 * t;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (widget.onTap == null && widget.onLongPress == null)
          ? null
          : (_) => _ensureCtl().forward(),
      onTapUp: (widget.onTap == null && widget.onLongPress == null)
          ? null
          : (_) => _ctl?.reverse(),
      onTapCancel: (widget.onTap == null && widget.onLongPress == null)
          ? null
          : () => _ctl?.reverse(),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              _ctl?.reverse();
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: Transform(
        alignment: Alignment.center,
        transform: t == 0.0
            ? Matrix4.identity()
            : (Matrix4.identity()
              ..scaleByDouble(scale, scale, 1.0, 1.0)
              ..rotateZ(angle)),
        child: widget.child,
      ),
    );
  }
}

/// Fade + rise entrance, staggered by [index].
class Reveal extends StatefulWidget {
  final Widget child;
  final int index;
  const Reveal({super.key, required this.child, this.index = 0});
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  late final CurvedAnimation _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final CurvedAnimation _slideCurve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, .045), end: Offset.zero).animate(_slideCurve);

  @override
  void initState() {
    super.initState();
    final delayMs = 28 * math.min<int>(widget.index, 6);
    if (delayMs == 0) {
      _c.forward();
    } else {
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    _slideCurve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

class SketchChip extends StatelessWidget {
  final String label;
  final bool selected, dashed;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int seed;
  const SketchChip({
    super.key,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.dashed = false,
    this.seed = 1,
  });
  @override
  Widget build(BuildContext context) {
    return SketchTap(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedScale(
        scale: selected ? 1.06 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: selected ? Ink.grey : (dashed ? Ink.bg : Ink.paper)),
          duration: const Duration(milliseconds: 200),
          child: Text(label, style: T.body(14, c: dashed ? Ink.soft : Ink.ink)),
          builder: (_, c, child) => SketchBox(
            fill: c ?? Ink.paper,
            shadow: false,
            dashed: dashed,
            jitter: 1.6,
            strokeWidth: 1.4,
            seed: seed,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Display-only switch; wrap in a [SketchTap] row to make it interactive.
class SketchSwitch extends StatelessWidget {
  final bool value;
  const SketchSwitch(this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 28,
      child: Stack(children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: AnimatedOpacity(
                opacity: value ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: SizedBox.expand(
                    child: CustomPaint(
                        painter: HatchPainter(Hatch.diagonal, gap: 3.5, outline: false))),
              ),
            ),
          ),
        ),
        const Positioned.fill(
            child: SketchBox(shadow: false, fill: Colors.transparent, jitter: 1.2, strokeWidth: 1.6, padding: EdgeInsets.zero)),
        Positioned.fill(
          child: AnimatedAlign(
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutBack,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? Ink.ink : Ink.paper,
                  border: Border.all(color: Ink.ink, width: 2),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class SketchTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const SketchTextButton(this.label, {super.key, required this.onTap, this.primary = false});
  @override
  Widget build(BuildContext context) => SketchTap(
        onTap: onTap,
        child: SketchBox(
          fill: primary ? Ink.ink : Ink.paper,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          seed: primary ? 2 : 9,
          child: Text(label.toUpperCase(),
              style: T.head(13, c: primary ? Ink.paper : Ink.ink)),
        ),
      );
}

class SketchButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool primary;
  final int seed;
  final EdgeInsets padding;

  const SketchButton({
    super.key,
    required this.child,
    this.onTap,
    this.primary = false,
    this.seed = 2,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  @override
  Widget build(BuildContext context) => SketchTap(
        onTap: onTap,
        child: SketchBox(
          fill: primary ? Ink.ink : Ink.paper,
          padding: padding,
          seed: seed,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: primary ? Ink.paper : Ink.ink),
            child: child,
          ),
        ),
      );
}

// ───────────────────────── dialogs & toasts ─────────────────────────

Future<R?> showSketchDialog<R>(BuildContext context, WidgetBuilder builder) {
  return showGeneralDialog<R>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'close',
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (c, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            type: MaterialType.transparency,
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: builder(c)),
          ),
        ),
      ),
    ),
    transitionBuilder: (c, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
        child: child,
      ),
    ),
  );
}

class SketchDialogCard extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  const SketchDialogCard({super.key, required this.title, required this.body, required this.actions});
  @override
  Widget build(BuildContext context) {
    return SketchBox(
      padding: const EdgeInsets.all(18),
      seed: 21,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: T.head(20)),
        const SizedBox(height: 10),
        ClipRect(child: body),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          for (final a in actions) Padding(padding: const EdgeInsets.only(left: 10), child: a),
        ]),
      ]),
    );
  }
}

void showNote(BuildContext context, String text) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(24, 0, 24, 96),
    padding: EdgeInsets.zero,
    duration: const Duration(milliseconds: 2200),
    content: SketchBox(
      fill: Ink.ink,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(text, style: T.body(15, c: Ink.paper)),
    ),
  ));
}

// ───────────────────────── bottom nav ─────────────────────────

class SketchNav extends StatelessWidget {
  final int? currentIndex;
  final ValueChanged<int>? onTabSelected;

  const SketchNav({
    super.key,
    this.currentIndex,
    this.onTabSelected,
  });

  static const _items = [
    (Icons.music_note, 'today'),
    (Icons.calendar_today_outlined, 'calendar'),
    (Icons.people_outline, 'friends'),
    (Icons.tune, 'settings'),
  ];
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final activeTab = currentIndex ?? app.tab;
        return SketchBox(
          strokeWidth: 2,
          seed: 5,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: SketchTap(
                  onTap: () {
                    if (onTabSelected != null) {
                      onTabSelected!(i);
                    } else {
                      app.setTab(i);
                    }
                  },
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedScale(
                      scale: activeTab == i ? 1.22 : 1,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: Icon(_items[i].$1, size: 22, color: activeTab == i ? Ink.ink : Ink.soft),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _items[i].$2,
                      style: T.note(14, c: activeTab == i ? Ink.ink : Ink.soft).copyWith(
                            fontWeight: activeTab == i ? FontWeight.w700 : FontWeight.w400,
                            decoration:
                                activeTab == i ? TextDecoration.underline : TextDecoration.none,
                          ),
                    ),
                  ]),
                ),
              ),
          ]),
        );
      },
    );
  }
}
