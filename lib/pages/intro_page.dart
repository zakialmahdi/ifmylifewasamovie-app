import 'dart:async';
import 'package:flutter/material.dart' hide Ink;
import 'package:go_router/go_router.dart';

import '../services/youtube_music_service.dart';
import '../sketch.dart';
import '../state.dart';
import '../widgets/youtube_login_sheet.dart';

/// An interactive, sketchbook-themed carousel walkthrough explaining the core
/// concept of "If My Life Was A Movie" and providing an upfront YouTube session
/// bridge setup before entering the main home screen.
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    } else {
      _finishAndEnter();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  void _jumpToFinish() {
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
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
        showNote(context, 'YouTube session connected · bot blocks resolved ✓');
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
                  _buildSlideOne(),
                  _buildSlideTwo(),
                  _buildSlideThree(),
                  _buildSlideFour(),
                ],
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Top App Bar ─────────────────────────

  Widget _buildTopBar() {
    final actTitles = [
      'ACT I · THE CONCEPT',
      'ACT II · THE SOUNDTRACK',
      'ACT III · THE CAST & REEL',
      'FINALE · SEAMLESS SETUP',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (widget.isReplay)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Ink.ink),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              SketchBox(
                seed: 11,
                fill: Ink.paper,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  actTitles[_currentPage],
                  style: T.head(12, c: Ink.soft),
                ),
              ),
            ],
          ),
          if (_currentPage < 3 && !widget.isReplay)
            SketchTap(
              onTap: _jumpToFinish,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'SKIP TO SETUP',
                      style: T.head(12, c: Ink.soft).copyWith(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, size: 10, color: Ink.soft),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────────── Slide 1: Life is a Movie ─────────────────────────

  Widget _buildSlideOne() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Text(
              'YOUR LIFE IS A MOVIE',
              textAlign: TextAlign.center,
              style: T.head(28),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Note(
              'one song a day · one tiny scene · your personal cinema',
              size: 15,
            ),
          ),
          const SizedBox(height: 18),

          // Hand-drawn Clapperboard illustration
          SketchBox(
            seed: 71,
            fill: Ink.paper,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.movie_creation_outlined, size: 22, color: Ink.ink),
                        const SizedBox(width: 8),
                        Text('PRODUCTION REEL', style: T.head(15)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Ink.ink, width: 1.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('24 FPS', style: T.head(11)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const DashedLine(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SCENE', style: T.head(11, c: Ink.soft)),
                          Text('TODAY', style: T.head(18)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 28, color: Ink.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TAKE', style: T.head(11, c: Ink.soft)),
                          Text('01', style: T.head(18)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 28, color: Ink.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DIRECTOR', style: T.head(11, c: Ink.soft)),
                          Text(
                            app.name.isNotEmpty ? app.name.toUpperCase() : 'YOU',
                            style: T.head(18),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _buildBulletItem(
            icon: Icons.auto_stories_outlined,
            title: 'Cinematic Journaling',
            desc: 'Forget tedious checklists. Frame each day as an intentional scene in your unfolding story.',
          ),
          const SizedBox(height: 12),
          _buildBulletItem(
            icon: Icons.photo_camera_outlined,
            title: 'Visual Keepsakes',
            desc: 'Attach candid snapshots to capture the atmosphere and aesthetic of the moment.',
          ),
          const SizedBox(height: 12),
          _buildBulletItem(
            icon: Icons.draw_outlined,
            title: 'Hand-Drawn Sketch Interface',
            desc: 'Crafted with tactile paper, ink textures, and notebook margins for an intimate feel.',
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ───────────────────────── Slide 2: Soundtrack ─────────────────────────

  Widget _buildSlideTwo() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Text(
              'SCORE EVERY SCENE',
              textAlign: TextAlign.center,
              style: T.head(28),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Note(
              'music anchors memories deeper than plain words',
              size: 15,
            ),
          ),
          const SizedBox(height: 18),

          // Cassette / Vinyl illustration card
          SketchBox(
            seed: 82,
            fill: Ink.paper,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.album_outlined, size: 24, color: Ink.ink),
                    const SizedBox(width: 8),
                    Text('ORIGINAL MOTION PICTURE SOUNDTRACK', style: T.head(13)),
                  ],
                ),
                const SizedBox(height: 12),
                SketchBox(
                  seed: 83,
                  fill: Ink.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note, size: 20, color: Ink.ink),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TODAY\'S THEME SONG', style: T.head(13)),
                            const Note('YouTube Music · streaming directly in-app', size: 12),
                          ],
                        ),
                      ),
                      const Icon(Icons.play_circle_fill, size: 28, color: Ink.ink),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _buildBulletItem(
            icon: Icons.search,
            title: 'YouTube Music Search',
            desc: 'Find any song, artist, or soundtrack instantaneously without leaving the journal.',
          ),
          const SizedBox(height: 12),
          _buildBulletItem(
            icon: Icons.replay_outlined,
            title: 'Emotional Time Machine',
            desc: 'Tap play weeks or months later to instantly reignite the exact mood of that day.',
          ),
          const SizedBox(height: 12),
          _buildBulletItem(
            icon: Icons.queue_music_outlined,
            title: 'Your Life Playlist',
            desc: 'Build an evolving, living tracklist documenting the soundtrack of your years.',
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ───────────────────────── Slide 3: The Cast & Storyboard ─────────────────────────

  Widget _buildSlideThree() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Text(
              'THE CAST & TIMELINE',
              textAlign: TextAlign.center,
              style: T.head(28),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Note(
              'share the story with friends · lock your private thoughts',
              size: 15,
            ),
          ),
          const SizedBox(height: 18),

          // Sketch illustration card
          SketchBox(
            seed: 93,
            fill: Ink.paper,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMiniFeature(Icons.calendar_month_outlined, 'CALENDAR', 'Timeline history'),
                Container(width: 1, height: 42, color: Ink.grey),
                _buildMiniFeature(Icons.people_alt_outlined, 'THE CAST', 'Close friends'),
                Container(width: 1, height: 42, color: Ink.grey),
                _buildMiniFeature(Icons.lock_outline, 'PRIVACY', '4-digit PIN'),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _buildBulletItem(
            icon: Icons.calendar_today_outlined,
            title: 'Chronological Calendar',
            desc: 'Scrub through previous scenes and discover recurring moods, feelings, and musical arcs.',
          ),
          const SizedBox(height: 12),
          _buildBulletItem(
            icon: Icons.group_outlined,
            title: 'Friends (The Cast)',
            desc: 'Connect with close friends to see what songs and scenes are playing in their lives.',
          ),
          const SizedBox(height: 12),
          _buildBulletItem(
            icon: Icons.lock_outline,
            title: 'Privacy PIN Lock',
            desc: 'Enable a 4-digit security code in Settings to keep your intimate diary locked from prying eyes.',
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMiniFeature(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Ink.ink),
        const SizedBox(height: 4),
        Text(title, style: T.head(12)),
        Note(subtitle, size: 11),
      ],
    );
  }

  // ───────────────────────── Slide 4: YouTube Setup & Skip ─────────────────────────

  Widget _buildSlideFour() {
    return ListenableBuilder(
      listenable: musicService,
      builder: (context, _) {
        final isConnected = musicService.isYouTubeConnected;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'SEAMLESS PLAYBACK',
                  textAlign: TextAlign.center,
                  style: T.head(28),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Note(
                  'link YouTube for uninterrupted streaming & zero bot blocks',
                  size: 15,
                ),
              ),
              const SizedBox(height: 16),

              // Status Card
              SketchBox(
                seed: 104,
                fill: isConnected ? const Color(0xFFEAF5EC) : Ink.paper,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          isConnected ? Icons.check_circle_outline : Icons.link,
                          color: isConnected ? const Color(0xFF2E7D32) : Ink.ink,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isConnected
                                    ? 'YOUTUBE SESSION ACTIVE ✓'
                                    : 'CONNECT YOUTUBE ACCOUNT',
                                style: T.head(
                                  15,
                                  c: isConnected ? const Color(0xFF2E7D32) : Ink.ink,
                                ),
                              ),
                              Text(
                                isConnected
                                    ? 'Bot protection bypassed. You are ready for smooth playback.'
                                    : 'Takes 30 seconds via secure in-app Google sign in.',
                                style: T.body(13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (!isConnected)
                      SketchButton(
                        primary: true,
                        onTap: _connectYouTube,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.login, size: 18, color: Ink.paper),
                              const SizedBox(width: 8),
                              Text('CONNECT YOUTUBE ACCOUNT', style: T.head(14)),
                            ],
                          ),
                        ),
                      )
                    else
                      SketchButton(
                        primary: true,
                        onTap: _finishAndEnter,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.movie, size: 18, color: Ink.paper),
                              const SizedBox(width: 8),
                              Text('ENTER STUDIO · START DIRECTING', style: T.head(14)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // The Consequence / Skip Card (Crucial User Requirement)
              SketchBox(
                seed: 105,
                fill: Ink.bg,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.help_outline, size: 18, color: Ink.ink),
                        const SizedBox(width: 6),
                        Text('CAN I SKIP THIS STEP?', style: T.head(14)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Yes, you can skip and start using the app right away!',
                      style: T.body(14, FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const DashedLine(),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⚠️', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Consequence if you skip:',
                                style: T.head(12, c: const Color(0xFF9E4010)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'You can still search songs and write journal entries. However, YouTube will treat playback as an anonymous guest. Playback may occasionally freeze or fail with "Sign in to confirm you\'re not a bot" rate limits during heavy usage.',
                                style: T.body(13),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'You can always connect or disconnect anytime later under Settings ➔ YouTube Session Bridge.',
                                style: T.note(12, c: Ink.soft),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (!isConnected)
                      Center(
                        child: SketchTap(
                          onTap: _finishAndEnter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Ink.ink, width: 1.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('SKIP FOR NOW & ENTER APP', style: T.head(13)),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward, size: 14, color: Ink.ink),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ───────────────────────── Helper Item ─────────────────────────

  Widget _buildBulletItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Ink.ink, width: 1.2),
          ),
          child: Icon(icon, size: 18, color: Ink.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: T.head(15)),
              const SizedBox(height: 2),
              Text(desc, style: T.body(14)),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Bottom Navigation & Dots ─────────────────────────

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Ink.faint, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          if (_currentPage > 0)
            SketchTextButton(
              '◀ back',
              onTap: _prevPage,
            )
          else
            const SizedBox(width: 60),

          // Dots Indicator
          Row(
            children: List.generate(4, (index) {
              final isSelected = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isSelected ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isSelected ? Ink.ink : Ink.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          // Next / Finish button
          if (_currentPage < 3)
            SketchButton(
              primary: true,
              onTap: _nextPage,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('NEXT', style: T.head(13)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 14, color: Ink.paper),
                ],
              ),
            )
          else
            SketchButton(
              primary: true,
              onTap: _finishAndEnter,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ENTER 🎬', style: T.head(13)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
