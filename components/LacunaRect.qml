import QtQuick

Rectangle {
  id: root

  color: "transparent"
  border.width: 0

  Behavior on color {
    LacunaColorAnim {}
  }

  Behavior on opacity {
    LacunaAnim { motion: "fast" }
  }
}
