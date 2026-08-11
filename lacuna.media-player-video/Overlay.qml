import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtMultimedia
import QtQuick

Item {
  id: root

  property string omarchyPath: ""
  property var shell: null
  property var manifest: null
  property var service: null

  readonly property string targetOutput: String(manifest && manifest.defaults && manifest.defaults.targetOutput !== undefined
    ? manifest.defaults.targetOutput : "ALL")
  readonly property bool allOutputs: targetOutput === "" || targetOutput === "ALL" || targetOutput === "*"
  readonly property string presentationMode: service && service.presentationMode !== undefined
    ? String(service.presentationMode || "auto")
    : "auto"
  readonly property string presentationState: service && service.presentationState !== undefined
    ? String(service.presentationState || "inline")
    : (service && service.backgroundVideoEnabled === true ? "background" : "inline")
  readonly property string pendingHandoffSurface: service && service.pendingHandoffSurface !== undefined
    ? String(service.pendingHandoffSurface || "") : ""
  readonly property bool desiredBackgroundVideo: {
    // Demotion keeps the background alive until the inline surface reports
    // ready. Promotion likewise loads behind the cover while inline remains.
    if (presentationState === "promoting" || presentationState === "background"
        || presentationState === "demoting" || presentationState === "recovering") return true
    if (presentationState === "inline" && service && service.desiredBackgroundVideo !== undefined) {
      return service.desiredBackgroundVideo === true
    }
    if (presentationState === "inline") return false
    if (service && service.desiredBackgroundVideo !== undefined) return service.desiredBackgroundVideo === true
    return service && service.backgroundVideoEnabled === true
  }
  readonly property string videoQuality: service && service.videoQuality !== undefined
    ? String(service.videoQuality || "adaptive")
    : "adaptive"
  readonly property bool reducedMotion: service && (service.reduceMotion === true
    || (service.lacunaSettings && service.lacunaSettings.reduceMotion === true))
  readonly property string adaptiveVideoSource: service
    ? String(service.adaptiveBackgroundStreamUrl || "")
    : ""
  readonly property string progressiveVideoSource: service
    ? String(service.progressiveBackgroundStreamUrl || service.backgroundStreamUrl || "")
    : ""
  readonly property bool adaptivePreferred: videoQuality !== "stable"
    && videoQuality !== "progressive"
    && videoQuality !== "360p"
  readonly property string preferredVideoSource: adaptivePreferred && !usingProgressiveFallback && adaptiveVideoSource !== ""
    ? adaptiveVideoSource
    : progressiveVideoSource
  readonly property bool backgroundSurfaceDesired: desiredBackgroundVideo && service && service.playing === true
  readonly property bool backgroundVisible: backgroundSurfaceDesired && String(highResVideoSource) !== ""
  readonly property bool backgroundPlaying: backgroundSurfaceDesired && activeSource !== "" && service.paused !== true
  readonly property string highResVideoSource: preferredVideoSource
  readonly property int backgroundRequestRevision: service && service.backgroundRequestRevision !== undefined ? Number(service.backgroundRequestRevision) || 0 : 0
  readonly property int playbackSessionRevision: service && service.playbackSessionRevision !== undefined
    ? Number(service.playbackSessionRevision) || 0
    : backgroundRequestRevision
  readonly property int presentationRevision: service && service.presentationRevision !== undefined
    ? Number(service.presentationRevision) || 0 : 0
  readonly property bool backgroundResolveFailed: service && service.backgroundResolveFailed === true
  readonly property string videoSource: backgroundVisible ? highResVideoSource : ""
  readonly property real startPosition: service && service.playbackPosition !== undefined ? Math.max(0, Number(service.playbackPosition) || 0) : 0
  readonly property bool wallpaperDesired: backgroundVisible && videoSource !== ""
  readonly property bool waitingForHighRes: service
    && desiredBackgroundVideo
    && service.playing === true
    && service.paused !== true
    && highResVideoSource === ""
  readonly property int normalFadeCoverRiseDuration: 220
  readonly property int normalSourceHoldDuration: 80
  readonly property int normalFadeInDuration: 850
  readonly property int normalExitFadeToBlackDuration: 240
  readonly property int normalExitFadeFromBlackDuration: 700
  readonly property int reducedMotionDuration: 75
  readonly property int fadeCoverRiseDuration: transitionDuration(normalFadeCoverRiseDuration)
  readonly property int sourceHoldDuration: transitionDuration(normalSourceHoldDuration)
  readonly property int fadeInDuration: transitionDuration(normalFadeInDuration)
  readonly property int fadeOutDuration: transitionDuration(normalFadeInDuration)
  readonly property int exitFadeToBlackDuration: transitionDuration(normalExitFadeToBlackDuration)
  readonly property int exitFadeFromBlackDuration: transitionDuration(normalExitFadeFromBlackDuration)
  readonly property int outputRegistrationTimeoutDuration: 5000
  readonly property int adaptiveReadinessTimeoutDuration: 4000
  readonly property int hardSeekCooldownDuration: 1500
  readonly property int transitionSettleDelay: reducedMotion ? 5 : 24
  property string activeSource: ""
  property string activeCandidateKind: "none"
  property int activeStartPosition: 0
  property int mediaRestartAttempts: 0
  property int resolveRetryAttempts: 0
  property int wallpaperRecoveryAttempts: 0
  property bool usingProgressiveFallback: false
  property string fallbackReason: ""
  property int hardSeekFailureCount: 0
  property double lastHardSeekAt: 0
  property bool driftValidationPending: false
  property bool driftCorrectionBlocked: false
  property string lastReportedReadyKey: ""
  property string lastReportedFailureKey: ""
  property string activeRevisionKey: ""
  property int lastHandledResolveFailureRevision: -1
  property int sourceRevision: 0
  property var activeHandoffToken: null
  property bool fadeCoverVisible: false
  property real fadeCoverOpacity: 0
  property double fadeCoverStartedAt: 0
  property double activeSourceAssignedAt: 0
  property int fadeRevealDelay: 0
  property bool fadeCoverRising: false
  property int fadeCoverDuration: fadeInDuration
  property bool exitTransitionActive: false
  property bool clearingWallpaperAfterExit: false
  property bool failureExitActive: false
  property string pendingGiveUpReason: ""
  property int wallpaperFadeGateDelay: 0
  property bool waitingForPlayerReady: false
  property bool wallpaperPositionRefreshPending: false
  property string wallpaperPositionRefreshKey: ""
  readonly property int mediaReadyMinimumHoldMs: sourceHoldDuration
  readonly property bool wallpaperLayerVisible: wallpaperDesired || activeSource !== "" || exitTransitionActive || fadeCoverVisible

  function transitionDuration(normalDuration) {
    return reducedMotion ? reducedMotionDuration : normalDuration
  }

  function resolvedLocalCoverOpacity(localPlayerReady) {
    // Once the source is cleared, the black cover must follow the root exit
    // fade. Keeping it pinned opaque until Loader teardown creates a one-frame
    // cut back to the static wallpaper.
    if (activeSource === "" || clearingWallpaperAfterExit) return fadeCoverOpacity
    return localPlayerReady === true ? fadeCoverOpacity : 1
  }

  function outputMatches(screen) {
    if (allOutputs) return true
    var name = screen && screen.name !== undefined ? String(screen.name) : ""
    return name === targetOutput
  }

  function expectedMatchedPlayerCount() {
    var screens = Quickshell.screens || []
    var count = 0
    for (var i = 0; i < screens.length; i++) {
      if (outputMatches(screens[i])) count += 1
    }
    return count
  }

  function registeredMatchedPlayerCount() {
    var screens = Quickshell.screens || []
    var count = 0
    for (var i = 0; i < screens.length; i++) {
      if (outputMatches(screens[i]) && playerForScreen(screens[i]) !== null) count += 1
    }
    return count
  }

  function allMatchedPlayersRegistered() {
    var expected = expectedMatchedPlayerCount()
    return expected > 0 && registeredMatchedPlayerCount() >= expected
  }

  function allMatchedPlayersReadyFor(source) {
    var screens = Quickshell.screens || []
    var expected = 0
    var ready = 0
    for (var i = 0; i < screens.length; i++) {
      var screen = screens[i]
      if (!outputMatches(screen)) continue
      expected += 1
      var player = playerForScreen(screen)
      if (player && Number(player.lacunaSourceRevision) === sourceRevision
          && String(player.source) === source && player.lacunaReady === true) ready += 1
    }
    return expected > 0 && ready >= expected
  }

  function playerForScreen(screen) {
    var name = screen && screen.name !== undefined ? String(screen.name) : ""
    var fallback = null
    for (var i = 0; i < videoPlayers.length; i++) {
      var player = videoPlayers[i]
      var playerName = player && player.targetScreen && player.targetScreen.name !== undefined
        ? String(player.targetScreen.name) : ""
      if (!player || !(player.targetScreen === screen || (name !== "" && playerName === name))) continue
      if (Number(player.lacunaSourceRevision) === sourceRevision) return player
      if (fallback === null) fallback = player
    }
    return fallback
  }

  function playbackStateCategory(player) {
    if (!player) return "missing"
    if (player.playbackState === MediaPlayer.PlayingState) return "playing"
    if (player.playbackState === MediaPlayer.PausedState) return "paused"
    if (player.playbackState === MediaPlayer.StoppedState) return "stopped"
    return "unknown"
  }

  function mediaStatusCategory(player) {
    if (!player) return "missing"
    if (player.mediaStatus === MediaPlayer.NoMedia) return "no-media"
    if (player.mediaStatus === MediaPlayer.LoadingMedia) return "loading"
    if (player.mediaStatus === MediaPlayer.LoadedMedia) return "loaded"
    if (player.mediaStatus === MediaPlayer.BufferingMedia) return "buffering"
    if (player.mediaStatus === MediaPlayer.StalledMedia) return "stalled"
    if (player.mediaStatus === MediaPlayer.BufferedMedia) return "buffered"
    if (player.mediaStatus === MediaPlayer.EndOfMedia) return "end"
    if (player.mediaStatus === MediaPlayer.InvalidMedia) return "invalid"
    return "unknown"
  }

  function outputDiagnostics(stage) {
    var screens = Quickshell.screens || []
    var outputs = []
    var registered = 0
    var ready = 0
    var target = Math.max(0, startPosition * 1000)
    for (var i = 0; i < screens.length; i++) {
      var screen = screens[i]
      if (!outputMatches(screen)) continue
      var player = playerForScreen(screen)
      var sourceMatched = player !== null && String(player.source) === activeSource && activeSource !== ""
      var converged = sourceMatched && Math.abs(target - Number(player.position || 0)) < 400
      if (player) registered += 1
      if (sourceMatched && player.lacunaReady && converged) ready += 1
      outputs.push({
        name: screen && screen.name !== undefined ? String(screen.name) : "",
        registered: player !== null,
        sourceMatched: sourceMatched,
        ready: sourceMatched && player.lacunaReady === true,
        playbackState: playbackStateCategory(player),
        mediaStatus: mediaStatusCategory(player),
        converged: converged,
        error: player !== null && player.mediaStatus === MediaPlayer.InvalidMedia
      })
    }
    return {
      stage: String(stage || ""),
      expectedOutputs: outputs.length,
      registeredOutputs: registered,
      readyOutputs: ready,
      outputs: outputs
    }
  }

  function makeHandoffToken(nextSourceRevision) {
    return {
      surface: "background",
      playbackRevision: playbackSessionRevision,
      presentationRevision: presentationRevision,
      requestRevision: backgroundRequestRevision,
      sourceRevision: Math.max(1, Number(nextSourceRevision) || 1)
    }
  }

  function handoffTokenMatchesCurrent(token) {
    return token
      && Number(token.playbackRevision) === playbackSessionRevision
      && Number(token.presentationRevision) === presentationRevision
      && Number(token.requestRevision) === backgroundRequestRevision
      && Number(token.sourceRevision) === sourceRevision
  }

  function ensureFailureToken() {
    if (handoffTokenMatchesCurrent(activeHandoffToken)) return activeHandoffToken
    sourceRevision += 1
    activeHandoffToken = makeHandoffToken(sourceRevision)
    return activeHandoffToken
  }

  function backgroundSourceGenerationIsCurrent(player) {
    return player && handoffTokenMatchesCurrent(activeHandoffToken)
      && Number(player.lacunaSourceRevision) === sourceRevision
      && String(player.source || "") === activeSource
  }

  function reportLoading(stage) {
    if (service && typeof service.reportVideoLoading === "function" && activeHandoffToken)
      service.reportVideoLoading("background", activeHandoffToken,
        outputDiagnostics(String(stage || "loading-renderer")))
  }

  function resolveFrameGeometryRevision() {
    if (root.shell && root.shell.bar && root.shell.bar.lacunaFrameGeometryRevision !== undefined)
      return Number(root.shell.bar.lacunaFrameGeometryRevision) || 0
    return 0
  }

  function resolveFrameGeometryKey() {
    if (root.shell && root.shell.bar && root.shell.bar.lacunaFrameGeometryKey !== undefined)
      return String(root.shell.bar.lacunaFrameGeometryKey || "")
    return ""
  }

  function resolveFrameRect(screen) {
    if (root.shell && root.shell.bar && typeof root.shell.bar.lacunaFrameContentRect === "function") {
      var rect = root.shell.bar.lacunaFrameContentRect(screen)
      if (rect && rect.width > 0 && rect.height > 0) return rect
    }
    return {
      x: 0,
      y: 0,
      width: screen && screen.width !== undefined ? Math.max(1, Number(screen.width) || 1) : 1,
      height: screen && screen.height !== undefined ? Math.max(1, Number(screen.height) || 1) : 1,
      radius: 0,
      bleed: 0,
      framed: false
    }
  }

  function resolveService() {
    if (root.service) return
    if (root.shell && typeof root.shell.ensureService === "function") {
      var ensured = root.shell.ensureService("lacuna.media-player")
      if (ensured) {
        root.service = ensured
        return
      }
    }
    if (root.shell && typeof root.shell.serviceFor === "function") {
      var existing = root.shell.serviceFor("lacuna.media-player")
      if (existing) root.service = existing
    }
  }

  function open(payloadJson) {
    resolveService()
  }

  Component.onCompleted: {
    resolveService()
    syncWallpaper()
  }
  onShellChanged: resolveService()
  onWaitingForHighResChanged: syncWallpaper()
  onBackgroundRequestRevisionChanged: {
    resetCandidateState()
    lastHandledResolveFailureRevision = -1
    if (backgroundResolveFailed) handleResolveFailure()
    syncWallpaper()
  }
  onPlaybackSessionRevisionChanged: {
    mediaRestartAttempts = 0
    resetCandidateState()
    syncWallpaper()
  }
  onBackgroundResolveFailedChanged: {
    if (backgroundResolveFailed) handleResolveFailure()
    else lastHandledResolveFailureRevision = -1
  }
  onPresentationModeChanged: syncWallpaper()
  onPresentationStateChanged: syncWallpaper()
  onPresentationRevisionChanged: syncWallpaper()
  onDesiredBackgroundVideoChanged: syncWallpaper()
  onAdaptiveVideoSourceChanged: syncWallpaper()
  onProgressiveVideoSourceChanged: syncWallpaper()
  onVideoQualityChanged: {
    usingProgressiveFallback = false
    syncWallpaper()
  }
  onReducedMotionChanged: syncWallpaper()
  onWallpaperDesiredChanged: syncWallpaper()
  onVideoSourceChanged: syncWallpaper()
  onBackgroundPlayingChanged: syncWallpaper()
  onStartPositionChanged: syncVideoPosition(false)

  function resetCandidateState() {
    usingProgressiveFallback = false
    fallbackReason = ""
    hardSeekFailureCount = 0
    lastHardSeekAt = 0
    driftValidationPending = false
    driftCorrectionBlocked = false
    lastReportedReadyKey = ""
    lastReportedFailureKey = ""
    adaptiveReadinessTimer.stop()
    driftValidationTimer.stop()
    readyConvergenceTimer.stop()
  }

  function activePlayersConverged(toleranceMs) {
    var screens = Quickshell.screens || []
    var found = 0
    var target = Math.max(0, startPosition * 1000)
    for (var i = 0; i < screens.length; i++) {
      var screen = screens[i]
      if (!outputMatches(screen)) continue
      var player = playerForScreen(screen)
      if (!player || Number(player.lacunaSourceRevision) !== sourceRevision
          || String(player.source) !== activeSource) return false
      found += 1
      if (Math.abs(target - player.position) >= toleranceMs) return false
    }
    return found > 0
  }

  function reportReady() {
    var key = playbackSessionRevision + "#" + sourceRevision
    if (lastReportedReadyKey === key) return
    var surfacePosition = startPosition
    for (var i = 0; i < videoPlayers.length; i++) {
      var player = videoPlayers[i]
      if (!player || String(player.source) !== activeSource) continue
      surfacePosition = Math.max(0, Number(player.position) / 1000)
      break
    }
    if (service && typeof service.reportVideoReady === "function") {
      var accepted = service.reportVideoReady("background", playbackSessionRevision, surfacePosition,
        activeHandoffToken, outputDiagnostics("presented"))
      if (accepted === true) lastReportedReadyKey = key
    }
  }

  function reportFailure(reason) {
    var normalizedReason = String(reason || "unknown")
    var token = ensureFailureToken()
    var key = playbackSessionRevision + "#" + token.sourceRevision + "#" + normalizedReason
    if (lastReportedFailureKey === key) return
    lastReportedFailureKey = key
    if (service && typeof service.reportVideoFailure === "function") {
      service.reportVideoFailure("background", playbackSessionRevision, normalizedReason,
        token, outputDiagnostics("failed"))
    }
  }

  function holdFadeCover(duration) {
    exitTransitionActive = false
    clearingWallpaperAfterExit = false
    failureExitActive = false
    pendingGiveUpReason = ""
    exitClearTimer.stop()
    failureClearTimer.stop()
    fadeRevealTimer.stop()
    fadeHideTimer.stop()
    fadeCoverVisible = true
    fadeCoverStartedAt = Date.now()
    fadeCoverRising = true
    fadeCoverDuration = Math.max(1, Number(duration) || fadeCoverRiseDuration)
    fadeCoverOpacity = 1
    if (service && typeof service.reportVideoCovering === "function")
      service.reportVideoCovering("background", playbackSessionRevision, presentationRevision,
        backgroundRequestRevision, outputDiagnostics("covering"))
    if (!allMatchedPlayersRegistered()) outputRegistrationTimer.restart()
  }

  function fadeCoverRiseRemaining() {
    if (!fadeCoverRising || fadeCoverStartedAt <= 0) return 0
    return Math.max(0, fadeCoverDuration - (Date.now() - fadeCoverStartedAt))
  }

  function releaseFadeCoverSoon() {
    var elapsed = activeSourceAssignedAt > 0 ? Date.now() - activeSourceAssignedAt : mediaReadyMinimumHoldMs
    fadeRevealDelay = Math.max(0, mediaReadyMinimumHoldMs - elapsed)
    fadeRevealTimer.restart()
  }

  function releaseFadeCoverNow() {
    fadeRevealTimer.stop()
    outputRegistrationTimer.stop()
    waitingForPlayerReady = false
    fadeCoverRising = false
    fadeCoverDuration = clearingWallpaperAfterExit ? exitFadeFromBlackDuration : fadeOutDuration
    fadeCoverOpacity = 0
    fadeHideTimer.restart()
  }

  function anyPlayerReadyFor(source) {
    for (var i = 0; i < videoPlayers.length; i++) {
      var player = videoPlayers[i]
      if (!player || String(player.source) !== source) continue
      if (player.lacunaReady === true && player.playbackState === MediaPlayer.PlayingState) return true
    }
    return false
  }

  function notePlayerReady() {
    if (!waitingForPlayerReady || activeSource === "" || exitTransitionActive || !wallpaperDesired) return
    if (!allMatchedPlayersReadyFor(activeSource) || !activePlayersConverged(400)) {
      reportLoading("converging-outputs")
      syncVideoPosition(false)
      readyConvergenceTimer.restart()
      return
    }
    readyConvergenceTimer.stop()
    adaptiveReadinessTimer.stop()
    resolveRetryAttempts = 0
    wallpaperRecoveryAttempts = 0
    mediaRestartAttempts = 0
    hardSeekFailureCount = 0
    driftCorrectionBlocked = false
    reportReady()
    releaseFadeCoverSoon()
  }

  function notePlayerError(reason) {
    if (activeSource === "" || exitTransitionActive || !wallpaperDesired) return
    if (activeCandidateKind === "adaptive" && usingProgressiveFallback) return
    var category = String(reason || "player-error")
    console.warn("lacuna.media-player-video: player failure:", category, "restartAttempts:", mediaRestartAttempts)
    if (activeCandidateKind === "adaptive" && switchToProgressive("adaptive-error")) return
    if (mediaRestartAttempts < 2 && service && typeof service.refreshBackgroundStream === "function") {
      mediaRestartAttempts += 1
      waitingForPlayerReady = true
      reportFailure("renderer-retry")
      holdFadeCover(fadeCoverRiseDuration)
      service.refreshBackgroundStream()
      return
    }
    reportFailure(category)
    giveUpWallpaper(category)
  }

  function switchToProgressive(reason) {
    if (progressiveVideoSource === "" || activeCandidateKind === "progressive" || usingProgressiveFallback) return false
    fallbackReason = String(reason || "adaptive-fallback")
    usingProgressiveFallback = true
    adaptiveReadinessTimer.stop()
    waitingForPlayerReady = true
    hardSeekFailureCount = 0
    lastHardSeekAt = 0
    driftValidationPending = false
    driftCorrectionBlocked = false
    reportFailure(fallbackReason)
    holdFadeCover(fadeCoverRiseDuration)
    wallpaperFadeGateDelay = fadeCoverDuration
    wallpaperFadeGateTimer.restart()
    return true
  }

  function handleResolveFailure() {
    if (!backgroundResolveFailed) return
    if (lastHandledResolveFailureRevision === backgroundRequestRevision) return
    lastHandledResolveFailureRevision = backgroundRequestRevision
    var wantsVideo = desiredBackgroundVideo && service && service.playing === true && service.paused !== true
    if (wantsVideo && resolveRetryAttempts < 2 && service && typeof service.refreshBackgroundStream === "function") {
      resolveRetryAttempts += 1
      giveUpWallpaper("resolve-failed-retry-" + resolveRetryAttempts)
      resolveRetryTimer.restart()
      return
    }
    reportFailure("resolve-failed")
    giveUpWallpaper("resolve-failed")
  }

  function giveUpWallpaper(reason) {
    console.warn("lacuna.media-player-video: wallpaper gave up:", reason)
    wallpaperFadeGateTimer.stop()
    fadeRevealTimer.stop()
    adaptiveReadinessTimer.stop()
    driftValidationTimer.stop()
    outputRegistrationTimer.stop()
    waitingForPlayerReady = false
    readyConvergenceTimer.stop()
    pendingGiveUpReason = String(reason || "unknown")
    if (activeSource !== "" && fadeCoverOpacity < 0.999) {
      failureExitActive = true
      fadeCoverVisible = true
      fadeCoverRising = true
      fadeCoverStartedAt = Date.now()
      fadeCoverDuration = exitFadeToBlackDuration
      fadeCoverOpacity = 1
      failureClearTimer.restart()
      return
    }
    finishGiveUpWallpaper()
  }

  function finishGiveUpWallpaper() {
    failureExitActive = false
    clearingWallpaperAfterExit = true
    activeSource = ""
    activeRevisionKey = ""
    activeCandidateKind = "none"
    activeHandoffToken = null
    activeStartPosition = 0
    mediaRestartAttempts = 0
    wallpaperPositionRefreshPending = false
    wallpaperPositionRefreshKey = ""
    driftValidationPending = false
    releaseFadeCoverNow()
    // Giving up while the service still wants video used to strand the
    // static background until the next track; retry a bounded number of
    // times instead.
    if (wallpaperDesired && wallpaperRecoveryAttempts < 2) {
      wallpaperRecoveryAttempts += 1
      wallpaperRecoveryTimer.restart()
    }
    pendingGiveUpReason = ""
  }

  function syncWallpaper() {
    if (failureExitActive) return
    if (!backgroundSurfaceDesired) {
      if (activeSource !== "" && !exitTransitionActive && !clearingWallpaperAfterExit) {
        beginWallpaperExit()
        return
      }
      if (!exitTransitionActive && !clearingWallpaperAfterExit) clearWallpaperNow()
      return
    }

    // Resolution is not a teardown signal. Keep the previous frame running
    // until a replacement candidate exists, then swap it under black.
    if (videoSource === "") return

    if (exitTransitionActive || clearingWallpaperAfterExit) {
      exitTransitionActive = false
      clearingWallpaperAfterExit = false
      exitClearTimer.stop()
      fadeHideTimer.stop()
      if (fadeCoverOpacity < 0.999) {
        holdFadeCover(fadeCoverRiseDuration)
        wallpaperFadeGateDelay = fadeCoverDuration
        wallpaperFadeGateTimer.restart()
        return
      }
    }

    var sourceRevisionKey = videoSource + "#" + backgroundRequestRevision + "#" + playbackSessionRevision
    var presentationRefreshNeeded = pendingHandoffSurface === "background"
      && (!activeHandoffToken || Number(activeHandoffToken.presentationRevision) !== presentationRevision)
    var sourceAssignmentNeeded = activeSource !== videoSource
      || activeRevisionKey !== sourceRevisionKey || presentationRefreshNeeded
    if (sourceAssignmentNeeded && !fadeCoverRising && fadeCoverOpacity <= 0.001) {
      // Every appearance dips quickly to black and then reveals when the
      // player is actually ready — enabling the wallpaper feels the same as
      // a track change.
      holdFadeCover(fadeCoverRiseDuration)
      wallpaperFadeGateDelay = fadeCoverDuration
      wallpaperFadeGateTimer.restart()
      return
    }

    var remainingFadeCoverRise = fadeCoverRiseRemaining()
    if (remainingFadeCoverRise > 0) {
      wallpaperFadeGateDelay = Math.max(1, Math.ceil(remainingFadeCoverRise))
      wallpaperFadeGateTimer.restart()
      return
    }

    // Loader creation is synchronous in the common case, but output hotplug
    // and target changes can lag behind the global cover transition. Never
    // assign a source until every currently matched output has registered its
    // player; each late player also owns a local opaque cover until ready.
    if (!allMatchedPlayersRegistered()) {
      if (!outputRegistrationTimer.running) outputRegistrationTimer.restart()
      return
    }
    outputRegistrationTimer.stop()

    var refreshKey = sourceRevisionKey
    if (wallpaperPositionRefreshKey !== refreshKey && service && typeof service.updatePlaybackPosition === "function") {
      // The worker-backed clock refreshes synchronously; legacy probes report
      // their result later through onPlaybackPositionChanged. Do not hold an
      // already-opaque transition for an arbitrary timer before loading media.
      wallpaperPositionRefreshKey = refreshKey
      service.updatePlaybackPosition()
    }

    if (!sourceAssignmentNeeded) {
      if (anyPlayerReadyFor(activeSource)) {
        // A quick inline/background reversal can cancel exit after the cover
        // is already opaque. Re-arm readiness so the retained playing source
        // fades back in instead of remaining behind black forever.
        if (!waitingForPlayerReady) waitingForPlayerReady = true
        notePlayerReady()
      }
      return
    }

    var nextSourceRevision = sourceRevision + 1
    activeHandoffToken = makeHandoffToken(nextSourceRevision)
    activeCandidateKind = adaptiveVideoSource !== "" && videoSource === adaptiveVideoSource && !usingProgressiveFallback
      ? "adaptive"
      : "progressive"
    activeSource = videoSource
    activeRevisionKey = refreshKey
    sourceRevision = nextSourceRevision
    activeSourceAssignedAt = Date.now()
    activeStartPosition = Math.max(0, Math.floor(startPosition))
    waitingForPlayerReady = true
    reportLoading()
    if (activeCandidateKind === "adaptive") adaptiveReadinessTimer.restart()
    else adaptiveReadinessTimer.stop()
    syncVideoPosition(true)
    // A track repeat re-resolves to the same cached stream URL, so the
    // player keeps playing and never emits a fresh ready transition —
    // release the cover ourselves or the watchdog tears the wallpaper down.
    if (anyPlayerReadyFor(activeSource)) notePlayerReady()
  }

  function beginWallpaperExit() {
    wallpaperFadeGateTimer.stop()
    fadeRevealTimer.stop()
    fadeHideTimer.stop()
    outputRegistrationTimer.stop()
    adaptiveReadinessTimer.stop()
    readyConvergenceTimer.stop()
    driftValidationTimer.stop()
    waitingForPlayerReady = false
    driftValidationPending = false
    driftCorrectionBlocked = false
    exitTransitionActive = true
    clearingWallpaperAfterExit = false
    failureExitActive = false
    failureClearTimer.stop()
    fadeCoverVisible = true
    fadeCoverRising = true
    fadeCoverStartedAt = Date.now()
    fadeCoverDuration = exitFadeToBlackDuration
    fadeCoverOpacity = 1
    exitClearTimer.restart()
  }

  function clearWallpaperNow() {
    activeSource = ""
    activeRevisionKey = ""
    activeCandidateKind = "none"
    activeHandoffToken = null
    activeStartPosition = 0
    activeSourceAssignedAt = 0
    mediaRestartAttempts = 0
    waitingForPlayerReady = false
    wallpaperPositionRefreshPending = false
    wallpaperPositionRefreshKey = ""
    wallpaperFadeGateTimer.stop()
    outputRegistrationTimer.stop()
    adaptiveReadinessTimer.stop()
    driftValidationTimer.stop()
    readyConvergenceTimer.stop()
    driftValidationPending = false
    if (!waitingForHighRes) releaseFadeCoverNow()
  }

  function syncVideoPosition(force) {
    if (exitTransitionActive || !wallpaperDesired) return
    if (driftCorrectionBlocked && !force) return
    var now = Date.now()
    var hardSeekAllowed = force || now - lastHardSeekAt >= hardSeekCooldownDuration
    var hardSeekIssued = false
    for (var i = 0; i < videoPlayers.length; i++) {
      var player = videoPlayers[i]
      if (!player || player.source === "") continue
      var target = Math.max(0, Math.round(startPosition * 1000))
      var drift = target - player.position
      var absoluteDrift = Math.abs(drift)

      if (force) {
        player.playbackRate = 1.0
        player.setPosition(target)
        continue
      }
      if (absoluteDrift < 400) {
        player.playbackRate = 1.0
        continue
      }
      if (absoluteDrift <= 1500) {
        player.playbackRate = drift > 0 ? 1.03 : 0.97
        continue
      }

      player.playbackRate = 1.0
      if (!hardSeekAllowed) continue
      player.setPosition(target)
      hardSeekIssued = true
    }
    if (hardSeekIssued && !force) {
      lastHardSeekAt = now
      driftValidationPending = true
      driftValidationTimer.restart()
    }
  }

  function handleOutputRegistrationTimeout() {
    if (!wallpaperDesired || exitTransitionActive) return false
    if (allMatchedPlayersRegistered()) return false
    reportFailure("output-registration-timeout")
    giveUpWallpaper("output-registration-timeout")
    return true
  }

  function validateHardSeek() {
    if (!driftValidationPending || exitTransitionActive || !wallpaperDesired) return
    driftValidationPending = false
    var worstDrift = 0
    for (var i = 0; i < videoPlayers.length; i++) {
      var player = videoPlayers[i]
      if (!player || player.source === "") continue
      worstDrift = Math.max(worstDrift, Math.abs(Math.max(0, startPosition * 1000) - player.position))
    }
    if (worstDrift <= 1500) {
      hardSeekFailureCount = 0
      return
    }
    hardSeekFailureCount += 1
    if (hardSeekFailureCount < 2) return
    if (activeCandidateKind === "adaptive" && switchToProgressive("adaptive-seek-correction")) return
    driftCorrectionBlocked = true
    reportFailure("seek-correction-failed")
    giveUpWallpaper("seek-correction-failed")
  }

  Component.onDestruction: {
    activeSource = ""
  }

  Timer {
    interval: 500
    repeat: true
    running: root.service === null
    onTriggered: root.resolveService()
  }

  Timer {
    id: fadeRevealTimer
    interval: root.fadeRevealDelay
    repeat: false
    onTriggered: root.releaseFadeCoverNow()
  }

  Timer {
    id: fadeHideTimer
    interval: root.fadeCoverDuration + root.transitionSettleDelay
    repeat: false
    onTriggered: {
      if (root.fadeCoverOpacity <= 0.001) {
        root.fadeCoverVisible = false
        root.clearingWallpaperAfterExit = false
      }
    }
  }

  Timer {
    id: exitClearTimer
    interval: root.exitFadeToBlackDuration + root.transitionSettleDelay
    repeat: false
    onTriggered: {
      if (!root.exitTransitionActive || root.wallpaperDesired) return
      root.exitTransitionActive = false
      root.clearingWallpaperAfterExit = true
      root.clearWallpaperNow()
    }
  }

  Timer {
    id: failureClearTimer
    interval: root.exitFadeToBlackDuration + root.transitionSettleDelay
    repeat: false
    onTriggered: {
      if (!root.failureExitActive) return
      root.finishGiveUpWallpaper()
    }
  }

  Timer {
    id: wallpaperFadeGateTimer
    interval: root.wallpaperFadeGateDelay
    repeat: false
    onTriggered: root.syncWallpaper()
  }

  Timer {
    id: outputRegistrationTimer
    interval: root.outputRegistrationTimeoutDuration
    repeat: false
    onTriggered: root.handleOutputRegistrationTimeout()
  }

  Timer {
    id: adaptiveReadinessTimer
    interval: root.adaptiveReadinessTimeoutDuration
    repeat: false
    onTriggered: {
      if (!root.wallpaperDesired || root.exitTransitionActive) return
      if (!root.waitingForPlayerReady || root.activeCandidateKind !== "adaptive") return
      if (!root.switchToProgressive("adaptive-readiness-timeout")) {
        root.reportFailure("adaptive-readiness-timeout")
        root.giveUpWallpaper("adaptive-readiness-timeout")
      }
    }
  }

  Timer {
    id: readyConvergenceTimer
    interval: 100
    repeat: false
    onTriggered: {
      if (root.waitingForPlayerReady && root.anyPlayerReadyFor(root.activeSource)) root.notePlayerReady()
    }
  }

  Timer {
    id: driftValidationTimer
    interval: 500
    repeat: false
    onTriggered: root.validateHardSeek()
  }

  Timer {
    id: wallpaperRecoveryTimer
    interval: 6000
    repeat: false
    onTriggered: {
      if (!root.wallpaperDesired || root.activeSource !== "") return
      root.syncWallpaper()
    }
  }

  Timer {
    id: resolveRetryTimer
    interval: 8000
    repeat: false
    onTriggered: {
      if (!root.backgroundResolveFailed) return
      if (!(root.desiredBackgroundVideo && root.service && root.service.playing === true && root.service.paused !== true)) return
      root.service.refreshBackgroundStream()
    }
  }

  property var videoPlayers: []
  readonly property int loadedPlayerCount: videoPlayers.length

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: videoWindow

      required property var modelData
      readonly property bool targetMatched: root.outputMatches(modelData)
      readonly property var frameRect: {
        root.resolveFrameGeometryKey()
        root.resolveFrameGeometryRevision()
        modelData.width
        modelData.height
        return root.resolveFrameRect(modelData)
      }
      readonly property bool renderable: targetMatched && root.wallpaperLayerVisible

      screen: modelData
      // A background-layer surface cannot be restacked after mapping. Keep
      // it mapped from shell startup and gate only the in-window paint.
      visible: true
      color: "transparent"
      implicitWidth: 0
      implicitHeight: 0
      WlrLayershell.namespace: "lacuna-media-player-video"
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      Loader {
        id: videoContentLoader
        anchors.fill: parent
        active: videoWindow.renderable
        sourceComponent: videoContentComponent
        onLoaded: root.syncWallpaper()
      }

      Component {
        id: videoContentComponent

        Item {
          id: videoContent
          anchors.fill: parent
          property bool localPlayerReady: false
          readonly property var currentPlayer: backgroundPlayerLoader.item
          readonly property real localCoverOpacity: root.resolvedLocalCoverOpacity(localPlayerReady)

          Component.onCompleted: recreatePlayer()

          function playerEventIsCurrent(player) {
            return player && player === currentPlayer && root.backgroundSourceGenerationIsCurrent(player)
          }

          function recreatePlayer() {
            localPlayerReady = false
            backgroundPlayerLoader.active = false
            backgroundPlayerLoader.generation = root.sourceRevision
            backgroundPlayerLoader.sourceUrl = root.activeSource
            backgroundPlayerLoader.active = true
          }

          function markLocalPlayerReady(player) {
            if (!playerEventIsCurrent(player) || player.lacunaReady === true) return
            localReadyFallbackTimer.stop()
            player.lacunaReady = true
            root.syncVideoPosition(true)
            localPlayerReady = true
            root.notePlayerReady()
          }

          Timer {
            id: localReadyFallbackTimer
            interval: 140
            repeat: false
            onTriggered: {
              var player = videoContent.currentPlayer
              if (!videoContent.playerEventIsCurrent(player) || player.lacunaReady === true) return
              if (player.playbackState !== MediaPlayer.PlayingState) return
              if (player.mediaStatus !== MediaPlayer.LoadedMedia
                  && player.mediaStatus !== MediaPlayer.BufferingMedia
                  && player.mediaStatus !== MediaPlayer.BufferedMedia) return
              // Some QtMultimedia backends do not forward videoSink frame
              // signals through VideoOutput. A bounded playing+buffered settle
              // prevents an otherwise permanent black cover.
              videoContent.markLocalPlayerReady(player)
            }
          }

          Rectangle {
            id: videoFrame

            x: Math.round(videoWindow.frameRect.x)
            y: Math.round(videoWindow.frameRect.y)
            width: Math.round(videoWindow.frameRect.width)
            height: Math.round(videoWindow.frameRect.height)
            radius: Math.max(0, Number(videoWindow.frameRect.radius || 0))
            color: "transparent"
            clip: true

            Loader {
              id: backgroundPlayerLoader
              // Stage source + generation on the Loader so changing
              // root.activeSource cannot make the outgoing player begin a
              // duplicate network load before it is destroyed.
              property int generation: 0
              property string sourceUrl: ""
              active: false
              sourceComponent: backgroundPlayerComponent
            }

            Component {
              id: backgroundPlayerComponent

              MediaPlayer {
                id: backgroundPlayerInstance
                property var targetScreen: videoWindow.modelData
                property bool lacunaReady: false
                readonly property int lacunaSourceRevision: backgroundPlayerLoader.generation
                source: backgroundPlayerLoader.sourceUrl
                videoOutput: backgroundOutput
                audioOutput: AudioOutput {
                  muted: true
                  volume: 0
                }
                loops: MediaPlayer.Infinite
                onSourceChanged: {
                  lacunaReady = false
                  videoContent.localPlayerReady = false
                  root.syncVideoPosition(true)
                  if (root.backgroundPlaying) play()
                }
                onPlaybackStateChanged: {
                  if (!videoContent.playerEventIsCurrent(backgroundPlayerInstance)) return
                  if (playbackState === MediaPlayer.PlayingState
                      && (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferingMedia
                        || mediaStatus === MediaPlayer.BufferedMedia))
                    localReadyFallbackTimer.restart()
                  else if (playbackState !== MediaPlayer.PlayingState) {
                    localReadyFallbackTimer.stop()
                    playbackRate = 1.0
                  }
                }
                onMediaStatusChanged: {
                  if (!videoContent.playerEventIsCurrent(backgroundPlayerInstance)) return
                  // Loaded/Buffered only means the backend accepted the media;
                  // the first frame may not exist yet. Keep the local cover
                  // opaque until PlayingState confirms presentation started.
                  if ((mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferingMedia
                        || mediaStatus === MediaPlayer.BufferedMedia)
                      && playbackState === MediaPlayer.PlayingState) localReadyFallbackTimer.restart()
                  if (mediaStatus === MediaPlayer.InvalidMedia) root.notePlayerError("invalid-media")
                }
                onErrorOccurred: function(error, errorString) {
                  if (videoContent.playerEventIsCurrent(backgroundPlayerInstance) && error !== MediaPlayer.NoError)
                    root.notePlayerError("player-error")
                }
                Component.onCompleted: {
                  root.videoPlayers.push(backgroundPlayerInstance)
                  root.syncVideoPosition(true)
                  root.syncWallpaper()
                  if (root.backgroundPlaying) play()
                }
                Component.onDestruction: {
                  var index = root.videoPlayers.indexOf(backgroundPlayerInstance)
                  if (index >= 0) root.videoPlayers.splice(index, 1)
                }
              }
            }

            VideoOutput {
              id: backgroundOutput
              anchors.fill: parent
              fillMode: VideoOutput.PreserveAspectCrop
            }

            Connections {
              target: backgroundOutput.videoSink
              function onVideoFrameChanged(frame) {
                // A backend can report Loaded/Playing before a decoded frame
                // reaches the output. Accept only the first valid frame from a
                // currently playing generation; later frames must never seek.
                var player = videoContent.currentPlayer
                if (!player || player.playbackState !== MediaPlayer.PlayingState) return
                if (!frame || (typeof frame.isValid === "function" && !frame.isValid())) return
                videoContent.markLocalPlayerReady(player)
              }
            }

            Rectangle {
              id: fadeCover

              // The black cover lives inside the video window, above the
              // VideoOutput: sibling z-order is deterministic, whereas stacking
              // two separate layer-shell surfaces is map-order dependent and
              // could leave the video on top of its own cover, turning every
              // fade into an abrupt pop-in.
              anchors.fill: parent
              z: 10
              color: "#000000"
              visible: true
              opacity: videoContent.localCoverOpacity

              Behavior on opacity {
                NumberAnimation {
                  duration: root.fadeCoverDuration
                  easing.type: Easing.InOutSine
                }
              }
            }
          }

          Connections {
            target: root
            function onSourceRevisionChanged() { videoContent.recreatePlayer() }
            function onActiveSourceChanged() {
              var player = videoContent.currentPlayer
              if (!player) return
              if (root.activeSource === "") player.stop()
              else if (root.backgroundPlaying) player.play()
            }
            function onBackgroundPlayingChanged() {
              var player = videoContent.currentPlayer
              if (!player) return
              if (root.backgroundPlaying) {
                root.syncVideoPosition(true)
                player.play()
              } else {
                player.pause()
              }
            }
            function onWallpaperDesiredChanged() {
              var player = videoContent.currentPlayer
              if (player && root.wallpaperDesired && root.backgroundPlaying) {
                root.syncVideoPosition(true)
                player.play()
              }
            }
          }
        }
      }

    }
  }

  Connections {
    target: root.service

    function onBackgroundVideoEnabledChanged() { root.syncWallpaper() }
    function onPausedChanged() { root.syncWallpaper() }
    function onPlayingChanged() { root.syncWallpaper() }
    function onBackgroundStreamUrlChanged() { root.syncWallpaper() }
    function onPlaybackPositionChanged() { root.syncVideoPosition(false) }
    function onCurrentTrackUrlChanged() {
      root.resolveRetryAttempts = 0
      root.wallpaperRecoveryAttempts = 0
      root.resetCandidateState()
    }
  }

  IpcHandler {
    id: mediaPlayerVideoIpc

    target: "lacuna-media-player-video"

    function status(): string {
      return JSON.stringify({
        loaded: true,
        hasService: root.service !== null,
        backgroundVisible: root.backgroundVisible,
        backgroundPlaying: root.backgroundPlaying,
        wallpaperDesired: root.wallpaperDesired,
        wallpaperRunning: root.activeSource !== "",
        backgroundVideoEnabled: root.service && root.service.backgroundVideoEnabled === true,
        presentationMode: root.presentationMode,
        presentationState: root.presentationState,
        handoffPhase: root.service && root.service.handoffPhase !== undefined ? String(root.service.handoffPhase || "") : "",
        rendererHandoffDeadlineActive: root.service && root.service.rendererHandoffDeadlineActive === true,
        presentationError: root.service && root.service.presentationErrorText !== undefined ? String(root.service.presentationErrorText || "") : "",
        desiredBackgroundVideo: root.desiredBackgroundVideo,
        videoQuality: root.videoQuality,
        playing: root.service && root.service.playing === true,
        paused: root.service && root.service.paused === true,
        previewReady: root.service && String(root.service.previewStreamUrl || "") !== "",
        currentTrackUrl: root.service ? String(root.service.currentTrackUrl || "") : "",
        backgroundReady: root.service && String(root.service.backgroundStreamUrl || "") !== "",
        backgroundResolving: root.service && root.service.resolvingBackground === true,
        backgroundResolveFailed: root.backgroundResolveFailed,
        backgroundRequestRevision: root.backgroundRequestRevision,
        playbackSessionRevision: root.playbackSessionRevision,
        waitingForHighRes: root.waitingForHighRes,
        waitingForPlayerReady: root.waitingForPlayerReady,
        adaptiveReady: root.adaptiveVideoSource !== "",
        progressiveReady: root.progressiveVideoSource !== "",
        activeCandidateKind: root.activeCandidateKind,
        usingProgressiveFallback: root.usingProgressiveFallback,
        fallbackReason: root.fallbackReason,
        hardSeekFailureCount: root.hardSeekFailureCount,
        driftCorrectionBlocked: root.driftCorrectionBlocked,
        fadeCoverVisible: root.fadeCoverVisible,
        fadeCoverOpacity: root.fadeCoverOpacity,
        fadeCoverDuration: root.fadeCoverDuration,
        fadeRevealDelay: root.fadeRevealDelay,
        fadeCoverAgeMs: root.fadeCoverStartedAt > 0 ? Math.max(0, Date.now() - root.fadeCoverStartedAt) : 0,
        wallpaperLayerVisible: root.wallpaperLayerVisible,
        loadedPlayerCount: root.videoPlayers.length,
        expectedPlayerCount: root.expectedMatchedPlayerCount(),
        registeredPlayerCount: root.registeredMatchedPlayerCount(),
        matchedPlayersRegistered: root.allMatchedPlayersRegistered(),
        wallpaperFadeGateDelay: root.wallpaperFadeGateDelay,
        outputRegistrationTimeoutDuration: root.outputRegistrationTimeoutDuration,
        outputDiagnostics: root.outputDiagnostics("status"),
        activeHandoffToken: root.activeHandoffToken,
        sourceRevision: root.sourceRevision,
        adaptiveReadinessTimeoutDuration: root.adaptiveReadinessTimeoutDuration,
        reducedMotion: root.reducedMotion,
        wallpaperPositionRefreshPending: root.wallpaperPositionRefreshPending,
        // Preserve the compatibility field without exposing the signed stream
        // URL embedded in the internal refresh key.
        wallpaperPositionRefreshKey: root.wallpaperPositionRefreshKey !== "" ? "set" : "",
        exitTransitionActive: root.exitTransitionActive,
        clearingWallpaperAfterExit: root.clearingWallpaperAfterExit,
        activeStartPosition: root.activeStartPosition,
        targetOutput: root.targetOutput,
        mediaRestartAttempts: root.mediaRestartAttempts,
        resolveRetryAttempts: root.resolveRetryAttempts,
        wallpaperRecoveryAttempts: root.wallpaperRecoveryAttempts,
        backend: "qml-framed-video"
      })
    }
  }

  IpcHandler {
    target: "lacuna-youtube-music-video"

    function status(): string {
      return mediaPlayerVideoIpc.status()
    }
  }
}
