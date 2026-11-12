import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Ink;

import '../services/youtube_music_service.dart';
import '../sketch.dart';
import '../state.dart';
import 'mood_prompt_dialog.dart';

/// Prompts the user to confirm deleting a saved journal [entry] and deletes it
/// from both local state and Supabase (`public.scenes`) if confirmed.
Future<bool> confirmDeleteScene(BuildContext context, Entry entry) async {
  final confirmed = await showSketchDialog<bool>(
    context,
    (c) => SketchDialogCard(
      title: 'delete scene ${entry.scene}?',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Note(dayLabel(entry.date), size: 15),
          const SizedBox(height: 4),
          Text(
            '${entry.song.title} · ${entry.song.artist}',
            style: T.body(15, w: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            'erase this journal scene from your soundtrack reel? this cannot be undone.',
            style: T.body(14, c: Ink.soft),
          ),
        ],
      ),
      actions: [
        SketchTextButton('cancel', onTap: () => Navigator.pop(c, false)),
        SketchTextButton(
          'delete',
          primary: true,
          onTap: () => Navigator.pop(c, true),
        ),
      ],
    ),
  );

  if (confirmed != true) return false;

  await app.deleteSceneForDate(entry.date);
  if (context.mounted) {
    showNote(context, 'scene ${entry.scene} deleted from the reel ✓');
  }
  return true;
}

/// Opens a sketch-styled bottom sheet to update an existing journal scene
/// (or film a missed past day) for [date].
Future<void> openSceneEditor(
  BuildContext context,
  DateTime date, {
  Entry? initialEntry,
}) async {
  final existing = initialEntry ?? app.entryFor(date);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SceneEditorSheet(
      date: DateTime(date.year, date.month, date.day),
      initialEntry: existing,
    ),
  );
  if (musicService.isPreviewPlayback) {
    await musicService.stop();
  }
}

class SceneEditorSheet extends StatefulWidget {
  final DateTime date;
  final Entry? initialEntry;

  const SceneEditorSheet({
    super.key,
    required this.date,
    this.initialEntry,
  });

  @override
  State<SceneEditorSheet> createState() => _SceneEditorSheetState();
}

class _SceneEditorSheetState extends State<SceneEditorSheet> {
  late Song _song;
  late Mood _mood;
  late final TextEditingController _noteCtl;

  bool get _isEditing => widget.initialEntry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.initialEntry;
    _song = e?.song ?? catalog.first;
    _mood = e?.mood ?? hopeful;
    _noteCtl = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _pickSong() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<Song>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SongPicker(),
    );
    if (musicService.isPreviewPlayback) {
      await musicService.stop();
    }
    if (picked != null && mounted) {
      setState(() => _song = picked);
    }
  }

  Future<void> _addCustomMood() async {
    final ctl = TextEditingController();
    await showSketchDialog<void>(
      context,
      (c) => SketchDialogCard(
        title: 'add a mood',
        body: SketchBox(
          shadow: false,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: TextField(
            controller: ctl,
            autofocus: true,
            maxLength: 18,
            style: T.body(16),
            onSubmitted: (v) {
              final created = app.ensureMood(v);
              if (created != null && mounted) {
                setState(() => _mood = created);
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
        actions: [
          SketchTextButton('cancel', onTap: () => Navigator.pop(c)),
          SketchTextButton(
            'add',
            primary: true,
            onTap: () {
              final created = app.ensureMood(ctl.text);
              if (created != null && mounted) {
                setState(() => _mood = created);
              }
              Navigator.pop(c);
            },
          ),
        ],
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
                      if (_mood == mood) {
                        setState(() => _mood = app.moods.first);
                      }
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
                if (_mood == mood) {
                  setState(() => _mood = Mood(newName.toLowerCase(), chosenHatch));
                }
                showNote(context, 'feeling updated to "$newName" ✓');
              }
              Navigator.pop(c);
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDelete() async {
    final entry = widget.initialEntry;
    if (entry == null) return;
    FocusScope.of(context).unfocus();
    final deleted = await confirmDeleteScene(context, entry);
    if (deleted && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    if (app.moodPrompts) {
      final promptAnswer = await showMoodPromptDialog(context);
      if (promptAnswer == null) {
        return;
      }
      if (promptAnswer.isNotEmpty) {
        final existing = _noteCtl.text.trim();
        if (existing.isEmpty) {
          _noteCtl.text = promptAnswer;
        } else {
          _noteCtl.text = '$existing\n\n[director\'s reflection] $promptAnswer';
        }
      }
    }
    if (!mounted) return;
    final scNo = widget.initialEntry?.scene ?? sceneNo(widget.date);
    app.saveSceneForDate(
      widget.date,
      song: _song,
      mood: _mood,
      note: _noteCtl.text,
    );
    Navigator.pop(context);
    showNote(
      context,
      _isEditing
          ? 'scene $scNo updated ✓'
          : 'scene $scNo saved to the reel ✓',
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxH = math.max(
      300.0,
      mq.size.height - mq.viewInsets.bottom - mq.padding.top - 24,
    );
    final scNo = widget.initialEntry?.scene ?? sceneNo(widget.date);

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, mq.viewInsets.bottom + 14),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: SketchBox(
          padding: const EdgeInsets.all(16),
          seed: 44,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Note('${dayLabel(widget.date)} · scene $scNo', size: 14),
                        Text(
                          _isEditing ? 'UPDATE JOURNAL SCENE' : 'FILM JOURNAL SCENE',
                          style: T.head(20),
                        ),
                      ],
                    ),
                  ),
                  SketchTap(
                    onTap: () async {
                      if (musicService.isPreviewPlayback) {
                        await musicService.stop();
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Icon(Icons.close, size: 20, color: Ink.soft),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Scrollable body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SOUNDTRACK', style: T.head(12)),
                      const SizedBox(height: 5),
                      SketchBox(
                        shadow: false,
                        seed: 46,
                        padding: const EdgeInsets.all(9),
                        child: Row(
                          children: [
                            SongArtBox(song: _song, size: 46),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _song.title,
                                    style: T.body(15, w: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${_song.artist} · ${fmtTime(_song.seconds)}',
                                    style: T.body(12, c: Ink.soft),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            SongPlayButton(song: _song, size: 30, seed: 47),
                            const SizedBox(width: 6),
                            SketchTextButton('change ♪', onTap: _pickSong),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text('HOW DID IT FEEL?', style: T.head(12)),
                      const SizedBox(height: 6),
                      ListenableBuilder(
                        listenable: app,
                        builder: (context, _) => Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var k = 0; k < app.moods.length; k++)
                              SketchChip(
                                label: app.moods[k].name,
                                selected: _mood == app.moods[k],
                                seed: 100 + k,
                                onTap: () => setState(() => _mood = app.moods[k]),
                                onLongPress: () => _editMood(app.moods[k]),
                              ),
                            SketchChip(
                              label: '+ add',
                              dashed: true,
                              seed: 140,
                              onTap: _addCustomMood,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text('WHY THIS SONG?', style: T.head(12)),
                      const SizedBox(height: 5),
                      SketchBox(
                        shadow: false,
                        seed: 48,
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                        child: TextField(
                          controller: _noteCtl,
                          minLines: 3,
                          maxLines: 4,
                          style: T.body(15),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: 'scribble a line about that day...',
                            hintStyle: T.body(14, c: Ink.faint),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Bottom actions
              Row(
                children: [
                  if (_isEditing)
                    SketchTap(
                      onTap: _handleDelete,
                      child: SketchBox(
                        shadow: false,
                        dashed: true,
                        fill: Ink.bg,
                        seed: 49,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.delete_outline,
                              size: 15,
                              color: Ink.ink,
                            ),
                            const SizedBox(width: 4),
                            Text('DELETE', style: T.head(13)),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  SketchTextButton(
                    'cancel',
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  SketchTextButton(
                    _isEditing ? 'update' : 'save',
                    primary: true,
                    onTap: _handleSave,
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

// ───────────────────────── song picker ─────────────────────────

class SongPicker extends StatefulWidget {
  const SongPicker({super.key});
  @override
  State<SongPicker> createState() => _SongPickerState();
}

class _SongPickerState extends State<SongPicker> {
  final TextEditingController _searchCtl = TextEditingController();
  Timer? _debounce;
  int _searchSeq = 0;

  String _query = '';
  bool _searching = false;
  String? _error;
  List<Song> _searchResults = const <Song>[];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    if (musicService.isPreviewPlayback) {
      unawaited(musicService.stop());
    }
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      _error = null;
    });
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      ++_searchSeq;
      setState(() {
        _searching = false;
        _searchResults = const <Song>[];
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _runSearch(trimmed);
    });
  }

  Future<void> _runSearch(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    _debounce?.cancel();
    final seq = ++_searchSeq;
    if (mounted) {
      setState(() {
        _searching = true;
        _error = null;
      });
    }
    try {
      final found = await musicService.searchMusic(trimmed);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searchResults = found;
        _searching = false;
      });
    } on SocketException catch (_) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searching = false;
        _error = 'device offline – check your internet connection.';
      });
    } on HttpException catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searching = false;
        _error = e.message.contains('429')
            ? 'rate limited by catalog – wait a moment and retry.'
            : 'catalog server response error – please retry.';
      });
    } catch (_) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searching = false;
        _error = 'couldn\'t reach music catalog – check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final availableH = mq.size.height - mq.viewInsets.bottom - mq.padding.top - 28;
    final sheetH = math.min(mq.size.height * 0.78, math.max(280.0, availableH));

    final trimmed = _query.trim();
    final lower = trimmed.toLowerCase();
    final localMatches = lower.isEmpty
        ? catalog
        : catalog
            .where((s) =>
                s.title.toLowerCase().contains(lower) ||
                s.artist.toLowerCase().contains(lower))
            .toList();

    final displayList = trimmed.isEmpty
        ? catalog
        : (_searchResults.isNotEmpty ? _searchResults : localMatches);

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, mq.viewInsets.bottom + 14),
      child: SizedBox(
        height: sheetH,
        child: SketchBox(
          padding: const EdgeInsets.all(16),
          seed: 50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('PICK A SONG', style: T.head(20))),
                  SketchTap(
                    onTap: () async {
                      if (musicService.isPreviewPlayback) {
                        await musicService.stop();
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Icon(Icons.close, size: 20, color: Ink.soft),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SketchBox(
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(children: [
                  const Icon(Icons.search, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchCtl,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      style: T.body(15),
                      onChanged: _onQueryChanged,
                      onSubmitted: _runSearch,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'search song or artist...',
                        hintStyle: T.body(14, c: Ink.faint),
                      ),
                    ),
                  ),
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Ink.ink,
                        ),
                      ),
                    )
                  else if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtl.clear();
                        _onQueryChanged('');
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.clear, size: 17, color: Ink.soft),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Note(
                      trimmed.isEmpty
                          ? 'reel classics · type above to search catalog'
                          : _searching && _searchResults.isEmpty
                              ? 'searching catalog...'
                              : _searchResults.isNotEmpty
                                  ? '${_searchResults.length} songs found'
                                  : 'local reel matches',
                      size: 13,
                    ),
                  ),
                  const InlineIconNote(
                    prefix: 'tap ',
                    icon: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: SketchPlayIcon(playing: false, size: 9, color: Ink.soft),
                    ),
                    suffix: ' for 30s preview',
                    size: 13,
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                SketchBox(
                  shadow: false,
                  dashed: true,
                  fill: Ink.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_outlined, size: 15, color: Ink.ink),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_error!, style: T.body(13))),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _runSearch(_query),
                        child: Text(
                          'retry',
                          style: T.note(14, c: Ink.ink).copyWith(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: _searching && displayList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Ink.ink,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Note('digging through the crates for "$trimmed"...', size: 16),
                          ],
                        ),
                      )
                    : displayList.isEmpty
                        ? const Center(child: Note('no tracks found for that search...', size: 18))
                        : ListView.builder(
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            itemCount: displayList.length,
                            itemBuilder: (_, k) {
                              final item = displayList[k];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: SketchTap(
                                  onTap: () async {
                                    if (musicService.isPreviewPlayback) {
                                      await musicService.stop();
                                    }
                                    if (context.mounted) {
                                      Navigator.pop(context, item);
                                    }
                                  },
                                  child: SketchBox(
                                    shadow: false,
                                    seed: 60 + k,
                                    padding: const EdgeInsets.all(8),
                                    child: Row(children: [
                                      SongArtBox(song: item, size: 42),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              style: T.body(15),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${item.artist} · ${fmtTime(item.seconds)}',
                                              style: T.body(12, c: Ink.soft),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SongPlayButton(
                                        song: item,
                                        size: 32,
                                        seed: 120 + k,
                                        previewOnly: true,
                                      ),
                                    ]),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
