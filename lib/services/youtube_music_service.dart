import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../state.dart';

/// Isolate-safe parser for the iTunes Search API JSON payload.
/// Produces clean track titles, clean artist names, exact durations,
/// high-quality 1:1 square album artwork (`600x600bb`), and instant iTunes
/// AAC song preview URLs (`previewUrl`).
List<Song> _parseITunesSongs(String responseBody) {
  final decoded = jsonDecode(responseBody);
  if (decoded is! Map<String, dynamic>) return const <Song>[];
  final rawList = decoded['results'];
  if (rawList is! List) return const <Song>[];

  const artOptions = <Hatch>[
    Hatch.diagonal,
    Hatch.cross,
    Hatch.dots,
    Hatch.lines,
  ];

  final seen = <String>{};
  final out = <Song>[];

  for (final raw in rawList) {
    if (raw is! Map<String, dynamic>) continue;
    final title = (raw['trackName'] as String?)?.trim() ?? '';
    final artist = (raw['artistName'] as String?)?.trim() ?? '';
    if (title.isEmpty || artist.isEmpty) continue;

    final dedupKey = '${title.toLowerCase()}|${artist.toLowerCase()}';
    if (!seen.add(dedupKey)) continue;

    final millis = (raw['trackTimeMillis'] as num?)?.toInt() ?? 180000;
    final seconds = (millis / 1000).round().clamp(1, 7200);
    final trackId = (raw['trackId'] as num?)?.toInt() ?? dedupKey.hashCode;
    final hatch = artOptions[trackId.abs() % artOptions.length];

    final rawArt = (raw['artworkUrl100'] as String?)?.trim();
    final squareCover = (rawArt != null && rawArt.isNotEmpty)
        ? rawArt.replaceAll(RegExp(r'\d+x\d+bb'), '600x600bb')
        : null;

    final rawPreview = (raw['previewUrl'] as String?)?.trim();
    final previewUrl =
        (rawPreview != null && rawPreview.isNotEmpty) ? rawPreview : null;

    out.add(
      Song(
        title,
        artist,
        seconds,
        hatch,
        coverUrl: squareCover,
        previewUrl: previewUrl,
      ),
    );
  }

  return out;
}

List<Song> _parseDeezerSongs(String rawBody) {
  final decoded = jsonDecode(rawBody);
  if (decoded is! Map<String, dynamic>) return const <Song>[];
  final rawList = decoded['data'];
  if (rawList is! List) return const <Song>[];

  const artOptions = <Hatch>[
    Hatch.diagonal,
    Hatch.cross,
    Hatch.dots,
    Hatch.lines,
  ];

  final seen = <String>{};
  final out = <Song>[];

  for (final raw in rawList) {
    if (raw is! Map<String, dynamic>) continue;
    final title = (raw['title'] as String?)?.trim() ?? '';
    final artist = (raw['artist'] is Map
            ? (raw['artist']['name'] as String?)
            : null)
            ?.trim() ??
        '';
    if (title.isEmpty || artist.isEmpty) continue;

    final dedupKey = '${title.toLowerCase()}|${artist.toLowerCase()}';
    if (!seen.add(dedupKey)) continue;

    final seconds =
        ((raw['duration'] as num?)?.toInt() ?? 180).clamp(1, 7200);
    final trackId = (raw['id'] as num?)?.toInt() ?? dedupKey.hashCode;
    final hatch = artOptions[trackId.abs() % artOptions.length];

    final album = raw['album'];
    String? coverUrl;
    if (album is Map) {
      final xl = (album['cover_xl'] as String?)?.trim();
      final big = (album['cover_big'] as String?)?.trim();
      final medium = (album['cover_medium'] as String?)?.trim();
      coverUrl = (xl != null && xl.isNotEmpty)
          ? xl
          : ((big != null && big.isNotEmpty)
              ? big
              : ((medium != null && medium.isNotEmpty) ? medium : null));
    }

    final rawPreview = (raw['preview'] as String?)?.trim();
    final previewUrl =
        (rawPreview != null && rawPreview.isNotEmpty) ? rawPreview : null;

    out.add(
      Song(
        title,
        artist,
        seconds,
        hatch,
        coverUrl: coverUrl,
        previewUrl: previewUrl,
      ),
    );
  }

  return out;
}

enum CoverArtState {
  ready,
  loading,
  unavailable,
}

/// Custom YouTube HTTP client that attaches the user's authenticated Google/YouTube
/// session cookies (`LOGIN_INFO`, `SID`, `VISITOR_INFO1_LIVE`) to all Innertube
/// requests, bypassing rate limits and bot-detection blocks (`RequestLimitExceededException`).
class AuthenticatedYoutubeClient extends YoutubeHttpClient {
  final String cookieHeader;

  AuthenticatedYoutubeClient(String rawCookies, [super.httpClient])
      : cookieHeader = rawCookies.replaceAll(RegExp(r'[\r\n]'), ' ').trim();

  @override
  Map<String, String> get headers => <String, String>{
        ...super.headers,
        'cookie': cookieHeader,
        'user-agent':
            'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['cookie'] = cookieHeader;
    request.headers['user-agent'] =
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
    return super.send(request);
  }
}

class YouTubeMusicService extends ChangeNotifier {
  YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _player = AudioPlayer();
  final http.Client _http = http.Client();
  String? _youtubeCookies;

  bool get isYouTubeConnected =>
      _youtubeCookies != null && _youtubeCookies!.isNotEmpty;

  static final List<List<YoutubeApiClient>> _clientFallbacks =
      <List<YoutubeApiClient>>[
    <YoutubeApiClient>[YoutubeApiClient.androidSdkless],
    <YoutubeApiClient>[YoutubeApiClient.android],
  ];

  final Map<String, ({Uri url, DateTime fetchedAt})> _streamCache =
      <String, ({Uri url, DateTime fetchedAt})>{};
  final Map<String, String> _lookupVideoIdCache = <String, String>{};
  final Map<String, Future<String>> _inFlightLookups =
      <String, Future<String>>{};
  final Map<String, ({String? coverUrl, String? previewUrl})> _itunesMetaCache =
      <String, ({String? coverUrl, String? previewUrl})>{};
  final Set<String> _attemptedITunesMetaKeys = <String>{};
  final Set<String> _confirmedNoCoverKeys = <String>{};
  final Map<String, Future<({String? coverUrl, String? previewUrl})?>>
      _inFlightITunesMeta =
      <String, Future<({String? coverUrl, String? previewUrl})?>>{};
  int _activeBgMetaFetches = 0;
  final List<Song> _bgMetaQueue = <Song>[];

  final Map<String, String> _localFileByVideoId = <String, String>{};
  final Map<String, Future<File?>> _inFlightDownloads =
      <String, Future<File?>>{};

  Directory? _cacheDir;
  Future<void>? _cacheInitFuture;
  Future<void>? _cookieInitFuture;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<ProcessingState>? _processingStateSub;
  int _activeRequestToken = 0;

  Song? currentSong;
  bool isPreviewPlayback = false;
  bool isLoadingStream = false;
  bool isCachingCurrent = false;
  String? playbackError;
  void Function(Song)? onPlaybackSongChanged;

  YouTubeMusicService() {
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
      notifyListeners();
    });

    // Optimistic Audio UI: notify immediately on buffering / loading / ready transitions.
    _processingStateSub = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.ready && isLoadingStream) {
        isLoadingStream = false;
      }
      notifyListeners();
    });

    if (!kIsWeb) {
      _cacheInitFuture = _initLocalCacheIndex();
      _cookieInitFuture = _loadYouTubeCookies();
    }
  }

  AudioPlayer get player => _player;
  bool get isPlaying => _player.playing;
  ProcessingState get processingState => _player.processingState;

  /// True while resolving an audio source OR while `just_audio` is buffering/loading.
  bool get isBuffering =>
      isLoadingStream ||
      _player.processingState == ProcessingState.loading ||
      _player.processingState == ProcessingState.buffering;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  static String _songLookupKey(Song song) =>
      '${song.artist.trim().toLowerCase()}|${song.title.trim().toLowerCase()}';

  static String _normToken(String raw) =>
      raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String _sanitizeFileStem(String raw) =>
      raw.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');

  static const String _mobilePlaybackUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  static const Map<String, String> _browserHeaders = <String, String>{
    'User-Agent': _mobilePlaybackUserAgent,
    'Accept': '*/*',
  };

  static const Map<String, String> _audioPlaybackHeaders = <String, String>{
    'User-Agent': _mobilePlaybackUserAgent,
    'Accept': '*/*',
  };

  /// Detects legacy 16:9 YouTube video thumbnail URLs so they are never used
  /// in place of 1:1 iTunes album artwork.
  static bool isYouTubeThumbnail(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('img.youtube.com') || lower.contains('ytimg.com');
  }

  /// Returns the 1:1 square iTunes album cover URL for [song] if known,
  /// ignoring any YouTube video thumbnails.
  String? albumCoverFor(Song song) {
    final direct = song.coverUrl?.trim();
    if (direct != null && direct.isNotEmpty && !isYouTubeThumbnail(direct)) {
      return direct;
    }
    final cached = _itunesMetaCache[_songLookupKey(song)]?.coverUrl;
    if (cached != null && cached.isNotEmpty && !isYouTubeThumbnail(cached)) {
      return cached;
    }
    return null;
  }

  /// Reports whether [song] has a 1:1 iTunes cover ready, is still resolving
  /// against the iTunes API, or was confirmed to have no cover in iTunes.
  CoverArtState coverStateFor(Song song) {
    if (albumCoverFor(song) != null) return CoverArtState.ready;
    if (_confirmedNoCoverKeys.contains(_songLookupKey(song))) {
      return CoverArtState.unavailable;
    }
    return CoverArtState.loading;
  }

  /// Returns the iTunes 30s AAC preview URL for [song] if already resolved.
  String? previewUrlFor(Song song) {
    final direct = song.previewUrl?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    return _itunesMetaCache[_songLookupKey(song)]?.previewUrl;
  }

  bool isCurrentSong(Song song) {
    final cur = currentSong;
    if (cur == null) return false;
    if (cur.videoId != null &&
        cur.videoId!.isNotEmpty &&
        song.videoId != null &&
        song.videoId!.isNotEmpty) {
      return cur.videoId == song.videoId;
    }
    return cur.title.toLowerCase() == song.title.toLowerCase() &&
        cur.artist.toLowerCase() == song.artist.toLowerCase();
  }

  /// Synchronous check for whether [song] is already saved on device for 0ms offline playback.
  bool isCachedLocally(Song song) {
    if (kIsWeb) return false;
    final vid = (song.videoId != null && song.videoId!.isNotEmpty)
        ? song.videoId!
        : _lookupVideoIdCache[_songLookupKey(song)];
    if (vid == null || vid.isEmpty) return false;
    return _localFileByVideoId.containsKey(_sanitizeFileStem(vid));
  }

  // ───────────────────────── 1. Dual-Engine Catalog Search (iTunes MY + Deezer) ─────────────────────────

  /// Searches track catalog using iTunes (Malaysia storefront) with automatic
  /// Deezer fallback for comprehensive Malaysian & regional Southeast Asian coverage.
  Future<List<Song>> searchMusic(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const <Song>[];

    // 1. Primary: iTunes Search API targeting Malaysia storefront (country=MY)
    try {
      final itunes = await searchITunes(clean, country: 'MY');
      if (itunes.isNotEmpty) return itunes;
    } catch (_) {}

    // 2. Secondary: Deezer Public API (extensive Southeast Asian & local Malaysian tracks)
    try {
      final deezer = await searchDeezer(clean);
      if (deezer.isNotEmpty) return deezer;
    } catch (_) {}

    // 3. Fallback: iTunes US storefront in case an international song is storefront-locked
    try {
      final itunesUS = await searchITunes(clean, country: 'US');
      if (itunesUS.isNotEmpty) return itunesUS;
    } catch (_) {}

    return const <Song>[];
  }

  /// Queries Apple's free, key-less iTunes Search API for studio-clean track metadata,
  /// 1:1 album artwork, and `previewUrl`s. Defaults to [country] = 'MY'.
  Future<List<Song>> searchITunes(String query, {String country = 'MY'}) async {
    final clean = query.trim();
    if (clean.isEmpty) return const <Song>[];

    final uri = Uri.https('itunes.apple.com', '/search', <String, String>{
      'term': clean,
      'country': country,
      'media': 'music',
      'entity': 'song',
      'limit': '25',
    });

    final response = await _http.get(
      uri,
      headers: const <String, String>{
        HttpHeaders.acceptHeader: 'application/json',
        HttpHeaders.userAgentHeader:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      },
    ).timeout(const Duration(seconds: 6));

    if (response.statusCode == 429) {
      // Rate limited by iTunes API: return empty to let fallback provider handle it
      return const <Song>[];
    }

    if (response.statusCode != 200) {
      throw HttpException(
        'iTunes Search API returned status ${response.statusCode}',
        uri: uri,
      );
    }

    final parsed = await compute(_parseITunesSongs, response.body);
    var changed = false;
    var stateChanged = false;
    for (final s in parsed) {
      final key = _songLookupKey(s);
      _attemptedITunesMetaKeys.add(key);
      if (s.coverUrl == null || s.coverUrl!.isEmpty) {
        if (_confirmedNoCoverKeys.add(key)) stateChanged = true;
      } else {
        if (_confirmedNoCoverKeys.remove(key)) stateChanged = true;
      }
      if (!_itunesMetaCache.containsKey(key) &&
          (s.coverUrl != null || s.previewUrl != null)) {
        _itunesMetaCache[key] =
            (coverUrl: s.coverUrl, previewUrl: s.previewUrl);
        changed = true;
        stateChanged = true;
      }
    }
    if (changed) {
      unawaited(_persistITunesMetaIndex());
    }
    if (stateChanged) {
      notifyListeners();
    }
    return parsed;
  }

  /// Queries Deezer's key-less public API for Southeast Asian and Malaysian tracks
  /// with 1:1 high-res artwork (`cover_xl` / `cover_big`) and 30s MP3 audio previews.
  Future<List<Song>> searchDeezer(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const <Song>[];

    final uri = Uri.https('api.deezer.com', '/search', <String, String>{
      'q': clean,
      'limit': '25',
    });

    final response = await _http.get(
      uri,
      headers: const <String, String>{
        HttpHeaders.acceptHeader: 'application/json',
        HttpHeaders.userAgentHeader:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      },
    ).timeout(const Duration(seconds: 6));

    if (response.statusCode == 429) {
      return const <Song>[];
    }

    if (response.statusCode != 200) {
      throw HttpException(
        'Deezer Search API returned status ${response.statusCode}',
        uri: uri,
      );
    }

    final parsed = await compute(_parseDeezerSongs, response.body);
    var changed = false;
    var stateChanged = false;
    for (final s in parsed) {
      final key = _songLookupKey(s);
      _attemptedITunesMetaKeys.add(key);
      if (s.coverUrl == null || s.coverUrl!.isEmpty) {
        if (_confirmedNoCoverKeys.add(key)) stateChanged = true;
      } else {
        if (_confirmedNoCoverKeys.remove(key)) stateChanged = true;
      }
      if (!_itunesMetaCache.containsKey(key) &&
          (s.coverUrl != null || s.previewUrl != null)) {
        _itunesMetaCache[key] =
            (coverUrl: s.coverUrl, previewUrl: s.previewUrl);
        changed = true;
        stateChanged = true;
      }
    }
    if (changed) {
      unawaited(_persistITunesMetaIndex());
    }
    if (stateChanged) {
      notifyListeners();
    }
    return parsed;
  }

  /// Non-blocking background helper called by UI widgets (`SongArtBox`) when a
  /// seed/saved [song] doesn't yet have its 1:1 iTunes album cover cached.
  /// Never calls `notifyListeners()` synchronously during widget build.
  void ensureITunesMetadata(Song song) {
    if (albumCoverFor(song) != null) return;
    final key = _songLookupKey(song);
    if (_attemptedITunesMetaKeys.contains(key)) return;
    _attemptedITunesMetaKeys.add(key);

    _bgMetaQueue.add(song);
    _pumpBgMetaQueue();
  }

  void _pumpBgMetaQueue() {
    while (_activeBgMetaFetches < 4 && _bgMetaQueue.isNotEmpty) {
      final next = _bgMetaQueue.removeAt(0);
      _activeBgMetaFetches++;
      unawaited(
        fetchITunesMetadata(next).whenComplete(() {
          _activeBgMetaFetches--;
          _pumpBgMetaQueue();
        }),
      );
    }
  }

  /// Resolves 1:1 square album cover (`600x600bb`) and `previewUrl` from iTunes
  /// for a specific [song] (`"${song.title} ${song.artist}"`).
  Future<({String? coverUrl, String? previewUrl})?> fetchITunesMetadata(
    Song song,
  ) async {
    await _ensureCacheInitialized();

    final directCover = albumCoverFor(song);
    final directPreview = previewUrlFor(song);
    if (directCover != null && directPreview != null) {
      return (coverUrl: directCover, previewUrl: directPreview);
    }

    final key = _songLookupKey(song);
    final cached = _itunesMetaCache[key];
    if (cached != null &&
        cached.coverUrl != null &&
        cached.previewUrl != null) {
      return cached;
    }

    final inFlight = _inFlightITunesMeta[key];
    if (inFlight != null) return inFlight;

    final future = () async {
      try {
        List<Song> matches = const <Song>[];

        // 1. Try iTunes targeting Malaysia storefront (country=MY)
        try {
          final uri = Uri.https('itunes.apple.com', '/search', <String, String>{
            'term': '${song.title} ${song.artist}',
            'country': 'MY',
            'media': 'music',
            'entity': 'song',
            'limit': '5',
          });

          final response = await _http.get(
            uri,
            headers: const <String, String>{
              HttpHeaders.acceptHeader: 'application/json',
            },
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            matches = await compute(_parseITunesSongs, response.body);
          }
        } catch (_) {}

        // 2. Fall back to Deezer if iTunes Malaysia returned no matches
        if (matches.isEmpty) {
          try {
            final deezerUri =
                Uri.https('api.deezer.com', '/search', <String, String>{
              'q': '${song.title} ${song.artist}',
              'limit': '5',
            });

            final response = await _http.get(
              deezerUri,
              headers: const <String, String>{
                HttpHeaders.acceptHeader: 'application/json',
              },
            ).timeout(const Duration(seconds: 5));

            if (response.statusCode == 200) {
              matches = await compute(_parseDeezerSongs, response.body);
            }
          } catch (_) {}
        }

        // 3. Fall back to iTunes US storefront if still empty
        if (matches.isEmpty) {
          try {
            final uriUS =
                Uri.https('itunes.apple.com', '/search', <String, String>{
              'term': '${song.title} ${song.artist}',
              'country': 'US',
              'media': 'music',
              'entity': 'song',
              'limit': '5',
            });

            final response = await _http.get(
              uriUS,
              headers: const <String, String>{
                HttpHeaders.acceptHeader: 'application/json',
              },
            ).timeout(const Duration(seconds: 5));

            if (response.statusCode == 200) {
              matches = await compute(_parseITunesSongs, response.body);
            }
          } catch (_) {}
        }

        if (matches.isEmpty) {
          if (directCover == null && cached?.coverUrl == null) {
            _confirmedNoCoverKeys.add(key);
            notifyListeners();
          }
          return cached;
        }

        final targetArtist = _normToken(song.artist);
        final targetTitle = _normToken(song.title);

        Song? best;
        for (final m in matches) {
          final a = _normToken(m.artist);
          final t = _normToken(m.title);
          final artistMatches = targetArtist.isEmpty ||
              a == targetArtist ||
              a.contains(targetArtist) ||
              targetArtist.contains(a);
          final titleMatches = targetTitle.isEmpty ||
              t == targetTitle ||
              t.contains(targetTitle) ||
              targetTitle.contains(t);
          if (artistMatches && titleMatches && m.coverUrl != null) {
            best = m;
            break;
          }
        }

        best ??= matches.where((m) {
          if (m.coverUrl == null) return false;
          final a = _normToken(m.artist);
          return targetArtist.isNotEmpty &&
              (a.contains(targetArtist) || targetArtist.contains(a));
        }).firstOrNull;

        final finalCover = best?.coverUrl ?? directCover;
        final finalPreview = best?.previewUrl ?? directPreview;

        if (finalCover == null || finalCover.isEmpty) {
          _confirmedNoCoverKeys.add(key);
          notifyListeners();
          return cached;
        }

        _confirmedNoCoverKeys.remove(key);
        final resolved = (coverUrl: finalCover, previewUrl: finalPreview);
        _itunesMetaCache[key] = resolved;
        _attemptedITunesMetaKeys.add(key);
        unawaited(_persistITunesMetaIndex());
        notifyListeners();
        return resolved;
      } catch (_) {
        if (directCover == null && cached?.coverUrl == null) {
          _confirmedNoCoverKeys.add(key);
          notifyListeners();
        }
        return cached;
      }
    }();

    _inFlightITunesMeta[key] = future;
    try {
      return await future;
    } finally {
      _inFlightITunesMeta.remove(key);
    }
  }

  /// Plays or pauses the iTunes 30-second AAC preview (`previewUrl`) when
  /// browsing/searching tracks inside `SongPicker`.
  Future<void> togglePreview(Song song) async {
    if (isCurrentSong(song) &&
        isPreviewPlayback &&
        !isLoadingStream &&
        playbackError == null) {
      if (_player.playing) {
        await _player.pause();
      } else {
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        unawaited(_player.play());
      }
      notifyListeners();
      return;
    }

    final token = ++_activeRequestToken;
    currentSong = song;
    isPreviewPlayback = true;
    isLoadingStream = true;
    playbackError = null;
    notifyListeners();

    try {
      await _ensureCacheInitialized();
      await _player.stop();
      if (token != _activeRequestToken) return;

      var previewUrl = previewUrlFor(song);
      var coverUrl = albumCoverFor(song);
      if (previewUrl == null || previewUrl.isEmpty) {
        final meta = await fetchITunesMetadata(song);
        if (token != _activeRequestToken) return;
        previewUrl = meta?.previewUrl;
        coverUrl ??= meta?.coverUrl;
      }

      if (previewUrl == null || previewUrl.isEmpty) {
        throw StateError('No iTunes preview available for this song.');
      }

      currentSong = song.copyWith(
        coverUrl: coverUrl,
        previewUrl: previewUrl,
      );

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(previewUrl),
          headers: _browserHeaders,
        ),
      );
      if (token != _activeRequestToken) {
        try {
          await _player.stop();
        } catch (_) {}
        return;
      }

      isLoadingStream = false;
      notifyListeners();
      unawaited(_player.play());
    } on PlayerException catch (e) {
      if (token != _activeRequestToken) return;
      isLoadingStream = false;
      playbackError = 'preview unavailable (${e.message ?? e.code})';
      notifyListeners();
    } on SocketException catch (_) {
      if (token != _activeRequestToken) return;
      isLoadingStream = false;
      playbackError = 'network error – check your connection.';
      notifyListeners();
    } on TimeoutException catch (_) {
      if (token != _activeRequestToken) return;
      isLoadingStream = false;
      playbackError = 'preview timed out – please retry.';
      notifyListeners();
    } catch (_) {
      if (token != _activeRequestToken) return;
      isLoadingStream = false;
      playbackError = 'no preview clip available for this track.';
      notifyListeners();
    }
  }

  /// Invisible background resolver: maps a clean iTunes/catalog [Song] to its best
  /// YouTube full-length audio `videoId` (`"${artist} - ${title} official audio"`).
  Future<String> resolveVideoId(Song song) async {
    await _ensureCacheInitialized();

    final existing = song.videoId?.trim();
    if (existing != null && existing.isNotEmpty) {
      _rememberLookup(song, existing);
      return existing;
    }

    final cacheKey = _songLookupKey(song);
    final memHit = _lookupVideoIdCache[cacheKey];
    if (memHit != null && memHit.isNotEmpty) {
      return memHit;
    }

    final pending = _inFlightLookups[cacheKey];
    if (pending != null) {
      return pending;
    }

    final future = () async {
      final ytQuery = '${song.artist} - ${song.title} official audio';
      var ytResults = await _yt.search.search(ytQuery);
      var candidates = ytResults.where((v) => !v.isLive).toList();

      if (candidates.isEmpty) {
        ytResults =
            await _yt.search.search('${song.artist} ${song.title} audio');
        candidates = ytResults.where((v) => !v.isLive).toList();
      }
      if (candidates.isEmpty) {
        ytResults =
            await _yt.search.search('${song.artist} ${song.title}');
        candidates = ytResults.where((v) => !v.isLive).toList();
      }
      if (candidates.isEmpty) {
        final cleanTitle = song.title
            .replaceAll(
              RegExp(
                r'\(feat\.[^)]*\)|\[feat\.[^\]]*\]|\(with[^)]*\)',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
        if (cleanTitle != song.title && cleanTitle.isNotEmpty) {
          ytResults = await _yt.search.search('${song.artist} $cleanTitle');
          candidates = ytResults.where((v) => !v.isLive).toList();
        }
      }
      if (candidates.isEmpty) {
        throw StateError('No matching audio stream found on YouTube.');
      }

      // Prefer a track whose duration closely matches the studio duration so we
      // skip shorts, teasers, or 1-hour loops.
      Video chosen = candidates.first;
      if (song.seconds > 0) {
        for (final v in candidates.take(6)) {
          final d = v.duration?.inSeconds;
          if (d != null && (d - song.seconds).abs() <= 35) {
            chosen = v;
            break;
          }
        }
      }

      final vid = chosen.id.value;
      _rememberLookup(song, vid);
      return vid;
    }();

    _inFlightLookups[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inFlightLookups.remove(cacheKey);
    }
  }

  /// Resolves [song]'s 1:1 iTunes album cover + YouTube `videoId` in the
  /// background AND caches the full audio file locally on disk so subsequent
  /// Calendar visits play in 0ms offline. Never uses YouTube video thumbnails.
  Future<Song> prepareAndCacheSong(Song song) async {
    String? resolvedCover = albumCoverFor(song);
    String? resolvedPreview = previewUrlFor(song);

    if (resolvedCover == null) {
      final meta = await fetchITunesMetadata(song);
      resolvedCover = meta?.coverUrl;
      resolvedPreview ??= meta?.previewUrl;
    }

    try {
      final videoId = await resolveVideoId(song);
      unawaited(cacheSongLocally(videoId));
      return song.copyWith(
        videoId: videoId,
        coverUrl: resolvedCover,
        previewUrl: resolvedPreview,
      );
    } catch (_) {
      return song.copyWith(
        coverUrl: resolvedCover,
        previewUrl: resolvedPreview,
      );
    }
  }

  // ── YouTube Authenticated Session Bridge ──

  Future<void> _loadYouTubeCookies() async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File(p.join(docs.path, 'youtube_cookies.json'));
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          final cookies = decoded['cookies'] as String?;
          if (cookies != null && cookies.isNotEmpty) {
            _youtubeCookies = cookies;
            _yt = YoutubeExplode(
              httpClient: AuthenticatedYoutubeClient(cookies),
            );
            notifyListeners();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> connectYouTube(String cookies) async {
    _youtubeCookies = cookies;
    _yt = YoutubeExplode(
      httpClient: AuthenticatedYoutubeClient(cookies),
    );
    _streamCache.clear();
    notifyListeners();
    if (!kIsWeb) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final file = File(p.join(docs.path, 'youtube_cookies.json'));
        await file.writeAsString(
          jsonEncode(<String, dynamic>{
            'cookies': cookies,
            'connectedAt': DateTime.now().millisecondsSinceEpoch,
          }),
          flush: true,
        );
      } catch (_) {}
    }
  }

  Future<void> disconnectYouTube() async {
    _youtubeCookies = null;
    _yt = YoutubeExplode();
    _streamCache.clear();
    notifyListeners();
    if (!kIsWeb) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final file = File(p.join(docs.path, 'youtube_cookies.json'));
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  // ───────────────────────── 2. Local Audio Caching (0ms Offline Playback) ─────────────────────────

  Future<void> _ensureCacheInitialized() async {
    if (kIsWeb) return;
    await (_cacheInitFuture ??= _initLocalCacheIndex());
    await (_cookieInitFuture ??= _loadYouTubeCookies());
  }

  Future<void> _initLocalCacheIndex() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'audio_cache'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;

      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final ext = p.extension(entity.path).toLowerCase();
        final base = p.basename(entity.path);
        if (ext == '.part') {
          try {
            await entity.delete();
          } catch (_) {}
          continue;
        }
        if (ext == '.m4a' || ext == '.webm' || ext == '.mp4') {
          final stem = p.basenameWithoutExtension(entity.path);
          if (stem.isNotEmpty) {
            _localFileByVideoId[stem] = entity.path;
          }
        } else if (base == 'index.json') {
          try {
            final raw = await entity.readAsString();
            final map = jsonDecode(raw);
            if (map is Map<String, dynamic>) {
              map.forEach((k, v) {
                if (v is String && v.isNotEmpty) {
                  _lookupVideoIdCache[k] = v;
                }
              });
            }
          } catch (_) {}
        } else if (base == 'itunes_meta.json') {
          try {
            final raw = await entity.readAsString();
            final map = jsonDecode(raw);
            if (map is Map<String, dynamic>) {
              map.forEach((k, v) {
                if (v is Map<String, dynamic>) {
                  final rawC = v['coverUrl'] as String?;
                  final c = (rawC != null &&
                          rawC.isNotEmpty &&
                          !isYouTubeThumbnail(rawC))
                      ? rawC
                      : null;
                  final pr = v['previewUrl'] as String?;
                  if (c != null || pr != null) {
                    _itunesMetaCache[k] = (coverUrl: c, previewUrl: pr);
                    if (c != null) {
                      _attemptedITunesMetaKeys.add(k);
                    }
                  }
                }
              });
            }
          } catch (_) {}
        }
      }
      notifyListeners();
    } catch (_) {
      // Keep working in streaming-only mode if filesystem is unavailable.
    }
  }

  void _rememberLookup(Song song, String videoId) {
    final key = _songLookupKey(song);
    if (_lookupVideoIdCache[key] == videoId) return;
    _lookupVideoIdCache[key] = videoId;
    unawaited(_persistLookupIndex());
  }

  Future<void> _persistLookupIndex() async {
    if (kIsWeb || _cacheDir == null) return;
    try {
      final file = File(p.join(_cacheDir!.path, 'index.json'));
      await file.writeAsString(jsonEncode(_lookupVideoIdCache), flush: true);
    } catch (_) {}
  }

  Future<void> _persistITunesMetaIndex() async {
    if (kIsWeb || _cacheDir == null) return;
    try {
      final serializable = <String, Map<String, String?>>{};
      _itunesMetaCache.forEach((k, v) {
        serializable[k] = <String, String?>{
          'coverUrl': v.coverUrl,
          'previewUrl': v.previewUrl,
        };
      });
      final file = File(p.join(_cacheDir!.path, 'itunes_meta.json'));
      await file.writeAsString(jsonEncode(serializable), flush: true);
    } catch (_) {}
  }

  Future<File?> _findCachedFile(String videoId) async {
    if (kIsWeb) return null;
    await _ensureCacheInitialized();
    final safeId = _sanitizeFileStem(videoId);
    if (safeId.isEmpty) return null;

    final indexedPath = _localFileByVideoId[safeId];
    if (indexedPath != null) {
      final f = File(indexedPath);
      if (await f.exists() && await f.length() > 0) {
        return f;
      }
      _localFileByVideoId.remove(safeId);
    }

    final dir = _cacheDir;
    if (dir == null) return null;
    for (final ext in const <String>['.m4a', '.webm', '.mp4']) {
      final candidate = File(p.join(dir.path, '$safeId$ext'));
      if (await candidate.exists() && await candidate.length() > 0) {
        _localFileByVideoId[safeId] = candidate.path;
        return candidate;
      }
    }
    return null;
  }

  /// Downloads and caches the audio stream for [videoId] into the app's local
  /// documents directory (`audio_cache/<videoId>.m4a` or `.webm`).
  /// If already downloaded, returns the local [File] immediately (0ms delay).
  Future<File?> cacheSongLocally(
    String videoId, {
    String? fileName,
  }) async {
    if (kIsWeb) return null;
    await _ensureCacheInitialized();

    final safeId = _sanitizeFileStem(fileName ?? videoId);
    if (safeId.isEmpty || _cacheDir == null) return null;

    final existing = await _findCachedFile(safeId);
    if (existing != null) return existing;

    final activeDownload = _inFlightDownloads[safeId];
    if (activeDownload != null) return activeDownload;

    final downloadFuture = () async {
      if (currentSong?.videoId == videoId) {
        isCachingCurrent = true;
        notifyListeners();
      }

      try {
        for (final clients in _clientFallbacks) {
          StreamManifest manifest;
          try {
            manifest = await _yt.videos.streamsClient.getManifest(
              videoId,
              ytClients: clients,
            );
          } catch (_) {
            continue;
          }

          final candidates = _orderedCandidateStreams(
            manifest,
            forFileCache: true,
          );

          for (final streamInfo in candidates) {
            final ext =
                streamInfo.container == StreamContainer.mp4 ? 'm4a' : 'webm';
            final finalPath = p.join(_cacheDir!.path, '$safeId.$ext');
            final partFile = File('$finalPath.part');

            IOSink? sink;
            try {
              if (await partFile.exists()) {
                await partFile.delete();
              }
              final audioStream = _yt.videos.streamsClient.get(streamInfo);
              sink = partFile.openWrite();
              await audioStream.pipe(sink);
              await sink.flush();
              await sink.close();
              sink = null;

              if (await partFile.exists() && await partFile.length() > 1024) {
                final savedFile = await partFile.rename(finalPath);
                _localFileByVideoId[safeId] = savedFile.path;
                notifyListeners();
                return savedFile;
              }
            } catch (_) {
              try {
                await sink?.close();
              } catch (_) {}
              try {
                if (await partFile.exists()) {
                  await partFile.delete();
                }
              } catch (_) {}
            }
          }
        }
        return null;
      } finally {
        if (currentSong?.videoId == videoId) {
          isCachingCurrent = false;
          notifyListeners();
        }
      }
    }();

    _inFlightDownloads[safeId] = downloadFuture;
    try {
      return await downloadFuture;
    } finally {
      _inFlightDownloads.remove(safeId);
    }
  }

  // ───────────────────────── 3. Full-Track Playback & 403 Stream Fallback ─────────────────────────

  Future<void> playSong(String videoId) async {
    final token = ++_activeRequestToken;
    isPreviewPlayback = false;
    await _loadSourceWithFallback(videoId, token);
    if (token != _activeRequestToken) return;
    unawaited(_player.play());
  }

  /// Plays or pauses the full-length [song] with Optimistic Audio UI, 0ms local
  /// file cache lookup (`AudioSource.file`), and multi-codec / multi-client 403
  /// fallback. Album cover always comes from 1:1 iTunes artwork, never YouTube.
  Future<void> togglePlay(Song song) async {
    if (isCurrentSong(song) &&
        !isPreviewPlayback &&
        !isLoadingStream &&
        playbackError == null) {
      if (_player.playing) {
        await _player.pause();
      } else {
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        unawaited(_player.play());
      }
      notifyListeners();
      return;
    }

    // Optimistic Audio UI: acknowledge tap synchronously (0ms) before any async work.
    final token = ++_activeRequestToken;
    currentSong = song;
    isPreviewPlayback = false;
    isLoadingStream = true;
    playbackError = null;
    ensureITunesMetadata(song);
    notifyListeners();
    onPlaybackSongChanged?.call(song);

    try {
      await _ensureCacheInitialized();
      await _player.stop();
      if (token != _activeRequestToken) return;

      final videoId = await resolveVideoId(song);
      if (token != _activeRequestToken) return;

      currentSong = song.copyWith(
        videoId: videoId,
        coverUrl: albumCoverFor(song),
        previewUrl: previewUrlFor(song),
      );
      notifyListeners();
      onPlaybackSongChanged?.call(currentSong!);

      final loadedFromDisk = await _loadSourceWithFallback(videoId, token);
      if (token != _activeRequestToken) return;

      isLoadingStream = false;
      notifyListeners();
      unawaited(_player.play());

      // If streamed over the network, cache locally in the background after a
      // brief head start so future Calendar/Feed plays load in 0ms offline.
      if (!loadedFromDisk && !kIsWeb) {
        Future<void>.delayed(const Duration(milliseconds: 1400), () {
          if (token == _activeRequestToken) {
            unawaited(cacheSongLocally(videoId));
          }
        });
      }
    } on SocketException catch (_) {
      if (token != _activeRequestToken) return;
      final vid = currentSong?.videoId ?? song.videoId;
      if (vid != null) {
        _streamCache.remove(vid);
      }
      isLoadingStream = false;
      playbackError = 'network disconnected – check your internet.';
      notifyListeners();
    } on PlayerException catch (e) {
      if (token != _activeRequestToken) return;
      final vid = currentSong?.videoId ?? song.videoId;
      if (vid != null) {
        _streamCache.remove(vid);
      }
      isLoadingStream = false;
      playbackError =
          'stream playback error (${e.message ?? e.code}) – trying another format or track.';
      notifyListeners();
    } on TimeoutException catch (_) {
      if (token != _activeRequestToken) return;
      final vid = currentSong?.videoId ?? song.videoId;
      if (vid != null) {
        _streamCache.remove(vid);
      }
      isLoadingStream = false;
      playbackError = 'streaming connection timed out – please retry.';
      notifyListeners();
    } catch (_) {
      if (token != _activeRequestToken) return;
      final vid = currentSong?.videoId ?? song.videoId;
      if (vid != null) {
        _streamCache.remove(vid);
      }
      isLoadingStream = false;
      playbackError =
          'couldn\'t stream track – check internet or try another song.';
      notifyListeners();
    }
  }

  /// Loads [videoId] into `_player` from local disk (`AudioSource.file`) if cached,
  /// otherwise walks through ordered codecs/bitrates and fallback YouTube clients
  /// so a `403 Forbidden` on one codec automatically falls back to the next.
  /// Returns `true` if loaded from local disk cache, `false` if streamed via URL.
  Future<bool> _loadSourceWithFallback(String videoId, int token) async {
    // 1. Check local file cache first -> 0ms delay & 100% offline playback.
    final cachedFile = await _findCachedFile(videoId);
    if (cachedFile != null) {
      try {
        await _player.setAudioSource(AudioSource.file(cachedFile.path));
        return true;
      } catch (_) {
        _localFileByVideoId.remove(_sanitizeFileStem(videoId));
        try {
          await cachedFile.delete();
        } catch (_) {}
      }
    }

    // 2. Try warm in-memory URL cache (< 25 minutes old).
    final warm = _streamCache[videoId];
    if (warm != null &&
        DateTime.now().difference(warm.fetchedAt) <
            const Duration(minutes: 25)) {
      try {
        await _player.setAudioSource(
          AudioSource.uri(
            warm.url,
            headers: _audioPlaybackHeaders,
          ),
        );
        return false;
      } catch (_) {
        try {
          await _player.setAudioSource(AudioSource.uri(warm.url));
          return false;
        } catch (_) {
          _streamCache.remove(videoId);
        }
      }
    }

    // 3. Fallback across YouTube API clients AND across codecs/bitrates (highest -> lowest).
    Object? lastError;
    for (final clients in _clientFallbacks) {
      if (token != _activeRequestToken) return false;

      StreamManifest manifest;
      try {
        manifest = await _yt.videos.streamsClient.getManifest(
          videoId,
          ytClients: clients,
        );
      } catch (e) {
        lastError = e;
        continue;
      }

      final candidates = _orderedCandidateStreams(
        manifest,
        forFileCache: false,
      );

      for (final stream in candidates) {
        if (token != _activeRequestToken) return false;
        final urlStr = stream.url.toString();
        if (urlStr.isEmpty) continue;

        try {
          await _player.setAudioSource(
            AudioSource.uri(
              Uri.parse(urlStr),
              headers: _audioPlaybackHeaders,
            ),
          );
          _streamCache[videoId] = (url: stream.url, fetchedAt: DateTime.now());
          return false;
        } catch (_) {
          // Native player fallback without custom headers
          try {
            await _player.setAudioSource(
              AudioSource.uri(Uri.parse(urlStr)),
            );
            _streamCache[videoId] = (url: stream.url, fetchedAt: DateTime.now());
            return false;
          } on PlayerException catch (e) {
            // 403 or unsupported codec on this stream -> fall back to next bitrate/container.
            lastError = e;
          } on SocketException catch (e) {
            lastError = e;
          } catch (e) {
            lastError = e;
          }
        }
      }
    }

    throw lastError ??
        StateError('No playable audio stream available for $videoId');
  }

  /// Orders candidate streams from highest bitrate to lowest bitrate,
  /// prioritizing AAC/MP4 (`.m4a`) for Apple platforms and local file caching,
  /// while keeping Opus/WebM and muxed streams as automatic fallbacks.
  List<StreamInfo> _orderedCandidateStreams(
    StreamManifest manifest, {
    required bool forFileCache,
  }) {
    final preferMp4 = forFileCache ||
        (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS));

    final audioStreams = manifest.audioOnly
        .where((s) => !forFileCache || s.container != StreamContainer.m3u8)
        .toList()
      ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

    final ordered = <StreamInfo>[];
    if (preferMp4) {
      ordered.addAll(
        audioStreams.where((s) => s.container == StreamContainer.mp4),
      );
      ordered.addAll(
        audioStreams.where((s) => s.container != StreamContainer.mp4),
      );
    } else {
      ordered.addAll(audioStreams);
    }

    if (!forFileCache && manifest.muxed.isNotEmpty) {
      final muxed = manifest.muxed.toList()
        ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
      ordered.addAll(muxed);
    }

    return ordered;
  }

  /// Resolves a single best playable URL with client & bitrate fallback.
  Future<String?> resolvePlayableUrl(String videoId) async {
    for (final clients in _clientFallbacks) {
      try {
        final manifest = await _yt.videos.streamsClient.getManifest(
          videoId,
          ytClients: clients,
        );
        final candidates = _orderedCandidateStreams(
          manifest,
          forFileCache: false,
        );
        for (final stream in candidates) {
          final urlStr = stream.url.toString();
          if (urlStr.isNotEmpty) return urlStr;
        }
      } catch (_) {
        // Catch 403 or signature parsing issues and try next fallback client.
      }
    }
    return null;
  }

  Future<void> seekToFraction(double fraction) async {
    final total = _player.duration ??
        (currentSong != null ? Duration(seconds: currentSong!.seconds) : null);
    if (total == null || total.inMilliseconds <= 0) return;
    final targetMs = (total.inMilliseconds * fraction.clamp(0.0, 1.0)).round();
    await _player.seek(Duration(milliseconds: targetMs));
  }

  Future<void> stop() async {
    ++_activeRequestToken;
    isPreviewPlayback = false;
    isLoadingStream = false;
    playbackError = null;
    currentSong = null;
    try {
      await _ensureCacheInitialized();
      await _player.stop();
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _processingStateSub?.cancel();
    _http.close();
    _yt.close();
    _player.dispose();
    super.dispose();
  }
}

final musicService = YouTubeMusicService();
