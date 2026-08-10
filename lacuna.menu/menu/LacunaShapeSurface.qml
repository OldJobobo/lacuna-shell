import QtQuick
import QtQuick.Shapes

Item {
  id: root

  property color panelColor: "#101315"
  property int panelRadius: 14
  property int topLeftCornerState: -1
  property int topRightCornerState: 0
  property int bottomRightCornerState: 0
  property int bottomLeftCornerState: -1

  readonly property real minimumRadius: 0
  readonly property color solidPanelColor: Qt.rgba(panelColor.r, panelColor.g, panelColor.b, 1)
  readonly property real effectiveRadius: Math.max(0, cornerHelper.flattenedRadius(Math.min(width, height), panelRadius))

  readonly property real tlMultX: cornerHelper.multX(topLeftCornerState)
  readonly property real tlMultY: cornerHelper.multY(topLeftCornerState)
  readonly property real tlRadius: cornerRadius(topLeftCornerState)
  readonly property real trMultX: cornerHelper.multX(topRightCornerState)
  readonly property real trMultY: cornerHelper.multY(topRightCornerState)
  readonly property real trRadius: cornerRadius(topRightCornerState)
  readonly property real brMultX: cornerHelper.multX(bottomRightCornerState)
  readonly property real brMultY: cornerHelper.multY(bottomRightCornerState)
  readonly property real brRadius: cornerRadius(bottomRightCornerState)
  readonly property real blMultX: cornerHelper.multX(bottomLeftCornerState)
  readonly property real blMultY: cornerHelper.multY(bottomLeftCornerState)
  readonly property real blRadius: cornerRadius(bottomLeftCornerState)

  function cornerRadius(cornerState) {
    return cornerState === -1 ? minimumRadius : effectiveRadius
  }

  LacunaCornerHelper {
    id: cornerHelper
  }

  Shape {
    anchors.fill: parent
    asynchronous: false
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: root.solidPanelColor
      strokeWidth: 0
      startX: root.tlRadius * root.tlMultX
      startY: 0

      PathLine {
        relativeX: root.width - root.tlRadius * root.tlMultX - root.trRadius * root.trMultX
        relativeY: 0
      }

      PathArc {
        relativeX: root.trRadius * root.trMultX
        relativeY: root.trRadius * root.trMultY
        radiusX: root.trRadius
        radiusY: root.trRadius
        direction: cornerHelper.arcDirection(root.trMultX, root.trMultY)
      }

      PathLine {
        relativeX: 0
        relativeY: root.height - root.trRadius * root.trMultY - root.brRadius * root.brMultY
      }

      PathArc {
        relativeX: -root.brRadius * root.brMultX
        relativeY: root.brRadius * root.brMultY
        radiusX: root.brRadius
        radiusY: root.brRadius
        direction: cornerHelper.arcDirection(root.brMultX, root.brMultY)
      }

      PathLine {
        relativeX: -(root.width - root.brRadius * root.brMultX - root.blRadius * root.blMultX)
        relativeY: 0
      }

      PathArc {
        relativeX: -root.blRadius * root.blMultX
        relativeY: -root.blRadius * root.blMultY
        radiusX: root.blRadius
        radiusY: root.blRadius
        direction: cornerHelper.arcDirection(root.blMultX, root.blMultY)
      }

      PathLine {
        relativeX: 0
        relativeY: -(root.height - root.blRadius * root.blMultY - root.tlRadius * root.tlMultY)
      }

      PathArc {
        relativeX: root.tlRadius * root.tlMultX
        relativeY: -root.tlRadius * root.tlMultY
        radiusX: root.tlRadius
        radiusY: root.tlRadius
        direction: cornerHelper.arcDirection(root.tlMultX, root.tlMultY)
      }
    }
  }
}
