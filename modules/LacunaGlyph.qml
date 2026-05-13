import QtQuick

Text {
  property color glyphColor: "#d8dee9"
  property var tooltipHost: null

  text: ""
  color: glyphColor
  font.family: "BlexMono Nerd Font Propo"
  font.pixelSize: 15
  opacity: 0.55

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onEntered: if (tooltipHost) tooltipHost.clear()
  }
}
