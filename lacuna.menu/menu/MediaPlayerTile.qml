import QtQuick
import QtQuick.Controls as QQC
import QtMultimedia
import Quickshell
import Quickshell.Widgets
import "../components"
import "../services"

Item {
  id: root

  signal openRequested()

  property var service: null
  property string surfaceId: "inline"
  property bool compact: false
  property color foreground: "#d8dee9"
  property color background: "#101315"
  property color accent: "#88c0d0"
  property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.48)
  property var designTokens: fallbackDesignTokens
  property string bodyFontFamily: "Hack Nerd Font Propo"
  property bool volumeOpen: false
  property bool previewPositionPending: false
  property int previewRecoveryAttempts: 0
  property double previewPlaybackStartedAt: 0
  property int previewTelemetrySamples: 0
  property int previewLastPosition: 0
  property int previewStablePositionTicks: 0
  property double previewLastTelemetryAt: 0
  property string previewLastEvent: "idle"
  property bool previewSuppressed: false
  property int previewDriftStrikes: 0
  property int previewLastSeekTarget: -1
  property double previewLastSeekAt: 0
  property int previewSourceRevision: 0
  property string assignedPreviewSource: ""
  property bool previewLoadingReportPending: false
  property bool previewLoadingAccepted: false
  property var activePreviewHandoffToken: null
  readonly property var previewPlayer: previewPlayerLoader.item
  readonly property bool previewPlayerLoaded: previewPlayerLoader.item !== null
  property real videoReveal: hasTrack ? 1 : 0
  property real layoutReveal: hasTrack ? 1 : 0

  activeFocusOnTab: false
  Accessible.role: Accessible.Button
  Accessible.name: hasTrack ? "Open media player for " + title : "Open media player"
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      root.openRequested()
      event.accepted = true
    }
  }

  readonly property bool available: service && service.available === true
  readonly property bool hasTrack: service && service.hasTrack === true
  readonly property bool playbackLoaded: service && service.playing === true
  readonly property bool hasPresentationState: service && service.presentationState !== undefined
  readonly property string presentationState: hasPresentationState ? String(service.presentationState) : ""
  readonly property bool presentationTransitioning: presentationState === "promoting"
    || presentationState === "demoting"
    || presentationState === "recovering"
  readonly property bool sentToBackground: hasPresentationState
    ? presentationState === "background"
    : service && service.backgroundVideoEnabled === true
  readonly property bool backgroundModeSelected: service && String(service.presentationMode || "auto") === "background"
  readonly property bool localPreviewVisible: hasTrack && !sentToBackground
  readonly property bool playing: service && service.playing === true && service.paused !== true
  readonly property string title: hasTrack ? service.displayTitle : (available ? "Media" : "Media unavailable")
  readonly property string subtitle: service ? service.statusText() : "Service disabled"
  readonly property string thumbnail: service && service.thumbnail ? String(service.thumbnail) : ""
  readonly property string thumbnailFallback: service && service.currentTrack && typeof service.thumbnailFallbackUrl === "function"
    ? String(service.thumbnailFallbackUrl(service.currentTrack)) : ""
  readonly property string previewUrl: service && service.previewStreamUrl ? String(service.previewStreamUrl) : ""
  readonly property string adaptivePreviewUrl: service && service.adaptivePreviewStreamUrl
    ? String(service.adaptivePreviewStreamUrl) : ""
  readonly property string progressivePreviewUrl: service && service.progressivePreviewStreamUrl
    ? String(service.progressivePreviewStreamUrl) : ""
  readonly property bool previewUsingAdaptive: adaptivePreviewUrl !== ""
    && previewUrl === adaptivePreviewUrl
    && progressivePreviewUrl !== ""
    && progressivePreviewUrl !== adaptivePreviewUrl
  readonly property bool reducedMotion: service && service.lacunaSettings
    && service.lacunaSettings.reduceMotion === true
  readonly property bool previewActive: previewUrl !== ""
  readonly property bool previewVideoActive: previewActive && !previewSuppressed
  readonly property bool previewRendererActive: playbackLoaded && previewVideoActive
  readonly property string desiredPreviewSource: previewRendererActive && localPreviewVisible ? previewUrl : ""
  readonly property bool previewSourceLoaded: previewPlayer !== null && String(previewPlayer.source || "") !== ""
  readonly property real playbackPosition: service && service.playbackPosition !== undefined ? Math.max(0, Number(service.playbackPosition) || 0) : 0
  readonly property int favoritesRevision: service && service.favoritesRevision !== undefined ? Number(service.favoritesRevision) : 0
  readonly property bool currentFavorite: favoritesRevision >= 0 && service && service.currentFavorite === true
  readonly property string repeatMode: service && service.repeatMode ? String(service.repeatMode) : "none"
  readonly property int streamVolume: service && service.volume !== undefined ? Number(service.volume) : 70
  readonly property int playbackRevision: service && service.playbackSessionRevision !== undefined
    ? Number(service.playbackSessionRevision) : 0
  readonly property int presentationRevision: service && service.presentationRevision !== undefined
    ? Number(service.presentationRevision) : 0
  readonly property string pendingHandoffSurface: service && service.pendingHandoffSurface !== undefined
    ? String(service.pendingHandoffSurface || "") : ""
  readonly property int previewRequestRevision: service && service.videoResolveRevision !== undefined
    ? Number(service.videoResolveRevision) : 0
  readonly property int tileInset: compact ? 8 : 10
  readonly property int previewWidth: Math.max(120, width - (tileInset * 2))
  readonly property int previewHeight: Math.round(previewWidth * 0.5625)
  readonly property real previewRevealHeight: previewHeight * videoReveal
  readonly property int previewTopGap: tileInset
  readonly property int expandedInfoTopGap: compact ? 7 : 9
  readonly property int collapsedLowerContentY: previewTopGap
  readonly property int expandedLowerContentY: previewTopGap + previewHeight + expandedInfoTopGap
  readonly property real revealedLowerContentY: collapsedLowerContentY + (expandedLowerContentY - collapsedLowerContentY) * layoutReveal
  readonly property int lowerContentHeight: compact ? 57 : 63
  readonly property int volumeRevealHeight: volumeOpen ? (compact ? 24 : 26) : 0
  readonly property int tileHeight: Math.round(revealedLowerContentY) + lowerContentHeight + 10 + volumeRevealHeight
  readonly property real collapsedContentOpacity: Math.max(0, Math.min(1, (0.3 - layoutReveal) / 0.3))
  readonly property real expandedContentOpacity: Math.max(0, Math.min(1, (layoutReveal - 0.58) / 0.42))

  Behavior on videoReveal {
    NumberAnimation {
      duration: root.reducedMotion ? 75 : (root.videoReveal > 0 ? 750 : 350)
      easing.type: Easing.OutCubic
    }
  }

  Behavior on layoutReveal {
    NumberAnimation {
      duration: root.reducedMotion ? 75 : (root.layoutReveal > 0 ? 750 : 350)
      easing.type: Easing.OutCubic
    }
  }

  function setVolumeFromX(localX, railWidth) {
    if (!service || railWidth <= 0) return
    service.setVolume(Math.round(Math.max(0, Math.min(1, localX / railWidth)) * 100))
  }

  function playerStateName(state) {
    if (state === MediaPlayer.PlayingState) return "playing"
    if (state === MediaPlayer.PausedState) return "paused"
    if (state === MediaPlayer.StoppedState) return "stopped"
    return "unknown"
  }

  function mediaStatusName(status) {
    if (status === MediaPlayer.NoMedia) return "no-media"
    if (status === MediaPlayer.LoadingMedia) return "loading"
    if (status === MediaPlayer.LoadedMedia) return "loaded"
    if (status === MediaPlayer.BufferingMedia) return "buffering"
    if (status === MediaPlayer.StalledMedia) return "stalled"
    if (status === MediaPlayer.BufferedMedia) return "buffered"
    if (status === MediaPlayer.EndOfMedia) return "end"
    if (status === MediaPlayer.InvalidMedia) return "invalid"
    return "unknown"
  }

  function resetPreviewTelemetry(reason) {
    previewTelemetrySamples = 0
    previewLastPosition = 0
    previewStablePositionTicks = 0
    previewDriftStrikes = 0
    previewLastSeekTarget = -1
    previewLastSeekAt = 0
    previewLastTelemetryAt = Date.now()
    previewLastEvent = reason || "reset"
    if (previewPlayer) previewPlayer.playbackRate = 1
  }

  function reportInlineAvailability() {
    if (service && typeof service.setInlineSurfaceAvailable === "function")
      service.setInlineSurfaceAvailable(root.visible && root.width > 0 && root.height > 0, surfaceId)
  }

  function makeInlineHandoffToken(nextSourceRevision) {
    return {
      surface: "inline",
      playbackRevision: playbackRevision,
      presentationRevision: presentationRevision,
      requestRevision: previewRequestRevision,
      sourceRevision: Math.max(1, Number(nextSourceRevision) || 1)
    }
  }

  function inlineHandoffDiagnostics(stage) {
    var player = previewPlayer
    var registered = player !== null && previewSourceLoaded
    var ready = player !== null && player.lacunaReady === true
    return {
      stage: String(stage || ""),
      expectedOutputs: localPreviewVisible ? 1 : 0,
      registeredOutputs: registered ? 1 : 0,
      readyOutputs: ready ? 1 : 0,
      outputs: [{
        name: "inline",
        registered: registered,
        sourceMatched: registered,
        ready: ready,
        playbackState: player ? playerStateName(player.playbackState) : "stopped",
        mediaStatus: player ? mediaStatusName(player.mediaStatus) : "no-media",
        converged: player ? Math.abs(player.position - Math.max(0, Math.round(playbackPosition * 1000))) < 400 : false,
        error: player ? player.mediaStatus === MediaPlayer.InvalidMedia : false
      }]
    }
  }

  function inlineTokenIsCurrent() {
    return activePreviewHandoffToken
      && Number(activePreviewHandoffToken.playbackRevision) === playbackRevision
      && Number(activePreviewHandoffToken.presentationRevision) === presentationRevision
      && Number(activePreviewHandoffToken.requestRevision) === previewRequestRevision
      && Number(activePreviewHandoffToken.sourceRevision) === previewSourceRevision
  }

  function inlineSourceGenerationIsCurrent(player) {
    // Renderer lifetime follows media source generation, not presentation
    // intent. Promotion must keep the working inline player alive while the
    // background destination loads under cover.
    return player
      && Number(player.lacunaSourceRevision) === previewSourceRevision
      && String(player.source || "") === assignedPreviewSource
  }

  function previewEventIsCurrent(player) {
    return player && player === previewPlayer && inlineSourceGenerationIsCurrent(player)
  }

  function recreatePreviewPlayer() {
    previewPlayerLoader.active = false
    previewPlayerLoader.generation = previewSourceRevision
    previewPlayerLoader.sourceUrl = assignedPreviewSource
    previewPlayerLoader.active = assignedPreviewSource !== ""
  }

  function reportInlineLoading() {
    if (!root.visible) return
    if (previewLoadingReportPending && activePreviewHandoffToken && assignedPreviewSource !== ""
        && service && typeof service.reportVideoLoading === "function") {
      previewLoadingAccepted = service.reportVideoLoading("inline", activePreviewHandoffToken,
        inlineHandoffDiagnostics("loading-renderer")) === true
      // A presentation revision can reach this tile before the service has
      // published pendingHandoffSurface. Keep the report pending and retry
      // when that destination binding changes instead of losing the handoff.
      previewLoadingReportPending = !previewLoadingAccepted
    }
  }

  function finishPreviewPlayerLoad() {
    if (!previewPlayer) return
    reportInlineLoading()
    syncPreviewPlayback()
  }

  function syncPreviewSource() {
    var desired = String(desiredPreviewSource || "")
    if (desired === "") {
      if (assignedPreviewSource === "" && !activePreviewHandoffToken) return
      activePreviewHandoffToken = null
      assignedPreviewSource = ""
      previewLoadingReportPending = false
      recreatePreviewPlayer()
      return
    }
    if (assignedPreviewSource === desired) {
      // A new demotion intent needs a fresh report token, but not a fresh
      // decoder. Presentation-only revisions must never reload the same URL.
      if (pendingHandoffSurface === "inline" && !inlineTokenIsCurrent()) {
        activePreviewHandoffToken = makeInlineHandoffToken(previewSourceRevision)
        previewLoadingAccepted = false
        previewLoadingReportPending = true
        reportInlineLoading()
        // The retained inline decoder may already have a presented frame, so
        // no new videoSink event will arrive for this handoff-only token.
        if (previewLoadingAccepted && previewPlayer && previewPlayer.lacunaReady === true)
          reportInlineReady(previewPlayer)
      }
      return
    }
    previewSourceRevision += 1
    activePreviewHandoffToken = makeInlineHandoffToken(previewSourceRevision)
    assignedPreviewSource = desired
    previewLoadingAccepted = false
    previewLoadingReportPending = true
    recreatePreviewPlayer()
    // Loader onLoaded can be coalesced when an existing player is replaced in
    // one event turn. Report the assigned generation directly as well; the
    // service treats duplicate loading for the same token as idempotent.
    reportInlineLoading()
  }

  function markInlineFrameReady(player) {
    if (!previewEventIsCurrent(player) || player.lacunaReady === true) return
    previewFrameReadyFallbackTimer.stop()
    player.lacunaReady = true
    syncPreviewPosition(true)
    reportInlineReady(player)
  }

  function reportInlineReady(player) {
    var renderer = player || previewPlayer
    if (!previewEventIsCurrent(renderer) || renderer.lacunaReady !== true
        || renderer.playbackState !== MediaPlayer.PlayingState
        || !service || typeof service.reportVideoReady !== "function"
        || !previewVideoActive || !localPreviewVisible)
      return

    var target = Math.max(0, Math.round(playbackPosition * 1000))
    if (Math.abs(renderer.position - target) < 400)
      service.reportVideoReady("inline", playbackRevision,
        Math.max(0, Number(renderer.position) || 0) / 1000,
        activePreviewHandoffToken, inlineHandoffDiagnostics("presented"))
  }

  function reportInlineFailure(reason, player) {
    var renderer = player || previewPlayer
    if (previewEventIsCurrent(renderer) && service && typeof service.reportVideoFailure === "function")
      service.reportVideoFailure("inline", playbackRevision, reason || "renderer",
        activePreviewHandoffToken, inlineHandoffDiagnostics("failed"))
  }

  function samplePreviewTelemetry(reason) {
    var position = Math.max(0, Math.round(Number(previewPlayer.position) || 0))
    if (previewTelemetrySamples > 0 && Math.abs(position - previewLastPosition) < 80 && previewPlayer.playbackState === MediaPlayer.PlayingState)
      previewStablePositionTicks += 1
    else
      previewStablePositionTicks = 0

    previewTelemetrySamples += 1
    previewLastPosition = position
    previewLastTelemetryAt = Date.now()
    previewLastEvent = reason || "sample"
    if (service && typeof service.updatePreviewTelemetry === "function")
      service.updatePreviewTelemetry(previewDiagnosticPayload())
  }

  function previewDiagnosticPayload() {
    return {
      loaded: playbackLoaded && String(previewPlayer.source || "") !== "",
      available: available,
      hasTrack: hasTrack,
      playing: playing,
      localPreviewVisible: localPreviewVisible,
      previewActive: previewActive,
      previewSuppressed: previewSuppressed,
      previewUrlReady: previewUrl !== "",
      previewUsingAdaptive: previewUsingAdaptive,
      playbackState: playerStateName(previewPlayer.playbackState),
      mediaStatus: mediaStatusName(previewPlayer.mediaStatus),
      playerPositionMs: Math.max(0, Math.round(Number(previewPlayer.position) || 0)),
      servicePositionSeconds: playbackPosition,
      durationMs: Math.max(0, Math.round(Number(previewPlayer.duration) || 0)),
      seekable: previewPlayer.seekable,
      positionPending: previewPositionPending,
      recoveryAttempts: previewRecoveryAttempts,
      driftStrikes: previewDriftStrikes,
      playbackStartedAgeMs: previewPlaybackStartedAt > 0 ? Math.max(0, Math.round(Date.now() - previewPlaybackStartedAt)) : 0,
      telemetrySamples: previewTelemetrySamples,
      stablePositionTicks: previewStablePositionTicks,
      lastPositionMs: previewLastPosition,
      lastTelemetryAgeMs: previewLastTelemetryAt > 0 ? Math.max(0, Math.round(Date.now() - previewLastTelemetryAt)) : 0,
      lastEvent: previewLastEvent,
      likelyFrozen: previewPlayer.playbackState === MediaPlayer.PlayingState && previewStablePositionTicks >= 4,
      backgroundVideoEnabled: service && service.backgroundVideoEnabled === true,
      serviceInstanceId: service && service.serviceInstanceId ? String(service.serviceInstanceId) : "",
      presentationRevision: presentationRevision,
      requestRevision: previewRequestRevision,
      sourceRevision: previewSourceRevision,
      tokenPresent: activePreviewHandoffToken !== null,
      tokenPlaybackRevision: activePreviewHandoffToken ? Number(activePreviewHandoffToken.playbackRevision) : -1,
      tokenPresentationRevision: activePreviewHandoffToken ? Number(activePreviewHandoffToken.presentationRevision) : -1,
      tokenRequestRevision: activePreviewHandoffToken ? Number(activePreviewHandoffToken.requestRevision) : -1,
      tokenSourceRevision: activePreviewHandoffToken ? Number(activePreviewHandoffToken.sourceRevision) : -1,
      loadingReportPending: previewLoadingReportPending,
      loadingAccepted: previewLoadingAccepted,
      sourceAssigned: assignedPreviewSource !== "",
      playerPresent: previewPlayer !== null,
      tileVisible: root.visible
    }
  }

  function syncPreviewPlayback() {
    if (!previewPlayer) return
    if (!playbackLoaded) {
      previewPositionSettleTimer.stop()
      previewRecoveryTimer.stop()
      previewPositionPending = false
      previewRecoveryAttempts = 0
      previewPlaybackStartedAt = 0
      resetPreviewTelemetry("stopped")
      previewPlayer.stop()
      samplePreviewTelemetry("stopped")
      return
    }
    if (!previewVideoActive) {
      previewPositionSettleTimer.stop()
      previewRecoveryTimer.stop()
      previewPositionPending = false
      previewRecoveryAttempts = 0
      previewPlaybackStartedAt = 0
      resetPreviewTelemetry("inactive")
      previewPlayer.stop()
      return
    }
    if (!localPreviewVisible) {
      previewPositionSettleTimer.stop()
      previewRecoveryTimer.stop()
      previewPositionPending = false
      previewRecoveryAttempts = 0
      previewPlaybackStartedAt = 0
      resetPreviewTelemetry("hidden")
      previewPlayer.pause()
      return
    }
    if (playing) {
      previewPlayer.play()
      previewPositionPending = true
      // Catch up to the live playback position immediately on resume; the
      // 1800ms settle deferral is for cold source loads, and waiting that
      // long lets the drift watchdog fire first.
      syncPreviewPosition(true)
      samplePreviewTelemetry("play-request")
      previewRecoveryTimer.restart()
    } else {
      previewPositionSettleTimer.stop()
      previewRecoveryTimer.stop()
      previewPositionPending = false
      previewRecoveryAttempts = 0
      previewPlaybackStartedAt = 0
      samplePreviewTelemetry("pause-request")
      previewPlayer.playbackRate = 1
      previewPlayer.pause()
      reportInlineReady()
    }
  }

  function previewCanSeek() {
    return previewPlayer && (previewPlayer.mediaStatus === MediaPlayer.LoadedMedia
      || previewPlayer.mediaStatus === MediaPlayer.BufferedMedia
      || previewPlayer.playbackState === MediaPlayer.PlayingState)
  }

  function previewBuffering() {
    return previewPlayer.mediaStatus === MediaPlayer.BufferingMedia
      || previewPlayer.mediaStatus === MediaPlayer.StalledMedia
  }

  function previewStartupSettling() {
    return previewPlaybackStartedAt > 0 && Date.now() - previewPlaybackStartedAt < 1800
  }

  function syncPreviewPosition(force) {
    if (!previewVideoActive || previewPlayer.playbackState === MediaPlayer.StoppedState) return
    if (!previewCanSeek()) {
      previewPositionPending = true
      previewPositionSettleTimer.restart()
      return
    }
    if (!force && previewStartupSettling()) {
      previewPositionPending = true
      previewPositionSettleTimer.restart()
      return
    }
    if (!force && previewBuffering()) return
    var target = Math.max(0, Math.round(playbackPosition * 1000))
    var signedDrift = previewPlayer.position - target
    var drift = Math.abs(signedDrift)
    if (drift < 400) {
      previewPositionPending = false
      previewDriftStrikes = 0
      previewPlayer.playbackRate = 1
      reportInlineReady()
      return
    }

    if (drift <= 1500) {
      previewPositionPending = true
      previewDriftStrikes = 0
      previewPlayer.playbackRate = signedDrift < 0 ? 1.03 : 0.97
      reportInlineReady()
      return
    }

    previewPlayer.playbackRate = 1
    if (previewLastSeekAt > 0 && Date.now() - previewLastSeekAt < 1500) {
      previewPositionPending = true
      return
    }

    previewPlayer.setPosition(target)
    previewLastSeekTarget = target
    previewLastSeekAt = Date.now()
    previewPositionPending = true
    previewDriftStrikes += 1
    if (previewDriftStrikes === 2)
      reportInlineFailure("seek-correction")
    previewPositionSettleTimer.restart()
    samplePreviewTelemetry("seek")
  }

  function maintainPreviewPosition() {
    samplePreviewTelemetry("periodic")
    if (!previewVideoActive || !localPreviewVisible || !playing) {
      previewPlayer.playbackRate = 1
      return
    }
    var target = Math.max(0, Math.round(playbackPosition * 1000))
    var drift = Math.abs(previewPlayer.position - target)
    if (drift < 400) {
      previewDriftStrikes = 0
      previewPositionPending = false
      previewPlayer.playbackRate = 1
      reportInlineReady()
      return
    }
    syncPreviewPosition(false)
  }

  function recoverPreviewPlayback() {
    if (!previewVideoActive || !localPreviewVisible || !playing) {
      previewRecoveryAttempts = 0
      return
    }
    if (previewPlayer.playbackState === MediaPlayer.PlayingState || previewPlayer.mediaStatus === MediaPlayer.LoadingMedia || previewPlayer.mediaStatus === MediaPlayer.BufferingMedia || previewPlayer.mediaStatus === MediaPlayer.StalledMedia) {
      previewRecoveryAttempts = 0
      return
    }
    if (previewPlayer.mediaStatus !== MediaPlayer.InvalidMedia && previewPlayer.playbackState !== MediaPlayer.StoppedState) return
    if (previewRecoveryAttempts >= 3) return
    previewRecoveryAttempts += 1
    previewPlayer.stop()
    previewPlayer.play()
    previewPositionPending = true
    samplePreviewTelemetry("recover")
    previewPositionSettleTimer.restart()
    previewRecoveryTimer.restart()
  }

  function syncAdaptiveReadinessTimer() {
    if (previewUsingAdaptive && previewVideoActive && localPreviewVisible && playing)
      previewAdaptiveReadinessTimer.restart()
    else
      previewAdaptiveReadinessTimer.stop()
  }

  function handleAdaptiveReadinessTimeout() {
    if (previewUsingAdaptive && previewVideoActive && localPreviewVisible && playing)
      reportInlineFailure("adaptive-readiness-timeout")
  }

  onPlayingChanged: {
    syncPreviewPlayback()
    syncAdaptiveReadinessTimer()
  }
  onPlaybackLoadedChanged: {
    syncPreviewPlayback()
    syncAdaptiveReadinessTimer()
  }
  onPreviewActiveChanged: {
    syncPreviewPlayback()
    syncAdaptiveReadinessTimer()
  }
  onDesiredPreviewSourceChanged: syncPreviewSource()
  onPlaybackRevisionChanged: syncPreviewSource()
  onPresentationRevisionChanged: syncPreviewSource()
  onPendingHandoffSurfaceChanged: {
    if (pendingHandoffSurface === "inline") {
      // Service publishes presentationRevision before the destination. Build
      // the destination token now that both halves of the intent are visible.
      syncPreviewSource()
      reportInlineLoading()
    }
  }
  onPreviewRequestRevisionChanged: syncPreviewSource()
  onPreviewUrlChanged: {
    previewSuppressed = false
    syncAdaptiveReadinessTimer()
    syncPreviewPlayback()
  }
  onLocalPreviewVisibleChanged: {
    // Returning from desktop-background mode must give a suppressed preview
    // another chance: the suppression latch otherwise only clears on a URL
    // change, leaving the tile on a static thumbnail for the whole track.
    if (localPreviewVisible) previewSuppressed = false
    syncAdaptiveReadinessTimer()
    syncPreviewPlayback()
    reportInlineAvailability()
  }
  onPlaybackPositionChanged: if (previewPositionPending) syncPreviewPosition(false)
  onVisibleChanged: {
    reportInlineAvailability()
    if (visible) {
      syncPreviewSource()
      reportInlineLoading()
    }
  }
  onWidthChanged: reportInlineAvailability()
  onHeightChanged: reportInlineAvailability()

  Component.onCompleted: {
    reportInlineAvailability()
    syncPreviewSource()
  }
  Component.onDestruction: {
    if (service && typeof service.setInlineSurfaceAvailable === "function")
      service.setInlineSurfaceAvailable(false, surfaceId)
  }

  width: parent ? parent.width : 260
  height: tileHeight
  visible: service !== null

  LacunaRect {
    anchors.fill: parent
    radius: root.designTokens.radius
    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, stateLayer.reveal * 0.055)
    border.width: root.designTokens.lacuna ? 0 : 1
    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.24)

    LacunaRect {
      visible: root.designTokens.lacuna
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: 1
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
    }

    LacunaStateLayer {
      id: stateLayer
      anchors.fill: parent
      stateColor: root.accent
      hoverOpacity: root.designTokens.hoverOpacity
      pressOpacity: root.designTokens.activeOpacity
      showFill: false
      onTriggered: {
        root.forceActiveFocus()
        root.openRequested()
      }
    }

    LacunaIconButton {
      id: tileFavoriteButton

      z: 4
      anchors.top: parent.top
      anchors.topMargin: root.tileInset
      anchors.right: parent.right
      anchors.rightMargin: root.tileInset
      icon: root.currentFavorite ? "heart-filled" : "heart"
      accessibleName: root.currentFavorite ? "Remove from favorites" : "Add to favorites"
      disabled: !root.hasTrack
      opacity: disabled ? 0.42 : 1
      foreground: root.foreground
      muted: root.currentFavorite ? root.accent : root.muted
      accent: root.accent
      hoverAccent: root.accent
      buttonSize: root.compact ? 24 : 26
      buttonRadius: root.designTokens.controlRadius
      hoverOpacity: root.designTokens.hoverOpacity
      pressOpacity: root.designTokens.activeOpacity
      iconSize: root.compact ? 13 : 14
      iconHoverScale: 1.28
      onTriggered: if (root.service) root.service.toggleFavorite(root.service.currentTrack)
    }

    Rectangle {
      id: previewFrame
      anchors.top: parent.top
      anchors.topMargin: root.previewTopGap
      anchors.horizontalCenter: parent.horizontalCenter
      width: root.previewWidth
      height: root.previewRevealHeight
      radius: root.designTokens.controlRadius
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
      opacity: root.videoReveal
      visible: root.videoReveal > 0.01
      clip: true

      Loader {
        id: previewPlayerLoader
        property int generation: 0
        property string sourceUrl: ""
        active: false
        sourceComponent: previewPlayerComponent
        onLoaded: root.finishPreviewPlayerLoad()
      }

      Component {
        id: previewPlayerComponent

        MediaPlayer {
          id: previewPlayerInstance
          property bool lacunaReady: false
          readonly property int lacunaSourceRevision: previewPlayerLoader.generation
          // Each token generation gets a new QtMultimedia instance. Late
          // backend events from a destroyed adaptive instance therefore
          // cannot be reported with the current progressive token.
          source: previewPlayerLoader.sourceUrl
          videoOutput: previewOutput
          audioOutput: AudioOutput {
            muted: true
            volume: 0
          }
          loops: MediaPlayer.Infinite
          onSourceChanged: {
            lacunaReady = false
            previewFrameReadyFallbackTimer.stop()
            root.resetPreviewTelemetry("source")
            root.syncPreviewPlayback()
          }
          onPlaybackStateChanged: {
            if (!root.previewEventIsCurrent(previewPlayerInstance)) return
            root.samplePreviewTelemetry("playback-" + root.playerStateName(playbackState))
            if (playbackState === MediaPlayer.PlayingState) {
              // Returning from the background can reuse the same source. Lock
              // immediately instead of waiting for the settle timer.
              root.syncPreviewPosition(true)
              previewAdaptiveReadinessTimer.stop()
              if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferingMedia
                  || mediaStatus === MediaPlayer.BufferedMedia) previewFrameReadyFallbackTimer.restart()
              root.previewRecoveryAttempts = 0
              root.previewPlaybackStartedAt = Date.now()
              previewRecoveryTimer.stop()
              previewPositionSettleTimer.interval = 1800
              previewPositionSettleTimer.restart()
            } else if (root.previewVideoActive && root.localPreviewVisible && root.playing) {
              previewRecoveryTimer.restart()
            }
          }
          onMediaStatusChanged: {
            if (!root.previewEventIsCurrent(previewPlayerInstance)) return
            root.samplePreviewTelemetry("media-" + root.mediaStatusName(mediaStatus))
            if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferingMedia
                || mediaStatus === MediaPlayer.BufferedMedia) {
              previewAdaptiveReadinessTimer.stop()
              if (root.playing && root.localPreviewVisible) previewPlayerInstance.play()
              if (root.playing && root.localPreviewVisible) root.syncPreviewPosition(true)
              if (playbackState === MediaPlayer.PlayingState) previewFrameReadyFallbackTimer.restart()
              if (root.previewPositionPending && !root.previewStartupSettling()) {
                previewPositionSettleTimer.interval = 350
                previewPositionSettleTimer.restart()
              }
            } else if (mediaStatus === MediaPlayer.InvalidMedia && root.previewVideoActive && root.localPreviewVisible && root.playing) {
              root.reportInlineFailure("invalid-media", previewPlayerInstance)
              previewRecoveryTimer.restart()
            }
          }
        }
      }

      VideoOutput {
        id: previewOutput
        anchors.fill: parent
        visible: root.previewRendererActive
        fillMode: VideoOutput.PreserveAspectCrop
      }

      Connections {
        target: previewOutput.videoSink
        function onVideoFrameChanged(frame) {
          var player = root.previewPlayer
          if (!player || player.playbackState !== MediaPlayer.PlayingState) return
          if (!frame || (typeof frame.isValid === "function" && !frame.isValid())) return
          root.markInlineFrameReady(player)
        }
      }

      Image {
        anchors.fill: parent
        property string primaryThumbnail: root.thumbnail
        property bool thumbnailFailed: false
        source: thumbnailFailed && root.thumbnailFallback !== "" ? root.thumbnailFallback : primaryThumbnail
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: root.previewVideoActive && root.previewPlayer
          && root.previewPlayer.lacunaReady === true ? 0 : 1
        visible: root.thumbnail !== "" && status !== Image.Error && opacity > 0
        onPrimaryThumbnailChanged: thumbnailFailed = false
        onStatusChanged: if (status === Image.Error && root.thumbnailFallback !== "") thumbnailFailed = true

        Behavior on opacity {
          LacunaAnim { motion: "fast" }
        }
      }

      LacunaTablerIcon {
        anchors.centerIn: parent
        visible: root.thumbnail === "" && !root.previewVideoActive
        name: "music"
        color: root.available ? root.accent : root.muted
        iconSize: root.compact ? 22 : 26
      }
    }

    Component {
      id: lowerContentComponent

      Item {
        id: contentRoot

        width: parent ? parent.width : 0
        height: root.lowerContentHeight

        Column {
          id: infoColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.rightMargin: root.tileInset + tileFavoriteButton.width
          anchors.top: parent.top
          spacing: root.compact ? 1 : 2

          LacunaText {
            width: parent.width
            text: root.title
            color: root.foreground
            fontFamily: root.bodyFontFamily
            font.pixelSize: root.compact ? 10 : 11
            font.weight: Font.DemiBold
            maximumLineCount: 1
            elide: Text.ElideRight
          }

          LacunaText {
            width: parent.width
            text: root.subtitle
            color: root.playing ? root.accent : root.muted
            fontFamily: root.bodyFontFamily
            font.pixelSize: root.compact ? 8 : 9
            maximumLineCount: 1
            elide: Text.ElideRight
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: infoColumn.bottom
          anchors.topMargin: root.compact ? 6 : 7
          spacing: 6

          LacunaIconButton {
            icon: "player-skip-back"
            accessibleName: "Previous track or restart"
            foreground: root.foreground
            muted: root.muted
            accent: root.accent
            hoverAccent: root.accent
            buttonSize: root.compact ? 24 : 26
            buttonRadius: root.designTokens.controlRadius
            hoverOpacity: root.designTokens.hoverOpacity
            pressOpacity: root.designTokens.activeOpacity
            iconSize: root.compact ? 13 : 14
            iconHoverScale: 1.28
            onTriggered: if (root.service) root.service.previousOrRestart()
          }

          LacunaIconButton {
            icon: root.playing ? "player-pause" : "player-play"
            accessibleName: root.playing ? "Pause" : "Play"
            foreground: root.foreground
            muted: root.muted
            accent: root.accent
            hoverAccent: root.accent
            buttonSize: root.compact ? 24 : 26
            buttonRadius: root.designTokens.controlRadius
            hoverOpacity: root.designTokens.hoverOpacity
            pressOpacity: root.designTokens.activeOpacity
            iconSize: root.compact ? 13 : 14
            iconHoverScale: 1.28
            onTriggered: if (root.service) root.service.togglePause()
          }

          LacunaIconButton {
            icon: "player-stop"
            accessibleName: "Stop"
            foreground: root.foreground
            muted: root.muted
            accent: root.accent
            hoverAccent: root.accent
            buttonSize: root.compact ? 24 : 26
            buttonRadius: root.designTokens.controlRadius
            hoverOpacity: root.designTokens.hoverOpacity
            pressOpacity: root.designTokens.activeOpacity
            iconSize: root.compact ? 13 : 14
            iconHoverScale: 1.28
            onTriggered: if (root.service) root.service.stop()
          }

          LacunaIconButton {
            icon: "player-skip-forward"
            accessibleName: "Next track"
            foreground: root.foreground
            muted: root.muted
            accent: root.accent
            hoverAccent: root.accent
            buttonSize: root.compact ? 24 : 26
            buttonRadius: root.designTokens.controlRadius
            hoverOpacity: root.designTokens.hoverOpacity
            pressOpacity: root.designTokens.activeOpacity
            iconSize: root.compact ? 13 : 14
            iconHoverScale: 1.28
            onTriggered: if (root.service) root.service.next()
          }

          LacunaIconButton {
            icon: root.repeatMode === "one" ? "repeat-once" : "repeat"
            accessibleName: "Change repeat mode"
            foreground: root.foreground
            muted: root.repeatMode === "none" ? root.muted : root.accent
            accent: root.accent
            hoverAccent: root.accent
            buttonSize: root.compact ? 24 : 26
            buttonRadius: root.designTokens.controlRadius
            hoverOpacity: root.designTokens.hoverOpacity
            pressOpacity: root.designTokens.activeOpacity
            iconSize: root.compact ? 13 : 14
            iconHoverScale: 1.28
            onTriggered: if (root.service) root.service.cycleRepeatMode()
          }

          LacunaIconButton {
            icon: "background"
            accessibleName: "Toggle background video"
            foreground: root.backgroundModeSelected ? root.accent : root.foreground
            muted: root.backgroundModeSelected ? root.accent : root.muted
            accent: root.accent
            hoverAccent: root.accent
            buttonSize: root.compact ? 24 : 26
            buttonRadius: root.designTokens.controlRadius
            hoverOpacity: root.designTokens.hoverOpacity
            pressOpacity: root.designTokens.activeOpacity
            iconSize: root.compact ? 13 : 14
            iconHoverScale: 1.28
            onTriggered: if (root.service) root.service.toggleBackgroundVideo()
            QQC.ToolTip.visible: hovered
            QQC.ToolTip.delay: 450
            QQC.ToolTip.text: "Background video"
          }

          LacunaIconButton {
            icon: "volume"
            accessibleName: "Volume"
            foreground: root.foreground
            muted: root.muted
            accent: root.accent
            hoverAccent: root.accent
            buttonSize: root.compact ? 24 : 26
            buttonRadius: root.designTokens.controlRadius
            hoverOpacity: root.designTokens.hoverOpacity
            pressOpacity: root.designTokens.activeOpacity
            iconSize: root.compact ? 13 : 14
            iconHoverScale: 1.28
            onTriggered: {
              root.volumeOpen = !root.volumeOpen
              if (root.volumeOpen) hideVolumeTimer.restart()
              else hideVolumeTimer.stop()
            }
          }

          LacunaIconButton {
            icon: "list"
            accessibleName: "Open queue"
            foreground: root.foreground
            muted: root.muted
            accent: root.accent
            hoverAccent: root.accent
            buttonSize: root.compact ? 24 : 26
            buttonRadius: root.designTokens.controlRadius
            hoverOpacity: root.designTokens.hoverOpacity
            pressOpacity: root.designTokens.activeOpacity
            iconSize: root.compact ? 13 : 14
            iconHoverScale: 1.28
            onTriggered: root.openRequested()
          }
        }
      }
    }

    Loader {
      id: collapsedContent
      x: root.tileInset
      y: root.collapsedLowerContentY
      width: Math.max(0, parent.width - root.tileInset * 2)
      height: root.lowerContentHeight
      active: root.layoutReveal < 0.45
      opacity: root.collapsedContentOpacity
      enabled: opacity > 0.01
      sourceComponent: lowerContentComponent
      visible: active && opacity > 0.01
    }

    Loader {
      id: expandedContent
      x: root.tileInset
      y: root.expandedLowerContentY
      width: Math.max(0, parent.width - root.tileInset * 2)
      height: root.lowerContentHeight
      active: root.layoutReveal > 0.35
      opacity: root.expandedContentOpacity
      enabled: opacity > 0.01
      sourceComponent: lowerContentComponent
      visible: active && opacity > 0.01
    }


    Row {
      id: volumeRow
      anchors.left: parent.left
      anchors.leftMargin: root.tileInset
      anchors.right: parent.right
      anchors.rightMargin: root.tileInset
      y: Math.round(root.revealedLowerContentY) + root.lowerContentHeight + (root.volumeOpen ? (root.compact ? 6 : 7) : 0)
      height: root.volumeRevealHeight
      opacity: root.volumeOpen ? 1 : 0
      visible: height > 0
      clip: true
      spacing: 6

      Behavior on height {
        LacunaAnim { motion: "fast" }
      }

      Behavior on opacity {
        LacunaAnim { motion: "fast" }
      }

      Item {
        id: volumeRail
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - volumeValue.width - parent.spacing
        height: parent.height
        activeFocusOnTab: false
        Accessible.role: Accessible.Slider
        Accessible.name: "Volume"
        Accessible.description: String(root.streamVolume) + " percent"
        Keys.onPressed: function(event) {
          if (!root.service) return
          if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) root.service.adjustVolume(-5)
          else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) root.service.adjustVolume(5)
          else if (event.key === Qt.Key_Home) root.service.setVolume(0)
          else if (event.key === Qt.Key_End) root.service.setVolume(100)
          else return
          root.volumeOpen = true
          hideVolumeTimer.restart()
          event.accepted = true
        }

        LacunaRect {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          height: 4
          radius: 2
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
        }

        LacunaRect {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(4, parent.width * root.streamVolume / 100)
          height: 4
          radius: 2
          color: root.accent
        }

        LacunaRect {
          x: Math.max(0, Math.min(parent.width - width, parent.width * root.streamVolume / 100 - width / 2))
          anchors.verticalCenter: parent.verticalCenter
          width: root.compact ? 10 : 11
          height: width
          radius: width / 2
          color: root.foreground
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onPressed: function(mouse) {
            volumeRail.forceActiveFocus()
            root.volumeOpen = true
            hideVolumeTimer.stop()
            root.setVolumeFromX(mouse.x, volumeRail.width)
          }
          onPositionChanged: function(mouse) { if (pressed) root.setVolumeFromX(mouse.x, volumeRail.width) }
          onReleased: hideVolumeTimer.restart()
          onWheel: function(wheel) {
            if (root.service) root.service.adjustVolume(wheel.angleDelta.y > 0 ? 5 : -5)
            root.volumeOpen = true
            hideVolumeTimer.restart()
            wheel.accepted = true
          }
        }
      }

      LacunaText {
        id: volumeValue
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        horizontalAlignment: Text.AlignRight
        text: String(root.streamVolume)
        color: root.muted
        fontFamily: root.bodyFontFamily
        font.pixelSize: root.compact ? 8 : 9
      }
    }

    Timer {
      id: hideVolumeTimer
      interval: 2600
      repeat: false
      onTriggered: root.volumeOpen = false
    }

    Timer {
      id: previewPositionSettleTimer
      interval: 350
      repeat: false
      onTriggered: {
        interval = 350
        root.syncPreviewPosition(true)
      }
    }

    Timer {
      id: previewRecoveryTimer
      interval: 900
      repeat: false
      onTriggered: root.recoverPreviewPlayback()
    }

    Timer {
      id: previewFrameReadyFallbackTimer
      interval: 140
      repeat: false
      onTriggered: {
        var player = root.previewPlayer
        if (!root.previewEventIsCurrent(player) || player.lacunaReady === true) return
        if (player.playbackState !== MediaPlayer.PlayingState) return
        if (player.mediaStatus !== MediaPlayer.LoadedMedia
            && player.mediaStatus !== MediaPlayer.BufferingMedia
            && player.mediaStatus !== MediaPlayer.BufferedMedia) return
        root.markInlineFrameReady(player)
      }
    }

    Timer {
      id: previewAdaptiveReadinessTimer
      interval: 4000
      repeat: false
      onTriggered: root.handleAdaptiveReadinessTimeout()
    }

    Timer {
      interval: 250
      repeat: true
      running: root.previewVideoActive && root.localPreviewVisible && root.playing
      onTriggered: root.maintainPreviewPosition()
    }
  }

  DesignTokens {
    id: fallbackDesignTokens
    compact: root.compact
    foreground: root.foreground
    background: root.background
    accent: root.accent
  }
}
