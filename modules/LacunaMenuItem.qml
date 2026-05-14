import QtQuick
import "../components"

LacunaRect {
  id: root

  signal triggered()

  property string kind: "item"
  property string icon: ""
  property string iconSource: ""
  property string label: ""
  property string hint: ""
  property string tone: "nav"
  property string priority: "normal"
  property string layout: "row"
  property bool danger: false
  property bool hasChildren: false
  property color foreground: "#d8dee9"
  property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.48)
  property color accent: "#88c0d0"
  property color toneAccent: accent
  property color background: "#101315"
  property string fontFamily: "GeistMono Nerd Font"
  property string labelFontFamily: fontFamily
  property int iconRailWidth: 32
  property bool compact: false
  readonly property bool hovered: stateLayer.containsMouse
  readonly property bool pressed: stateLayer.pressed
  readonly property real reveal: stateLayer.reveal
  readonly property bool header: kind === "header"
  readonly property bool featured: layout === "featured"
  readonly property bool compactRow: layout === "compact"
  readonly property bool primary: priority === "primary"
  readonly property int rowHeight: compact ? (featured ? 42 : primary ? 34 : compactRow ? 28 : 32) : (featured ? 48 : primary ? 40 : compactRow ? 32 : 38)
  property int contentLeftMargin: Math.round(reveal * (featured ? 3 : 2))

  width: parent ? parent.width : implicitWidth
  height: header ? (compact ? 24 : 30) : rowHeight
  clip: true

  Behavior on contentLeftMargin {
    LacunaAnim { motion: "fast" }
  }

  LacunaRect {
    visible: !root.header
    anchors.fill: parent
    color: root.toneAccent
    opacity: root.featured ? 0.045 + root.reveal * 0.065 : root.primary ? 0.025 + root.reveal * 0.06 : root.reveal * 0.055
  }

  LacunaRect {
    visible: !root.header
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: root.featured ? 5 : root.primary ? 4 : 3
    color: root.toneAccent
    opacity: root.featured ? 0.7 + root.reveal * 0.3 : root.primary ? 0.42 + root.reveal * 0.42 : root.reveal * 0.95
  }

  LacunaRect {
    visible: !root.header && root.reveal > 0
    anchors.left: parent.left
    anchors.leftMargin: 9
    anchors.top: parent.top
    width: root.featured ? 46 : root.primary ? 34 : 22
    height: 1
    color: root.toneAccent
    opacity: root.reveal * 0.42
  }

  LacunaRect {
    visible: !root.header && root.reveal > 0
    anchors.right: parent.right
    anchors.rightMargin: 8
    anchors.bottom: parent.bottom
    width: root.featured ? 32 : root.primary ? 26 : 14
    height: 1
    color: root.toneAccent
    opacity: root.reveal * 0.32
  }

  Row {
    visible: root.header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: 2
    anchors.rightMargin: 4
    anchors.bottomMargin: 5
    spacing: 8

    LacunaRect {
      width: 16
      height: 1
      anchors.verticalCenter: parent.verticalCenter
      color: root.toneAccent
      opacity: 0.6
    }

    LacunaText {
      width: parent.width - 24
      text: root.label.toUpperCase()
      color: root.muted
      fontFamily: root.fontFamily
      font.pixelSize: 9
      font.weight: Font.DemiBold
    }
  }

  Row {
    id: content
    visible: !root.header
    anchors.left: parent.left
    anchors.right: arrow.left
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: root.contentLeftMargin
    anchors.rightMargin: 8
    spacing: root.compact ? (root.featured ? 6 : 5) : (root.featured ? 8 : root.primary ? 7 : 6)

    Item {
      width: root.iconRailWidth
      height: root.rowHeight
      anchors.verticalCenter: parent.verticalCenter

      Image {
        id: iconImage

        anchors.centerIn: parent
        width: root.compact ? (root.featured ? 19 : root.primary ? 16 : 14) : (root.featured ? 22 : root.primary ? 19 : 17)
        height: width
        source: root.iconSource
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        mipmap: true
        smooth: true
        visible: root.iconSource !== "" && status === Image.Ready
        opacity: root.hovered ? 1 : 0.88
      }

      LacunaText {
        anchors.centerIn: parent
        width: parent.width
        visible: root.iconSource === "" || iconImage.status !== Image.Ready
        text: root.icon
        color: root.tone === "nav" && !root.hovered ? root.muted : root.toneAccent
        fontFamily: root.fontFamily
        font.pixelSize: root.compact ? (root.featured ? 15 : root.primary ? 13 : 12) : (root.featured ? 17 : root.primary ? 15 : 13)
        horizontalAlignment: Text.AlignHCenter
      }
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(0, parent.width - root.iconRailWidth - content.spacing)
      spacing: 1

      LacunaText {
        width: parent.width
        text: root.label
        color: root.foreground
        fontFamily: root.labelFontFamily
        font.pixelSize: root.compact ? (root.featured ? 13 : root.primary ? 12 : 11) : (root.featured ? 15 : root.primary ? 14 : 13)
        font.weight: root.hovered || root.primary || root.featured ? Font.DemiBold : Font.Normal
      }
    }
  }

  LacunaText {
    id: arrow
    visible: !root.header && root.hasChildren
    anchors.right: parent.right
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    text: "›"
    color: root.hovered ? root.toneAccent : root.muted
    fontFamily: root.fontFamily
    font.pixelSize: root.compact ? 14 : 16
  }

  LacunaStateLayer {
    id: stateLayer

    disabled: root.header
    stateColor: root.toneAccent
    showFill: false
    onTriggered: root.triggered()
  }
}
