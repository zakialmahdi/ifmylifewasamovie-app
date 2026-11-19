// YouTube Invisible Web Audio Bridge for if_my_life_was_a_movie
// Plays full audio tracks on web without showing any visible video element.

(function () {
  if (window.ytAudioBridge) return;

  var player = null;
  var isReady = false;
  var pendingAction = null;
  var progressInterval = null;
  var currentVideoId = '';
  var isBufferingState = false;
  var isPlayingState = false;
  var fallbackQuery = '';

  function ensureContainer() {
    var container = document.getElementById('yt-audio-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'yt-audio-container';
      container.style.cssText =
        'position:fixed;bottom:-9999px;left:-9999px;width:1px;height:1px;opacity:0.001;pointer-events:none;overflow:hidden;z-index:-99999;';
      var playerDiv = document.createElement('div');
      playerDiv.id = 'yt-audio-player';
      container.appendChild(playerDiv);
      document.body.appendChild(container);
    }
  }

  function loadScript() {
    if (window.YT && window.YT.Player) {
      initPlayer();
      return;
    }
    var existing = document.querySelector('script[src*="youtube.com/iframe_api"]');
    if (!existing) {
      var tag = document.createElement('script');
      tag.src = 'https://www.youtube.com/iframe_api';
      var first = document.getElementsByTagName('script')[0];
      if (first && first.parentNode) {
        first.parentNode.insertBefore(tag, first);
      } else {
        document.head.appendChild(tag);
      }
    }
  }

  function emitEvent(name, data) {
    var detail = { event: name, data: data || {} };
    try {
      window.dispatchEvent(
        new CustomEvent('yt-audio-event', { detail: JSON.stringify(detail) })
      );
    } catch (e) {}

    if (window.ytAudioBridge && typeof window.ytAudioBridge.onEvent === 'function') {
      try {
        window.ytAudioBridge.onEvent(JSON.stringify(detail));
      } catch (e) {}
    }
  }

  function startProgressTracking() {
    stopProgressTracking();
    progressInterval = setInterval(function () {
      if (!player || typeof player.getCurrentTime !== 'function') return;
      try {
        var pos = player.getCurrentTime() || 0;
        var dur = player.getDuration() || 0;
        emitEvent('timeupdate', { position: pos, duration: dur });
      } catch (e) {}
    }, 250);
  }

  function stopProgressTracking() {
    if (progressInterval) {
      clearInterval(progressInterval);
      progressInterval = null;
    }
  }

  function initPlayer() {
    if (player) return;
    ensureContainer();

    try {
      player = new window.YT.Player('yt-audio-player', {
        height: '1',
        width: '1',
        playerVars: {
          autoplay: 0,
          controls: 0,
          disablekb: 1,
          fs: 0,
          playsinline: 1,
          rel: 0,
          modestbranding: 1,
          origin: window.location.origin
        },
        events: {
          onReady: function () {
            isReady = true;
            emitEvent('ready');
            if (pendingAction) {
              var action = pendingAction;
              pendingAction = null;
              action();
            }
          },
          onStateChange: function (event) {
            // YT.PlayerState: UNSTARTED (-1), ENDED (0), PLAYING (1), PAUSED (2), BUFFERING (3), CUED (5)
            var state = event.data;
            if (state === 1) {
              isPlayingState = true;
              isBufferingState = false;
              startProgressTracking();
              try {
                var vidData = player.getVideoData();
                if (vidData && vidData.video_id) {
                  currentVideoId = vidData.video_id;
                  emitEvent('videoIdResolved', { videoId: currentVideoId });
                }
              } catch (e) {}
              emitEvent('stateChange', {
                state: 'playing',
                isPlaying: true,
                isBuffering: false
              });
            } else if (state === 2) {
              isPlayingState = false;
              isBufferingState = false;
              stopProgressTracking();
              emitEvent('stateChange', {
                state: 'paused',
                isPlaying: false,
                isBuffering: false
              });
            } else if (state === 3) {
              isBufferingState = true;
              emitEvent('stateChange', {
                state: 'buffering',
                isPlaying: isPlayingState,
                isBuffering: true
              });
            } else if (state === 0) {
              isPlayingState = false;
              isBufferingState = false;
              stopProgressTracking();
              emitEvent('stateChange', {
                state: 'ended',
                isPlaying: false,
                isBuffering: false
              });
            } else if (state === -1) {
              emitEvent('stateChange', { state: 'unstarted' });
            }
          },
          onError: function (event) {
            var code = event.data;
            // 101 or 150 = owner prohibits embed playback for this video id. Fallback to search query once.
            if ((code === 101 || code === 150) && fallbackQuery) {
              var q = fallbackQuery;
              fallbackQuery = '';
              try {
                player.loadPlaylist({ listType: 'search', list: q });
                return;
              } catch (e) {}
            }
            emitEvent('error', { code: code });
          }
        }
      });
    } catch (e) {
      console.warn('[ytAudioBridge] Init error:', e);
    }
  }

  var prevOnReady = window.onYouTubeIframeAPIReady;
  window.onYouTubeIframeAPIReady = function () {
    if (typeof prevOnReady === 'function') prevOnReady();
    initPlayer();
  };

  window.ytAudioBridge = {
    onEvent: null,

    play: function (videoId, query) {
      fallbackQuery = query || '';
      var execute = function () {
        if (!player) return;
        try {
          if (videoId && videoId.trim().length > 0) {
            currentVideoId = videoId.trim();
            player.loadVideoById({ videoId: currentVideoId });
          } else if (query && query.trim().length > 0) {
            player.loadPlaylist({ listType: 'search', list: query.trim() });
          }
          player.playVideo();
        } catch (e) {
          console.warn('[ytAudioBridge] Play error:', e);
        }
      };

      if (!isReady || !player) {
        pendingAction = execute;
        loadScript();
      } else {
        execute();
      }
    },

    pause: function () {
      if (player && typeof player.pauseVideo === 'function') {
        try { player.pauseVideo(); } catch (e) {}
      }
    },

    resume: function () {
      if (player && typeof player.playVideo === 'function') {
        try { player.playVideo(); } catch (e) {}
      }
    },

    stop: function () {
      stopProgressTracking();
      isPlayingState = false;
      isBufferingState = false;
      pendingAction = null;
      if (player && typeof player.stopVideo === 'function') {
        try { player.stopVideo(); } catch (e) {}
      }
    },

    seekTo: function (seconds) {
      if (player && typeof player.seekTo === 'function') {
        try {
          player.seekTo(seconds, true);
        } catch (e) {}
      }
    },

    getPosition: function () {
      if (player && typeof player.getCurrentTime === 'function') {
        try { return player.getCurrentTime() || 0; } catch (e) {}
      }
      return 0;
    },

    getDuration: function () {
      if (player && typeof player.getDuration === 'function') {
        try { return player.getDuration() || 0; } catch (e) {}
      }
      return 0;
    },

    isPlaying: function () {
      return isPlayingState;
    },

    isBuffering: function () {
      return isBufferingState;
    },

    getVideoId: function () {
      return currentVideoId;
    }
  };

  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    ensureContainer();
    loadScript();
  } else {
    document.addEventListener('DOMContentLoaded', function () {
      ensureContainer();
      loadScript();
    });
  }
})();
