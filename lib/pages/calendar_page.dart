import 'package:flutter/material.dart' hide Ink;

import '../services/youtube_music_service.dart';
import '../sketch.dart';
import '../state.dart';
import '../widgets/scene_editor.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  int _dir = 1;

  void _shift(int d) {
    _dir = d;
    app.shiftMonth(d);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        var i = 0;
        Widget r(Widget w) => Reveal(index: i++, child: w);
        final m = app.viewMonth;

        return ListView(
          addRepaintBoundaries: false,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          children: [
            r(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Note('the whole film so far', size: 15),
              const SizedBox(height: 2),
              Text('MY SOUNDTRACK', style: T.head(27)),
            ])),
            const SizedBox(height: 14),
            r(SketchBox(
              seed: 8,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(children: [
                Row(children: [
                  _ArrowBtn(Icons.chevron_left, () => _shift(-1)),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                      child: Text('${monthNames[m.month - 1]} ${m.year}'.toUpperCase(),
                          key: ValueKey(m), textAlign: TextAlign.center, style: T.head(19)),
                    ),
                  ),
                  _ArrowBtn(Icons.chevron_right, () => _shift(1)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(child: Center(child: Note(d, size: 15, color: Ink.ink))),
                ]),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position:
                          Tween(begin: Offset(0.10 * _dir, 0), end: Offset.zero).animate(a),
                      child: c,
                    ),
                  ),
                  child: _grid(m),
                ),
              ]),
            )),
            const SizedBox(height: 12),
            r(Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final mood in app.moods)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    HatchSwatch(mood.hatch, size: 18, circle: true, gap: 3),
                    const SizedBox(width: 5),
                    Text(mood.name, style: T.body(13)),
                  ]),
              ],
            )),
            const SizedBox(height: 14),
            r(_detail(app.selected)),
          ],
        );
      },
    );
  }

  Widget _grid(DateTime m) {
    final lead = DateTime(m.year, m.month, 1).weekday - 1;
    final days = DateTime(m.year, m.month + 1, 0).day;
    final rows = <Widget>[];
    var day = 1 - lead;
    while (day <= days) {
      final cells = <Widget>[];
      for (var c = 0; c < 7; c++, day++) {
        cells.add(Expanded(
          child: (day < 1 || day > days)
              ? const SizedBox(height: 46)
              : _cell(DateTime(m.year, m.month, day)),
        ));
      }
      rows.add(Row(children: cells));
    }
    return Column(key: ValueKey(m), children: rows);
  }

  Widget _cell(DateTime d) {
    final e = app.entryFor(d);
    final sel = sameDay(d, app.selected);
    return SizedBox(
      height: 46,
      child: SketchTap(
        pressedScale: .82,
        onTap: () => app.select(d),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: 34,
            height: 32,
            child: Stack(alignment: Alignment.center, children: [
              if (e != null)
                Transform.scale(
                  scale: sel ? 1.08 : 1.0,
                  child: HatchSwatch(e.mood.hatch, size: 26, circle: true, gap: 3.2),
                )
              else
                const SizedBox(
                    width: 26,
                    height: 26,
                    child: CustomPaint(painter: _FaintCircle())),
              if (sel)
                IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.72, end: 1.0),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: const SizedBox(
                        width: 33,
                        height: 33,
                        child: CustomPaint(painter: DashedCirclePainter())),
                    builder: (_, s, ring) => Transform.scale(scale: s, child: ring),
                  ),
                ),
            ]),
          ),
          Text('${d.day}',
              style: T.body(10, c: e != null ? Ink.ink : Ink.faint)),
        ]),
      ),
    );
  }

  Widget _detail(DateTime d) {
    final e = app.entryFor(d);
    final isFuture = d.isAfter(app.today);
    return TagBox(
      label: 'scene ${e?.scene ?? sceneNo(d)}',
      seed: 17,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
                position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(a), child: c),
          ),
          child: e == null
              ? Padding(
                  key: ValueKey('empty${dayKey(d)}'),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(children: [
                      Note(dayLabel(d), size: 15),
                      const SizedBox(height: 4),
                      Text('NO SCENE FILMED', style: T.head(18)),
                      Note(
                        isFuture
                            ? 'this day hasn\'t been filmed yet.'
                            : 'nothing on the reel for this day.',
                        size: 15,
                      ),
                      if (!isFuture) ...[
                        const SizedBox(height: 10),
                        SketchTextButton(
                          sameDay(d, app.today) ? 'film today →' : '+ add scene',
                          onTap: () {
                            if (sameDay(d, app.today)) {
                              app.setTab(0);
                            } else {
                              openSceneEditor(context, d);
                            }
                          },
                        ),
                      ],
                    ]),
                  ),
                )
              : Column(
                  key: ValueKey(dayKey(d)),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      SongArtBox(song: e.song, size: 56),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ListenableBuilder(
                          listenable: musicService,
                          builder: (context, _) {
                            final active = musicService.isCurrentSong(e.song) &&
                                !musicService.isPreviewPlayback;
                            final buffering = active && musicService.isBuffering;
                            final cached = musicService.isCachedLocally(e.song);
                            final statusSuffix = buffering
                                ? ' · buffering...'
                                : (cached ? ' · ✓ offline' : '');
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Note('${dayLabel(e.date)}$statusSuffix', size: 14),
                                Text(
                                  e.song.title.toUpperCase(),
                                  style: T.head(19),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${e.song.artist} · ${e.mood.name}',
                                  style: T.body(13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SongPlayButton(song: e.song, size: 36, seed: 27),
                    ]),
                    const SizedBox(height: 10),
                    const DashedLine(),
                    const SizedBox(height: 8),
                    Text('“${e.note}”', style: T.note(18, c: Ink.ink)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SketchTextButton(
                          'delete',
                          onTap: () => confirmDeleteScene(context, e),
                        ),
                        const SizedBox(width: 8),
                        SketchTextButton(
                          'update',
                          primary: true,
                          onTap: () => openSceneEditor(
                            context,
                            e.date,
                            initialEntry: e,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FaintCircle extends CustomPainter {
  const _FaintCircle();
  @override
  void paint(Canvas canvas, Size size) {
    drawDashedOval(
      canvas,
      (Offset.zero & size).deflate(1),
      Paint()
        ..color = Ink.faint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
      dash: 2.5,
      gap: 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => SketchTap(
        onTap: onTap,
        pressedScale: .8,
        child: SketchBox(
          padding: EdgeInsets.zero,
          shadow: false,
          jitter: 1.4,
          strokeWidth: 1.5,
          child: SizedBox(width: 24, height: 24, child: Icon(icon, size: 18, color: Ink.ink)),
        ),
      );
}
