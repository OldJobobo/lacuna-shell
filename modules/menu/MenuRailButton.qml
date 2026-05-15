import QtQuick
import QtQuick.Shapes
import "../../components"

LacunaRect {
  id: root

  signal triggered()

  property string shape: "apps"
  property color muted: "#8b949e"
  property color hoverAccent: "#88c0d0"
  property int buttonSize: 32
  property int iconSize: 18
  readonly property bool hovered: stateLayer.containsMouse
  readonly property color iconColor: hovered ? hoverAccent : muted

  implicitWidth: buttonSize
  implicitHeight: buttonSize
  width: implicitWidth
  height: implicitHeight
  clip: true

  Shape {
    id: iconShape

    anchors.centerIn: parent
    width: 24
    height: 24
    scale: root.iconSize / 24
    transformOrigin: Item.Center
    asynchronous: true
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: root.shape === "lacuna" ? root.iconColor : "transparent"
      strokeWidth: 2
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: "M6 5h12l3 5l-8.5 9.5a.7 .7 0 0 1 -1 0l-8.5 -9.5l3 -5" }
      PathSvg { path: "M10 12l-2 -2.2l.6 -1" }
    }

    ShapePath {
      strokeColor: root.shape === "apps" ? root.iconColor : "transparent"
      strokeWidth: 2
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: "M4 5a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -4" }
      PathSvg { path: "M4 15a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -4" }
      PathSvg { path: "M14 15a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -4" }
      PathSvg { path: "M14 7l6 0" }
      PathSvg { path: "M17 4l0 6" }
    }

    ShapePath {
      strokeColor: root.shape === "customize" ? root.iconColor : "transparent"
      strokeWidth: 2
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: "M12 6a2 2 0 1 0 4 0a2 2 0 1 0 -4 0" }
      PathSvg { path: "M4 6l8 0" }
      PathSvg { path: "M16 6l4 0" }
      PathSvg { path: "M6 12a2 2 0 1 0 4 0a2 2 0 1 0 -4 0" }
      PathSvg { path: "M4 12l2 0" }
      PathSvg { path: "M10 12l10 0" }
      PathSvg { path: "M15 18a2 2 0 1 0 4 0a2 2 0 1 0 -4 0" }
      PathSvg { path: "M4 18l11 0" }
      PathSvg { path: "M19 18l1 0" }
    }

    ShapePath {
      strokeColor: root.shape === "system" ? root.iconColor : "transparent"
      strokeWidth: 2
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: "M7 6a7.75 7.75 0 1 0 10 0" }
      PathSvg { path: "M12 4l0 8" }
    }

    ShapePath {
      strokeColor: root.shape === "terminal" ? root.iconColor : "transparent"
      strokeWidth: 2
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: "M8 9l3 3l-3 3" }
      PathSvg { path: "M13 15l3 0" }
      PathSvg { path: "M3 6a2 2 0 0 1 2 -2h14a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2l0 -12" }
    }

    ShapePath {
      strokeColor: root.shape === "browser" ? root.iconColor : "transparent"
      strokeWidth: 2
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: "M3 12a9 9 0 1 0 18 0a9 9 0 0 0 -18 0" }
      PathSvg { path: "M3.6 9h16.8" }
      PathSvg { path: "M3.6 15h16.8" }
      PathSvg { path: "M11.5 3a17 17 0 0 0 0 18" }
      PathSvg { path: "M12.5 3a17 17 0 0 1 0 18" }
    }
  }

  LacunaStateLayer {
    id: stateLayer

    stateColor: root.hoverAccent
    onTriggered: root.triggered()
  }
}
