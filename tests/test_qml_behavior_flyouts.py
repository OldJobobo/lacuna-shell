import tempfile
import unittest
from pathlib import Path

from qml_harness import HAVE_SESSION, parse_behave, qml_url, require_no_qml_errors, run_quickshell


@unittest.skipUnless(HAVE_SESSION, "needs a quickshell binary and a Wayland session")
class RichFlyoutFourEdgeBehaviorTests(unittest.TestCase):
    def test_representative_surface_geometry_tracks_attachment_edge(self):
        cases = [
            ("simple", "lacuna.audio/BarFlyoutSurface.qml"),
            ("usage", "lacuna.claude-usage/BarFlyoutSurface.qml"),
            ("shadowed", "lacuna.theme/BarFlyoutSurface.qml"),
        ]
        for label, relative in cases:
            with self.subTest(label=label):
                qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var measuredRows: []
  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url(relative)}", Component.PreferSynchronous)
    if (component.status !== Component.Ready) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    var rows = []
    var edges = ["top", "bottom", "left", "right"]
    for (var i = 0; i < edges.length; i++) {{
      var surface = component.createObject(null, {{
        attachmentEdge: edges[i], panelWidth: 300, panelHeight: 400,
        joinRadius: 13, cornerRadius: 14
      }})
      rows.push({{
        edge: edges[i], width: surface.fullWidth, height: surface.fullHeight,
        left: surface.panelLeft, top: surface.panelTop,
        right: surface.panelRight, bottom: surface.panelBottom
      }})
      surface.destroy()
    }}
    root.measuredRows = rows
    finish.start()
  }}
  Timer {{
    id: finish
    interval: 20
    onTriggered: {{
      console.log("BEHAVE " + JSON.stringify({{ rows: root.measuredRows }}))
      Qt.quit()
    }}
  }}
}}
"""
                output = run_quickshell(qml)
                require_no_qml_errors(output)
                rows = parse_behave(output)[-1]["rows"]
                by_edge = {row["edge"]: row for row in rows}
                self.assertEqual(326, by_edge["top"]["width"])
                self.assertEqual(413, by_edge["top"]["height"])
                self.assertEqual(13, by_edge["top"]["top"])
                self.assertEqual(0, by_edge["bottom"]["top"])
                self.assertEqual(313, by_edge["left"]["width"])
                self.assertEqual(426, by_edge["left"]["height"])
                self.assertEqual(13, by_edge["left"]["left"])
                self.assertEqual(0, by_edge["right"]["left"])

    def test_square_and_custom_bar_flyout_geometry_share_universal_radius(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: root
  property var surface: null

  QtObject {{
    id: mockBar
    property bool frameBorderEnabled: true
    property bool fullFrameEnabled: false
    property color frameBorderColor: "#78824b"
  }}

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.clock/BarFlyoutSurface.qml')}", Component.PreferSynchronous)
    surface = component.createObject(root, {{
      bar: mockBar,
      attachmentEdge: "top",
      panelWidth: 300,
      panelHeight: 400,
      joinRadius: 0,
      cornerRadius: 0
    }})
    settle.start()
  }}

  Timer {{
    id: settle
    interval: 30
    onTriggered: {{
      var square = {{
        width: surface.fullWidth,
        height: surface.fullHeight,
        left: surface.panelLeft,
        top: surface.panelTop,
        strokeRadius: surface.strokeCornerRadius,
        overlap: surface.attachmentOverlap
      }}
      surface.joinRadius = 17
      surface.cornerRadius = 17
      var custom = {{ width: surface.fullWidth, height: surface.fullHeight, left: surface.panelLeft, top: surface.panelTop }}
      mockBar.fullFrameEnabled = true
      var fullFrameOverlap = surface.attachmentOverlap
      console.log("BEHAVE " + JSON.stringify({{ square: square, custom: custom, fullFrameOverlap: fullFrameOverlap }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml, timeout=8)
        require_no_qml_errors(output)
        result = parse_behave(output)[-1]
        self.assertEqual(
            {"width": 300, "height": 400, "left": 0, "top": 0, "strokeRadius": 0, "overlap": 1},
            result["square"],
        )
        self.assertEqual({"width": 334, "height": 417, "left": 17, "top": 17}, result["custom"])
        self.assertEqual(0, result["fullFrameOverlap"])

    def test_expanded_sidebar_displaces_horizontal_flyout_surface(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  QtObject {{
    id: mockBar
    property bool frameBorderEnabled: false
    property color frameBorderColor: "#78824b"
    property var popupAvoidanceInsets: ({{ left: 0, right: 0, top: 0, bottom: 0 }})
  }}

  Loader {{
    id: surfaceLoader
    source: "{qml_url('lacuna.clock/BarFlyoutSurface.qml')}"
    onLoaded: {{
      item.bar = mockBar
      item.attachmentEdge = "top"
      item.panelWidth = 300
      item.panelHeight = 400
      item.joinRadius = 13
      item.cornerRadius = 14
      measure.start()
    }}
  }}

  Timer {{
    id: measure
    interval: 20
    onTriggered: {{
      var surface = surfaceLoader.item
      var clear = surface.constrainedHorizontalPopupX(100, 1000, surface.fullWidth, 0, 8)
      mockBar.popupAvoidanceInsets = {{ left: 353, right: 0, top: 0, bottom: 0 }}
      var left = surface.constrainedHorizontalPopupX(100, 1000, surface.fullWidth, 0, 8)
      var leftShadow = surface.constrainedHorizontalPopupX(100, 1000, surface.fullWidth + 80, 40, 8)
      mockBar.popupAvoidanceInsets = {{ left: 0, right: 353, top: 0, bottom: 0 }}
      var right = surface.constrainedHorizontalPopupX(500, 1000, surface.fullWidth, 0, 8)
      var rightShadow = surface.constrainedHorizontalPopupX(500, 1000, surface.fullWidth + 80, 40, 8)
      mockBar.popupAvoidanceInsets = {{ left: 600, right: 600, top: 0, bottom: 0 }}
      var tooNarrow = surface.constrainedHorizontalPopupX(100, 1000, surface.fullWidth, 0, 8)
      console.log("BEHAVE " + JSON.stringify({{
        clear: clear, left: left, leftShadow: leftShadow,
        right: right, rightShadow: rightShadow, tooNarrow: tooNarrow,
        surfaceWidth: surface.fullWidth
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml)
        require_no_qml_errors(output)
        result = parse_behave(output)[-1]
        self.assertEqual(result["surfaceWidth"], 326)
        self.assertEqual(result["clear"], 100)
        self.assertEqual(result["left"], 353)
        self.assertEqual(result["leftShadow"], 313)
        self.assertEqual(result["right"], 321)
        self.assertEqual(result["rightShadow"], 281)
        self.assertEqual(result["tooNarrow"], 100)

    def test_bar_flyout_continues_enabled_frame_border(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            border_off = Path(temp_dir) / "bar-flyout-border-off.png"
            border_on = Path(temp_dir) / "bar-flyout-border-on.png"
            qml = f"""
import Quickshell
import QtQuick
import QtQuick.Window

ShellRoot {{
  QtObject {{
    id: mockBar
    property bool frameBorderEnabled: false
    property color frameBorderColor: "#78824b"
  }}

  Window {{
    width: 128
    height: 128
    visible: true
    color: "transparent"

    Loader {{
      id: surfaceLoader
      source: "{qml_url('lacuna.clock/BarFlyoutSurface.qml')}"
      onLoaded: {{
        item.bar = mockBar
        item.panelWidth = 96
        item.panelHeight = 96
        item.joinRadius = 13
        item.cornerRadius = 14
        item.panelColor = "#222222"
        item.attachmentEdge = "top"
        firstGrab.start()
      }}
    }}

    Timer {{
      id: firstGrab
      interval: 80
      onTriggered: surfaceLoader.item.grabToImage(function(result) {{
        result.saveToFile("{border_off}")
        mockBar.frameBorderEnabled = true
        secondGrab.start()
      }})
    }}

    Timer {{
      id: secondGrab
      interval: 80
      onTriggered: surfaceLoader.item.grabToImage(function(result) {{
        result.saveToFile("{border_on}")
        console.log("BEHAVE " + JSON.stringify({{
          enabled: surfaceLoader.item.borderEnabled,
          alpha: surfaceLoader.item.borderColor.a,
          inset: surfaceLoader.item.borderInset,
          color: surfaceLoader.item.borderColor.toString(),
          attachmentOverlap: surfaceLoader.item.attachmentOverlap,
          borderGapLength: surfaceLoader.item.borderGapLength
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
            self.assertTrue(result["enabled"])
            self.assertEqual(result["alpha"], 1)
            self.assertEqual(result["inset"], 0.5)
            self.assertEqual(result["color"], "#78824b")
            self.assertEqual(result["attachmentOverlap"], 1)
            self.assertEqual(result["borderGapLength"], 121)


if __name__ == "__main__":
    unittest.main()
