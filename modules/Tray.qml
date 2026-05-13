import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

Item {
  id: root

  property color foreground: "#d8dee9"
  property color background: "#101315"
  property color accent: "#88c0d0"
  property bool compact: false
  property var panelWindow: null
  property var tooltipHost: null
  property bool expanded: false

  implicitWidth: trayGroup.implicitWidth
  implicitHeight: compact ? 24 : 32
  visible: implicitWidth > 0

  function iconSource(iconName) {
    if (!iconName) return ""

    const pathMarker = "?path="
    const pathIndex = iconName.indexOf(pathMarker)
    if (pathIndex < 0) return iconName

    let name = iconName.substring(0, pathIndex)
    const path = iconName.substring(pathIndex + pathMarker.length)

    const iconPrefix = "image://icon/"
    if (name.indexOf(iconPrefix) === 0) name = name.substring(iconPrefix.length)

    return "file://" + path + "/hicolor/16x16/status/" + name + ".png"
  }

  Row {
    id: trayGroup
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.compact ? 4 : 8

    LacunaButton {
      text: root.expanded ? "" : ""
      minButtonWidth: 24
      compact: root.compact
      contentVerticalOffset: 1
      accent: root.accent
      foreground: root.foreground
      background: root.background
      tooltip: root.expanded ? "Hide tray" : "Show tray"
      tooltipHost: root.tooltipHost
      active: root.expanded
      onTriggered: root.expanded = !root.expanded
    }

    Item {
      id: drawer
      anchors.verticalCenter: parent.verticalCenter
      width: root.expanded ? trayRow.implicitWidth : 0
      height: root.compact ? 24 : 32
      clip: true

      Behavior on width {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }

      Row {
        id: trayRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.compact ? 4 : 8

        Repeater {
          model: SystemTray.items

          delegate: Item {
            id: trayItem

            width: root.compact ? 16 : 24
            height: root.compact ? 16 : 24

            property bool hovered: false
            property bool active: modelData.status === Status.NeedsAttention

            function displayMenu() {
              const position = trayItem.mapToItem(null, 0, trayItem.height)
              modelData.display(root.panelWindow, Math.round(position.x), Math.round(position.y))
            }

            Rectangle {
              anchors.fill: parent
              color: trayItem.active ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.10) : "transparent"
            }

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.leftMargin: 4
              anchors.rightMargin: 4
              height: 1
              color: root.accent
              opacity: trayItem.active || trayItem.hovered ? 0.75 : 0
            }

            Image {
              id: icon
              anchors.centerIn: parent
              width: root.compact ? 12 : 16
              height: width
              source: root.iconSource(modelData.icon)
              sourceSize.width: width
              sourceSize.height: height
              fillMode: Image.PreserveAspectFit
              mipmap: true
              smooth: true
              opacity: trayItem.hovered || trayItem.active ? 1 : 0.76
            }

            Text {
              anchors.centerIn: parent
              visible: icon.status === Image.Error || icon.source === ""
              text: "•"
              color: root.accent
              font.family: "BlexMono Nerd Font Propo"
              font.pixelSize: root.compact ? 10 : 11
            }

            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor

              onEntered: {
                trayItem.hovered = true
                if (root.tooltipHost) root.tooltipHost.clear()
              }
              onExited: trayItem.hovered = false
              onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                  trayItem.displayMenu()
                } else if (mouse.button === Qt.MiddleButton) {
                  modelData.secondaryActivate()
                } else if (modelData.onlyMenu && modelData.hasMenu) {
                  trayItem.displayMenu()
                } else {
                  modelData.activate()
                }
              }
              onWheel: function(wheel) {
                modelData.scroll(wheel.angleDelta.y, false)
              }
            }
          }
        }
      }
    }
  }
}
