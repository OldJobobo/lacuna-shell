import json
import tempfile
import unittest
from pathlib import Path

from qml_harness import HAVE_SESSION, parse_behave, qml_url, require_no_qml_errors, run_quickshell
from test_qml_behavior_video import make_media_player_source


class MediaPresentationOrderingContractTests(unittest.TestCase):
    def test_destination_is_published_before_presentation_state_changes(self):
        service = (Path(__file__).resolve().parents[1] / "lacuna.media-player/Service.qml").read_text(encoding="utf-8")
        reconcile = service[service.index("function reconcilePresentationState()") : service.index("function reportVideoCovering(")]
        self.assertLess(reconcile.index('pendingHandoffSurface = "background"'), reconcile.index('presentationState = "promoting"'))
        self.assertIn("if (!inlineSurfaceAvailable)", reconcile)
        self.assertIn('handoffLastEvent = "inline-without-surface:" + presentationRevision', reconcile)
        self.assertLess(reconcile.index('pendingHandoffSurface = "inline"'), reconcile.index('presentationState = "demoting"'))
        begin_intent = service[service.index("function beginPresentationIntent(phase)") : service.index("function schedulePresentationRecovery()")]
        self.assertLess(begin_intent.index('pendingHandoffSurface = ""'), begin_intent.index("presentationRevision += 1"))
        self.assertIn("property var inlineSurfaceAvailability: ({})", service)
        self.assertIn("function setInlineSurfaceAvailable(available, surfaceId)", service)
        toggle = service[service.index("function togglePause()") : service.index("function setPresentationMode(")]
        self.assertIn("if (hasTrack) playNormalized(currentTrack, false)", toggle)
        self.assertNotIn("if (hasTrack) startMpv(currentTrack)", toggle)


@unittest.skipUnless(HAVE_SESSION, "needs a quickshell binary and a Wayland session")
class QmlMediaPlayerV1ServiceBehaviorTests(unittest.TestCase):
    def test_service_consumes_progressive_worker_events(self):
        source_owner, source = make_media_player_source("{}")
        worker = source / "scripts" / "media-player-worker"
        worker.write_text(
            "#!/usr/bin/env python3\n"
            "import json, sys\n"
            "def emit(value):\n"
            "    print(json.dumps(value), flush=True)\n"
            "emit({'type': 'ready', 'mpv': True, 'ytdlp': True})\n"
            "for raw in sys.stdin:\n"
            "    message = json.loads(raw)\n"
            "    kind = message.get('type')\n"
            "    if kind == 'configure': emit({'type': 'configured'})\n"
            "    elif kind == 'search':\n"
            "        request = message['requestId']\n"
            "        emit({'type': 'provider-results', 'requestId': request, 'provider': 'jellyfin', 'results': [{'provider': 'jellyfin', 'providerId': 'j1', 'title': 'Local', 'url': 'jellyfin://item/j1'}], 'error': ''})\n"
            "        emit({'type': 'provider-results', 'requestId': request, 'provider': 'youtube', 'results': [{'provider': 'youtube', 'id': 'y1', 'title': 'Remote', 'url': 'https://example.test/y1'}], 'error': ''})\n"
            "    elif kind == 'shutdown': break\n",
            encoding="utf-8",
        )
        worker.chmod(0o755)
        with source_owner, tempfile.TemporaryDirectory() as cfg:
            qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var svc: null
  property bool requested: false
  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.media-player/Service.qml')}", Component.PreferSynchronous)
    svc = component.createObject(root, {{ manifest: {{ __sourceDir: "{source}" }} }})
  }}
  Timer {{
    interval: 20
    repeat: true
    running: true
    onTriggered: {{
      if (!svc || !svc.workerReady || !svc.stateLoaded || requested) return
      requested = true
      svc.lacunaSettings = {{ mediaProviders: {{ jellyfin: {{ enabled: true, serverUrl: "https://example.test", apiKey: "secret" }} }} }}
      svc.search("demo")
      finish.start()
    }}
  }}
  Timer {{
    id: finish
    interval: 180
    onTriggered: {{
      console.log("BEHAVE " + JSON.stringify({{
        workerReady: svc.workerReady,
        workerConfigured: svc.workerConfigured,
        searching: svc.searching,
        titles: svc.allResults.map(function(row) {{ return row.title }}),
        youtubeCount: svc.providerStates.youtube.count,
        jellyfinCount: svc.providerStates.jellyfin.count
      }}))
      Qt.quit()
    }}
  }}
}}
"""
            output = run_quickshell(qml, config_home=Path(cfg), timeout=8)

        require_no_qml_errors(output)
        final = parse_behave(output)[-1]
        self.assertTrue(final["workerReady"])
        self.assertTrue(final["workerConfigured"])
        self.assertFalse(final["searching"])
        self.assertEqual(final["titles"], ["Remote", "Local"])
        self.assertEqual(final["youtubeCount"], 1)
        self.assertEqual(final["jellyfinCount"], 1)

    def test_stop_then_play_resolves_video_again(self):
        source_owner, source = make_media_player_source("{}")
        messages = source / "worker-messages.jsonl"
        worker = source / "scripts" / "media-player-worker"
        worker.write_text(
            "#!/usr/bin/env python3\n"
            "import json, pathlib, sys\n"
            f"messages = pathlib.Path({str(messages)!r})\n"
            "def emit(value): print(json.dumps(value), flush=True)\n"
            "emit({'type':'ready','mpv':True,'ytdlp':True})\n"
            "for raw in sys.stdin:\n"
            "    message=json.loads(raw)\n"
            "    with messages.open('a', encoding='utf-8') as handle: handle.write(json.dumps(message)+'\\n')\n"
            "    if message.get('type')=='configure': emit({'type':'configured'})\n"
            "    elif message.get('type')=='play': emit({'type':'playback','revision':message['revision'],'running':True,'playing':True,'position':0,'duration':100})\n"
            "    elif message.get('type')=='resolve-video': emit({'type':'video-candidates','requestId':message['requestId'],'revision':message['revision'],'adaptiveUrl':'','progressiveUrl':'https://video.example/replay.mp4','error':''})\n"
            "    elif message.get('type')=='shutdown': break\n",
            encoding="utf-8",
        )
        worker.chmod(0o755)
        with source_owner, tempfile.TemporaryDirectory() as cfg:
            qml = f"""
import Quickshell
import QtQuick
ShellRoot {{
  id: root
  property var svc: null
  property int phase: 0
  Component.onCompleted: {{
    var c=Qt.createComponent("{qml_url('lacuna.media-player/Service.qml')}", Component.PreferSynchronous)
    svc=c.createObject(root, {{ manifest: {{ __sourceDir: "{source}" }} }})
  }}
  Timer {{
    interval: 20; repeat: true; running: true
    onTriggered: {{
      if (!svc || !svc.workerOperational || !svc.stateLoaded) return
      if (root.phase === 0) {{
        root.phase = 1
        svc.playNow({{ id:"replay", provider:"youtube", url:"https://example.test/replay", mediaType:"video" }})
        return
      }}
      if (root.phase === 1 && svc.previewStreamUrl !== "") {{
        root.phase = 2
        svc.playNow(svc.currentTrack)
        return
      }}
      if (root.phase === 2 && svc.previewStreamUrl !== "" && !svc.resolvingPreview
          && svc.activeVideoResolvePlaybackRevision === svc.playbackSessionRevision) {{
        root.phase = 3
        svc.stop()
        svc.togglePause()
        return
      }}
      if (root.phase === 3 && svc.previewStreamUrl !== "" && !svc.resolvingPreview) {{
        root.phase = 4
        finish.restart()
      }}
    }}
  }}
  Timer {{ id: finish; interval: 80; onTriggered: {{
    console.log("BEHAVE "+JSON.stringify({{ phase:root.phase, playing:svc.playing, preview:svc.previewStreamUrl }}))
    svc.stop(); Qt.quit()
  }} }}
}}
"""
            output = run_quickshell(qml, config_home=Path(cfg), timeout=8)
            posted = [json.loads(line) for line in messages.read_text(encoding="utf-8").splitlines() if line.strip()]

        require_no_qml_errors(output)
        final = parse_behave(output)[-1]
        self.assertEqual(final["phase"], 4, output[-2000:])
        self.assertTrue(final["playing"], output[-2000:])
        self.assertEqual(final["preview"], "https://video.example/replay.mp4", output[-2000:])
        resolves = [row for row in posted if row.get("type") == "resolve-video"]
        self.assertEqual(len(resolves), 3, posted)
        self.assertEqual([row["revision"] for row in resolves], sorted(row["revision"] for row in resolves), posted)

    def test_inline_surface_registry_is_not_last_writer_wins(self):
        source_owner, source = make_media_player_source("{}")
        with source_owner, tempfile.TemporaryDirectory() as cfg:
            qml = f"""
import Quickshell
import QtQuick
ShellRoot {{
  id: root
  property var svc: null
  Component.onCompleted: {{
    var c=Qt.createComponent("{qml_url('lacuna.media-player/Service.qml')}", Component.PreferSynchronous)
    svc=c.createObject(root, {{ manifest: {{ __sourceDir: "{source}" }} }})
    probe.restart()
  }}
  Timer {{ id: probe; interval: 30; onTriggered: {{
    svc.setInlineSurfaceAvailable(true, "DP-1")
    svc.setInlineSurfaceAvailable(false, "DP-2")
    var visibleSurvivesHidden = svc.inlineSurfaceAvailable
    svc.setInlineSurfaceAvailable(true, "DP-2")
    svc.setInlineSurfaceAvailable(false, "DP-1")
    var secondSurvivesFirst = svc.inlineSurfaceAvailable
    svc.setInlineSurfaceAvailable(false, "DP-2")
    console.log("BEHAVE "+JSON.stringify({{
      visibleSurvivesHidden:visibleSurvivesHidden,
      secondSurvivesFirst:secondSurvivesFirst,
      finalAvailable:svc.inlineSurfaceAvailable,
      finalCount:Object.keys(svc.inlineSurfaceAvailability).length
    }}))
    Qt.quit()
  }} }}
}}
"""
            output = run_quickshell(qml, config_home=Path(cfg), timeout=8)

        require_no_qml_errors(output)
        final = parse_behave(output)[-1]
        self.assertTrue(final["visibleSurvivesHidden"])
        self.assertTrue(final["secondSurvivesFirst"])
        self.assertFalse(final["finalAvailable"])
        self.assertEqual(final["finalCount"], 0)

    def test_background_refresh_forces_worker_cache_bypass(self):
        source_owner, source = make_media_player_source("{}")
        messages = source / "worker-messages.jsonl"
        worker = source / "scripts" / "media-player-worker"
        worker.write_text(
            "#!/usr/bin/env python3\n"
            "import json, pathlib, sys\n"
            f"messages = pathlib.Path({str(messages)!r})\n"
            "def emit(value):\n"
            "    print(json.dumps(value), flush=True)\n"
            "emit({'type': 'ready', 'mpv': True, 'ytdlp': True})\n"
            "for raw in sys.stdin:\n"
            "    message = json.loads(raw)\n"
            "    with messages.open('a', encoding='utf-8') as handle:\n"
            "        handle.write(json.dumps(message) + '\\n')\n"
            "    kind = message.get('type')\n"
            "    if kind == 'configure': emit({'type': 'configured'})\n"
            "    elif kind == 'resolve-video':\n"
            "        emit({'type': 'video-candidates', 'requestId': message['requestId'], 'revision': message['revision'], 'adaptiveUrl': '', 'progressiveUrl': 'https://video.example/fresh.mp4', 'error': ''})\n"
            "    elif kind == 'shutdown': break\n",
            encoding="utf-8",
        )
        worker.chmod(0o755)
        with source_owner, tempfile.TemporaryDirectory() as cfg:
            qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var svc: null
  property var track: null
  property int phase: 0
  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.media-player/Service.qml')}", Component.PreferSynchronous)
    svc = component.createObject(root, {{ manifest: {{ __sourceDir: "{source}" }} }})
  }}
  Timer {{
    interval: 20
    repeat: true
    running: true
    onTriggered: {{
      if (!svc || !svc.workerOperational || !svc.stateLoaded) return
      if (root.phase === 0) {{
        root.phase = 1
        root.track = svc.normalizeTrack({{ id: "refresh", provider: "youtube", url: "https://example.test/refresh", mediaType: "video" }})
        svc.currentTrack = root.track
        svc.playing = true
        svc.presentationMode = "background"
        svc.resolveBackground(root.track)
        return
      }}
      if (root.phase === 1 && svc.backgroundStreamUrl !== "") {{
        root.phase = 2
        svc.refreshBackgroundStream()
        return
      }}
      if (root.phase === 2 && svc.backgroundStreamUrl !== "" && !svc.resolvingBackground) {{
        stop()
        finish.start()
      }}
    }}
  }}
  Timer {{
    id: finish
    interval: 80
    onTriggered: {{
      console.log("BEHAVE " + JSON.stringify({{ phase: root.phase, background: svc.backgroundStreamUrl }}))
      Qt.quit()
    }}
  }}
}}
"""
            output = run_quickshell(qml, config_home=Path(cfg), timeout=8)
            posted = [
                json.loads(line)
                for line in messages.read_text(encoding="utf-8").splitlines()
                if line.strip()
            ]

        require_no_qml_errors(output)
        final = parse_behave(output)[-1]
        self.assertEqual(final["phase"], 2, output[-2000:])
        self.assertEqual(final["background"], "https://video.example/fresh.mp4", output[-2000:])
        resolves = [row for row in posted if row.get("type") == "resolve-video"]
        self.assertEqual(len(resolves), 2, posted)
        self.assertFalse(resolves[0].get("bypassCache"), posted)
        self.assertTrue(resolves[1].get("bypassCache"), posted)

    def test_presentation_handoff_and_smoothed_clock(self):
        source_owner, source = make_media_player_source("{}")
        with source_owner, tempfile.TemporaryDirectory() as cfg:
            qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var svc: null

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.media-player/Service.qml')}", Component.PreferSynchronous)
    svc = component.createObject(root, {{ manifest: {{ __sourceDir: "{source}" }} }})
    setup.start()
  }}

  Timer {{
    id: setup
    interval: 20
    repeat: true
    onTriggered: {{
      if (!svc || !svc.stateLoaded) return
      stop()
      var track = svc.normalizeTrack({{
        id: "video-one",
        provider: "youtube",
        title: "Video One",
        url: "https://example.test/video-one",
        mediaType: "video"
      }})
      svc.currentTrack = track
      svc.rememberStreamUrl(track, "https://cdn.example.test/video.mp4")
      svc.playbackSessionRevision = 10
      svc.playing = true
      svc.paused = false
      svc.inlineSurfaceAvailable = true
      svc.presentationMode = "auto"
      svc.reconcilePresentationState()
      var inlineState = svc.presentationState

      svc.inlineSurfaceAvailable = false
      svc.reconcilePresentationState()
      var promotingState = svc.presentationState
      var slowResolveHasNoDeadline = !svc.rendererHandoffDeadlineActive
      var backgroundToken = {{
        surface: "background",
        playbackRevision: 10,
        presentationRevision: svc.presentationRevision,
        requestRevision: svc.backgroundRequestRevision,
        sourceRevision: 1
      }}
      svc.reportVideoLoading("background", backgroundToken, {{ stage: "loading-renderer" }})
      var loadingStartedDeadline = svc.rendererHandoffDeadlineActive
      svc.reportVideoReady("background", 10, 0, backgroundToken, {{ stage: "presented" }})
      var backgroundState = svc.presentationState

      svc.inlineSurfaceAvailable = true
      svc.reconcilePresentationState()
      var demotingState = svc.presentationState
      var inlineToken = {{
        surface: "inline",
        playbackRevision: 10,
        presentationRevision: svc.presentationRevision,
        requestRevision: svc.videoResolveRevision,
        sourceRevision: 1
      }}
      svc.reportVideoLoading("inline", inlineToken, {{ stage: "loading-renderer" }})
      svc.reportVideoReady("inline", 10, 0, inlineToken, {{ stage: "presented" }})
      var returnedState = svc.presentationState

      svc.handleWorkerPlayback({{ revision: 10, playing: false, paused: true, running: true, position: 12, duration: 120 }})
      var pauseKeepsTrackActive = svc.playing && svc.paused
      svc.paused = false
      svc.playbackSamplePosition = 12
      svc.playbackSampledAtMs = Date.now() - 600
      svc.playbackPosition = 12
      svc.smoothPlaybackClock()
      var smoothedPosition = svc.playbackPosition

      svc.workerPlayRecoveryPending = true
      svc.commandRunning = false
      svc.handleWorkerPlayback({{ revision: 10, playing: false, paused: false, running: true, idleActive: true }})
      var recoveryPreserved = svc.playing && svc.commandRunning && svc.status === "loading"
      svc.workerPlayRecoveryPending = false

      for (var i = 0; i < 30; i++)
        svc.rememberStreamUrl("https://example.test/watch?v=cache" + i, "https://cdn.example.test/stream" + i)
      var boundedStreamCache = Object.keys(svc.streamUrlCache).length

      svc.workerReady = true
      svc.workerConfigured = false
      var unconfiguredResolveRejected = !svc.requestWorkerVideoCandidates(track)
      console.log("BEHAVE " + JSON.stringify({{
        inlineState: inlineState,
        promotingState: promotingState,
        backgroundState: backgroundState,
        demotingState: demotingState,
        returnedState: returnedState,
        slowResolveHasNoDeadline: slowResolveHasNoDeadline,
        loadingStartedDeadline: loadingStartedDeadline,
        deadlineCleared: !svc.rendererHandoffDeadlineActive,
        handoffPhase: svc.handoffPhase,
        backgroundEnabled: svc.backgroundVideoEnabled,
        pauseKeepsTrackActive: pauseKeepsTrackActive,
        smoothedPosition: smoothedPosition,
        recoveryPreserved: recoveryPreserved,
        boundedStreamCache: boundedStreamCache,
        unconfiguredResolveRejected: unconfiguredResolveRejected
      }}))
      Qt.quit()
    }}
  }}
}}
"""
            output = run_quickshell(qml, config_home=Path(cfg), timeout=8)

        require_no_qml_errors(output)
        final = parse_behave(output)[-1]
        self.assertEqual(final["inlineState"], "inline")
        self.assertEqual(final["promotingState"], "promoting")
        self.assertEqual(final["backgroundState"], "background")
        self.assertEqual(final["demotingState"], "demoting")
        self.assertEqual(final["returnedState"], "inline")
        self.assertTrue(final["slowResolveHasNoDeadline"])
        self.assertTrue(final["loadingStartedDeadline"])
        self.assertTrue(final["deadlineCleared"])
        self.assertEqual(final["handoffPhase"], "presented")
        self.assertFalse(final["backgroundEnabled"])
        self.assertTrue(final["pauseKeepsTrackActive"])
        self.assertGreaterEqual(final["smoothedPosition"], 12.5)
        self.assertLess(final["smoothedPosition"], 13.2)
        self.assertTrue(final["recoveryPreserved"])
        self.assertEqual(final["boundedStreamCache"], 24)
        self.assertTrue(final["unconfiguredResolveRejected"])

    def test_inline_timeout_and_surface_loss_keep_background_off_intent(self):
        source_owner, source = make_media_player_source("{}")
        with source_owner, tempfile.TemporaryDirectory() as cfg:
            qml = f"""
import Quickshell
import QtQuick
ShellRoot {{
  id: root
  property var svc: null
  Component.onCompleted: {{
    var c=Qt.createComponent("{qml_url('lacuna.media-player/Service.qml')}", Component.PreferSynchronous)
    svc=c.createObject(root, {{ manifest: {{ __sourceDir: "{source}" }} }})
    probe.restart()
  }}
  Timer {{ id: probe; interval: 30; onTriggered: {{
    svc.currentTrack=svc.normalizeTrack({{ id:"timeout", provider:"youtube", url:"https://example.test/timeout", mediaType:"video" }})
    svc.playing=true; svc.paused=false; svc.playbackSessionRevision=20
    svc.setInlineSurfaceAvailable(true, "test")
    svc.presentationMode="background"; svc.presentationState="background"
    svc.backgroundVideoEnabled=true; svc.backgroundSurfaceReady=true
    svc.setPresentationMode("inline")
    svc.setInlineSurfaceAvailable(false, "test")
    var surfaceLossState=svc.presentationState
    var surfaceLossEnabled=svc.backgroundVideoEnabled

    svc.setInlineSurfaceAvailable(true, "test")
    svc.presentationState="background"; svc.backgroundVideoEnabled=true; svc.backgroundSurfaceReady=true
    svc.setPresentationMode("inline")
    var token={{ surface:"inline", playbackRevision:20, presentationRevision:svc.presentationRevision,
      requestRevision:svc.videoResolveRevision, sourceRevision:1 }}
    svc.reportVideoLoading("inline", token, {{ stage:"loading-renderer" }})
    var handled=svc.handleRendererHandoffTimeout(token)
    console.log("BEHAVE "+JSON.stringify({{ handled:handled, mode:svc.presentationMode,
      state:svc.presentationState, enabled:svc.backgroundVideoEnabled, pending:svc.pendingHandoffSurface,
      surfaceLossState:surfaceLossState, surfaceLossEnabled:surfaceLossEnabled }}))
    Qt.quit()
  }} }}
}}
"""
            output = run_quickshell(qml, config_home=Path(cfg), timeout=8)

        require_no_qml_errors(output)
        final = parse_behave(output)[-1]
        self.assertEqual(final["surfaceLossState"], "inline")
        self.assertFalse(final["surfaceLossEnabled"])
        self.assertTrue(final["handled"], output[-2000:])
        self.assertEqual(final["mode"], "inline")
        self.assertEqual(final["state"], "inline")
        self.assertFalse(final["enabled"])
        self.assertEqual(final["pending"], "")

    def test_tokenized_handoffs_reject_stale_callbacks_and_timers(self):
        source_owner, source = make_media_player_source("{}")
        with source_owner, tempfile.TemporaryDirectory() as cfg:
            qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var svc: null

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.media-player/Service.qml')}", Component.PreferSynchronous)
    svc = component.createObject(root, {{ manifest: {{ __sourceDir: "{source}" }} }})
    setup.start()
  }}

  Timer {{
    id: setup
    interval: 20
    repeat: true
    onTriggered: {{
      if (!svc || !svc.stateLoaded) return
      stop()
      var track = svc.normalizeTrack({{
        id: "token-video",
        provider: "youtube",
        title: "Token Video",
        url: "https://example.test/token-video",
        mediaType: "video"
      }})
      svc.currentTrack = track
      svc.rememberStreamUrl(track, "https://cdn.example.test/token.mp4")
      svc.playbackSessionRevision = 44
      svc.playing = true
      svc.paused = false
      svc.inlineSurfaceAvailable = false
      svc.presentationMode = "auto"
      svc.reconcilePresentationState()
      var resolvingWithoutDeadline = svc.handoffPhase === "source-ready" && !svc.rendererHandoffDeadlineActive
      var firstRevision = svc.presentationRevision
      var first = {{ surface: "background", playbackRevision: 44,
        presentationRevision: firstRevision, requestRevision: svc.backgroundRequestRevision, sourceRevision: 1 }}
      var loadingAccepted = svc.reportVideoLoading("background", first, {{
        stage: "loading-renderer", url: "https://secret.invalid/signed",
        outputs: [{{ name: "https://secret.invalid/output", registered: true, sourceMatched: true, ready: false,
          playbackState: "loading", mediaStatus: "loading", converged: false, error: false,
          rawError: "credential" }}]
      }})
      var duplicateAccepted = svc.reportVideoLoading("background", first, {{ stage: "loading-renderer" }})

      svc.inlineSurfaceAvailable = true
      svc.reconcilePresentationState()
      var newestAfterDemotion = svc.presentationRevision
      var staleReady = svc.reportVideoReady("background", 44, 0, first, {{ stage: "presented" }})
      var staleFailure = svc.reportVideoFailure("background", 44, "late-adaptive", first, {{ stage: "failed" }})
      var staleTimeout = svc.handleRendererHandoffTimeout(first)
      var demotionSurvived = svc.presentationState === "demoting" && svc.presentationRevision === newestAfterDemotion

      svc.inlineSurfaceAvailable = false
      svc.reconcilePresentationState()
      var latestRevision = svc.presentationRevision
      var adaptive = {{ surface: "background", playbackRevision: 44,
        presentationRevision: latestRevision, requestRevision: svc.backgroundRequestRevision, sourceRevision: 2 }}
      var progressive = {{ surface: "background", playbackRevision: 44,
        presentationRevision: latestRevision, requestRevision: svc.backgroundRequestRevision, sourceRevision: 3 }}
      svc.reportVideoLoading("background", adaptive, {{ stage: "loading-renderer" }})
      svc.reportVideoLoading("background", progressive, {{ stage: "loading-renderer" }})
      var reverseOrderLoading = svc.reportVideoLoading("background", adaptive, {{ stage: "loading-renderer" }})
      var lateAdaptiveFailure = svc.reportVideoFailure("background", 44, "adaptive-error", adaptive, {{ stage: "failed" }})
      var progressiveStillActive = svc.handoffTokensEqual(svc.activeHandoffToken, progressive)
      var readyAccepted = svc.reportVideoReady("background", 44, 0, progressive, {{
        stage: "presented", outputs: [{{ name: "DP-1", registered: true, sourceMatched: true,
          ready: true, playbackState: "playing", mediaStatus: "buffered", converged: true, error: false }}]
      }})
      var staleRecovery = svc.settlePresentationRecovery(firstRevision)
      var diagnosticsJson = JSON.stringify(svc.handoffDiagnostics)
      var sanitizedOutputCount = svc.handoffDiagnostics.outputs.length

      svc.inlineSurfaceAvailable = true
      svc.reconcilePresentationState()
      var inlineFailureToken = {{ surface: "inline", playbackRevision: 44,
        presentationRevision: svc.presentationRevision, requestRevision: svc.videoResolveRevision, sourceRevision: 4 }}
      svc.reportVideoLoading("inline", inlineFailureToken, {{ stage: "loading-renderer" }})
      svc.reportVideoFailure("inline", 44, "https://secret.invalid/backend?credential=token",
        inlineFailureToken, {{ stage: "failed", rawError: "credential" }})
      var safePresentationError = svc.presentationErrorText
      console.log("BEHAVE " + JSON.stringify({{
        resolvingWithoutDeadline: resolvingWithoutDeadline,
        loadingAccepted: loadingAccepted,
        duplicateAccepted: duplicateAccepted,
        staleReady: staleReady,
        staleFailure: staleFailure,
        staleTimeout: staleTimeout,
        demotionSurvived: demotionSurvived,
        reverseOrderLoading: reverseOrderLoading,
        lateAdaptiveFailure: lateAdaptiveFailure,
        progressiveStillActive: progressiveStillActive,
        readyAccepted: readyAccepted,
        staleRecovery: staleRecovery,
        finalState: svc.presentationState,
        finalPhase: svc.handoffPhase,
        deadlineActive: svc.rendererHandoffDeadlineActive,
        diagnosticsRedacted: diagnosticsJson.indexOf("http") < 0 && diagnosticsJson.indexOf("credential") < 0,
        safePresentationError: safePresentationError,
        presentationErrorRedacted: safePresentationError.indexOf("http") < 0 && safePresentationError.indexOf("credential") < 0,
        outputCount: sanitizedOutputCount
      }}))
      Qt.quit()
    }}
  }}
}}
"""
            output = run_quickshell(qml, config_home=Path(cfg), timeout=8)

        require_no_qml_errors(output)
        final = parse_behave(output)[-1]
        self.assertTrue(final["resolvingWithoutDeadline"])
        self.assertTrue(final["loadingAccepted"])
        self.assertTrue(final["duplicateAccepted"])
        self.assertFalse(final["staleReady"])
        self.assertFalse(final["staleFailure"])
        self.assertFalse(final["staleTimeout"])
        self.assertTrue(final["demotionSurvived"])
        self.assertFalse(final["reverseOrderLoading"])
        self.assertFalse(final["lateAdaptiveFailure"])
        self.assertTrue(final["progressiveStillActive"])
        self.assertTrue(final["readyAccepted"])
        self.assertFalse(final["staleRecovery"])
        self.assertEqual(final["finalState"], "inline")
        self.assertEqual(final["finalPhase"], "presented")
        self.assertFalse(final["deadlineActive"])
        self.assertTrue(final["diagnosticsRedacted"])
        self.assertEqual(final["safePresentationError"], "player-error")
        self.assertTrue(final["presentationErrorRedacted"])
        self.assertEqual(final["outputCount"], 1)

    def test_stop_normalizes_state_and_rejects_late_legacy_video_result(self):
        source_owner, source = make_media_player_source("{}")
        preview = source / "scripts" / "media-player-preview"
        preview.write_text(
            "#!/bin/sh\n"
            "sleep 0.20\n"
            "printf %s\\n '{\"url\":\"https://cdn.example.test/late.mp4\"}'\n",
            encoding="utf-8",
        )
        preview.chmod(0o755)
        with source_owner, tempfile.TemporaryDirectory() as cfg:
            qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var svc: null

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.media-player/Service.qml')}", Component.PreferSynchronous)
    svc = component.createObject(root, {{ manifest: {{ __sourceDir: "{source}" }} }})
    setup.start()
  }}

  Timer {{
    id: setup
    interval: 20
    repeat: true
    onTriggered: {{
      if (!svc || !svc.stateLoaded) return
      stop()
      var track = svc.normalizeTrack({{
        id: "stopped-video",
        provider: "youtube",
        title: "Stopped Video",
        url: "https://example.test/stopped-video",
        mediaType: "video"
      }})
      svc.workerReady = false
      svc.workerConfigured = false
      svc.mpvAvailable = true
      svc.ytdlpAvailable = true
      svc.currentTrack = track
      svc.playing = true
      svc.paused = false
      svc.playbackPosition = 42
      svc.playbackDuration = 120
      svc.playbackSamplePosition = 42
      svc.playbackSampledAtMs = Date.now()
      svc.playbackSessionRevision = 27
      svc.workerErrorText = "media worker failed"
      svc.presentationErrorText = "renderer-timeout"
      svc.errorText = "renderer failed"
      svc.previewStreamUrl = "https://cdn.example.test/old.mp4"
      svc.adaptivePreviewStreamUrl = "https://cdn.example.test/old.m3u8"
      svc.progressivePreviewStreamUrl = "https://cdn.example.test/old.mp4"
      svc.backgroundStreamUrl = "https://cdn.example.test/old.mp4"
      svc.backgroundSurfaceReady = true
      svc.presentationFallbackInline = true
      svc.activeVideoResolveRevision = 19
      svc.resolvePreview(track)
      svc.stop()
      svc.handleWorkerLine(JSON.stringify({{
        type: "error",
        scope: "playback",
        revision: 27,
        error: "late worker failure"
      }}))
      // A newly configured worker emits an idle sample at shell startup. It
      // must not move the public stopped clock above zero.
      svc.handleWorkerPlayback({{
        revision: svc.playbackSessionRevision,
        position: 0,
        sampledAtMs: Date.now() - 5,
        paused: false,
        playing: false,
        running: false,
        idleActive: true
      }})
      finish.start()
    }}
  }}

  Timer {{
    id: finish
    interval: 420
    onTriggered: {{
      console.log("BEHAVE " + JSON.stringify({{
        playing: svc.playing,
        paused: svc.paused,
        position: svc.playbackPosition,
        duration: svc.playbackDuration,
        samplePosition: svc.playbackSamplePosition,
        sampledAt: svc.playbackSampledAtMs,
        preview: svc.previewStreamUrl,
        adaptivePreview: svc.adaptivePreviewStreamUrl,
        progressivePreview: svc.progressivePreviewStreamUrl,
        previewRequest: svc.previewRequestUrl,
        background: svc.backgroundStreamUrl,
        backgroundRequest: svc.backgroundRequestUrl,
        resolvingPreview: svc.resolvingPreview,
        resolvingBackground: svc.resolvingBackground,
        activeVideoResolveRevision: svc.activeVideoResolveRevision,
        workerError: svc.workerErrorText,
        presentationError: svc.presentationErrorText,
        error: svc.errorText,
        telemetryLoaded: svc.previewTelemetry.loaded === true,
        presentationState: svc.presentationState,
        backgroundReady: svc.backgroundSurfaceReady,
        fallbackInline: svc.presentationFallbackInline,
        status: svc.status
      }}))
      Qt.quit()
    }}
  }}
}}
"""
            output = run_quickshell(qml, config_home=Path(cfg), timeout=8)

        require_no_qml_errors(output)
        final = parse_behave(output)[-1]
        self.assertFalse(final["playing"])
        self.assertFalse(final["paused"])
        self.assertEqual(final["position"], 0)
        self.assertEqual(final["duration"], 0)
        self.assertEqual(final["samplePosition"], 0)
        self.assertEqual(final["sampledAt"], 0)
        self.assertEqual(final["preview"], "")
        self.assertEqual(final["adaptivePreview"], "")
        self.assertEqual(final["progressivePreview"], "")
        self.assertEqual(final["previewRequest"], "")
        self.assertEqual(final["background"], "")
        self.assertEqual(final["backgroundRequest"], "")
        self.assertFalse(final["resolvingPreview"])
        self.assertFalse(final["resolvingBackground"])
        self.assertEqual(final["activeVideoResolveRevision"], -1)
        self.assertEqual(final["workerError"], "")
        self.assertEqual(final["presentationError"], "")
        self.assertEqual(final["error"], "")
        self.assertFalse(final["telemetryLoaded"])
        self.assertEqual(final["presentationState"], "inline")
        self.assertFalse(final["backgroundReady"])
        self.assertFalse(final["fallbackInline"])
        self.assertEqual(final["status"], "stopped")

    def test_same_url_stop_and_replay_restarts_legacy_preview_resolver(self):
        source_owner, source = make_media_player_source("{}")
        marker = source / "preview-count"
        preview = source / "scripts" / "media-player-preview"
        preview.write_text(
            "#!/bin/sh\n"
            f"marker={str(marker)!r}\n"
            "count=0; [ ! -f \"$marker\" ] || count=$(cat \"$marker\")\n"
            "count=$((count + 1)); printf %s \"$count\" > \"$marker\"\n"
            "if [ \"$count\" -eq 1 ]; then sleep 2; else sleep 0.03; fi\n"
            "printf '{\"url\":\"https://cdn.example.test/preview-%s.mp4\"}\\n' \"$count\"\n",
            encoding="utf-8",
        )
        preview.chmod(0o755)
        with source_owner, tempfile.TemporaryDirectory() as cfg:
            qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var svc: null
  property var track: null
  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.media-player/Service.qml')}", Component.PreferSynchronous)
    svc = component.createObject(root, {{ manifest: {{ __sourceDir: "{source}" }} }})
    setup.start()
  }}
  Timer {{
    id: setup; interval: 20; repeat: true
    onTriggered: {{
      if (!svc || !svc.stateLoaded) return
      stop()
      svc.workerReady = false; svc.workerConfigured = false
      svc.mpvAvailable = true; svc.ytdlpAvailable = true
      root.track = svc.normalizeTrack({{ id: "same", provider: "youtube", url: "https://example.test/same", mediaType: "video" }})
      svc.currentTrack = root.track
      svc.resolvePreview(root.track)
      replay.start()
    }}
  }}
  Timer {{
    id: replay; interval: 500
    onTriggered: {{
      svc.stop()
      svc.currentTrack = root.track
      svc.playing = true
      svc.resolvePreview(root.track)
      finish.start()
    }}
  }}
  Timer {{
    id: finish; interval: 650
    onTriggered: {{
      console.log("BEHAVE " + JSON.stringify({{
        preview: svc.previewStreamUrl,
        resolving: svc.resolvingPreview,
        request: svc.previewRequestUrl
      }}))
      Qt.quit()
    }}
  }}
}}
"""
            output = run_quickshell(qml, config_home=Path(cfg), timeout=8)
            count = marker.read_text(encoding="utf-8") if marker.exists() else "0"

        require_no_qml_errors(output)
        final = parse_behave(output)[-1]
        self.assertEqual(count, "2", output[-2000:])
        self.assertEqual(final["preview"], "https://cdn.example.test/preview-2.mp4", output[-2000:])
        self.assertFalse(final["resolving"], output[-2000:])
        self.assertEqual(final["request"], "https://example.test/same", output[-2000:])

    def test_same_url_stop_and_replay_restarts_legacy_background_resolver(self):
        source_owner, source = make_media_player_source("{}")
        marker = source / "background-count"
        background = source / "scripts" / "media-player-background"
        background.write_text(
            "#!/bin/sh\n"
            f"marker={str(marker)!r}\n"
            "count=0; [ ! -f \"$marker\" ] || count=$(cat \"$marker\")\n"
            "count=$((count + 1)); printf %s \"$count\" > \"$marker\"\n"
            "if [ \"$count\" -eq 1 ]; then sleep 0.35; else sleep 0.03; fi\n"
            "printf '{\"url\":\"https://cdn.example.test/background-%s.mp4\"}\\n' \"$count\"\n",
            encoding="utf-8",
        )
        background.chmod(0o755)
        with source_owner, tempfile.TemporaryDirectory() as cfg:
            qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var svc: null
  property var track: null
  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.media-player/Service.qml')}", Component.PreferSynchronous)
    svc = component.createObject(root, {{ manifest: {{ __sourceDir: "{source}" }} }})
    setup.start()
  }}
  Timer {{
    id: setup; interval: 20; repeat: true
    onTriggered: {{
      if (!svc || !svc.stateLoaded) return
      stop()
      svc.workerReady = false; svc.workerConfigured = false
      svc.mpvAvailable = true; svc.ytdlpAvailable = true
      root.track = svc.normalizeTrack({{ id: "same", provider: "youtube", url: "https://example.test/same", mediaType: "video" }})
      svc.currentTrack = root.track
      svc.resolveBackground(root.track)
      replay.start()
    }}
  }}
  Timer {{
    id: replay; interval: 90
    onTriggered: {{
      svc.stop()
      svc.currentTrack = root.track
      svc.playing = true
      svc.streamUrlCache = ({{}})
      svc.resolveBackground(root.track)
      finish.start()
    }}
  }}
  Timer {{
    id: finish; interval: 650
    onTriggered: {{
      console.log("BEHAVE " + JSON.stringify({{
        background: svc.backgroundStreamUrl,
        resolving: svc.resolvingBackground,
        request: svc.backgroundRequestUrl
      }}))
      Qt.quit()
    }}
  }}
}}
"""
            output = run_quickshell(qml, config_home=Path(cfg), timeout=8)
            count = marker.read_text(encoding="utf-8") if marker.exists() else "0"

        require_no_qml_errors(output)
        final = parse_behave(output)[-1]
        self.assertEqual(count, "2", output[-2000:])
        self.assertEqual(final["background"], "https://cdn.example.test/background-2.mp4", output[-2000:])
        self.assertFalse(final["resolving"], output[-2000:])
        self.assertEqual(final["request"], "https://example.test/same", output[-2000:])

    def test_temporary_provider_unavailability_preserves_selected_filter(self):
        source_owner, source = make_media_player_source("{}")
        with source_owner, tempfile.TemporaryDirectory() as cfg:
            qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var svc: null
  property string youtubeFilter: ""
  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.media-player/Service.qml')}", Component.PreferSynchronous)
    svc = component.createObject(root, {{ manifest: {{ __sourceDir: "{source}" }} }})
  }}
  Timer {{
    interval: 20
    repeat: true
    running: true
    onTriggered: {{
      if (!svc || !svc.stateLoaded) return
      stop()
      svc.ytdlpAvailable = true
      svc.setProviderFilter("youtube")
      svc.ytdlpAvailable = false
      root.youtubeFilter = svc.providerFilter
      svc.lacunaSettings = {{ mediaProviders: {{ jellyfin: {{ enabled: true, serverUrl: "https://example.test", apiKey: "secret" }} }} }}
      jellyfinReady.start()
    }}
  }}
  Timer {{
    id: jellyfinReady
    interval: 20
    repeat: true
    onTriggered: {{
      if (!svc.jellyfinConfigured) return
      stop()
      svc.setProviderFilter("jellyfin")
      svc.lacunaSettings = {{ mediaProviders: {{}} }}
      finish.start()
    }}
  }}
  Timer {{
    id: finish
    interval: 40
    onTriggered: {{
      console.log("BEHAVE " + JSON.stringify({{
        youtubeFilter: root.youtubeFilter,
        jellyfinConfigured: svc.jellyfinConfigured,
        jellyfinFilter: svc.providerFilter
      }}))
      Qt.quit()
    }}
  }}
}}
"""
            output = run_quickshell(qml, config_home=Path(cfg), timeout=8)

        require_no_qml_errors(output)
        final = parse_behave(output)[-1]
        self.assertEqual(final["youtubeFilter"], "youtube", output[-2000:])
        self.assertFalse(final["jellyfinConfigured"], output[-2000:])
        self.assertEqual(final["jellyfinFilter"], "jellyfin", output[-2000:])

    def test_v3_state_migrates_to_v4_defaults_without_losing_queue(self):
        source_owner, source = make_media_player_source("{}")
        with source_owner, tempfile.TemporaryDirectory() as cfg:
            qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var svc: null
  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.media-player/Service.qml')}", Component.PreferSynchronous)
    svc = component.createObject(root, {{ manifest: {{ __sourceDir: "{source}" }} }})
    finish.start()
  }}
  Timer {{
    id: finish
    interval: 20
    repeat: true
    onTriggered: {{
      if (!svc || !svc.stateLoaded) return
      stop()
      svc.applyLoadedState(JSON.stringify({{
        version: 3,
        queue: [{{ title: "Queued", url: "https://example.test/queued" }}],
        volume: 42,
        repeatMode: "all"
      }}))
      var payload = JSON.parse(svc.statePayload())
      console.log("BEHAVE " + JSON.stringify({{
        version: payload.version,
        queueLength: payload.queue.length,
        volume: payload.volume,
        repeatMode: payload.repeatMode,
        presentationMode: payload.presentationMode,
        videoQuality: payload.videoQuality,
        providerFilter: payload.providerFilter
      }}))
      Qt.quit()
    }}
  }}
}}
"""
            output = run_quickshell(qml, config_home=Path(cfg), timeout=8)

        require_no_qml_errors(output)
        final = parse_behave(output)[-1]
        self.assertEqual(final["version"], 4)
        self.assertEqual(final["queueLength"], 1)
        self.assertEqual(final["volume"], 42)
        self.assertEqual(final["repeatMode"], "all")
        self.assertEqual(final["presentationMode"], "auto")
        self.assertEqual(final["videoQuality"], "adaptive")
        self.assertEqual(final["providerFilter"], "all")


if __name__ == "__main__":
    unittest.main()
