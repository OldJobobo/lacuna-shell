import QtQuick
import Quickshell
import "../../components"

Column {
  id: root

  signal activated(var entry)

  required property var menuState
  required property var registry
  property bool open: true
  property color foreground: "#d8dee9"
  property color accent: "#88c0d0"
  property color shellAccent: "#88c0d0"
  property color sessionAccent: "#ebcb8b"
  property color dangerAccent: "#bf616a"
  property color navAccent: "#d8dee9"
  property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.48)
  property color panelColor: "#101315"
  property string bodyFontFamily: "GeistMono Nerd Font"
  property int railWidth: 32
  property var panelWindow: null
  property var tooltipTarget: null
  property string tooltipText: ""
  property color tooltipAccent: accent
  property int tooltipX: 0
  property int tooltipY: 0
  property int tooltipWidth: 118
  property int tooltipHeight: 30
  property bool tooltipVisible: false

  function toneAccent(tone) {
    if (tone === "lacuna") return root.accent
    if (tone === "shell") return root.shellAccent
    if (tone === "session") return root.sessionAccent
    if (tone === "danger") return root.dangerAccent
    return root.navAccent
  }

  function railItems() {
    var source = root.registry.itemsFor(root.menuState.currentView)
    var items = []
    for (var i = 0; i < source.length; i++) {
      if (source[i].kind === "item") items.push(source[i])
    }
    return items
  }

  function showTooltip(item, entry) {
    if (!item || !entry || !entry.label) return

    tooltipTarget = item
    tooltipText = entry.label
    tooltipAccent = toneAccent(entry.tone)
    tooltipWidth = Math.max(82, Math.min(154, entry.label.length * 9 + 30))
    positionTooltip()
    tooltipVisible = true
  }

  function hideTooltip(item) {
    if (item && tooltipTarget !== item) return
    tooltipVisible = false
    tooltipTarget = null
    tooltipText = ""
  }

  function positionTooltip() {
    if (!panelWindow || !tooltipTarget) return

    var point = panelWindow.mapFromItem(tooltipTarget, tooltipTarget.width, tooltipTarget.height / 2)
    tooltipX = Math.round(point.x + 8)
    tooltipY = Math.round(Math.max(8, Math.min(point.y - tooltipHeight / 2, panelWindow.height - tooltipHeight - 8)))
  }

  spacing: 7
  opacity: open ? 1 : 0

  Behavior on opacity {
    LacunaAnim { motion: "normal" }
  }

  Repeater {
    model: root.railItems()

    LacunaIconButton {
      icon: modelData.icon
      foreground: root.foreground
      muted: root.muted
      accent: root.toneAccent(modelData.tone)
      hoverAccent: root.toneAccent(modelData.tone)
      buttonSize: root.railWidth
      iconSize: modelData.priority === "primary" ? 17 : 15
      fontFamily: root.bodyFontFamily
      onHoveredChanged: if (hovered) root.showTooltip(this, modelData)
                      else root.hideTooltip(this)
      onTriggered: root.activated(modelData)
    }
  }

  PopupWindow {
    anchor {
      window: root.panelWindow
      rect {
        x: root.tooltipX
        y: root.tooltipY
        width: root.tooltipWidth
        height: root.tooltipHeight
      }
    }

    visible: root.tooltipVisible && root.tooltipText !== ""
    color: "transparent"
    grabFocus: false
    implicitWidth: root.tooltipWidth
    implicitHeight: root.tooltipHeight

    LacunaRect {
      anchors.fill: parent
      color: root.panelColor
      opacity: 1
      border.width: 1
      border.color: Qt.rgba(root.tooltipAccent.r, root.tooltipAccent.g, root.tooltipAccent.b, 0.24)

      LacunaRect {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: root.tooltipAccent
        opacity: 0.82
      }

      LacunaText {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.tooltipText
        color: root.foreground
        fontFamily: root.bodyFontFamily
        font.pixelSize: 11
        font.weight: Font.DemiBold
      }
    }
  }
}
