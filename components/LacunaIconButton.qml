import QtQuick

LacunaRect {
  id: root

  signal triggered()
  signal secondaryTriggered()

  property alias icon: iconLabel.text
  property color foreground: "#d8dee9"
  property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.48)
  property color accent: "#88c0d0"
  property color hoverAccent: accent
  property bool disabled: false
  property int iconSize: 15
  property int buttonSize: tokens.controlSmall
  property string fontFamily: tokens.monoFont
  readonly property bool hovered: stateLayer.containsMouse

  implicitWidth: buttonSize
  implicitHeight: buttonSize
  width: implicitWidth
  height: implicitHeight
  clip: true

  LacunaText {
    id: iconLabel

    anchors.centerIn: parent
    color: stateLayer.containsMouse ? root.hoverAccent : root.muted
    fontFamily: root.fontFamily
    font.pixelSize: root.iconSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  LacunaStateLayer {
    id: stateLayer

    disabled: root.disabled
    stateColor: root.hoverAccent
    onTriggered: root.triggered()
    onSecondaryClicked: root.secondaryTriggered()
  }

  LacunaTokens {
    id: tokens
  }
}
