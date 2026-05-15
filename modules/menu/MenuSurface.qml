import QtQuick
import QtQuick.Shapes
import "../../components"

Item {
  id: root

  default property alias content: contentHost.data
  readonly property alias surfaceX: surface.x

  property bool open: false
  property int panelWidth: 340
  property int barHeight: 32
  // Position of the bar's bottom edge inside this surface's coordinate space.
  // Defaults to barHeight (overlay mode, where the surface starts at the screen top
  // and the bar covers our top barHeight pixels). In exclusive mode the parent window
  // is already pushed below the bar, so the caller passes 0.
  property int barBottomY: barHeight
  property int joinRadius: 18
  property int connectorOverlap: 33
  property int bodyRightInset: joinRadius
  property bool cornerPieces: true
  property color panelColor: "#101315"
  property real openProgress: open ? 1 : 0

  readonly property int bodyTop: barBottomY
  readonly property real curveKappa: 0.5522847498

  width: panelWidth + bodyRightInset

  Behavior on openProgress {
    LacunaAnim {}
  }

  LacunaRect {
    id: surface

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: root.panelWidth + root.bodyRightInset
    x: -surface.width * (1 - root.openProgress)

    LacunaRect {
      x: 0
      y: 0
      width: root.panelWidth
      height: surface.height
      color: root.panelColor
    }

    Shape {
      id: cornerMold

      visible: root.cornerPieces && root.bodyRightInset > 0
      x: root.panelWidth
      y: root.bodyTop
      width: root.bodyRightInset
      height: root.bodyRightInset
      asynchronous: true

      ShapePath {
        fillColor: root.panelColor
        strokeWidth: 0
        startX: 0
        startY: 0

        PathLine { x: cornerMold.width; y: 0 }
        PathCubic {
          x: 0
          y: cornerMold.height
          control1X: cornerMold.width * (1 - root.curveKappa)
          control1Y: 0
          control2X: 0
          control2Y: cornerMold.height * (1 - root.curveKappa)
        }
        PathLine { x: 0; y: 0 }
      }
    }

    MouseArea {
      x: 0
      y: 0
      width: root.panelWidth
      height: surface.height
      onClicked: function(mouse) {
        mouse.accepted = true
      }
    }

    MouseArea {
      enabled: root.cornerPieces && root.bodyRightInset > 0
      x: root.panelWidth
      y: root.bodyTop
      width: root.bodyRightInset
      height: root.bodyRightInset
      onClicked: function(mouse) {
        mouse.accepted = true
      }
    }

    Item {
      id: contentHost

      x: 0
      y: 0
      width: root.panelWidth
      height: surface.height
    }

  }
}
