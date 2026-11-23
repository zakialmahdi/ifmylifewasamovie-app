// PWA Install & Smartphone Detection Bridge for If My Life A Movie
(function () {
  if (window.pwaInstallBridge) return;

  var deferredInstallPrompt = undefined;
  var isInstalledState = false;
  var isInstalling = false;
  var supportsWebInstall =
    typeof Navigator !== 'undefined' &&
    typeof Navigator.prototype.install === 'function';

  function checkStandalone() {
    try {
      if (window.navigator && window.navigator.standalone === true) {
        return true;
      }
      if (
        window.matchMedia &&
        (window.matchMedia('(display-mode: standalone)').matches ||
          window.matchMedia('(display-mode: fullscreen)').matches ||
          window.matchMedia('(display-mode: minimal-ui)').matches)
      ) {
        return true;
      }
    } catch (e) {}
    return isInstalledState;
  }

  function checkIsIos() {
    try {
      var ua = (window.navigator && window.navigator.userAgent) || '';
      return /iPhone|iPod/i.test(ua);
    } catch (e) {
      return false;
    }
  }

  function checkIsSmartphone() {
    try {
      var nav = window.navigator || {};
      var ua = nav.userAgent || '';

      // Exclude desktop/laptop OS platforms unless explicit mobile Phone UA is present
      var isPhoneUa =
        /iPhone|iPod|Android.*Mobile|Windows Phone|BlackBerry|IEMobile|Opera Mini/i.test(
          ua
        );
      if (isPhoneUa) return true;

      if (nav.userAgentData && typeof nav.userAgentData.mobile === 'boolean') {
        if (nav.userAgentData.mobile) return true;
        return false;
      }

      // Reject laptops/desktops (Windows, macOS, ChromeOS, desktop Linux) and tablets (iPad)
      if (/Windows NT|Macintosh|CrOS|iPad|X11; Linux x86_64/i.test(ua)) {
        return false;
      }

      var hasTouch =
        nav.maxTouchPoints > 0 || 'ontouchstart' in window;
      var shortestSide = Math.min(
        window.screen ? window.screen.width : window.innerWidth,
        window.screen ? window.screen.height : window.innerHeight
      );
      return hasTouch && shortestSide > 0 && shortestSide <= 600 && /Android|Mobile/i.test(ua);
    } catch (e) {
      return false;
    }
  }

  function notifyDart(state) {
    if (
      window.pwaInstallBridge &&
      typeof window.pwaInstallBridge.onStateChanged === 'function'
    ) {
      try {
        window.pwaInstallBridge.onStateChanged(state);
      } catch (e) {}
    }
  }

  window.addEventListener('beforeinstallprompt', function (event) {
    event.preventDefault();
    deferredInstallPrompt = event;
    notifyDart('ready');
  });

  window.addEventListener('appinstalled', function () {
    isInstalledState = true;
    deferredInstallPrompt = undefined;
    notifyDart('installed');
  });

  window.pwaInstallBridge = {
    isSmartphone: function () {
      return checkIsSmartphone();
    },
    isIos: function () {
      return checkIsIos();
    },
    isStandalone: function () {
      return checkStandalone();
    },
    canPromptNatively: function () {
      return !checkStandalone() && (supportsWebInstall || !!deferredInstallPrompt);
    },
    triggerInstall: async function () {
      if (isInstalling) return 'busy';
      if (checkStandalone()) return 'installed';
      isInstalling = true;
      try {
        if (supportsWebInstall) {
          // MANDATORY: Call during the click handler; delayed calls lose user activation.
          await navigator.install();
          isInstalledState = true;
          notifyDart('installed');
          return 'accepted';
        } else if (deferredInstallPrompt) {
          // Save and clear the single-use event before awaiting the user's choice.
          var promptEvent = deferredInstallPrompt;
          deferredInstallPrompt = undefined;
          await promptEvent.prompt();
          var choiceResult = await promptEvent.userChoice;
          var outcome = choiceResult && choiceResult.outcome ? choiceResult.outcome : 'dismissed';
          if (outcome === 'accepted') {
            isInstalledState = true;
            notifyDart('installed');
            return 'accepted';
          }
          notifyDart('dismissed');
          return 'dismissed';
        }
        return 'manual';
      } catch (error) {
        if (error && error.name === 'AbortError') {
          // Cancellation is an expected user choice; keep the button available to retry.
          return 'dismissed';
        }
        console.error(error);
        return 'manual';
      } finally {
        isInstalling = false;
      }
    },
    onStateChanged: null,
  };
})();
