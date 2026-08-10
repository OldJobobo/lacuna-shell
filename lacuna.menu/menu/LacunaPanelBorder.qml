import QtQuick
import QtQuick.Shapes
import "../components"

Item {
  id: root

  property bool active: false
  property bool connectorVisible: false
  property bool flyoutVisible: false
  property bool openToLeft: false
  property real connectorX: 0
  property real connectorY: 0
  property real connectorWidth: 0
  property real flyoutX: 0
  property real flyoutY: 0
  property real flyoutWidth: 0
  property real flyoutHeight: 0
  property real panelRadius: 14
  property color borderColor: Qt.rgba(1, 1, 1, 1)
  property real borderWidth: 1

  readonly property real curveKappa: lacunaGeometry.curveKappa
  readonly property real borderInset: Math.max(0, borderWidth / 2)
  readonly property real visibleFlyoutWidth: Math.max(0, flyoutWidth)
  readonly property real visibleFlyoutHeight: Math.max(0, flyoutHeight)
  readonly property real strokeLeft: flyoutX + borderInset
  readonly property real strokeTop: flyoutY + borderInset
  readonly property real strokeRight: flyoutX + visibleFlyoutWidth - borderInset
  readonly property real strokeBottom: flyoutY + visibleFlyoutHeight - borderInset
  readonly property real strokeRadius: Math.max(0, Math.min(panelRadius, visibleFlyoutWidth / 2, visibleFlyoutHeight / 2) - borderInset)
  readonly property real effectiveConnectorWidth: connectorVisible ? Math.max(0, connectorWidth) : 0
  // Keep every exposed segment on the same half-pixel inset as the frame
  // border. Mixing integer connector/flyout coordinates with half-pixel frame
  // coordinates made horizontal edges look thicker and reduced their apparent
  // opacity through antialiasing.
  readonly property real outlineLeft: strokeLeft
  readonly property real outlineTop: strokeTop
  readonly property real outlineRight: strokeRight
  readonly property real outlineBottom: strokeBottom
  readonly property real outlineRadius: strokeRadius
  readonly property real connectorOutlineX: openToLeft
    ? connectorX + effectiveConnectorWidth - borderInset
    : connectorX + borderInset
  readonly property real connectorOutlineTop: connectorY + borderInset
  readonly property real connectorOutlineBottom: connectorY + effectiveConnectorWidth * 2 + visibleFlyoutHeight - borderInset
  readonly property bool renderable: active && flyoutVisible && visibleFlyoutWidth > 0 && visibleFlyoutHeight > 0

  LacunaGeometry { id: lacunaGeometry }

  visible: renderable
  enabled: false

  // Right-opening flyout: square attachment edge on the left, exposed
  // rounded corners on the right, and optional molding curves to the sidebar.
  Shape {
    anchors.fill: parent
    visible: root.renderable && !root.openToLeft
    asynchronous: false
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.borderColor
      strokeWidth: root.borderWidth
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.MiterJoin
      startX: root.connectorVisible
        ? root.connectorOutlineX
        : root.strokeLeft
      startY: root.connectorVisible
        ? root.connectorOutlineTop
        : root.strokeTop

      PathCubic {
        x: root.outlineLeft
        y: root.outlineTop
        control1X: root.connectorVisible ? root.connectorOutlineX : root.outlineLeft
        control1Y: root.connectorVisible ? root.connectorOutlineTop + root.effectiveConnectorWidth * root.curveKappa : root.outlineTop
        control2X: root.connectorVisible ? root.connectorOutlineX + root.effectiveConnectorWidth * (1 - root.curveKappa) : root.outlineLeft
        control2Y: root.outlineTop
      }
      PathLine {
        x: root.outlineRight - root.outlineRadius
        y: root.outlineTop
      }
      PathCubic {
        x: root.outlineRight
        y: root.outlineTop + root.outlineRadius
        control1X: root.outlineRight - root.outlineRadius * (1 - root.curveKappa)
        control1Y: root.outlineTop
        control2X: root.outlineRight
        control2Y: root.outlineTop + root.outlineRadius * (1 - root.curveKappa)
      }
      PathLine {
        x: root.outlineRight
        y: root.outlineBottom - root.outlineRadius
      }
      PathCubic {
        x: root.outlineRight - root.outlineRadius
        y: root.outlineBottom
        control1X: root.outlineRight
        control1Y: root.outlineBottom - root.outlineRadius * (1 - root.curveKappa)
        control2X: root.outlineRight - root.outlineRadius * (1 - root.curveKappa)
        control2Y: root.outlineBottom
      }
      PathLine {
        x: root.outlineLeft
        y: root.outlineBottom
      }
      PathCubic {
        x: root.connectorVisible
          ? root.connectorOutlineX
          : root.outlineLeft
        y: root.connectorVisible
          ? root.connectorOutlineBottom
          : root.outlineBottom
        control1X: root.connectorVisible ? root.connectorOutlineX + root.effectiveConnectorWidth * (1 - root.curveKappa) : root.outlineLeft
        control1Y: root.outlineBottom
        control2X: root.connectorVisible ? root.connectorOutlineX : root.outlineLeft
        control2Y: root.connectorVisible ? root.outlineBottom + root.effectiveConnectorWidth * (1 - root.curveKappa) : root.outlineBottom
      }
    }
  }

  // Left-opening flyout: exact horizontal mirror of the path above. The old
  // implementation had no path at all for this orientation, so enabling the
  // frame border silently dropped the attached-panel outline on right-side
  // sidebars.
  Shape {
    anchors.fill: parent
    visible: root.renderable && root.openToLeft
    asynchronous: false
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.borderColor
      strokeWidth: root.borderWidth
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.MiterJoin
      startX: root.connectorVisible
        ? root.connectorOutlineX
        : root.strokeRight
      startY: root.connectorVisible
        ? root.connectorOutlineTop
        : root.strokeTop

      PathCubic {
        x: root.outlineRight
        y: root.outlineTop
        control1X: root.connectorVisible ? root.connectorOutlineX : root.outlineRight
        control1Y: root.connectorVisible ? root.connectorOutlineTop + root.effectiveConnectorWidth * root.curveKappa : root.outlineTop
        control2X: root.connectorVisible ? root.connectorOutlineX - root.effectiveConnectorWidth * (1 - root.curveKappa) : root.outlineRight
        control2Y: root.outlineTop
      }
      PathLine {
        x: root.outlineLeft + root.outlineRadius
        y: root.outlineTop
      }
      PathCubic {
        x: root.outlineLeft
        y: root.outlineTop + root.outlineRadius
        control1X: root.outlineLeft + root.outlineRadius * (1 - root.curveKappa)
        control1Y: root.outlineTop
        control2X: root.outlineLeft
        control2Y: root.outlineTop + root.outlineRadius * (1 - root.curveKappa)
      }
      PathLine {
        x: root.outlineLeft
        y: root.outlineBottom - root.outlineRadius
      }
      PathCubic {
        x: root.outlineLeft + root.outlineRadius
        y: root.outlineBottom
        control1X: root.outlineLeft
        control1Y: root.outlineBottom - root.outlineRadius * (1 - root.curveKappa)
        control2X: root.outlineLeft + root.outlineRadius * (1 - root.curveKappa)
        control2Y: root.outlineBottom
      }
      PathLine {
        x: root.outlineRight
        y: root.outlineBottom
      }
      PathCubic {
        x: root.connectorVisible
          ? root.connectorOutlineX
          : root.outlineRight
        y: root.connectorVisible
          ? root.connectorOutlineBottom
          : root.outlineBottom
        control1X: root.connectorVisible ? root.connectorOutlineX - root.effectiveConnectorWidth * (1 - root.curveKappa) : root.outlineRight
        control1Y: root.outlineBottom
        control2X: root.connectorVisible ? root.connectorOutlineX : root.outlineRight
        control2Y: root.connectorVisible ? root.outlineBottom + root.effectiveConnectorWidth * (1 - root.curveKappa) : root.outlineBottom
      }
    }
  }
}
