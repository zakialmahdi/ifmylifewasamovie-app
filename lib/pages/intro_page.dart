import 'package:flutter/material.dart' hide Ink;
import 'package:go_router/go_router.dart';

import '../services/youtube_music_service.dart';
import '../sketch.dart';
import '../state.dart';
import '../widgets/youtube_login_sheet.dart';

/// A clean, sketchbook-styled carousel shown once on a newly registered user's
/// first session (or replayed from Settings) explaining the core workflow and
/// offering an upfront YouTube connection with an explicit skip option.
class IntroPage extends StatefulWidget {
  final bool isReplay;

  const IntroPage({
    super.key,
    this.isReplay = false,
  });

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static final Song _sampleSong = Song(
    'Midnight City',
    'M83',
    244,
    Hatch.diagonal,
  );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _jumpToConnect() {
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _connectYouTube() async {
    final cookies = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => const YouTubeLoginSheet(),
      ),
    );

    if (cookies != null && cookies.isNotEmpty) {
      await musicService.connectYouTube(cookies);
      if (mounted) {
        showNote(context, 'YouTube connected · bot checks resolved ✓');
        setState(() {});
      }
    }
  }

  Future<void> _finishAndEnter() async {
    await app.completeIntro();
    if (!mounted) return;

    if (widget.isReplay) {
      Navigator.of(context).maybePop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildSlide1Song(),
                  _buildSlide2Mood(),
                  _buildSlide3CalendarAndFriends(),
                  _buildSlide4YouTube(),
                ],
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Top Bar ─────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (widget.isReplay)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SketchTap(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 20, color: Ink.ink),
                    ),
                  ),
                ),
              Note('${_currentPage + 1} / 4', size: 15),
            ],
          ),
          if (_currentPage < 3)
            SketchTap(
              onTap: _jumpToConnect,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  'skip',
                  style: T.note(16, c: Ink.soft).copyWith(
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 28),
        ],
      ),
    );
  }

  // ───────────────────────── Slide Frame ─────────────────────────

  Widget _slideFrame({
    required Widget visual,
    required String title,
    required String subtitle,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 330),
                child: visual,
              ),
              const SizedBox(height: 32),
              Text(
                title,
                textAlign: TextAlign.center,
                style: T.head(27),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: T.body(16, c: Ink.soft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Slide 1: One Song A Day ─────────────────────────

  Widget _buildSlide1Song() {
    return _slideFrame(
      visual: TagBox(
        label: 'scene #1',
        right: true,
        seed: 11,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SongArtBox(song: _sampleSong, size: 50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MIDNIGHT CITY', style: T.head(17), overflow: TextOverflow.ellipsis),
                      const Note('M83 · 4:04', size: 14),
                    ],
                  ),
                ),
                const SketchPlayIcon(playing: false, size: 22, color: Ink.ink),
              ],
            ),
            const SizedBox(height: 12),
            const DashedLine(),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.search, size: 16, color: Ink.soft),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'search YouTube Music...',
                    style: T.note(15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      title: 'ONE SONG A DAY',
      subtitle: 'pick one song that matches the mood of your day.',
    );
  }

  // ───────────────────────── Slide 2: Mood & Line ─────────────────────────

  Widget _buildSlide2Mood() {
    return _slideFrame(
      visual: TagBox(
        label: 'how does it feel?',
        seed: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SketchChip(label: 'hopeful', selected: true, seed: 1, onTap: () {}),
                SketchChip(label: 'dreamy', selected: false, seed: 2, onTap: () {}),
                SketchChip(label: 'restless', selected: false, seed: 3, onTap: () {}),
              ],
            ),
            const SizedBox(height: 14),
            const DashedLine(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '"walked home in the rain with this on repeat."',
                    style: T.note(16, c: Ink.ink),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit_outlined, size: 15, color: Ink.soft),
              ],
            ),
          ],
        ),
      ),
      title: 'TAG & SCRIBBLE',
      subtitle: 'choose a feeling pattern and jot down one quick line why.',
    );
  }

  // ───────────────────────── Slide 3: Calendar & Co-Stars ─────────────────────────

  Widget _buildSlide3CalendarAndFriends() {
    const days = ['M', 'T', 'W', 'T', 'F'];
    const hatches = [
      Hatch.diagonal,
      Hatch.dots,
      Hatch.waves,
      Hatch.cross,
      Hatch.diagonal,
    ];

    return _slideFrame(
      visual: TagBox(
        label: 'my soundtrack',
        right: true,
        seed: 33,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < days.length; i++)
                  Column(
                    children: [
                      Note(days[i], size: 13),
                      const SizedBox(height: 5),
                      HatchSwatch(hatches[i], size: 26, circle: true, gap: 3),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const DashedLine(),
            const SizedBox(height: 10),
            Row(
              children: [
                const HatchSwatch(Hatch.cross, size: 28, circle: true, gap: 3),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'jules · Motion Sickness',
                    style: T.body(14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SketchPlayIcon(playing: false, size: 16, color: Ink.ink),
              ],
            ),
          ],
        ),
      ),
      title: 'CALENDAR & CO-STARS',
      subtitle: 'watch your month fill with patterns and hear friends\' songs.',
    );
  }

  // ───────────────────────── Slide 4: Connect YouTube ─────────────────────────

  Widget _buildSlide4YouTube() {
    return ListenableBuilder(
      listenable: musicService,
      builder: (context, _) {
        final isConnected = musicService.isYouTubeConnected;

        return LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 330),
                    child: SketchBox(
                      seed: 44,
                      fill: isConnected ? const Color(0xFFEAF5EC) : Ink.paper,
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isConnected
                                ? Icons.check_circle_outline
                                : Icons.headphones_outlined,
                            size: 36,
                            color: isConnected
                                ? const Color(0xFF2E7D32)
                                : Ink.ink,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isConnected
                                ? 'YOUTUBE CONNECTED ✓'
                                : 'SEAMLESS MUSIC',
                            textAlign: TextAlign.center,
                            style: T.head(
                              24,
                              c: isConnected
                                  ? const Color(0xFF2E7D32)
                                  : Ink.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isConnected
                                ? 'bot checks bypassed — ready for smooth playback.'
                                : 'connect your YouTube account so songs play smoothly without bot checks.',
                            textAlign: TextAlign.center,
                            style: T.body(15, c: Ink.soft),
                          ),
                          const SizedBox(height: 20),
                          if (!isConnected)
                            SketchButton(
                              primary: true,
                              onTap: _connectYouTube,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: Center(
                                child: Text(
                                  'CONNECT YOUTUBE',
                                  style: T.head(15, c: Ink.paper),
                                ),
                              ),
                            )
                          else
                            SketchButton(
                              primary: true,
                              onTap: _finishAndEnter,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: Center(
                                child: Text(
                                  'START DIRECTING',
                                  style: T.head(15, c: Ink.paper),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!isConnected) ...[
                    const SizedBox(height: 22),
                    SketchTap(
                      onTap: _finishAndEnter,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'SKIP FOR NOW',
                              style: T.head(14).copyWith(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward,
                              size: 15,
                              color: Ink.ink,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: const Note(
                        'if you skip: you can still log & search songs, though audio playback may hit YouTube bot blocks. connect anytime in settings.',
                        size: 14,
                        align: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────── Bottom Nav ─────────────────────────

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            SketchTap(
              onTap: _prevPage,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back, size: 15, color: Ink.ink),
                    const SizedBox(width: 4),
                    Text('BACK', style: T.head(14)),
                  ],
                ),
              ),
            )
          else
            const SizedBox(width: 68),

          Row(
            children: List.generate(4, (index) {
              final isSelected = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isSelected ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isSelected ? Ink.ink : Ink.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          if (_currentPage < 3)
            SketchButton(
              primary: true,
              onTap: _nextPage,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('NEXT', style: T.head(14, c: Ink.paper)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 15, color: Ink.paper),
                ],
              ),
            )
          else
            const SizedBox(width: 68),
        ],
      ),
    );
  }
}
