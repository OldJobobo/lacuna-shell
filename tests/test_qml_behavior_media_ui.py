import unittest

from qml_harness import HAVE_SESSION, parse_behave, qml_url, require_no_qml_errors, run_quickshell


@unittest.skipUnless(HAVE_SESSION, "needs a quickshell binary and a Wayland session")
class QmlMediaUiBehaviorTests(unittest.TestCase):
    def test_flyout_filters_progressive_results_and_changes_presentation(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var flyout: null

  QtObject {{
    id: service
    property bool available: true
    property bool hasTrack: true
    property bool playing: true
    property bool paused: false
    property bool backgroundVideoEnabled: false
    property string displayTitle: "Track"
    property bool youtubeLoginEnabled: false
    property bool currentFavorite: false
    property var currentTrack: ({{ title: "Track" }})
    property var queue: []
    property var favorites: []
    property int favoritesRevision: 0
    property int favoritesLength: 0
    property string repeatMode: "none"
    property string searchFilter: "all"
    property string providerFilter: "all"
    property string presentationMode: "auto"
    property string presentationState: "inline"
    property var providerStates: ({{
      youtube: {{ loading: false, complete: true, error: "", count: 1 }},
      jellyfin: {{ loading: true, complete: false, error: "", count: 1 }}
    }})
    property var results: [
      {{ title: "YouTube result", provider: "youtube", uploader: "Channel", duration: "3:00" }},
      {{ title: "Jellyfin result", provider: "jellyfin", artist: "Artist", duration: "4:00" }}
    ]
    property bool searching: true
    property bool canLoadMore: false
    property string errorText: ""
    property int defaultSuggestionCalls: 0
    property int draftCalls: 0
    property string playedTitle: ""
    property string queuedTitle: ""

    function statusText() {{ return "Playing" }}
    function isYoutubeUrl(value) {{ return false }}
    function isFavorite(track) {{ return false }}
    function loadDefaultSuggestions() {{ defaultSuggestionCalls += 1 }}
    function previewSearch(value) {{ draftCalls += 1 }}
    function setVisibleLimit(value) {{}}
    function setProviderFilter(value) {{ providerFilter = value }}
    function setPresentationMode(value) {{ presentationMode = value }}
    function playNow(track) {{ playedTitle = track.title }}
    function addToQueue(track) {{ queuedTitle = track.title }}
  }}

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/menu/FlyoutMediaPlayerContent.qml')}")
    if (component.status === Component.Error) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    flyout = component.createObject(root, {{
      service: service,
      width: 520,
      height: 480,
      open: true,
      contentVisible: true
    }})
    probe.restart()
  }}

  Timer {{
    id: probe
    interval: 50
    repeat: false
    onTriggered: {{
      var initial = root.flyout.visibleSearchResults.length
      root.flyout.setProviderFilter("youtube")
      var filtered = root.flyout.visibleSearchResults.length
      root.flyout.setProviderFilter("jellyfin")
      var resetIndex = root.flyout.selectedResultIndex
      root.flyout.moveResultSelection(1)
      root.flyout.activateSelectedResult(false)
      root.flyout.selectedResultIndex = 0
      root.flyout.activateSelectedResult(true)
      root.flyout.searchPasteMenuOpen = true
      root.flyout.activeTab = "queue"
      var dismissedOnTab = !root.flyout.searchPasteMenuOpen
      root.flyout.activeTab = "search"
      root.flyout.searchPasteMenuOpen = true
      root.flyout.dismissSearchPasteMenuAt(root.flyout.width, root.flyout.height)
      var dismissedOutside = !root.flyout.searchPasteMenuOpen
      root.flyout.forceSearchFocus()
      root.flyout.activeTab = "favorites"
      var focusedOnFavorites = root.flyout.searchInputFocused
      root.flyout.setPresentationMode("background")
      console.log("BEHAVE " + JSON.stringify({{
        initial: initial,
        filtered: filtered,
        providerFilter: service.providerFilter,
        resetIndex: resetIndex,
        playedTitle: service.playedTitle,
        queuedTitle: service.queuedTitle,
        dismissedOnTab: dismissedOnTab,
        dismissedOutside: dismissedOutside,
        focusedOnFavorites: focusedOnFavorites,
        presentationMode: service.presentationMode,
        jellyfinLoading: root.flyout.providerStatus("jellyfin").loading
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml)
        require_no_qml_errors(output)
        row = parse_behave(output)[0]
        self.assertEqual(row["initial"], 2, output[-2000:])
        self.assertEqual(row["filtered"], 1, output[-2000:])
        self.assertEqual(row["providerFilter"], "jellyfin", output[-2000:])
        self.assertEqual(row["resetIndex"], -1, output[-2000:])
        self.assertEqual(row["playedTitle"], "Jellyfin result", output[-2000:])
        self.assertEqual(row["queuedTitle"], "Jellyfin result", output[-2000:])
        self.assertTrue(row["dismissedOnTab"], output[-2000:])
        self.assertTrue(row["dismissedOutside"], output[-2000:])
        self.assertFalse(row["focusedOnFavorites"], output[-2000:])
        self.assertEqual(row["presentationMode"], "background", output[-2000:])
        self.assertTrue(row["jellyfinLoading"], output[-2000:])

    def test_inline_renderer_keeps_pause_buffer_but_unloads_on_stop(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var tile: null

  QtObject {{
    id: service
    property bool available: true
    property bool hasTrack: true
    property bool playing: true
    property bool paused: false
    property string presentationState: "inline"
    property bool backgroundVideoEnabled: false
    property string displayTitle: "Track"
    property string thumbnail: ""
    property string previewStreamUrl: "file:///dev/null?stable"
    property string adaptivePreviewStreamUrl: ""
    property string progressivePreviewStreamUrl: "file:///dev/null?stable"
    property real playbackPosition: 0
    property int playbackSessionRevision: 3
    property int presentationRevision: 4
    property int videoResolveRevision: 8
    property string pendingHandoffSurface: ""
    property int favoritesRevision: 0
    property bool currentFavorite: false
    property string repeatMode: "none"
    property int volume: 70
    property var currentTrack: ({{ title: "Track" }})
    property var lacunaSettings: ({{ reduceMotion: true }})
    property int loadingCalls: 0
    property var lastLoadingToken: null
    function statusText() {{ return playing ? (paused ? "Paused" : "Playing") : "Stopped" }}
    function setInlineSurfaceAvailable(value) {{}}
    function updatePreviewTelemetry(value) {{}}
    function reportVideoLoading(surface, token, diagnostics) {{ loadingCalls += 1; lastLoadingToken = token; return true }}
    function reportVideoReady(surface, revision, position) {{}}
    function reportVideoFailure(surface, revision, reason) {{}}
  }}

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/menu/MediaPlayerTile.qml')}", Component.PreferSynchronous)
    if (component.status !== Component.Ready) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    tile = component.createObject(root, {{ service: service, width: 300 }})
    probe.restart()
  }}

  Timer {{
    id: probe
    interval: 30
    onTriggered: {{
      var activeLoaded = tile.previewSourceLoaded
      var initialLoadingCalls = service.loadingCalls
      var firstSourceRevision = tile.previewSourceRevision
      var oldGeneration = {{ source: tile.assignedPreviewSource, lacunaSourceRevision: firstSourceRevision }}
      service.presentationRevision = 5
      service.pendingHandoffSurface = "background"
      service.presentationState = "promoting"
      var promotionSourceRevision = tile.previewSourceRevision
      service.presentationRevision = 6
      service.pendingHandoffSurface = "inline"
      service.presentationState = "demoting"
      var newestPresentationRevision = service.lastLoadingToken.presentationRevision
      var demotionSourceRevision = tile.previewSourceRevision
      var lateOldEventAccepted = tile.inlineSourceGenerationIsCurrent(oldGeneration)
      var newestGenerationAccepted = tile.inlineSourceGenerationIsCurrent({{
        source: tile.assignedPreviewSource,
        lacunaSourceRevision: demotionSourceRevision
      }})
      service.paused = true
      var pausedLoaded = tile.previewSourceLoaded
      service.playing = false
      var stoppedLoaded = tile.previewSourceLoaded
      service.paused = false
      service.playing = true
      var replayLoaded = tile.previewSourceLoaded
      var secondSourceRevision = tile.previewSourceRevision
      service.playing = false
      console.log("BEHAVE " + JSON.stringify({{
        activeLoaded: activeLoaded,
        pausedLoaded: pausedLoaded,
        stoppedLoaded: stoppedLoaded,
        replayLoaded: replayLoaded,
        loadingCalls: service.loadingCalls,
        newLoadingCalls: service.loadingCalls - initialLoadingCalls,
        firstSourceRevision: firstSourceRevision,
        promotionSourceRevision: promotionSourceRevision,
        demotionSourceRevision: demotionSourceRevision,
        newestPresentationRevision: newestPresentationRevision,
        lateOldEventAccepted: lateOldEventAccepted,
        newestGenerationAccepted: newestGenerationAccepted,
        secondSourceRevision: secondSourceRevision,
        rendererActive: tile.previewRendererActive
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        row = parse_behave(output)[-1]
        self.assertTrue(row["activeLoaded"], output[-2000:])
        self.assertTrue(row["pausedLoaded"], output[-2000:])
        self.assertFalse(row["stoppedLoaded"], output[-2000:])
        self.assertTrue(row["replayLoaded"], output[-2000:])
        self.assertGreaterEqual(row["loadingCalls"], 3, output[-2000:])
        self.assertEqual(row["newLoadingCalls"], 2, output[-2000:])
        self.assertEqual(row["promotionSourceRevision"], row["firstSourceRevision"])
        self.assertEqual(row["demotionSourceRevision"], row["promotionSourceRevision"])
        self.assertEqual(row["newestPresentationRevision"], 6)
        self.assertTrue(row["lateOldEventAccepted"])
        self.assertTrue(row["newestGenerationAccepted"])
        self.assertGreater(row["secondSourceRevision"], row["demotionSourceRevision"])
        self.assertFalse(row["rendererActive"], output[-2000:])

    def test_inline_adaptive_timeout_ignores_hidden_and_paused_renderer(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var tile: null

  QtObject {{
    id: service
    property bool available: true
    property bool hasTrack: true
    property bool playing: true
    property bool paused: false
    property string presentationState: "background"
    property bool backgroundVideoEnabled: true
    property string displayTitle: "Track"
    property string thumbnail: ""
    property string previewStreamUrl: "file:///dev/null?adaptive"
    property string adaptivePreviewStreamUrl: "file:///dev/null?adaptive"
    property string progressivePreviewStreamUrl: "file:///dev/null?stable"
    property real playbackPosition: 0
    property int playbackSessionRevision: 2
    property int favoritesRevision: 0
    property bool currentFavorite: false
    property string repeatMode: "none"
    property int volume: 70
    property var currentTrack: ({{ title: "Track" }})
    property var lacunaSettings: ({{ reduceMotion: true }})
    property int failureReports: 0
    function statusText() {{ return "Playing" }}
    function setInlineSurfaceAvailable(value) {{}}
    function updatePreviewTelemetry(value) {{}}
    function reportVideoReady(surface, revision, position) {{}}
    function reportVideoFailure(surface, revision, reason) {{ failureReports += 1 }}
  }}

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/menu/MediaPlayerTile.qml')}", Component.PreferSynchronous)
    if (component.status !== Component.Ready) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    tile = component.createObject(root, {{ service: service, width: 300 }})
    probe.restart()
  }}

  Timer {{
    id: probe
    interval: 20
    repeat: false
    onTriggered: {{
    tile.handleAdaptiveReadinessTimeout()
    var hiddenCount = service.failureReports
    service.presentationState = "inline"
    service.paused = true
    tile.handleAdaptiveReadinessTimeout()
    var pausedCount = service.failureReports
    service.paused = false
    tile.handleAdaptiveReadinessTimeout()
    console.log("BEHAVE " + JSON.stringify({{
      hiddenCount: hiddenCount,
      pausedCount: pausedCount,
      visibleCount: service.failureReports
    }}))
    Qt.quit()
  }}
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        row = parse_behave(output)[-1]
        self.assertEqual(row["hiddenCount"], 0, output[-2000:])
        self.assertEqual(row["pausedCount"], 0, output[-2000:])
        self.assertEqual(row["visibleCount"], 1, output[-2000:])


    def test_stopped_media_tile_has_no_qt_multimedia_player(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var tile: null

  QtObject {{
    id: service
    property bool available: true
    property bool hasTrack: true
    property bool playing: true
    property bool paused: false
    property bool backgroundVideoEnabled: false
    property string presentationState: "idle"
    property string displayTitle: ""
    property string thumbnail: ""
    property string previewStreamUrl: "file:///tmp/lacuna-phase6-missing.mp4"
    property string adaptivePreviewStreamUrl: ""
    property string progressivePreviewStreamUrl: "file:///tmp/lacuna-phase6-missing.mp4"
    property real playbackPosition: 0
    property real playbackDuration: 0
    property int playbackSessionRevision: 0
    property int presentationRevision: 0
    property int videoResolveRevision: 0
    property string pendingHandoffSurface: ""
    property int favoritesRevision: 0
    property bool currentFavorite: false
    property string repeatMode: "none"
    property int volume: 70
    property var currentTrack: null
    property var lacunaSettings: ({{ reduceMotion: true }})
    function statusText() {{ return "Stopped" }}
  }}

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/menu/MediaPlayerTile.qml')}")
    if (component.status === Component.Error) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    tile = component.createObject(root, {{ service: service, width: 420 }})
    probe.restart()
  }}

  Timer {{
    id: probe
    property bool wasLoaded: false
    interval: 150
    onTriggered: {{
      wasLoaded = root.tile.previewPlayerLoaded
      service.playing = false
      settle.restart()
    }}
  }}

  Timer {{
    id: settle
    interval: 100
    onTriggered: {{
      console.log("BEHAVE " + JSON.stringify({{
        wasLoaded: probe.wasLoaded,
        loaded: root.tile.previewPlayerLoaded,
        playerNull: root.tile.previewPlayer === null,
        desiredSource: root.tile.desiredPreviewSource
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        row = parse_behave(output)[-1]
        self.assertTrue(row["wasLoaded"])
        self.assertFalse(row["loaded"])
        self.assertTrue(row["playerNull"])
        self.assertEqual("", row["desiredSource"])


if __name__ == "__main__":
    unittest.main()
