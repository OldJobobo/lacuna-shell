import unittest
from pathlib import Path

from qml_harness import HAVE_SESSION, parse_behave, qml_url, require_no_qml_errors, run_quickshell

ROOT = Path(__file__).resolve().parents[1]


def read_overlay() -> str:
    return (ROOT / "lacuna.media-player-video/Overlay.qml").read_text(encoding="utf-8")


class MediaOverlayContractTests(unittest.TestCase):
    def test_presentation_handoff_keeps_background_during_transition_states(self):
        overlay = read_overlay()

        self.assertIn('presentationState === "promoting"', overlay)
        self.assertIn('presentationState === "demoting"', overlay)
        self.assertIn('presentationState === "recovering"', overlay)
        self.assertIn('if (presentationState === "inline" && service && service.desiredBackgroundVideo !== undefined)', overlay)
        self.assertIn('if (presentationState === "inline") return false', overlay)
        self.assertIn('service.reportVideoLoading("background", activeHandoffToken,', overlay)
        self.assertIn('outputDiagnostics(String(stage || "loading-renderer"))', overlay)
        self.assertIn('service.reportVideoReady("background", playbackSessionRevision, surfacePosition,', overlay)
        self.assertIn('service.reportVideoFailure("background", playbackSessionRevision, normalizedReason,', overlay)

    def test_transition_timing_and_source_swap_are_bounded(self):
        overlay = read_overlay()

        for timing in [
            "normalFadeCoverRiseDuration: 220",
            "normalSourceHoldDuration: 80",
            "normalFadeInDuration: 850",
            "normalExitFadeToBlackDuration: 240",
            "normalExitFadeFromBlackDuration: 700",
            "reducedMotionDuration: 75",
            "outputRegistrationTimeoutDuration: 5000",
        ]:
            self.assertIn(timing, overlay)
        token_assignment = overlay.index("activeHandoffToken = makeHandoffToken(sourceRevision)")
        source_assignment = overlay.index("activeSource = videoSource", token_assignment)
        loading_report = overlay.index("reportLoading()", source_assignment)
        self.assertLess(token_assignment, source_assignment)
        self.assertLess(source_assignment, loading_report)
        self.assertIn("root.finishGiveUpWallpaper()", overlay)
        self.assertIn("visible: true", overlay)
        self.assertIn("readonly property bool renderable: targetMatched && root.wallpaperLayerVisible", overlay)
        self.assertIn("id: videoContentLoader", overlay)
        self.assertIn("active: videoWindow.renderable", overlay)
        self.assertIn("sourceComponent: videoContentComponent", overlay)
        self.assertIn("loadedPlayerCount: root.videoPlayers.length", overlay)
        self.assertIn("if (!allMatchedPlayersRegistered()) {", overlay)
        self.assertIn("if (!allMatchedPlayersReadyFor(activeSource) || !activePlayersConverged(400))", overlay)
        self.assertIn("property bool localPlayerReady: false", overlay)
        self.assertIn("readonly property real localCoverOpacity: root.resolvedLocalCoverOpacity(localPlayerReady)", overlay)
        self.assertIn("target: backgroundOutput.videoSink", overlay)
        self.assertIn("function onVideoFrameChanged(frame)", overlay)
        self.assertIn("player.lacunaReady === true) return", overlay)
        self.assertIn("player.playbackState !== MediaPlayer.PlayingState", overlay)
        self.assertIn('typeof frame.isValid === "function" && !frame.isValid()', overlay)
        self.assertIn("property var targetScreen: videoWindow.modelData", overlay)
        self.assertIn("id: outputRegistrationTimer", overlay)
        self.assertNotIn("id: failureWatchdog", overlay)
        self.assertIn("function outputDiagnostics(stage)", overlay)
        self.assertIn("activeHandoffToken = makeHandoffToken(sourceRevision)", overlay)
        self.assertIn("id: backgroundPlayerLoader", overlay)
        self.assertIn('property string sourceUrl: ""', overlay)
        self.assertIn("source: backgroundPlayerLoader.sourceUrl", overlay)
        self.assertIn("backgroundPlayerLoader.sourceUrl = root.activeSource", overlay)
        self.assertIn("function backgroundSourceGenerationIsCurrent(player)", overlay)
        self.assertIn("function onSourceRevisionChanged() { videoContent.recreatePlayer() }", overlay)
        self.assertIn("if (!sourceAssignmentNeeded) {", overlay)
        refresh_key = overlay.index("wallpaperPositionRefreshKey = refreshKey")
        refresh_call = overlay.index("service.updatePlaybackPosition()", refresh_key)
        source_assignment = overlay.index("activeSource = videoSource", refresh_call)
        self.assertLess(refresh_key, refresh_call)
        self.assertLess(refresh_call, source_assignment)
        self.assertNotIn("id: wallpaperPositionRefreshTimer", overlay)
        self.assertIn("fadeCoverAgeMs: root.fadeCoverStartedAt > 0", overlay)
        self.assertIn('wallpaperPositionRefreshKey: root.wallpaperPositionRefreshKey !== "" ? "set" : ""', overlay)
        self.assertNotIn("wallpaperPositionRefreshKey: root.wallpaperPositionRefreshKey,", overlay)

    def test_adaptive_fallback_and_drift_policy_are_explicit(self):
        overlay = read_overlay()

        self.assertIn("adaptiveReadinessTimeoutDuration: 4000", overlay)
        self.assertIn('switchToProgressive("adaptive-readiness-timeout")', overlay)
        self.assertIn('switchToProgressive("adaptive-error")', overlay)
        self.assertIn('switchToProgressive("adaptive-seek-correction")', overlay)
        self.assertIn("if (absoluteDrift < 400)", overlay)
        self.assertIn("if (absoluteDrift <= 1500)", overlay)
        self.assertIn("player.playbackRate = drift > 0 ? 1.03 : 0.97", overlay)
        self.assertIn("var hardSeekAllowed = force || now - lastHardSeekAt >= hardSeekCooldownDuration", overlay)
        self.assertIn("if (!hardSeekAllowed) continue", overlay)
        self.assertIn("if (hardSeekFailureCount < 2) return", overlay)
        self.assertIn('if (activeCandidateKind === "adaptive" && usingProgressiveFallback) return', overlay)
        self.assertIn("outputRegistrationTimer.stop()", overlay)
        self.assertIn("waitingForPlayerReady = false", overlay)
        self.assertIn("if (!root.wallpaperDesired || root.exitTransitionActive) return", overlay)
        self.assertIn("player.lacunaReady === true && player.playbackState === MediaPlayer.PlayingState", overlay)
        self.assertNotIn("if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia)", overlay)

    def test_playback_reuses_the_current_session_video_resolve(self):
        service = (ROOT / "lacuna.media-player/Service.qml").read_text(encoding="utf-8")
        start = service.index("function playNormalized(normalized, rememberPrevious)")
        end = service.index("function refreshDependencies()", start)
        body = service[start:end]

        # Playback owns the session revision, so it must be established before
        # a candidate request captures that revision.
        self.assertLess(body.index("startMpv(normalized)"), body.index("resolvePreview(normalized)"))
        self.assertLess(body.index("resolvePreview(normalized)"), body.index("reconcilePresentationState()"))
        self.assertIn("resolvingBackground && backgroundRequestUrl === url", service)
        self.assertIn("activeVideoResolvePlaybackRevision === playbackSessionRevision", service)


@unittest.skipUnless(HAVE_SESSION, "needs a quickshell binary and a Wayland session")
class MediaOverlayRuntimeTests(unittest.TestCase):
    def test_cleared_source_cover_fades_to_static_wallpaper(self):
        qml = f'''\nimport Quickshell\nimport QtQuick\n\nShellRoot {{\n  id: root\n  property var overlay: null\n  Component.onCompleted: {{\n    var c = Qt.createComponent("{qml_url('lacuna.media-player-video/Overlay.qml')}", Component.PreferSynchronous)\n    overlay = c.createObject(root, {{ manifest: {{ defaults: {{ targetOutput: "__missing_output__" }} }} }})\n    overlay.fadeCoverOpacity = 0.4\n    overlay.activeSource = ""\n    overlay.clearingWallpaperAfterExit = true\n    finish.restart()\n  }}\n  Timer {{\n    id: finish\n    interval: 10\n    onTriggered: {{\n      console.log("BEHAVE " + JSON.stringify({{ opacity: overlay.resolvedLocalCoverOpacity(false) }}))\n      Qt.quit()\n    }}\n  }}\n}}\n'''
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        result = parse_behave(output)[-1]
        self.assertAlmostEqual(result["opacity"], 0.4, places=3, msg=output[-2000:])

    def test_matched_player_registration_and_readiness_gate(self):
        qml = f'''\nimport Quickshell\nimport QtQuick\n\nShellRoot {{\n  id: root\n  property var overlay: null\n  Component.onCompleted: {{\n    var c = Qt.createComponent("{qml_url('lacuna.media-player-video/Overlay.qml')}", Component.PreferSynchronous)\n    overlay = c.createObject(root, {{ manifest: {{ defaults: {{ targetOutput: "ALL" }} }} }})\n    probe.restart()\n  }}\n  Timer {{\n    id: probe\n    interval: 10\n    onTriggered: {{\n      var expected = overlay.expectedMatchedPlayerCount()\n      var before = overlay.allMatchedPlayersRegistered()\n      for (var i = 0; i < Quickshell.screens.length; i++) {{\n        overlay.videoPlayers.push({{\n          targetScreen: Quickshell.screens[i],\n          source: "test-source",\n          lacunaReady: true,\n          lacunaSourceRevision: overlay.sourceRevision,\n          position: 0\n        }})\n      }}\n      console.log("BEHAVE " + JSON.stringify({{\n        expected: expected,\n        before: before,\n        registered: overlay.allMatchedPlayersRegistered(),\n        ready: overlay.allMatchedPlayersReadyFor("test-source"),\n        diagnostics: overlay.outputDiagnostics("test")\n      }}))\n      Qt.quit()\n    }}\n  }}\n}}\n'''
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        result = parse_behave(output)[-1]
        self.assertGreater(result["expected"], 0, output[-2000:])
        self.assertFalse(result["before"], output[-2000:])
        self.assertTrue(result["registered"], output[-2000:])
        self.assertTrue(result["ready"], output[-2000:])
        self.assertEqual(len(result["diagnostics"]["outputs"]), result["expected"])
        self.assertNotIn("test-source", str(result["diagnostics"]))
        self.assertNotIn("http", str(result["diagnostics"]).lower())

    def test_output_registration_timeout_settles_cover_and_reports_token(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var overlay: null

  QtObject {{
    id: mediaService
    property string presentationMode: "background"
    property string presentationState: "promoting"
    property int presentationRevision: 5
    property bool desiredBackgroundVideo: true
    property string videoQuality: "stable"
    property string adaptiveBackgroundStreamUrl: ""
    property string progressiveBackgroundStreamUrl: "https://example.test/video.mp4"
    property string backgroundStreamUrl: "https://example.test/video.mp4"
    property bool backgroundVideoEnabled: true
    property int backgroundRequestRevision: 9
    property int playbackSessionRevision: 11
    property bool backgroundResolveFailed: false
    property bool resolvingBackground: false
    property bool playing: true
    property bool paused: false
    property real playbackPosition: 0
    property var lacunaSettings: ({{ reduceMotion: true }})
    property int failures: 0
    property string reason: ""
    property var token: null
    function reportVideoLoading(surface, value, diagnostics) {{}}
    function reportVideoReady(surface, revision, position, value, diagnostics) {{}}
    function reportVideoFailure(surface, revision, value, handoffToken, diagnostics) {{
      failures += 1
      reason = value
      token = handoffToken
    }}
    function updatePlaybackPosition() {{}}
  }}

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.media-player-video/Overlay.qml')}", Component.PreferSynchronous)
    overlay = component.createObject(root, {{
      service: mediaService,
      manifest: {{ defaults: {{ targetOutput: "__missing_output__" }} }}
    }})
    // Replacing a retained source can time out before the new output player
    // registers. The old source must not bypass failure settlement.
    overlay.sourceRevision = 2
    overlay.activeSource = "https://example.test/retained.mp4"
    overlay.activeHandoffToken = {{ surface: "background", playbackRevision: 11,
      presentationRevision: 4, requestRevision: 8, sourceRevision: 2 }}
    overlay.fadeCoverVisible = true
    overlay.fadeCoverOpacity = 1
    probe.restart()
  }}

  Timer {{
    id: probe
    interval: 20
    onTriggered: {{
      var handled = overlay.handleOutputRegistrationTimeout()
      var tokenJson = JSON.stringify(mediaService.token)
      console.log("BEHAVE " + JSON.stringify({{
        handled: handled,
        failures: mediaService.failures,
        reason: mediaService.reason,
        activeSource: overlay.activeSource,
        waiting: overlay.waitingForPlayerReady,
        coverOpacity: overlay.fadeCoverOpacity,
        tokenSafe: tokenJson.indexOf("http") < 0 && mediaService.token.sourceRevision > 0
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        final = parse_behave(output)[-1]
        self.assertTrue(final["handled"], output[-2000:])
        self.assertEqual(final["failures"], 1, output[-2000:])
        self.assertEqual(final["reason"], "output-registration-timeout")
        self.assertEqual(final["activeSource"], "")
        self.assertFalse(final["waiting"])
        self.assertEqual(final["coverOpacity"], 0)
        self.assertTrue(final["tokenSafe"])

    def test_late_old_player_generation_cannot_match_progressive_token(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var overlay: null
  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.media-player-video/Overlay.qml')}", Component.PreferSynchronous)
    overlay = component.createObject(root, {{ manifest: {{ defaults: {{ targetOutput: "__missing_output__" }} }} }})
    overlay.sourceRevision = 7
    overlay.activeSource = "file:///dev/null?progressive"
    overlay.activeHandoffToken = {{ surface: "background", playbackRevision: overlay.playbackSessionRevision,
      presentationRevision: overlay.presentationRevision, requestRevision: overlay.backgroundRequestRevision,
      sourceRevision: 7 }}
    var oldAdaptive = {{ source: overlay.activeSource, lacunaSourceRevision: 6 }}
    var currentProgressive = {{ source: overlay.activeSource, lacunaSourceRevision: 7 }}
    root.result = {{
      lateOldAccepted: overlay.backgroundSourceGenerationIsCurrent(oldAdaptive),
      currentAccepted: overlay.backgroundSourceGenerationIsCurrent(currentProgressive)
    }}
    finish.restart()
  }}
  property var result: ({{}})
  Timer {{
    id: finish
    interval: 10
    onTriggered: {{
      console.log("BEHAVE " + JSON.stringify(root.result))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        final = parse_behave(output)[-1]
        self.assertFalse(final["lateOldAccepted"], output[-2000:])
        self.assertTrue(final["currentAccepted"], output[-2000:])

    def test_optional_v1_service_contract_and_legacy_fallback_coexist(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var overlay: null
  property string retainedDuringResolve: ""

  QtObject {{
    id: mediaService
    property string presentationMode: "auto"
    property string presentationState: "inline"
    property bool desiredBackgroundVideo: false
    property string videoQuality: "adaptive"
    property string adaptiveBackgroundStreamUrl: ""
    property string progressiveBackgroundStreamUrl: ""
    property string backgroundStreamUrl: ""
    property bool backgroundVideoEnabled: false
    property int backgroundRequestRevision: 3
    property int playbackSessionRevision: 7
    property int presentationRevision: 1
    property bool backgroundResolveFailed: false
    property bool resolvingBackground: false
    property bool playing: true
    property bool paused: false
    property real playbackPosition: 12
    property string previewStreamUrl: ""
    property string currentTrackUrl: "https://example.test/watch"
    property var lacunaSettings: ({{ reduceMotion: true }})
    property int failureReports: 0
    property string failureReason: ""
    function reportVideoLoading(surface, token, diagnostics) {{}}
    function reportVideoReady(surface, revision, position, token, diagnostics) {{}}
    function reportVideoFailure(surface, revision, reason, token, diagnostics) {{
      failureReports += 1
      failureReason = reason
    }}
    function updatePlaybackPosition() {{}}
    function refreshBackgroundStream() {{}}
  }}

  Component.onCompleted: {{
    var c = Qt.createComponent("{qml_url('lacuna.media-player-video/Overlay.qml')}", Component.PreferSynchronous)
    if (c.status !== Component.Ready) {{
      console.log("BEHAVE_ERR " + c.errorString())
      Qt.quit()
      return
    }}
    overlay = c.createObject(root, {{
      service: mediaService,
      manifest: {{ defaults: {{ targetOutput: "__test_no_output__" }} }}
    }})
    overlay.activeSource = "https://example.test/previous.mp4"
    mediaService.presentationState = "promoting"
    mediaService.desiredBackgroundVideo = true
    root.retainedDuringResolve = overlay.activeSource
    mediaService.progressiveBackgroundStreamUrl = "https://example.test/video-360.mp4"
    mediaService.adaptiveBackgroundStreamUrl = "https://example.test/video-720.m3u8"
    probe.restart()
  }}

  Timer {{
    id: probe
    interval: 20
    onTriggered: {{
      var adaptive = overlay.preferredVideoSource
      overlay.activeCandidateKind = "adaptive"
      overlay.switchToProgressive("runtime-test")
      overlay.notePlayerError("duplicate-adaptive-error")
      var duplicateErrorSuppressed = mediaService.failureReports === 1
      overlay.waitingForPlayerReady = true
      mediaService.presentationState = "demoting"
      mediaService.desiredBackgroundVideo = false
      var heldDuringDemotion = overlay.desiredBackgroundVideo
      overlay.beginWallpaperExit()
      overlay.notePlayerError("exit-error")
      var exitFailureSuppressed = mediaService.failureReports === 1
      var exitReadinessCleared = !overlay.waitingForPlayerReady
      mediaService.presentationState = "inline"
      console.log("BEHAVE " + JSON.stringify({{
        adaptive: adaptive,
        fallback: overlay.preferredVideoSource,
        retainedDuringResolve: root.retainedDuringResolve,
        heldDuringDemotion: heldDuringDemotion,
        inlineDesired: overlay.desiredBackgroundVideo,
        fadeCoverRiseDuration: overlay.fadeCoverRiseDuration,
        fadeInDuration: overlay.fadeInDuration,
        failureReports: mediaService.failureReports,
        failureReason: mediaService.failureReason,
        duplicateErrorSuppressed: duplicateErrorSuppressed,
        exitFailureSuppressed: exitFailureSuppressed,
        exitReadinessCleared: exitReadinessCleared,
        loadedPlayers: overlay.videoPlayers.length
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        final = parse_behave(output)[-1]
        self.assertEqual(final["adaptive"], "https://example.test/video-360.mp4")
        self.assertEqual(final["fallback"], "https://example.test/video-360.mp4")
        self.assertEqual(final["retainedDuringResolve"], "https://example.test/previous.mp4")
        self.assertTrue(final["heldDuringDemotion"])
        self.assertFalse(final["inlineDesired"])
        self.assertEqual(final["fadeCoverRiseDuration"], 75)
        self.assertEqual(final["fadeInDuration"], 75)
        self.assertEqual(final["failureReports"], 1)
        self.assertEqual(final["failureReason"], "runtime-test")
        self.assertTrue(final["duplicateErrorSuppressed"])
        self.assertTrue(final["exitFailureSuppressed"])
        self.assertTrue(final["exitReadinessCleared"])
        self.assertEqual(final["loadedPlayers"], 0)


if __name__ == "__main__":
    unittest.main()
