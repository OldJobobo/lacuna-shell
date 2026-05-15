import QtQuick
import "../../components"

Item {
  id: root

  property string title: ""
  property color foreground: "#d8dee9"
  property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.48)
  property color accent: "#88c0d0"
  property bool band: false
  property string fontFamily: "GeistMono Nerd Font"
  property bool compact: false

  width: parent ? parent.width : implicitWidth
  height: compact ? (band ? 28 : 24) : (band ? 34 : 30)

  LacunaRect {
    visible: root.band
    anchors.fill: parent
    color: root.accent
    opacity: 0.035
  }

  LacunaRect {
    anchors.left: parent.left
    anchors.leftMargin: 2
    anchors.verticalCenter: label.verticalCenter
    width: root.compact ? (root.band ? 20 : 12) : (root.band ? 24 : 16)
    height: 1
    color: root.accent
    opacity: root.band ? 0.78 : 0.6
  }

  LacunaText {
    id: label

    anchors.left: parent.left
    anchors.leftMargin: root.compact ? (root.band ? 28 : 20) : (root.band ? 34 : 26)
    anchors.right: parent.right
    anchors.rightMargin: 4
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.compact ? (root.band ? 7 : 4) : (root.band ? 9 : 5)
    text: root.title.toUpperCase()
    color: root.band ? root.foreground : root.muted
    fontFamily: root.fontFamily
    font.pixelSize: root.compact ? 8 : 9
    font.weight: Font.DemiBold
    font.letterSpacing: root.compact ? 0.5 : 0.7
  }
}
