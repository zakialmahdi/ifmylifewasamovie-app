import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' hide Ink;
import 'package:flutter/services.dart';

import '../services/youtube_music_service.dart';
import '../sketch.dart';
import '../state.dart';
import '../widgets/mood_prompt_dialog.dart';
import '../widgets/scene_editor.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _justSaved = false;
  double _clapTurns = 0;

  Future<void> _pickSong() async {
    final s = await showModalBottomSheet<Song>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SongPicker(),
    );
    if (musicService.isPreviewPlayback) {
      await musicService.stop();
    }
    if (s != null) {
      await musicService.stop();
      app.setSong(s);
      unawaited(musicService.togglePlay(s));
    }
  }

  Future<void> _addMood() async {
    final ctl = TextEditingController();
    var chosenHatch = app.nextUnusedHatch();

    await showSketchDialog<void>(
      context,
      (c) => StatefulBuilder(
        builder: (ctx, setDlgState) => SketchDialogCard(
          title: 'add a feeling',
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SketchBox(
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: TextField(
                  controller: ctl,
                  autofocus: true,
                  maxLength: 18,
                  style: T.body(16),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) {
                      app.addMood(v.trim(), chosenHatch);
                    }
                    Navigator.pop(c);
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: 'e.g. nostalgic',
                    hintStyle: T.body(16, c: Ink.faint),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Note('calendar pattern swatch', size: 14),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final h in Hatch.values)
                      if (h != Hatch.solid) ...[
                        GestureDetector(
                          onTap: () => setDlgState(() => chosenHatch = h),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: chosenHatch == h ? Ink.ink : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: HatchSwatch(h, size: 28, circle: true, gap: 3),
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SketchTextButton('cancel', onTap: () => Navigator.pop(c)),
            SketchTextButton('add', primary: true, onTap: () {
              final text = ctl.text.trim();
              if (text.isNotEmpty) {
                app.addMood(text, chosenHatch);
              }
              Navigator.pop(c);
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _editMood(Mood mood) async {
    final ctl = TextEditingController(text: mood.name);
    var chosenHatch = mood.hatch;

    await showSketchDialog<void>(
      context,
      (c) => StatefulBuilder(
        builder: (ctx, setDlgState) => SketchDialogCard(
          title: 'edit feeling',
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Note('feeling name', size: 14),
              const SizedBox(height: 4),
              SketchBox(
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: TextField(
                  controller: ctl,
                  autofocus: false,
                  maxLength: 18,
                  style: T.body(16),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: 'e.g. nostalgic',
                    hintStyle: T.body(16, c: Ink.faint),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Note('calendar pattern swatch', size: 14),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final h in Hatch.values)
                      if (h != Hatch.solid) ...[
                        GestureDetector(
                          onTap: () => setDlgState(() => chosenHatch = h),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: chosenHatch == h ? Ink.ink : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: HatchSwatch(h, size: 28, circle: true, gap: 3),
                          ),
                        ),
                      ],
                  ],
                ),
              ),
              if (app.moods.length > 1) ...[
                const SizedBox(height: 14),
                const DashedLine(),
                const SizedBox(height: 8),
                SketchTap(
                  onTap: () async {
                    final confirm = await showSketchDialog<bool>(
                      context,
                      (delCtx) => SketchDialogCard(
                        title: 'delete feeling?',
                        body: Text(
                          'delete "${mood.name}" from your feeling options?',
                          style: T.body(15),
                        ),
                        actions: [
                          SketchTextButton('cancel', onTap: () => Navigator.pop(delCtx, false)),
                          SketchTextButton(
                            'delete',
                            primary: true,
                            onTap: () => Navigator.pop(delCtx, true),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      app.deleteMood(mood);
                      if (c.mounted) {
                        Navigator.pop(c);
                      }
                      showNote(context, 'deleted "${mood.name}" from feelings ✓');
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_outline, size: 16, color: Ink.ink),
                      const SizedBox(width: 4),
                      Text(
                        'DELETE FEELING',
                        style: T.head(13).copyWith(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            SketchTextButton('cancel', onTap: () => Navigator.pop(c)),
            SketchTextButton('update', primary: true, onTap: () {
              final newName = ctl.text.trim();
              if (newName.isNotEmpty) {
                app.updateMood(mood, newName: newName, newHatch: chosenHatch);
                showNote(context, 'feeling updated to "$newName" ✓');
              }
              Navigator.pop(c);
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _openDirectorSlate() async {
    setState(() => _clapTurns += 1);
    await showSketchDialog<void>(
      context,
      (c) => SketchDialogCard(
        title: "director's slate",
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _DirectorAvatarBox(size: 54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name.toUpperCase(),
                        style: T.head(18),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(app.handle, style: T.body(14, c: Ink.soft)),
                      const SizedBox(height: 2),
                      Note(
                        app.demoMode
                            ? 'offline demo reel'
                            : (app.email ?? 'indie director'),
                        size: 13,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const DashedLine(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SketchBox(
                    shadow: false,
                    seed: 31,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Column(
                      children: [
                        Text('${app.streak}', style: T.head(20)),
                        const Note('day streak', size: 12),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SketchBox(
                    shadow: false,
                    seed: 33,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Column(
                      children: [
                        Text('${app.sceneCount}', style: T.head(20)),
                        const Note('scenes', size: 12),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SketchBox(
                    shadow: false,
                    seed: 35,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Column(
                      children: [
                        Text('${app.friends.length}', style: T.head(20)),
                        const Note('co-stars', size: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Note('reel ticket code (tap to copy)', size: 14),
            const SizedBox(height: 4),
            SketchTap(
              onTap: () {
                Clipboard.setData(ClipboardData(text: app.inviteCode));
                Navigator.pop(c);
                showNote(context, 'ticket ${app.inviteCode} copied – send to a co-star ✓');
              },
              child: SketchBox(
                shadow: false,
                dashed: true,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.confirmation_number_outlined, size: 18, color: Ink.ink),
                    const SizedBox(width: 8),
                    Expanded(child: Text(app.inviteCode, style: T.head(18))),
                    const Icon(Icons.copy, size: 15, color: Ink.soft),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          SketchTextButton(
            'settings',
            onTap: () {
              Navigator.pop(c);
              app.setTab(3);
            },
          ),
          SketchTextButton(
            'got it',
            primary: true,
            onTap: () => Navigator.pop(c),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (app.moodPrompts) {
      final promptAnswer = await showMoodPromptDialog(context);
      if (promptAnswer == null) {
        // User dismissed the prompt without saving
        return;
      }
      if (promptAnswer.isNotEmpty) {
        final existing = app.noteCtl.text.trim();
        if (existing.isEmpty) {
          app.noteCtl.text = promptAnswer;
        } else {
          app.noteCtl.text = '$existing\n\n[director\'s reflection] $promptAnswer';
        }
      }
    }
    app.saveToday();
    if (!mounted) return;
    showNote(context, 'scene ${sceneNo(app.today)} saved to the reel ✓');
    setState(() => _justSaved = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _justSaved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final recent = app.recent(3);
        var i = 0;
        Widget r(Widget w) => Reveal(index: i++, child: w);
        final label = _justSaved ? 'SCENE SAVED ✓' : (app.savedToday ? 'UPDATE SCENE' : 'SAVE SCENE');

        return ListView(
          addRepaintBoundaries: false,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          children: [
            // ── header
            r(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Note('scene no. ${sceneNo(app.today)}', size: 14),
                  const SizedBox(height: 2),
                  Text('IF MY LIFE\nWAS A MOVIE...', style: T.head(27)),
                ]),
              ),
              SketchTap(
                onTap: _openDirectorSlate,
                child: AnimatedRotation(
                  turns: _clapTurns,
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutBack,
                  child: SketchBox(
                    padding: EdgeInsets.zero,
                    seed: 4,
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: Stack(alignment: Alignment.center, children: [
                        const HatchSwatch(Hatch.cross, size: 42, gap: 4),
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
            const SizedBox(height: 14),
            r(Text('${dayLabel(app.today)} – what\'s today\'s song?',
                style: T.note(19, c: Ink.ink).copyWith(decoration: TextDecoration.underline))),
            const SizedBox(height: 12),

            // ── now playing
            r(TagBox(
              label: 'draft #1',
              right: true,
              child: NowPlaying(song: app.draftSong),
            )),
            const SizedBox(height: 18),

            // ── mood
            r(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionTitle('How does it feel?'),
                const Note('tap to pick · hold to edit / delete', size: 13),
              ],
            )),
            r(Wrap(spacing: 8, runSpacing: 8, children: [
              for (var k = 0; k < app.moods.length; k++)
                SketchChip(
                  label: app.moods[k].name,
                  selected: app.draftMood == app.moods[k],
                  seed: k + 1,
                  onTap: () => app.setMood(app.moods[k]),
                  onLongPress: () => _editMood(app.moods[k]),
                ),
              SketchChip(label: '+ add', dashed: true, seed: 40, onTap: _addMood),
            ])),
            const SizedBox(height: 18),

            // ── why
            r(const SectionTitle('Why this song?')),
            r(SketchBox(
              seed: 12,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: SizedBox(
                height: 66,
                child: Stack(children: [
                  TextField(
                    controller: app.noteCtl,
                    maxLines: 3,
                    style: T.body(15),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: 'scribble a line about today...',
                      hintStyle: T.body(14, c: Ink.faint),
                    ),
                  ),
                  const Positioned(
                      right: 0, bottom: 0, child: Icon(Icons.edit_outlined, size: 16, color: Ink.ink)),
                ]),
              ),
            )),
            const SizedBox(height: 12),
            r(Row(children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: SketchTap(
                    onTap: _pickSong,
                    child: SketchBox(
                      seed: 14,
                      shadow: false,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(children: [
                        const Icon(Icons.search, size: 18, color: Ink.ink),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text('search any song...',
                                style: T.body(14, c: Ink.faint), overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                width: 138,
                child: SketchTap(
                  onTap: _save,
                  child: SketchBox(
                    fill: Ink.ink,
                    seed: 15,
                    padding: EdgeInsets.zero,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (c, a) => ScaleTransition(
                            scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                            child: FadeTransition(opacity: a, child: c)),
                        child: Text(label,
                            key: ValueKey(label), style: T.head(14, c: Ink.paper)),
                      ),
                    ),
                  ),
                ),
              ),
            ])),
            const SizedBox(height: 22),

            // ── previous scenes
            r(Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const SectionTitle('Previous scenes'),
              GestureDetector(
                onTap: () => app.setTab(1),
                child: Text('see all →',
                    style: T.note(15, c: Ink.ink).copyWith(decoration: TextDecoration.underline)),
              ),
            ])),
            if (recent.isEmpty)
              r(Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SketchBox(
                  seed: 30,
                  dashed: true,
                  shadow: false,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: const Center(
                    child: Note(
                      'no previous scenes on the reel yet.',
                      size: 15,
                      align: TextAlign.center,
                    ),
                  ),
                ),
              )),
            for (var k = 0; k < recent.length; k++)
              r(Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SketchTap(
                  onTap: () => app.showDay(recent[k].date),
                  child: SketchBox(
                    seed: 30 + k,
                    padding: const EdgeInsets.all(8),
                    child: Row(children: [
                      SongArtBox(song: recent[k].song, size: 38),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(recent[k].song.title, style: T.body(15), overflow: TextOverflow.ellipsis),
                          Text('${recent[k].song.artist} · ${recent[k].mood.name}',
                              style: T.body(12, c: Ink.soft), overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                      Text(weekday(recent[k].date),
                          style: T.note(17, c: Ink.ink).copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      SongPlayButton(song: recent[k].song, size: 30, seed: 90 + k),
                      const SizedBox(width: 6),
                      SketchTap(
                        onTap: () => openSceneEditor(
                          context,
                          recent[k].date,
                          initialEntry: recent[k],
                        ),
                        pressedScale: 0.88,
                        child: SketchBox(
                          shadow: false,
                          seed: 105 + k,
                          jitter: 1.2,
                          strokeWidth: 1.4,
                          padding: EdgeInsets.zero,
                          child: const SizedBox(
                            width: 30,
                            height: 30,
                            child: Icon(
                              Icons.edit_outlined,
                              size: 15,
                              color: Ink.ink,
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              )),
            const SizedBox(height: 4),
            r(Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Note('★ ${app.streak}-day streak – keep the film rolling ★',
                    key: ValueKey(app.streak), size: 16, color: Ink.soft),
              ),
            )),
          ],
        );
      },
    );
  }
}

// ───────────────────────── now playing ─────────────────────────

class NowPlaying extends StatefulWidget {
  final Song song;
  const NowPlaying({super.key, required this.song});
  @override
  State<NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<NowPlaying> with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 4));
  final ValueNotifier<double> _progress = ValueNotifier<double>(0.0);
  final ValueNotifier<int> _elapsedSec = ValueNotifier<int>(0);
  final ValueNotifier<int> _totalSec = ValueNotifier<int>(0);

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;

  @override
  void initState() {
    super.initState();
    _totalSec.value = widget.song.seconds;
    musicService.addListener(_syncFromService);
    _posSub = musicService.positionStream.listen(_onPosition);
    _durSub = musicService.durationStream.listen(_onDuration);
    _syncFromService();
  }

  @override
  void didUpdateWidget(NowPlaying old) {
    super.didUpdateWidget(old);
    if (old.song != widget.song) {
      _syncFromService();
    }
  }

  bool get _isFullSongActive =>
      musicService.isCurrentSong(widget.song) && !musicService.isPreviewPlayback;

  void _syncFromService() {
    if (!mounted) return;
    final active = _isFullSongActive;
    if (active && musicService.isPlaying) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      if (_spin.isAnimating) _spin.stop();
    }

    if (active) {
      final dur = musicService.player.duration;
      final total = (dur != null && dur.inSeconds > 0)
          ? dur.inSeconds
          : widget.song.seconds;
      final pos = musicService.player.position;
      _totalSec.value = total;
      _elapsedSec.value = pos.inSeconds.clamp(0, total);
      final totalMs = (dur != null && dur.inMilliseconds > 0)
          ? dur.inMilliseconds
          : widget.song.seconds * 1000;
      _progress.value = totalMs > 0
          ? (pos.inMilliseconds / totalMs).clamp(0.0, 1.0)
          : 0.0;
    } else {
      _totalSec.value = widget.song.seconds;
      _elapsedSec.value = 0;
      _progress.value = 0.0;
    }
    setState(() {});
  }

  void _onPosition(Duration pos) {
    if (!_isFullSongActive) return;
    final dur = musicService.player.duration;
    final totalSec = (dur != null && dur.inSeconds > 0)
        ? dur.inSeconds
        : widget.song.seconds;
    final totalMs = (dur != null && dur.inMilliseconds > 0)
        ? dur.inMilliseconds
        : widget.song.seconds * 1000;
    final sec = pos.inSeconds.clamp(0, totalSec);
    if (_elapsedSec.value != sec) {
      _elapsedSec.value = sec;
    }
    if (totalMs > 0) {
      _progress.value = (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);
    }
  }

  void _onDuration(Duration? dur) {
    if (!_isFullSongActive) return;
    if (dur != null && dur.inSeconds > 0) {
      _totalSec.value = dur.inSeconds;
    }
  }

  @override
  void dispose() {
    musicService.removeListener(_syncFromService);
    _posSub?.cancel();
    _durSub?.cancel();
    _progress.dispose();
    _elapsedSec.dispose();
    _totalSec.dispose();
    _spin.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    await musicService.togglePlay(widget.song);
  }

  Future<void> _seek(double dx, double w) async {
    if (w <= 0) return;
    final frac = (dx / w).clamp(0.0, 1.0);
    _progress.value = frac;
    _elapsedSec.value = (_totalSec.value * frac).round();
    if (!_isFullSongActive) {
      await musicService.togglePlay(widget.song);
    }
    await musicService.seekToFraction(frac);
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final active = _isFullSongActive;
    final loading = active && musicService.isBuffering;
    final playing = active && musicService.isPlaying && !loading;
    final cached = musicService.isCachedLocally(song);
    final error = active ? musicService.playbackError : null;
    final coverState = musicService.coverStateFor(song);
    if (coverState == CoverArtState.loading) {
      musicService.ensureITunesMetadata(song);
    }

    final statusNote = error != null
        ? '↑ $error'
        : loading
            ? '↑ resolving & buffering audio stream...'
            : playing && cached
                ? '↑ playing offline from local reel cache ♪'
                : playing
                    ? '↑ streaming live & caching locally for offline replay ♪'
                    : cached
                        ? '↑ saved offline on device · 0ms instant play'
                        : '↑ tap ▶ to stream · search clean catalog below';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SketchTap(
          onTap: _toggle,
          pressedScale: 0.95,
          child: SketchBox(
            shadow: false,
            padding: EdgeInsets.zero,
            jitter: 1.4,
            child: SizedBox(
              width: 92,
              height: 92,
              child: Stack(alignment: Alignment.center, children: [
                RepaintBoundary(
                  child: SongArtBox(song: song, size: 92, gap: 4.5),
                ),
                if (coverState != CoverArtState.unavailable)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: RotationTransition(
                      turns: _spin,
                      child: const RepaintBoundary(
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: CustomPaint(painter: VinylPainter()),
                        ),
                      ),
                    ),
                  )
                else
                  RotationTransition(
                    turns: _spin,
                    child: const RepaintBoundary(
                      child: SizedBox(
                        width: 66,
                        height: 66,
                        child: CustomPaint(painter: VinylPainter()),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Note(playing ? 'now playing aloud ♪' : 'now playing in my head', size: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(song.title.toUpperCase(),
                  key: ValueKey(song.title), style: T.head(22), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            Text(song.artist, style: T.body(15), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(children: [
              SketchTap(
                onTap: _toggle,
                pressedScale: .8,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: loading
                          ? const SizedBox(
                              key: ValueKey('buf'),
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Ink.ink,
                              ),
                            )
                          : Icon(
                              playing ? Icons.pause : Icons.play_arrow,
                              key: ValueKey(playing),
                              size: 22,
                              color: Ink.ink,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _seek(d.localPosition.dx, c.maxWidth),
                    onHorizontalDragUpdate: (d) => _seek(d.localPosition.dx, c.maxWidth),
                    child: RepaintBoundary(
                      child: SizedBox(
                        height: 20,
                        child: CustomPaint(painter: ProgressPainter(_progress)),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<int>(
                valueListenable: _elapsedSec,
                builder: (_, sec, _) => ValueListenableBuilder<int>(
                  valueListenable: _totalSec,
                  builder: (_, tot, _) => Text(
                    active || sec > 0 ? '${fmtTime(sec)} / ${fmtTime(tot)}' : fmtTime(tot),
                    style: T.body(12),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ]),
      const SizedBox(height: 8),
      Note(statusNote, size: 15, color: Ink.ink),
    ]);
  }
}

class VinylPainter extends CustomPainter {
  const VinylPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = Ink.ink;
    canvas.drawCircle(c, r, Paint()..color = Ink.paper);
    canvas.drawCircle(c, r - 1, stroke..strokeWidth = 1.8);
    for (final f in [.8, .66, .52]) {
      canvas.drawCircle(c, r * f, Paint()
        ..style = PaintingStyle.stroke
        ..color = Ink.ink.withAlpha(110)
        ..strokeWidth = .8);
    }
    // shine arc (makes the spin visible)
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * .9),
        -0.9,
        0.8,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..color = Ink.ink.withAlpha(120)
          ..strokeWidth = 3);
    canvas.drawCircle(c, r * .3, Paint()..color = Ink.grey);
    canvas.drawCircle(c, r * .3, stroke..strokeWidth = 1.2);
    canvas.drawCircle(c, r * .07, Paint()..color = Ink.ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class ProgressPainter extends CustomPainter {
  final ValueListenable<double> progress;
  ProgressPainter(this.progress) : super(repaint: progress);

  Path _line(double to) {
    final p = Path()..moveTo(0, sizeH);
    for (var x = 0.0; x <= to; x += 4) {
      p.lineTo(x, sizeH + math.sin(x / 7) * 0.9);
    }
    return p;
  }

  static const sizeH = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final v = progress.value;
    canvas.drawPath(
        _line(w),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Ink.ink.withAlpha(110)
          ..strokeWidth = 1.2);
    canvas.drawPath(
        _line(w * v),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..color = Ink.ink
          ..strokeWidth = 2.6);
    canvas.drawCircle(Offset(w * v, sizeH), 4.2, Paint()..color = Ink.ink);
  }

  @override
  bool shouldRepaint(ProgressPainter o) => o.progress != progress;
}

class _DirectorAvatarBox extends StatelessWidget {
  final double size;

  const _DirectorAvatarBox({required this.size});

  @override
  Widget build(BuildContext context) {
    final mem = app.avatarMemoryBytes;
    final url = app.avatarUrl;
    final hatch = app.avatarHatch;

    Widget inner;
    if (mem != null) {
      inner = Image.memory(
        mem,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else if (url != null && url.isNotEmpty) {
      inner = Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackHatch(hatch),
      );
    } else {
      inner = _fallbackHatch(hatch);
    }

    return SketchBox(
      shadow: false,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: size,
        height: size,
        child: inner,
      ),
    );
  }

  Widget _fallbackHatch(Hatch hatch) {
    final innerBox = (size * 0.64).roundToDouble();
    return Stack(
      alignment: Alignment.center,
      children: [
        HatchSwatch(hatch, size: size, gap: 4),
        Container(
          width: innerBox,
          height: innerBox,
          color: Ink.paper,
          child: Icon(Icons.person, size: size * 0.48, color: Ink.ink),
        ),
      ],
    );
  }
}
