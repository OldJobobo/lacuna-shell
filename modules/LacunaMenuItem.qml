import QtQuick

Rectangle {
  id: root

  signal triggered()

  property string kind: "item"
  property string icon: ""
  property string label: ""
  property string hint: ""
  property bool hasChildren: false
  property color foreground: "#d8dee9"
  property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.48)
  property color accent: "#88c0d0"
  property color background: "#101315"
  property bool hovered: false
  readonly property bool header: kind === "header"

  width: parent ? parent.width : implicitWidth
  height: header ? 26 : 36
  color: header ? "transparent" : hovered ? Qt.rgba(accent.r, accent.g, accent.b, 0.10) : "transparent"
  border.width: 0
  clip: true

  Text {
    visible: root.header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: 4
    anchors.rightMargin: 4
    text: root.label
    color: root.muted
    font.family: "BlexMono Nerd Font Propo"
    font.pixelSize: 10
    font.weight: Font.DemiBold
    elide: Text.ElideRight
  }

  Row {
    visible: !root.header
    anchors.left: parent.left
    anchors.right: arrow.left
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: 6
    anchors.rightMargin: 8
    spacing: 10

    Text {
      width: 18
      anchors.verticalCenter: parent.verticalCenter
      text: root.icon
      color: root.accent
      font.family: "BlexMono Nerd Font Propo"
      font.pixelSize: 13
      horizontalAlignment: Text.AlignHCenter
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 28
      spacing: 1

      Text {
        width: parent.width
        text: root.label
        color: root.foreground
        font.family: "BlexMono Nerd Font Propo"
        font.pixelSize: 12
        font.weight: root.hovered ? Font.DemiBold : Font.Normal
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      Text {
        visible: root.hint !== ""
        width: parent.width
        text: root.hint
        color: root.muted
        font.family: "BlexMono Nerd Font Propo"
        font.pixelSize: 9
        elide: Text.ElideRight
        maximumLineCount: 1
      }
    }
  }

  Text {
    id: arrow
    visible: !root.header && root.hasChildren
    anchors.right: parent.right
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    text: "›"
    color: root.muted
    font.family: "BlexMono Nerd Font Propo"
    font.pixelSize: 16
  }

  MouseArea {
    anchors.fill: parent
    enabled: !root.header
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: root.triggered()
  }
}
