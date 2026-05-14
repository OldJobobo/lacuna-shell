import QtQuick

MouseArea {
  id: root

  signal triggered()
  signal secondaryClicked()
  signal scrolled(int delta)

  property bool disabled: false
  property color stateColor: "#88c0d0"
  property real hoverOpacity: 0.06
  property real pressOpacity: 0.11
  property bool showFill: true
  readonly property real reveal: pressed ? 1 : containsMouse ? 1 : 0

  anchors.fill: parent
  acceptedButtons: Qt.LeftButton | Qt.RightButton
  enabled: !disabled
  hoverEnabled: true
  cursorShape: disabled ? Qt.ArrowCursor : Qt.PointingHandCursor

  onClicked: function(mouse) {
    if (mouse.button === Qt.RightButton) {
      root.secondaryClicked()
    } else {
      root.triggered()
    }
  }

  onWheel: function(wheel) {
    root.scrolled(wheel.angleDelta.y)
  }

  Rectangle {
    anchors.fill: parent
    color: root.stateColor
    opacity: root.showFill ? (root.pressed ? root.pressOpacity : root.containsMouse ? root.hoverOpacity : 0) : 0

    Behavior on opacity {
      LacunaAnim { motion: "fast" }
    }
  }
}
