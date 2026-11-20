import 'package:flutter/material.dart' hide Ink;

import '../services/youtube_music_service.dart';
import '../sketch.dart';
import '../state.dart';
import '../widgets/scene_editor.dart';

enum _CalendarCircleMode { feeling, song }

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  int _dir = 1;
  _CalendarCircleMode _mode = _CalendarCircleMode.feeling;

  void _shift(int d) {
    _dir = d;
    app.shiftMonth(d);
  }

  void _goToToday() {
    final now = app.today;
    final currentM = DateTime(app.viewMonth.year, app.viewMonth.month, 1);
    final targetM = DateTime(now.year, now.month, 1);
    if (targetM.isAfter(currentM)) {
      _dir = 1;
    } else if (targetM.isBefore(currentM)) {
      _dir = -1;
    }
    app.goToToday();
  }

  void _setMode(_CalendarCircleMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
  }

  Widget _viewToggle() {
    const options = [
      (mode: _CalendarCircleMode.feeling, label: 'feeling', seed: 31),
      (mode: _CalendarCircleMode.song, label: 'song', seed: 32),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Note('view:', size: 14),
        for (final opt in options)
          SketchChip(
            label: opt.label,
            selected: _mode == opt.mode,
            seed: opt.seed,
            onTap: () => _setMode(opt.mode),
          ),
      ],
    );
  }

  Widget _legend() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: _mode == _CalendarCircleMode.song
          ? const Align(
              key: ValueKey(_CalendarCircleMode.song),
              alignment: Alignment.centerLeft,
              child: Note('each circle shows that day’s song album cover', size: 13),
            )
          : Align(
              key: const ValueKey(_CalendarCircleMode.feeling),
              alignment: Alignment.centerLeft,
              child: Wrap(
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
              ),
            ),
    );
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
              const SizedBox(height: 10),
              _viewToggle(),
            ])),
            const SizedBox(height: 12),
            r(SketchBox(
              seed: 8,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(children: [
                Row(children: [
                  _ArrowBtn(Icons.chevron_left, () => _shift(-1)),
                  Expanded(
                    child: SketchTap(
                      onTap: _goToToday,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                        child: Text('${monthNames[m.month - 1]} ${m.year}'.toUpperCase(),
                            key: ValueKey(m), textAlign: TextAlign.center, style: T.head(19)),
                      ),
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
            r(_legend()),
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
              ? const SizedBox(height: 56)
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
    final isToday = sameDay(d, app.today);
    return SizedBox(
      height: 56,
      child: SketchTap(
        pressedScale: .82,
        onTap: () => app.select(d),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: 44,
            height: 40,
            child: Stack(alignment: Alignment.center, children: [
              if (e != null)
                Transform.scale(
                  scale: sel ? 1.06 : 1.0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _mode == _CalendarCircleMode.song
                        ? SongArtBox(
                            key: const ValueKey(_CalendarCircleMode.song),
                            song: e.song,
                            size: 34,
                            circle: true,
                            gap: 3.4,
                          )
                        : HatchSwatch(
                            key: const ValueKey(_CalendarCircleMode.feeling),
                            e.mood.hatch,
                            size: 34,
                            circle: true,
                            gap: 3.4,
                          ),
                  ),
                )
              else if (isToday)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Ink.ink, width: 1.6),
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Ink.ink,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(
                    width: 34,
                    height: 34,
                    child: CustomPaint(painter: _FaintCircle())),
              if (isToday)
                IgnorePointer(
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Ink.ink, width: 2.0),
                    ),
                  ),
                ),
              if (sel)
                IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.72, end: 1.0),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: CustomPaint(painter: DashedCirclePainter())),
                    builder: (_, s, ring) => Transform.scale(scale: s, child: ring),
                  ),
                ),
              if (e != null && e.cheers > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Ink.paper,
                      shape: BoxShape.circle,
                      border: Border.all(color: Ink.ink, width: 1),
                    ),
                    child: const Icon(Icons.favorite, size: 8, color: Ink.ink),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 2),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Ink.ink,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${d.day}',
                style: T.body(10, c: Ink.paper, w: FontWeight.w700),
              ),
            )
          else
            Text(
              '${d.day}',
              style: T.body(11, c: e != null ? Ink.ink : Ink.faint),
            ),
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
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: e.cheers > 0 ? () => _showCheersDialog(context, e) : null,
                      child: SketchBox(
                        shadow: false,
                        fill: e.cheers > 0 ? Ink.paper : Ink.bg,
                        jitter: 1.1,
                        strokeWidth: 1.1,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              e.cheers > 0 ? Icons.favorite : Icons.favorite_border,
                              size: 14,
                              color: Ink.ink,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                e.cheers > 0
                                    ? (e.cheeredByNames.isNotEmpty
                                        ? '${e.cheers} ${e.cheers == 1 ? "cheer" : "cheers"} · cheered by ${e.cheeredByNames.join(", ")}'
                                        : '${e.cheers} ${e.cheers == 1 ? "cheer" : "cheers"}')
                                    : '0 cheers on this scene',
                                style: T.body(12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

  void _showCheersDialog(BuildContext context, Entry e) {
    if (e.cheers == 0) return;
    showSketchDialog<void>(
      context,
      (ctx) => SketchDialogCard(
        title: 'scene cheers 🍿',
        actions: [
          SketchTextButton('close', onTap: () => Navigator.pop(ctx)),
        ],
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Note('${dayLabel(e.date)} · ${e.cheers} ${e.cheers == 1 ? "cheer" : "cheers"}', size: 14),
            const SizedBox(height: 10),
            if (e.cheeredByNames.isEmpty)
              const Text('Friends cheered this scene on your reel.', style: TextStyle(fontSize: 14))
            else
              for (final name in e.cheeredByNames)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, size: 13, color: Ink.ink),
                      const SizedBox(width: 8),
                      Text(name, style: T.body(14)),
                    ],
                  ),
                ),
          ],
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
