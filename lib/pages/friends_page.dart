import 'dart:async';

import 'package:flutter/material.dart' hide Ink;
import 'package:flutter/services.dart';

import '../sketch.dart';
import '../state.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});
  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final ScrollController _scrollCtl = ScrollController();
  final GlobalKey _calendarKey = GlobalKey();
  int _dir = 1;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    if (app.isAuthenticated && !app.demoMode) {
      unawaited(app.refreshFriends());
    }
  }

  @override
  void dispose() {
    _scrollCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await app.refreshFriends();
      if (mounted) {
        showNote(context, 'co-star reels synced ✓');
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _shiftMonth(int d) {
    _dir = d;
    app.shiftFriendMonth(d);
  }

  void _jumpToFriendCalendar(Friend f) {
    app.openFriendCalendar(f.id);
    final ctx = _calendarKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _confirmRemoveFriend(Friend friend) async {
    await showSketchDialog<void>(
      context,
      (c) => SketchDialogCard(
        title: 'remove co-star?',
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'disconnect from ${friend.name} (${friend.handle})?',
              style: T.body(15),
            ),
            const SizedBox(height: 8),
            const Note(
              'their soundtrack and shared calendar will be unlinked from your reel.',
              size: 14,
            ),
          ],
        ),
        actions: [
          SketchTextButton('cancel', onTap: () => Navigator.pop(c)),
          SketchTextButton(
            'remove',
            primary: true,
            onTap: () async {
              Navigator.pop(c);
              final ok = await app.removeFriend(friend.id);
              if (mounted && ok) {
                showNote(context, 'removed ${friend.name} from co-stars');
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openConnectDialog() async {
    final ctl = TextEditingController();
    await showSketchDialog<void>(
      context,
      (c) => SketchDialogCard(
        title: 'connect a co-star',
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Note('your reel ticket (tap to copy)', size: 14),
            const SizedBox(height: 4),
            SketchTap(
              onTap: () {
                Clipboard.setData(ClipboardData(text: app.inviteCode));
                Navigator.pop(c);
                showNote(context, 'ticket ${app.inviteCode} copied – send it to a friend ✓');
              },
              child: SketchBox(
                shadow: false,
                dashed: true,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(children: [
                  const Icon(Icons.confirmation_number_outlined, size: 18, color: Ink.ink),
                  const SizedBox(width: 8),
                  Expanded(child: Text(app.inviteCode, style: T.head(18))),
                  const Icon(Icons.copy, size: 15, color: Ink.soft),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            const Note('or enter a friend\'s handle / ticket', size: 14),
            const SizedBox(height: 4),
            SketchBox(
              shadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: TextField(
                controller: ctl,
                autofocus: true,
                maxLength: 20,
                style: T.body(16),
                onSubmitted: (v) async {
                  Navigator.pop(c);
                  final msg = await app.connectCoStar(v);
                  if (mounted && msg != null) {
                    showNote(context, msg);
                  }
                },
                decoration: InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: 'e.g. @leo or LEO-718',
                  hintStyle: T.body(15, c: Ink.faint),
                ),
              ),
            ),
          ],
        ),
        actions: [
          SketchTextButton('cancel', onTap: () => Navigator.pop(c)),
          SketchTextButton(
            'connect',
            primary: true,
            onTap: () async {
              final input = ctl.text;
              Navigator.pop(c);
              final msg = await app.connectCoStar(input);
              if (mounted && msg != null) {
                showNote(context, msg);
              }
            },
          ),
        ],
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
        final myToday = app.entryFor(app.today);
        final active = app.activeFriend;

        final listView = ListView(
          controller: _scrollCtl,
          addRepaintBoundaries: false,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          children: [
            // ── header
            r(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Note('co-stars & shared reels', size: 15),
                  const SizedBox(height: 2),
                  Text('FRIENDS', style: T.head(27)),
                ]),
              ),
              if (!app.demoMode && app.isAuthenticated) ...[
                SketchTap(
                  onTap: _refresh,
                  child: SketchBox(
                    padding: EdgeInsets.zero,
                    seed: 5,
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: Center(
                        child: _refreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Ink.ink,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 20, color: Ink.ink),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              SketchTap(
                onTap: _openConnectDialog,
                child: SketchBox(
                  padding: EdgeInsets.zero,
                  seed: 6,
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Stack(alignment: Alignment.center, children: [
                      const HatchSwatch(Hatch.diagonal, size: 42, gap: 4),
                      Container(
                        width: 24,
                        height: 24,
                        color: Ink.paper,
                        child: const Icon(Icons.person_add_alt_1_outlined, size: 18, color: Ink.ink),
                      ),
                    ]),
                  ),
                ),
              ),
            ])),
            const SizedBox(height: 14),

            // ── my broadcast / sharing status
            r(TagBox(
              label: !app.sharingEnabled
                  ? 'off air'
                  : app.sharingAudience == 'all'
                      ? 'on air · all'
                      : 'on air · ${app.sharedFriendsCount} of ${app.friends.length}',
              right: true,
              seed: 23,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SketchTap(
                  onTap: app.toggleSharing,
                  pressedScale: .98,
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Share my mood & calendar', style: T.body(16)),
                        Note(
                          !app.sharingEnabled
                              ? 'paused – your reel is tucked backstage'
                              : app.sharingAudience == 'all'
                                  ? 'broadcasting live to all connected co-stars'
                                  : 'sharing only with ${app.sharedFriendsCount} selected co-star${app.sharedFriendsCount == 1 ? '' : 's'}',
                          size: 13,
                        ),
                      ]),
                    ),
                    SketchSwitch(app.sharingEnabled),
                  ]),
                ),
                if (app.sharingEnabled) ...[
                  const SizedBox(height: 10),
                  const DashedLine(),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Note('Audience: ', size: 13),
                    const SizedBox(width: 4),
                    SketchChip(
                      label: 'All co-stars',
                      selected: app.sharingAudience == 'all',
                      seed: 31,
                      onTap: () {
                        app.setSharingAudience('all');
                        showNote(context, 'sharing with all connected co-stars ✓');
                      },
                    ),
                    const SizedBox(width: 6),
                    SketchChip(
                      label: app.sharingAudience == 'specific'
                          ? 'Specific (${app.sharedFriendsCount})'
                          : 'Specific friends',
                      selected: app.sharingAudience == 'specific',
                      seed: 32,
                      onTap: () {
                        app.setSharingAudience('specific');
                        showNote(context, 'selective sharing active – pick co-stars below');
                      },
                    ),
                  ]),
                  if (app.sharingAudience == 'specific') ...[
                    const SizedBox(height: 10),
                    if (app.friends.isEmpty)
                      const Note('no co-stars connected yet – add friends below', size: 12)
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Note('allow viewing for:', size: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  app.shareWithAllFriends();
                                  showNote(context, 'selected all co-stars ✓');
                                },
                                child: Text('all', style: T.note(12, c: Ink.ink).copyWith(decoration: TextDecoration.underline)),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  app.unshareAllFriends();
                                  showNote(context, 'unselected all co-stars');
                                },
                                child: Text('none', style: T.note(12, c: Ink.soft).copyWith(decoration: TextDecoration.underline)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final f in app.friends)
                            SketchChip(
                              label: app.isSharedWith(f.id) ? '✓ ${f.name}' : '× ${f.name}',
                              selected: app.isSharedWith(f.id),
                              dashed: !app.isSharedWith(f.id),
                              seed: f.id.hashCode.abs() % 100,
                              onTap: () {
                                final willShare = !app.isSharedWith(f.id);
                                app.toggleFriendSharing(f.id);
                                showNote(
                                  context,
                                  willShare
                                      ? 'shared reel with ${f.name} ✓'
                                      : 'hidden reel from ${f.name}',
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ],
                ],
                const SizedBox(height: 10),
                const DashedLine(),
                const SizedBox(height: 8),
                Row(children: [
                  if (myToday != null) ...[
                    HatchSwatch(
                      myToday.mood.hatch,
                      size: 22,
                      circle: true,
                      gap: 3,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'today: ${myToday.mood.name} · ${myToday.song.title}',
                            style: T.body(
                              13,
                              c: app.sharingEnabled ? Ink.ink : Ink.soft,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Note(
                            app.demoMode
                                ? 'offline demo reel (connect real accounts to sync live)'
                                : !app.sharingEnabled
                                    ? 'hidden backstage · co-stars see "quiet today"'
                                    : app.sharingAudience == 'all'
                                        ? 'broadcasting live to all accepted co-stars ✓'
                                        : 'shared with ${app.sharedFriendsCount} selected co-star${app.sharedFriendsCount == 1 ? '' : 's'} ✓',
                            size: 12,
                            color: app.sharingEnabled ? Ink.ink : Ink.soft,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CustomPaint(painter: DashedCirclePainter(color: Ink.soft, width: 1.2)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'no scene filmed yet today (${app.draftMood.name} draft)',
                        style: T.body(13, c: Ink.soft),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => app.setTab(0),
                      child: Text(
                        'film now →',
                        style: T.note(14, c: Ink.ink).copyWith(decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ]),
              ]),
            )),

            // ── pending reel invites
            if (app.invites.isNotEmpty) ...[
              const SizedBox(height: 18),
              r(const SectionTitle('Reel invites')),
              for (final inv in app.invites)
                r(Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SketchBox(
                    seed: inv.name.length + 41,
                    dashed: true,
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      HatchSwatch(inv.avatar, size: 38),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(inv.name.toUpperCase(), style: T.head(17)),
                          Note('${inv.handle} wants to swap calendars', size: 13),
                        ]),
                      ),
                      SketchTextButton(
                        'later',
                        onTap: () => app.dismissInvite(inv.id),
                      ),
                      const SizedBox(width: 6),
                      SketchTextButton(
                        'accept',
                        primary: true,
                        onTap: () {
                          final added = app.acceptInvite(inv.id);
                          if (added != null) {
                            showNote(context, '${added.name} joined your reel ✓');
                          }
                        },
                      ),
                    ]),
                  ),
                )),
            ],

            // ── connected friends' daily moods
            const SizedBox(height: 18),
            r(Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const SectionTitle('Today\'s moods'),
              Note('${app.friends.length} connected', size: 14),
            ])),
            if (app.friends.isEmpty)
              r(SketchBox(
                seed: 49,
                dashed: true,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                child: Column(children: [
                  Text('NO CO-STARS CONNECTED YET', style: T.head(17)),
                  const SizedBox(height: 4),
                  Note(
                    'share your ticket (${app.inviteCode}) or add a friend\'s code to swap moods & calendars.',
                    size: 15,
                    align: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SketchTextButton(
                    'connect a co-star →',
                    primary: true,
                    onTap: _openConnectDialog,
                  ),
                ]),
              )),
            for (var k = 0; k < app.friends.length; k++)
              r(_FriendMoodCard(
                friend: app.friends[k],
                seed: 51 + k,
                selected: active?.id == app.friends[k].id,
                onOpenCalendar: () => _jumpToFriendCalendar(app.friends[k]),
                onRemove: () => _confirmRemoveFriend(app.friends[k]),
              )),

            // ── shared calendars
            if (active != null) ...[
              const SizedBox(height: 12),
              r(Container(
                key: _calendarKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SectionTitle('Shared calendars'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (app.sharingEnabled) ...[
                            SketchTap(
                              onTap: () {
                                final willShare = !app.isSharedWith(active.id);
                                app.toggleFriendSharing(active.id);
                                showNote(
                                  context,
                                  willShare
                                      ? 'now sharing your reel with ${active.name} ✓'
                                      : 'your reel is now hidden from ${active.name}',
                                );
                              },
                              pressedScale: .9,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    app.isSharedWith(active.id)
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 14,
                                    color: app.isSharedWith(active.id) ? Ink.ink : Ink.soft,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    app.isSharedWith(active.id) ? 'shared' : 'hidden',
                                    style: T.note(13, c: app.isSharedWith(active.id) ? Ink.ink : Ink.soft)
                                        .copyWith(decoration: TextDecoration.underline),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          SketchTap(
                            onTap: () => _confirmRemoveFriend(active),
                            pressedScale: .9,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_remove_outlined, size: 14, color: Ink.soft),
                                const SizedBox(width: 4),
                                Text(
                                  'remove ${active.name}',
                                  style: T.note(13, c: Ink.soft).copyWith(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (var k = 0; k < app.friends.length; k++)
                      SketchChip(
                        label: app.friends[k].name,
                        selected: active.id == app.friends[k].id,
                        seed: 70 + k,
                        onTap: () => app.selectFriend(app.friends[k].id),
                      ),
                    SketchChip(
                      label: app.compareCalendar ? '⇄ w/ mine ✓' : '⇄ compare',
                      selected: app.compareCalendar,
                      dashed: !app.compareCalendar,
                      seed: 88,
                      onTap: app.toggleCompareCalendar,
                    ),
                  ]),
                ]),
              )),
              const SizedBox(height: 12),
              r(_SharedCalendarCard(
                friend: active,
                month: app.friendViewMonth,
                selectedDate: app.friendSelectedDate,
                compareWithMine: app.compareCalendar && app.isSharedWith(active.id),
                dir: _dir,
                onShiftMonth: _shiftMonth,
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
              r(_SharedSceneDetail(
                friend: active,
                date: app.friendSelectedDate,
                compareWithMine: app.compareCalendar && app.isSharedWith(active.id),
              )),
            ],
          ],
        );

        if (app.demoMode || !app.isAuthenticated) {
          return listView;
        }

        return RefreshIndicator(
          color: Ink.ink,
          backgroundColor: Ink.paper,
          onRefresh: _refresh,
          child: listView,
        );
      },
    );
  }
}

class _FriendMoodCard extends StatelessWidget {
  final Friend friend;
  final int seed;
  final bool selected;
  final VoidCallback onOpenCalendar;
  final VoidCallback onRemove;

  const _FriendMoodCard({
    required this.friend,
    required this.seed,
    required this.selected,
    required this.onOpenCalendar,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final todayScene = friend.entryFor(app.today);
    final streak = friend.streakFrom(app.today);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SketchBox(
        seed: seed,
        strokeWidth: selected ? 2.2 : 1.8,
        padding: const EdgeInsets.all(11),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SketchBox(
              shadow: false,
              padding: EdgeInsets.zero,
              jitter: 1.2,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Stack(alignment: Alignment.center, children: [
                  HatchSwatch(friend.avatar, size: 40, gap: 4),
                  Container(
                    width: 24,
                    height: 24,
                    color: Ink.paper,
                    alignment: Alignment.center,
                    child: Text(friend.name[0].toUpperCase(), style: T.head(16)),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(friend.name.toUpperCase(), style: T.head(18), overflow: TextOverflow.ellipsis),
                Note('${friend.handle} · $streak-day streak', size: 13),
              ]),
            ),
            if (todayScene != null)
              SketchBox(
                shadow: false,
                fill: Ink.bg,
                jitter: 1.2,
                strokeWidth: 1.3,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  HatchSwatch(todayScene.mood.hatch, size: 16, circle: true, gap: 2.8),
                  const SizedBox(width: 5),
                  Text(todayScene.mood.name, style: T.body(13)),
                ]),
              )
            else if (!friend.sharingEnabled)
              SketchBox(
                shadow: false,
                dashed: true,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_outline, size: 13, color: Ink.soft),
                  const SizedBox(width: 4),
                  const Note('mood sharing off', size: 13),
                ]),
              )
            else
              const Note('quiet today', size: 14),
          ]),
          if (todayScene != null) ...[
            const SizedBox(height: 9),
            Row(children: [
              SongArtBox(song: todayScene.song, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${todayScene.song.title} · ${todayScene.song.artist}',
                  style: T.body(14, c: Ink.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              SongPlayButton(song: todayScene.song, size: 28, seed: seed + 3),
            ]),
            const SizedBox(height: 4),
            Text('“${todayScene.note}”', style: T.note(16, c: Ink.ink)),
          ],
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            SketchTap(
              onTap: () => app.toggleCheerFriend(friend.id),
              pressedScale: .9,
              child: SketchBox(
                shadow: false,
                fill: friend.cheeredToday ? Ink.grey : Ink.paper,
                jitter: 1.3,
                strokeWidth: 1.3,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    friend.cheeredToday ? Icons.favorite : Icons.favorite_border,
                    size: 14,
                    color: Ink.ink,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    friend.cheeredToday ? 'cheered · ${friend.cheers}' : 'cheer · ${friend.cheers}',
                    style: T.body(12),
                  ),
                ]),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (app.sharingEnabled) ...[
                  SketchTap(
                    onTap: () {
                      final willShare = !app.isSharedWith(friend.id);
                      app.toggleFriendSharing(friend.id);
                      showNote(
                        context,
                        willShare
                            ? 'now sharing your reel with ${friend.name} ✓'
                            : 'your reel is now hidden from ${friend.name}',
                      );
                    },
                    pressedScale: .85,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            app.isSharedWith(friend.id)
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 14,
                            color: app.isSharedWith(friend.id) ? Ink.ink : Ink.soft,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            app.isSharedWith(friend.id) ? 'shared' : 'hidden',
                            style: T.note(12, c: app.isSharedWith(friend.id) ? Ink.ink : Ink.soft)
                                .copyWith(decoration: TextDecoration.underline),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                SketchTap(
                  onTap: onRemove,
                  pressedScale: .85,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_remove_outlined, size: 14, color: Ink.soft),
                        const SizedBox(width: 3),
                        Text(
                          'remove',
                          style: T.note(12, c: Ink.soft).copyWith(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onOpenCalendar,
                  child: Text(
                    'calendar →',
                    style: T.note(14, c: Ink.ink).copyWith(decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ]),
        ]),
      ),
    );
  }
}

class _SharedCalendarCard extends StatelessWidget {
  final Friend friend;
  final DateTime month;
  final DateTime selectedDate;
  final bool compareWithMine;
  final int dir;
  final ValueChanged<int> onShiftMonth;

  const _SharedCalendarCard({
    required this.friend,
    required this.month,
    required this.selectedDate,
    required this.compareWithMine,
    required this.dir,
    required this.onShiftMonth,
  });

  @override
  Widget build(BuildContext context) {
    return SketchBox(
      seed: 19,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(children: [
        Row(children: [
          _MiniArrowBtn(Icons.chevron_left, () => onShiftMonth(-1)),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
              child: Column(
                key: ValueKey('${friend.id}_${month.year}_${month.month}'),
                children: [
                  Text(
                    '${monthNames[month.month - 1]} ${month.year}'.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: T.head(19),
                  ),
                  Note(
                    compareWithMine
                        ? (app.isSharedWith(friend.id)
                            ? '${friend.name}\'s reel + tiny pips for yours'
                            : '${friend.name}\'s reel (your reel hidden from them)')
                        : '${friend.name}\'s shared soundtrack',
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
          _MiniArrowBtn(Icons.chevron_right, () => onShiftMonth(1)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
            Expanded(child: Center(child: Note(d, size: 15, color: Ink.ink))),
        ]),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: Offset(0.10 * dir, 0), end: Offset.zero).animate(a),
              child: c,
            ),
          ),
          child: _grid(),
        ),
      ]),
    );
  }

  Widget _grid() {
    final lead = DateTime(month.year, month.month, 1).weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = <Widget>[];
    var day = 1 - lead;
    while (day <= days) {
      final cells = <Widget>[];
      for (var c = 0; c < 7; c++, day++) {
        cells.add(Expanded(
          child: (day < 1 || day > days)
              ? const SizedBox(height: 46)
              : _cell(DateTime(month.year, month.month, day)),
        ));
      }
      rows.add(Row(children: cells));
    }
    return Column(key: ValueKey('${friend.id}_${month.year}_${month.month}'), children: rows);
  }

  Widget _cell(DateTime d) {
    final theirEntry = friend.entryFor(d);
    final myEntry = compareWithMine ? app.entryFor(d) : null;
    final sel = sameDay(d, selectedDate);

    return SizedBox(
      height: 46,
      child: SketchTap(
        pressedScale: .82,
        onTap: () => app.selectFriendDate(d),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: 34,
            height: 32,
            child: Stack(alignment: Alignment.center, children: [
              if (theirEntry != null)
                Transform.scale(
                  scale: sel ? 1.08 : 1.0,
                  child: HatchSwatch(theirEntry.mood.hatch, size: 26, circle: true, gap: 3.2),
                )
              else
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CustomPaint(painter: _SharedFaintCircle()),
                ),
              if (myEntry != null)
                Positioned(
                  right: 1,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(color: Ink.paper, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(1),
                    child: HatchSwatch(myEntry.mood.hatch, size: 11, circle: true, gap: 2.4),
                  ),
                ),
              if (sel)
                IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.72, end: 1.0),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: const SizedBox(
                      width: 33,
                      height: 33,
                      child: CustomPaint(painter: DashedCirclePainter()),
                    ),
                    builder: (_, s, ring) => Transform.scale(scale: s, child: ring),
                  ),
                ),
            ]),
          ),
          Text(
            '${d.day}',
            style: T.body(10, c: (theirEntry != null || myEntry != null) ? Ink.ink : Ink.faint),
          ),
        ]),
      ),
    );
  }
}

class _SharedSceneDetail extends StatelessWidget {
  final Friend friend;
  final DateTime date;
  final bool compareWithMine;

  const _SharedSceneDetail({
    required this.friend,
    required this.date,
    required this.compareWithMine,
  });

  @override
  Widget build(BuildContext context) {
    final e = friend.entryFor(date);
    final mine = compareWithMine ? app.entryFor(date) : null;

    return TagBox(
      label: '${friend.name} · scene ${e?.scene ?? sceneNo(date)}',
      seed: 29,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(a),
              child: c,
            ),
          ),
          child: Column(
            key: ValueKey('${friend.id}_${dayKey(date)}_$compareWithMine'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(children: [
                      Note(dayLabel(date), size: 15),
                      const SizedBox(height: 4),
                      Text('NO SCENE FROM ${friend.name.toUpperCase()}', style: T.head(17)),
                      const Note('nothing filmed on their reel for this day.', size: 15),
                    ]),
                  ),
                )
              else ...[
                Row(children: [
                  SongArtBox(song: e.song, size: 54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Note(dayLabel(e.date), size: 14),
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
                    ]),
                  ),
                  const SizedBox(width: 10),
                  SongPlayButton(song: e.song, size: 36, seed: 39),
                ]),
                const SizedBox(height: 10),
                const DashedLine(),
                const SizedBox(height: 8),
                Text('“${e.note}”', style: T.note(18, c: Ink.ink)),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: SketchTextButton(
                    'borrow song ♪',
                    onTap: () {
                      app.setSong(e.song);
                      showNote(context, 'loaded "${e.song.title}" into your draft ♪');
                    },
                  ),
                ),
              ],
              if (mine != null) ...[
                const SizedBox(height: 10),
                const DashedLine(),
                const SizedBox(height: 8),
                Row(children: [
                  HatchSwatch(mine.mood.hatch, size: 20, circle: true, gap: 3),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'your scene: ${mine.song.title} · ${mine.mood.name}',
                      style: T.body(13, c: Ink.soft),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedFaintCircle extends CustomPainter {
  const _SharedFaintCircle();
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

class _MiniArrowBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MiniArrowBtn(this.icon, this.onTap);
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
