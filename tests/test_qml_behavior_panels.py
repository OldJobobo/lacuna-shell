import unittest
from pathlib import Path

from qml_harness import HAVE_SESSION, parse_behave, qml_url, require_no_qml_errors, run_quickshell


ROOT = Path(__file__).resolve().parents[1]


class SettingsFlyoutTransitionContracts(unittest.TestCase):
    def test_settings_surfaces_do_not_reanimate_controller_owned_opacity(self):
        for relative in [
            "lacuna.menu/settings/SettingsWindow.qml",
            "lacuna.menu/settings/OmarchyShellSettingsWindow.qml",
            "lacuna.shell-settings/settings/OmarchyShellSettingsWindow.qml",
        ]:
            qml = (ROOT / relative).read_text(encoding="utf-8")
            self.assertNotIn("Behavior on opacity", qml, relative)

        window = (ROOT / "lacuna.menu/menu/MenuWindow.qml").read_text(encoding="utf-8")
        self.assertIn('opacity: root.flyoutContentOpacity("settings")', window)
        self.assertIn('opacity: root.flyoutContentOpacity("shellSettings")', window)


@unittest.skipUnless(HAVE_SESSION, "needs a quickshell binary and a Wayland session")
class QmlPanelBehaviorTests(unittest.TestCase):
    def test_settings_toggle_uses_requested_on_off_palette(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var menuOff: null
  property var menuOn: null
  property var shellOff: null
  property var shellOn: null

  Component.onCompleted: {{
    var menuComponent = Qt.createComponent("{qml_url('lacuna.menu/settings/SettingsRow.qml')}", Component.PreferSynchronous)
    var shellComponent = Qt.createComponent("{qml_url('lacuna.shell-settings/settings/SettingsRow.qml')}", Component.PreferSynchronous)
    var colors = {{
      control: "toggle",
      foreground: "#f0f0f0",
      background: "#101010",
      muted: "#777777",
      toneAccent: "#ff3366"
    }}
    menuOff = menuComponent.createObject(root, Object.assign({{}}, colors, {{ checked: false }}))
    menuOn = menuComponent.createObject(root, Object.assign({{}}, colors, {{ checked: true }}))
    shellOff = shellComponent.createObject(root, Object.assign({{}}, colors, {{ checked: false }}))
    shellOn = shellComponent.createObject(root, Object.assign({{}}, colors, {{ checked: true }}))
    probe.restart()
  }}

  Timer {{
    id: probe
    interval: 30
    onTriggered: {{
      console.log("BEHAVE " + JSON.stringify({{
        menuOnKnob: root.menuOn.toggleKnobColor.toString(),
        menuOffKnob: root.menuOff.toggleKnobColor.toString(),
        menuOnTrackAlpha: root.menuOn.toggleTrackColor.a,
        menuOffTrackAlpha: root.menuOff.toggleTrackColor.a,
        menuOnBorderAlpha: root.menuOn.toggleBorderColor.a,
        menuOffBorderAlpha: root.menuOff.toggleBorderColor.a,
        shellOnKnob: root.shellOn.toggleKnobColor.toString(),
        shellOffKnob: root.shellOff.toggleKnobColor.toString(),
        shellOnTrackAlpha: root.shellOn.toggleTrackColor.a,
        shellOffTrackAlpha: root.shellOff.toggleTrackColor.a,
        shellOnBorderAlpha: root.shellOn.toggleBorderColor.a,
        shellOffBorderAlpha: root.shellOff.toggleBorderColor.a
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        row = parse_behave(output)[-1]

        self.assertEqual("#f0f0f0", row["menuOnKnob"])
        self.assertEqual("#101010", row["menuOffKnob"])
        self.assertLess(row["menuOnTrackAlpha"], row["menuOffTrackAlpha"])
        self.assertLess(row["menuOnBorderAlpha"], row["menuOffBorderAlpha"])
        self.assertEqual("#f0f0f0", row["shellOnKnob"])
        self.assertEqual("#101010", row["shellOffKnob"])
        self.assertLess(row["shellOnTrackAlpha"], row["shellOffTrackAlpha"])
        self.assertLess(row["shellOnBorderAlpha"], row["shellOffBorderAlpha"])

    def test_panel_geometry_transaction_is_newest_wins_and_reduced_motion_atomic(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var host: null

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/menu/LacunaPanelHost.qml')}", Component.PreferSynchronous)
    if (component.status !== Component.Ready) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    host = component.createObject(root, {{
      flyoutRenderable: true,
      flyoutProgress: 1,
      geometryTransitionEnabled: false,
      geometryAnimationDuration: 10000
    }})
    probe.restart()
  }}

  Timer {{
    id: probe
    interval: 30
    onTriggered: {{
      var a = host.makePanelGeometry(80, 560, 620, 18, 33, false, 18)
      var b = host.makePanelGeometry(160, 420, 440, 0, 0, false, 0)
      var c = host.makePanelGeometry(40, 600, 500, 18, 33, false, 18)
      host.requestPanelGeometry(a, "A")
      host.geometryTransitionEnabled = true
      host.requestPanelGeometry(b, "B")
      host.geometryAnimationController.stop()
      host.panelGeometryProgress = 0.4
      var interrupted = host.copyPanelGeometry(host.effectivePanelGeometry)
      var visibleDuringConnectorExit = host.effectiveConnectorVisible
      var beforeRevision = host.panelGeometryRevision
      host.requestPanelGeometry(c, "C")
      host.geometryAnimationController.stop()
      var capturedNewest = host.copyPanelGeometry(host.fromPanelGeometry)
      host.panelGeometryProgress = 0.5
      var newestMiddle = host.copyPanelGeometry(host.effectivePanelGeometry)
      host.requestPanelGeometry(a, "A-reversal")
      host.geometryAnimationController.stop()
      var reversalFrom = host.copyPanelGeometry(host.fromPanelGeometry)
      host.reducedMotion = true
      host.requestPanelGeometry(b, "reduced")
      console.log("BEHAVE " + JSON.stringify({{
        interrupted: interrupted,
        capturedNewest: capturedNewest,
        newestMiddle: newestMiddle,
        reversalFrom: reversalFrom,
        revisionAdvanced: host.panelGeometryRevision > beforeRevision,
        visibleDuringConnectorExit: visibleDuringConnectorExit,
        interruptedRadiusMatchesConnector: interrupted.panelRadius === interrupted.connectorWidth,
        middleRadiusMatchesConnector: newestMiddle.panelRadius === newestMiddle.connectorWidth,
        reducedTarget: host.copyPanelGeometry(host.effectivePanelGeometry),
        reducedInactive: !host.panelGeometryTransitionActive,
        connectorHiddenAtZero: !host.effectiveConnectorVisible
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        row = parse_behave(output)[-1]
        expected_interrupted = {
            "flyoutY": 112,
            "flyoutWidth": 504,
            "flyoutHeight": 548,
            "connectorWidth": 11,
            "connectorOverlap": 20,
            "panelRadius": 11,
            "anchorRight": False,
        }
        for key, expected in expected_interrupted.items():
            if isinstance(expected, bool):
                self.assertEqual(expected, row["interrupted"][key], output[-2000:])
                self.assertEqual(expected, row["capturedNewest"][key], output[-2000:])
            else:
                self.assertAlmostEqual(expected, row["interrupted"][key], places=6, msg=output[-2000:])
                self.assertAlmostEqual(expected, row["capturedNewest"][key], places=6, msg=output[-2000:])
        expected_middle = {
            "flyoutY": 76,
            "flyoutWidth": 552,
            "flyoutHeight": 524,
            "connectorWidth": 15,
            "connectorOverlap": 27,
            "panelRadius": 15,
            "anchorRight": False,
        }
        for key, expected in expected_middle.items():
            if isinstance(expected, bool):
                self.assertEqual(expected, row["newestMiddle"][key], output[-2000:])
            else:
                self.assertAlmostEqual(expected, row["newestMiddle"][key], places=6, msg=output[-2000:])
        self.assertEqual(row["newestMiddle"], row["reversalFrom"], output[-2000:])
        self.assertTrue(row["revisionAdvanced"], output[-2000:])
        self.assertTrue(row["visibleDuringConnectorExit"], output[-2000:])
        self.assertTrue(row["interruptedRadiusMatchesConnector"], output[-2000:])
        self.assertTrue(row["middleRadiusMatchesConnector"], output[-2000:])
        self.assertEqual(0, row["reducedTarget"]["connectorWidth"], output[-2000:])
        self.assertEqual(0, row["reducedTarget"]["panelRadius"], output[-2000:])
        self.assertTrue(row["reducedInactive"], output[-2000:])
        self.assertTrue(row["connectorHiddenAtZero"], output[-2000:])

    def test_transactional_input_masks_empty_and_track_effective_geometry(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var host: null

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/menu/LacunaPanelHost.qml')}", Component.PreferSynchronous)
    if (component.status !== Component.Ready) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    host = component.createObject(root, {{
      panelWidth: 248,
      sidebarHeight: 900,
      flyoutRenderable: true,
      flyoutProgress: 0.5,
      geometryTransitionEnabled: false
    }})
    host.requestPanelGeometry(host.makePanelGeometry(60, 560, 620, 18, 33, false, 18), "open")
    var middle = {{
      connectorWidth: host.connectorMaskWidth,
      connectorHeight: host.connectorMaskHeight,
      flyoutWidth: host.flyoutMaskWidth,
      flyoutHeight: host.flyoutMaskHeight
    }}
    host.flyoutProgress = 0
    var closedProgress = {{ connectorWidth: host.connectorMaskWidth, flyoutWidth: host.flyoutMaskWidth }}
    host.flyoutRenderable = false
    var empty = {{
      connectorWidth: host.connectorMaskWidth,
      connectorHeight: host.connectorMaskHeight,
      flyoutWidth: host.flyoutMaskWidth,
      flyoutHeight: host.flyoutMaskHeight
    }}
    console.log("BEHAVE " + JSON.stringify({{ middle: middle, closedProgress: closedProgress, empty: empty }}))
    finish.start()
  }}

  Timer {{ id: finish; interval: 20; onTriggered: Qt.quit() }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        row = parse_behave(output)[-1]
        self.assertEqual(18, row["middle"]["connectorWidth"])
        self.assertEqual(656, row["middle"]["connectorHeight"])
        self.assertEqual(280, row["middle"]["flyoutWidth"])
        self.assertEqual(620, row["middle"]["flyoutHeight"])
        self.assertEqual(18, row["closedProgress"]["connectorWidth"])
        self.assertEqual(0, row["closedProgress"]["flyoutWidth"])
        self.assertEqual(
            {"connectorWidth": 0, "connectorHeight": 0, "flyoutWidth": 0, "flyoutHeight": 0},
            row["empty"],
        )

    def test_persistent_sidebar_rejects_external_close_without_hiding(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var controller: null

  QtObject {{
    id: menuState
    property bool open: true
    function show() {{ open = true }}
    function close() {{ open = false }}
  }}

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/services/PanelController.qml')}")
    controller = component.createObject(root, {{
      menuState: menuState,
      retainMenuOnExternalClose: true,
      animationDuration: 10000,
      panelVisible: true,
      menuProgress: 1
    }})
    menuState.open = false
    console.log("BEHAVE " + JSON.stringify({{
      open: menuState.open,
      progress: controller.menuProgress,
      visible: controller.panelVisible,
      state: controller.menuStateName,
      target: controller.menuAnimationTarget
    }}))
    quitTimer.start()
  }}

  Timer {{ id: quitTimer; interval: 20; onTriggered: Qt.quit() }}
}}
"""
        output = run_quickshell(qml)
        require_no_qml_errors(output)
        row = parse_behave(output)[0]
        self.assertTrue(row["open"])
        self.assertEqual(row["progress"], 1)
        self.assertTrue(row["visible"])
        self.assertEqual(row["target"], 1)

    def test_panel_controller_threshold_queue_and_reduced_motion_contract(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var controller: null
  QtObject {{
    id: menuState
    property bool open: true
    function show() {{ open = true }}
    function close() {{ open = false }}
  }}
  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/services/PanelController.qml')}")
    controller = component.createObject(root, {{ menuState: menuState }})
    controller.animationDuration = 10000
    controller.panelVisible = true
    controller.menuProgress = 0.64
    controller.openFlyout("settings")
    console.log("BEHAVE " + JSON.stringify({{ label: "queued", pending: controller.pendingFlyout, active: controller.activeFlyout, content: controller.contentProgress }}))
    controller.motionTokens.animationDisabled = true
    controller.menuProgress = 0.65
    console.log("BEHAVE " + JSON.stringify({{ label: "threshold", pending: controller.pendingFlyout, active: controller.activeFlyout, flyout: controller.flyoutProgress, content: controller.contentProgress }}))
    controller.closeMenu()
    console.log("BEHAVE " + JSON.stringify({{ label: "cancelled", pending: controller.pendingFlyout, active: controller.activeFlyout }}))
    quitTimer.start()
  }}
  Timer {{ id: quitTimer; interval: 20; repeat: false; onTriggered: Qt.quit() }}
}}
"""
        output = run_quickshell(qml)
        require_no_qml_errors(output)
        rows = {row["label"]: row for row in parse_behave(output)}
        self.assertEqual(rows["queued"]["pending"], "settings")
        self.assertEqual(rows["queued"]["active"], "")
        self.assertEqual(rows["queued"]["content"], 0)
        self.assertEqual(rows["threshold"]["active"], "settings")
        self.assertEqual(rows["threshold"]["flyout"], 1)
        self.assertEqual(rows["threshold"]["content"], 1)
        self.assertEqual(rows["cancelled"]["pending"], "")

    def test_panel_controller_preserves_content_blend_on_interrupt_and_close(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var controller: null
  QtObject {{
    id: menuState
    property bool open: true
    function show() {{ open = true }}
    function close() {{ open = false }}
  }}
  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/services/PanelController.qml')}")
    controller = component.createObject(root, {{ menuState: menuState }})
    controller.motionTokens.animationDisabled = true
    controller.panelVisible = true; controller.menuProgress = 1
    controller.openFlyout("a")
    controller.motionTokens.animationDisabled = false
    controller.openFlyout("b")
    controller.contentSwitchProgress = 0.4
    controller.openFlyout("c")
    console.log("BEHAVE " + JSON.stringify({{ label: "third", retained: controller.retainedFlyout, retainedWeight: controller.retainedFlyoutWeight, outgoing: controller.outgoingFlyout, outgoingWeight: controller.outgoingFlyoutWeight, incoming: controller.incomingFlyout, a: controller.contentSwitchOpacity("a"), b: controller.contentSwitchOpacity("b"), c: controller.contentSwitchOpacity("c") }}))
    controller.contentSwitchProgress = 0.3
    controller.closeActiveFlyout()
    console.log("BEHAVE " + JSON.stringify({{ label: "close", retained: controller.retainedFlyout, retainedWeight: controller.retainedFlyoutWeight, outgoing: controller.outgoingFlyout, outgoingWeight: controller.outgoingFlyoutWeight, closing: controller.closingFlyout, incoming: controller.incomingFlyout, a: controller.contentSwitchOpacity("a"), b: controller.contentSwitchOpacity("b"), c: controller.contentSwitchOpacity("c") }}))
    quitTimer.start()
  }}
  Timer {{ id: quitTimer; interval: 20; repeat: false; onTriggered: Qt.quit() }}
}}
"""
        output = run_quickshell(qml)
        require_no_qml_errors(output)
        rows = {row["label"]: row for row in parse_behave(output)}
        third = rows["third"]
        self.assertEqual((third["retained"], third["outgoing"], third["incoming"]), ("a", "b", "c"))
        self.assertAlmostEqual(third["a"], 0.6)
        self.assertAlmostEqual(third["b"], 0.4)
        self.assertEqual(third["c"], 0)
        close = rows["close"]
        self.assertEqual(close["incoming"], "")
        self.assertAlmostEqual(close["a"], 0.42)
        self.assertAlmostEqual(close["b"], 0.28)
        self.assertEqual(close["closing"], "c")
        self.assertAlmostEqual(close["c"], 0.3)

    def test_panel_controller_sums_roles_when_switch_reverses(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var controller: null
  QtObject {{
    id: menuState
    property bool open: true
    function show() {{ open = true }}
    function close() {{ open = false }}
  }}
  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/services/PanelController.qml')}")
    controller = component.createObject(root, {{ menuState: menuState }})
    controller.motionTokens.animationDisabled = true
    controller.panelVisible = true
    controller.menuProgress = 1
    controller.openFlyout("a")
    controller.motionTokens.animationDisabled = false
    controller.openFlyout("b")
    controller.contentSwitchProgress = 0.4
    controller.openFlyout("a")
    controller.contentSwitchProgress = 0.5
    console.log("BEHAVE " + JSON.stringify({{ label: "reverse", a: controller.contentSwitchOpacity("a"), b: controller.contentSwitchOpacity("b") }}))
    quitTimer.start()
  }}
  Timer {{ id: quitTimer; interval: 20; repeat: false; onTriggered: Qt.quit() }}
}}
"""
        output = run_quickshell(qml)
        require_no_qml_errors(output)
        rows = {row["label"]: row for row in parse_behave(output)}
        self.assertAlmostEqual(rows["reverse"]["a"], 0.8)
        self.assertAlmostEqual(rows["reverse"]["b"], 0.2)
        self.assertAlmostEqual(rows["reverse"]["a"] + rows["reverse"]["b"], 1)

    def test_panel_controller_rapid_menu_and_flyout_transitions_settle(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var controller: null

  QtObject {{
    id: menuState
    property bool open: false
    function show() {{ open = true }}
    function close() {{ open = false }}
  }}

  function emitState(label) {{
    console.log("BEHAVE " + JSON.stringify({{
      label: label,
      menuStateName: controller.menuStateName,
      flyoutStateName: controller.flyoutStateName,
      menuProgress: controller.menuProgress,
      flyoutProgress: controller.flyoutProgress,
      activeFlyout: controller.activeFlyout,
      visibleFlyout: controller.visibleFlyout,
      panelVisible: controller.panelVisible,
      menuAnimationRevision: controller.menuAnimationRevision,
      flyoutAnimationRevision: controller.flyoutAnimationRevision
    }}))
  }}

  Component.onCompleted: {{
    var c = Qt.createComponent("{qml_url('lacuna.menu/services/PanelController.qml')}")
    if (c.status === Component.Error) {{
      console.log("BEHAVE_ERR " + c.errorString())
      Qt.quit()
      return
    }}
    controller = c.createObject(root, {{ menuState: menuState, animationDuration: 1 }})
    controller.openMenu()
    firstProbe.restart()
  }}

  Timer {{
    id: firstProbe
    interval: 30
    repeat: false
    onTriggered: {{
      root.emitState("opened")
      root.controller.openFlyout("music")
      secondProbe.restart()
    }}
  }}

  Timer {{
    id: secondProbe
    interval: 30
    repeat: false
    onTriggered: {{
      root.emitState("flyout-open")
      root.controller.toggleFlyout("music")
      root.controller.openFlyout("settings")
      root.controller.closeMenu()
      root.controller.openMenu()
      finalProbe.restart()
    }}
  }}

  Timer {{
    id: finalProbe
    interval: 80
    repeat: false
    onTriggered: {{
      root.emitState("final")
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml)
        require_no_qml_errors(output)
        rows = parse_behave(output)
        self.assertGreaterEqual(len(rows), 3, output[-2000:])
        opened = next(row for row in rows if row["label"] == "opened")
        flyout = next(row for row in rows if row["label"] == "flyout-open")
        final = next(row for row in rows if row["label"] == "final")

        self.assertEqual(opened["menuStateName"], "menuOpen")
        self.assertEqual(opened["menuProgress"], 1)
        self.assertEqual(flyout["flyoutStateName"], "flyoutOpen")
        self.assertEqual(flyout["activeFlyout"], "music")
        self.assertEqual(final["menuStateName"], "menuOpen")
        self.assertEqual(final["flyoutStateName"], "closed")
        self.assertEqual(final["activeFlyout"], "")
        self.assertEqual(final["visibleFlyout"], "")
        self.assertEqual(final["menuAnimationRevision"], -1)
        self.assertEqual(final["flyoutAnimationRevision"], -1)

    def test_flyout_swap_cancels_in_flight_close_animation(self):
        # Regression: closeActiveFlyout() starts an animation to 0; opening
        # another flyout while progress is still ~1 takes the fast-path swap.
        # Without cancelling the in-flight close, its completion cleared
        # visibleFlyout under the freshly opened flyout (open but invisible).
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var controller: null

  QtObject {{
    id: menuState
    property bool open: false
    function show() {{ open = true }}
    function close() {{ open = false }}
  }}

  function emitState(label) {{
    console.log("BEHAVE " + JSON.stringify({{
      label: label,
      flyoutStateName: controller.flyoutStateName,
      flyoutProgress: controller.flyoutProgress,
      activeFlyout: controller.activeFlyout,
      visibleFlyout: controller.visibleFlyout,
      flyoutAnimationRevision: controller.flyoutAnimationRevision
    }}))
  }}

  Component.onCompleted: {{
    var c = Qt.createComponent("{qml_url('lacuna.menu/services/PanelController.qml')}")
    if (c.status === Component.Error) {{
      console.log("BEHAVE_ERR " + c.errorString())
      Qt.quit()
      return
    }}
    controller = c.createObject(root, {{ menuState: menuState, animationDuration: 1 }})
    controller.openMenu()
    controller.openFlyout("music")
    swapProbe.restart()
  }}

  Timer {{
    id: swapProbe
    interval: 40
    repeat: false
    onTriggered: {{
      root.emitState("music-open")
      // Same-turn close-then-open: the close animation is in flight when
      // the fast-path swap runs.
      root.controller.closeActiveFlyout()
      root.controller.openFlyout("settings")
      settleProbe.restart()
    }}
  }}

  Timer {{
    id: settleProbe
    // The shell remains open while the controller-owned quick crossfade
    // completes; this must outlast MotionTokens.quick.
    interval: 220
    repeat: false
    onTriggered: {{
      root.emitState("after-swap")
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml)
        require_no_qml_errors(output)
        rows = parse_behave(output)
        music = next(row for row in rows if row["label"] == "music-open")
        after = next(row for row in rows if row["label"] == "after-swap")

        self.assertEqual(music["activeFlyout"], "music")
        self.assertEqual(music["flyoutProgress"], 1)
        self.assertEqual(after["activeFlyout"], "settings", output[-2000:])
        self.assertEqual(after["visibleFlyout"], "settings", output[-2000:])
        self.assertEqual(after["flyoutStateName"], "flyoutOpen", output[-2000:])
        self.assertEqual(after["flyoutProgress"], 1, output[-2000:])

    def test_youtube_music_tile_unsuppresses_preview_on_sidebar_handoff(self):
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
    property string displayTitle: "Track"
    property string previewStreamUrl: "file:///tmp/lacuna-preview-placeholder.mp4"
    property string thumbnail: ""
    property real playbackPosition: 120
    property int favoritesRevision: 0
    property bool currentFavorite: false
    property string repeatMode: "none"
    property int volume: 70
    function statusText() {{ return "Ready" }}
    function updatePreviewTelemetry(payload) {{}}
    function setVolume(value) {{ volume = value }}
  }}

  function emitState(label) {{
    console.log("BEHAVE " + JSON.stringify({{
      label: label,
      localPreviewVisible: tile.localPreviewVisible,
      previewSuppressed: tile.previewSuppressed,
      previewVideoActive: tile.previewVideoActive,
      previewPositionPending: tile.previewPositionPending
    }}))
  }}

  Component.onCompleted: {{
    var c = Qt.createComponent("{qml_url('lacuna.menu/menu/MediaPlayerTile.qml')}")
    if (c.status === Component.Error) {{
      console.log("BEHAVE_ERR " + c.errorString())
      Qt.quit()
      return
    }}
    tile = c.createObject(root, {{ service: service, width: 320 }})
    tile.previewSuppressed = true
    root.emitState("suppressed-desktop")
    service.backgroundVideoEnabled = true
    hiddenProbe.restart()
  }}

  Timer {{
    id: hiddenProbe
    interval: 20
    repeat: false
    onTriggered: {{
      root.emitState("sent-to-background")
      service.backgroundVideoEnabled = false
      finalProbe.restart()
    }}
  }}

  Timer {{
    id: finalProbe
    interval: 40
    repeat: false
    onTriggered: {{
      root.emitState("returned-to-sidebar")
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml)
        require_no_qml_errors(output)
        rows = parse_behave(output)
        final = next(row for row in rows if row["label"] == "returned-to-sidebar")
        self.assertTrue(final["localPreviewVisible"], output[-2000:])
        self.assertFalse(final["previewSuppressed"], output[-2000:])
        self.assertTrue(final["previewVideoActive"], output[-2000:])


if __name__ == "__main__":
    unittest.main()
