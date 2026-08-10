import tempfile
import unittest
from pathlib import Path

from qml_harness import HAVE_SESSION, parse_behave, qml_url, require_no_qml_errors, run_quickshell


@unittest.skipUnless(HAVE_SESSION, "needs a quickshell binary and a Wayland session")
class QmlFrameBorderBehaviorTests(unittest.TestCase):
    def test_border_consumes_authoritative_frame_geometry_record(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var border: null

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.bar/LacunaFrameBorderWindow.qml')}", Component.PreferSynchronous)
    border = component.createObject(root, {{
      width: 800,
      height: 600,
      active: true,
      frameThickness: 8,
      frameRadius: 14,
      leftEdgeOccupied: false,
      leftOccupiedWidth: 700,
      geometryRecord: {{
        framed: true,
        barPosition: "top",
        barSize: 30,
        thickness: 16,
        contentRadius: 31,
        topEdgeOccupied: false,
        bottomEdgeOccupied: false,
        leftEdgeOccupied: true,
        rightEdgeOccupied: false,
        leftOccupiedWidth: 159,
        rightOccupiedWidth: 0,
        holeX: 159,
        holeY: 30,
        holeRight: 784,
        holeBottom: 584
      }}
    }})
    settle.start()
  }}

  Timer {{
    id: settle
    interval: 30
    onTriggered: {{
      var moldingWidthAt1x = border.moldingBorderWidth
      var renderableBeforeSuppression = border.isRenderable
      border.outputScale = 2
      border.suppressed = true
      console.log("BEHAVE " + JSON.stringify({{
        holeX: border.holeX,
        holeY: border.holeY,
        holeRight: border.holeRight,
        holeBottom: border.holeBottom,
        holeRadius: border.holeRadius,
        borderLeft: border.borderLeft,
        borderTop: border.borderTop,
        borderAlpha: border.borderColor.a,
        moldingWidthAt1x: moldingWidthAt1x,
        moldingWidthAt2x: border.moldingBorderWidth,
        leftGap: border.leftAttachmentGapVisible,
        renderableBeforeSuppression: renderableBeforeSuppression,
        renderableWhileSuppressed: border.isRenderable
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        result = parse_behave(output)[-1]

        self.assertEqual(result["holeX"], 159)
        self.assertEqual(result["holeY"], 30)
        self.assertEqual(result["holeRight"], 784)
        self.assertEqual(result["holeBottom"], 584)
        self.assertEqual(result["holeRadius"], 31)
        self.assertEqual(result["borderLeft"], 159.5)
        self.assertEqual(result["borderTop"], 30.5)
        self.assertEqual(result["borderAlpha"], 1)
        self.assertEqual(result["moldingWidthAt1x"], 1.5)
        self.assertEqual(result["moldingWidthAt2x"], 1)
        self.assertFalse(result["leftGap"])
        self.assertTrue(result["renderableBeforeSuppression"])
        self.assertFalse(result["renderableWhileSuppressed"])

    def test_zero_radius_geometry_stays_exactly_square_across_borders(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var frameBorder: null
  property var overlay: null
  property var overlayFallback: null
  property var panelBorder: null
  property var shapeSurface: null

  Component.onCompleted: {{
    frameBorder = Qt.createComponent("{qml_url('lacuna.bar/LacunaFrameBorderWindow.qml')}", Component.PreferSynchronous).createObject(root, {{
      width: 800,
      height: 600,
      active: true,
      geometryRecord: {{
        framed: true,
        holeX: 8,
        holeY: 30,
        holeRight: 792,
        holeBottom: 592,
        contentRadius: 0
      }}
    }})
    overlay = Qt.createComponent("{qml_url('lacuna.menu/menu/LacunaFrameOverlay.qml')}", Component.PreferSynchronous).createObject(root, {{
      width: 800,
      height: 600,
      mode: "off",
      borderOnly: true,
      borderEnabled: true,
      borderGeometryRecord: {{
        framed: true,
        holeX: 8,
        holeY: 30,
        holeRight: 792,
        holeBottom: 592,
        contentRadius: 0
      }}
    }})
    overlayFallback = Qt.createComponent("{qml_url('lacuna.menu/menu/LacunaFrameOverlay.qml')}", Component.PreferSynchronous).createObject(root, {{
      width: 800,
      height: 600,
      mode: "off",
      borderOnly: true,
      borderEnabled: true,
      frameRadius: 14,
      moldingPieces: false
    }})
    panelBorder = Qt.createComponent("{qml_url('lacuna.menu/menu/LacunaPanelBorder.qml')}", Component.PreferSynchronous).createObject(root, {{
      width: 800,
      height: 600,
      active: true,
      flyoutVisible: true,
      flyoutX: 100,
      flyoutY: 80,
      flyoutWidth: 320,
      flyoutHeight: 420,
      panelRadius: 0
    }})
    shapeSurface = Qt.createComponent("{qml_url('lacuna.menu/menu/LacunaShapeSurface.qml')}", Component.PreferSynchronous).createObject(root, {{
      width: 320,
      height: 420,
      panelRadius: 0
    }})
    settle.start()
  }}

  Timer {{
    id: settle
    interval: 30
    onTriggered: {{
      console.log("BEHAVE " + JSON.stringify({{
        frameHoleRadius: frameBorder.holeRadius,
        frameBorderRadius: frameBorder.borderRadius,
        overlayBorderRadius: overlay.borderRadius,
        fallbackOverlayBorderRadius: overlayFallback.borderRadius,
        panelStrokeRadius: panelBorder.strokeRadius,
        surfaceRadius: shapeSurface.effectiveRadius
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        self.assertEqual(
            {
                "frameHoleRadius": 0,
                "frameBorderRadius": 0,
                "overlayBorderRadius": 0,
                "fallbackOverlayBorderRadius": 0,
                "panelStrokeRadius": 0,
                "surfaceRadius": 0,
            },
            parse_behave(output)[-1],
        )

    def test_border_only_overlay_consumes_authoritative_host_geometry(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var overlay: null

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/menu/LacunaFrameOverlay.qml')}", Component.PreferSynchronous)
    overlay = component.createObject(root, {{
      width: 800,
      height: 600,
      mode: "off",
      borderOnly: true,
      borderEnabled: true,
      progress: 1,
      frameWidth: 800,
      frameThickness: 8,
      frameRadius: 14,
      borderGeometryRecord: {{
        framed: true,
        holeX: 123,
        holeY: 34,
        holeRight: 789,
        holeBottom: 588,
        contentRadius: 27,
        leftEdgeOccupied: true,
        rightEdgeOccupied: false
      }}
    }})
    settle.start()
  }}

  Timer {{
    id: settle
    interval: 30
    onTriggered: {{
      console.log("BEHAVE " + JSON.stringify({{
        visible: overlay.visible,
        frameEnabled: overlay.frameEnabled,
        borderFrameEnabled: overlay.borderFrameEnabled,
        borderLeft: overlay.borderLeft,
        borderTop: overlay.borderTop,
        borderRight: overlay.borderRight,
        borderBottom: overlay.borderBottom,
        borderRadius: overlay.borderRadius
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        result = parse_behave(output)[-1]

        self.assertTrue(result["visible"])
        self.assertFalse(result["frameEnabled"])
        self.assertTrue(result["borderFrameEnabled"])
        self.assertEqual(result["borderLeft"], 123)
        self.assertEqual(result["borderTop"], 34)
        self.assertEqual(result["borderRight"], 789)
        self.assertEqual(result["borderBottom"], 588)
        self.assertEqual(result["borderRadius"], 26.5)

    def test_overlay_frame_rail_stops_at_connector_molding_tangents(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var overlay: null

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/menu/LacunaFrameOverlay.qml')}", Component.PreferSynchronous)
    overlay = component.createObject(root, {{
      width: 800,
      height: 600,
      mode: "off",
      borderOnly: true,
      borderEnabled: true,
      borderGeometryRecord: {{
        holeX: 159,
        holeY: 30,
        holeRight: 784,
        holeBottom: 584,
        contentRadius: 31,
        leftEdgeOccupied: true,
        rightEdgeOccupied: false
      }},
      leftEdgeOccupied: true,
      flyoutVisible: true,
      flyoutY: 200,
      flyoutHeight: 200,
      connectorVisible: true,
      connectorY: 182,
      connectorWidth: 18,
      connectorHeight: 236
    }})
    settle.start()
  }}

  Timer {{
    id: settle
    interval: 30
    onTriggered: {{
      var connectorTop = overlay.attachmentGapTop
      var connectorBottom = overlay.attachmentGapBottom
      overlay.connectorVisible = false
      console.log("BEHAVE " + JSON.stringify({{
        connectorTop: connectorTop,
        connectorBottom: connectorBottom,
        bodyTop: overlay.attachmentGapTop,
        bodyBottom: overlay.attachmentGapBottom
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        result = parse_behave(output)[-1]

        self.assertEqual(result["connectorTop"], 182.5)
        self.assertEqual(result["connectorBottom"], 417.5)
        self.assertEqual(result["bodyTop"], 200.5)
        self.assertEqual(result["bodyBottom"], 399.5)

    def test_sidebar_keeps_standalone_outline_when_full_frame_is_off(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var surface: null

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/menu/MenuSurface.qml')}", Component.PreferSynchronous)
    surface = component.createObject(root, {{
      height: 600,
      open: true,
      progress: 1,
      panelWidth: 320,
      bodyRightInset: 18,
      frameMoldingPieces: true,
      fullFrame: false,
      frameBorder: true,
      attachedFlyoutVisible: true,
      attachedFlyoutY: 200,
      attachedFlyoutHeight: 236
    }})
    settle.start()
  }}

  Timer {{
    id: settle
    interval: 30
    onTriggered: {{
      var visibleWithoutFrame = surface.standaloneSidebarBorderVisible
      var gapTop = surface.standaloneAttachmentGapTop
      var gapBottom = surface.standaloneAttachmentGapBottom
      var gapRenderable = surface.standaloneAttachmentGapRenderable
      surface.fullFrame = true
      console.log("BEHAVE " + JSON.stringify({{
        visibleWithoutFrame: visibleWithoutFrame,
        hiddenWithFullFrame: !surface.standaloneSidebarBorderVisible,
        panelWidth: surface.panelWidth,
        moldingRadius: surface.bodyRightInset,
        joinTangentY: surface.joinTop + surface.bodyRightInset,
        gapTop: gapTop,
        gapBottom: gapBottom,
        gapRenderable: gapRenderable
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        result = parse_behave(output)[-1]

        self.assertTrue(result["visibleWithoutFrame"])
        self.assertTrue(result["hiddenWithFullFrame"])
        self.assertEqual(result["panelWidth"], 320)
        self.assertEqual(result["moldingRadius"], 18)
        self.assertEqual(result["gapTop"], 200.5)
        self.assertEqual(result["gapBottom"], 435.5)
        self.assertTrue(result["gapRenderable"])

    def test_sidebar_lower_molding_repaints_canonical_two_pass_frame_border(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            border_off = Path(temp_dir) / "border-off.png"
            border_on = Path(temp_dir) / "border-on.png"
            qml = f"""
import Quickshell
import QtQuick
import QtQuick.Window

ShellRoot {{
  Window {{
    id: window
    width: 96
    height: 96
    visible: true
    color: "#101315"

    Loader {{
      id: surfaceLoader
      anchors.fill: parent
      source: "{qml_url('lacuna.menu/menu/MenuSurface.qml')}"
      onLoaded: {{
        item.height = 96
        item.open = true
        item.progress = 1
        item.panelWidth = 48
        item.bodyRightInset = 32
        item.frameThickness = 16
        item.fullFrame = true
        item.frameMoldingPieces = true
        item.frameBorder = false
        item.frameBorderColor = "#ffff00ff"
        item.frameBorderWidth = 1
        item.panelColor = "#101315"
        item.backgroundVisible = true
        firstGrab.start()
      }}
    }}

    Timer {{
      id: firstGrab
      interval: 80
      onTriggered: surfaceLoader.item.grabToImage(function(result) {{
        result.saveToFile("{border_off}")
        surfaceLoader.item.frameBorder = true
        secondGrab.start()
      }})
    }}

    Timer {{
      id: secondGrab
      interval: 80
      onTriggered: surfaceLoader.item.grabToImage(function(result) {{
        result.saveToFile("{border_on}")
        surfaceLoader.item.barPosition = "bottom"
        console.log("BEHAVE " + JSON.stringify({{
          borderInset: surfaceLoader.item.frameBorderInset,
          borderRadius: surfaceLoader.item.frameBorderRadius,
          baseWidth: surfaceLoader.item.frameBorderWidth,
          moldingWidthAt1x: surfaceLoader.item.frameMoldingBorderWidth,
          joinTop: surfaceLoader.item.bottomJoinTop,
          hiddenForBottomBar: !surfaceLoader.item.bottomFrameJoinBorderVisible
        }}))
        Qt.quit()
      }})
    }}
  }}
}}
"""
            output = run_quickshell(qml, timeout=10)
            require_no_qml_errors(output)
            result = parse_behave(output)[-1]

            self.assertGreater(border_off.stat().st_size, 0)
            self.assertGreater(border_on.stat().st_size, 0)
            self.assertNotEqual(border_off.read_bytes(), border_on.read_bytes())
            self.assertEqual(result["borderInset"], 0.5)
            self.assertEqual(result["borderRadius"], 31.5)
            self.assertEqual(result["baseWidth"], 1)
            self.assertEqual(result["moldingWidthAt1x"], 1.5)
            self.assertGreater(result["joinTop"], 0)
            self.assertTrue(result["hiddenForBottomBar"])

    def test_panel_border_lower_molding_reaches_connector_outer_edge(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var border: null

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.menu/menu/LacunaPanelBorder.qml')}", Component.PreferSynchronous)
    border = component.createObject(root, {{
      width: 900,
      height: 700,
      active: true,
      connectorVisible: true,
      flyoutVisible: true,
      connectorX: 310,
      connectorY: 100,
      connectorWidth: 18,
      flyoutX: 328,
      flyoutY: 118,
      flyoutWidth: 420,
      flyoutHeight: 300,
      panelRadius: 14
    }})
    settle.start()
  }}

  Timer {{
    id: settle
    interval: 30
    onTriggered: {{
      console.log("BEHAVE " + JSON.stringify({{
        flyoutBottom: border.outlineBottom,
        connectorBottom: border.connectorOutlineBottom,
        connectorWidth: border.effectiveConnectorWidth,
        renderable: border.renderable
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        result = parse_behave(output)[-1]

        self.assertEqual(result["flyoutBottom"], 417.5)
        self.assertEqual(result["connectorBottom"], 435.5)
        self.assertEqual(result["connectorBottom"] - result["flyoutBottom"], result["connectorWidth"])
        self.assertTrue(result["renderable"])
