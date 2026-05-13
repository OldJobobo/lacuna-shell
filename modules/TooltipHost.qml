import Quickshell
import QtQuick
import QtQuick.Shapes

Item {
  id: root

  required property var panelWindow
  property var targetItem: null
  property string tooltipText: ""
  property color accent: "#88c0d0"
  property color foreground: "#d8dee9"
  property color panelColor: "#101315"
  property bool tooltipVisible: false
  property bool richTooltip: false
  property int popupX: 4
  property int popupY: 0
  property int bodyWidth: 180
  property int popupWidth: bodyWidth + joinRadius * 2
  property int popupHeight: 40
  property int attachX: popupWidth / 2
  property int hoverToken: 0
  readonly property int joinRadius: 8
  readonly property int connectorOverlap: 1
  readonly property int bodyTop: connectorOverlap
  readonly property int contentTop: bodyTop + joinRadius

  function clean(text) {
    return String(text || "")
      .replace(new RegExp("<br\\s*/?>", "gi"), "\n")
      .replace(new RegExp("<[^>]+>", "g"), "")
      .replace(new RegExp("&nbsp;", "g"), " ")
      .replace(new RegExp("&lt;", "g"), "<")
      .replace(new RegExp("&gt;", "g"), ">")
      .replace(new RegExp("&amp;", "g"), "&")
  }

  function hasMarkup(text) {
    return new RegExp("<[^>]+>").test(String(text || ""))
  }

  function normalizeRich(text) {
    return String(text || "")
      .replace(new RegExp("<span([^>]*)foreground=['\"]([^'\"]+)['\"]([^>]*)>", "gi"), "<font color=\"$2\">")
      .replace(new RegExp("</span>", "gi"), "</font>")
      .replace(new RegExp("\\n", "g"), "<br/>")
  }

  function measureWidth(text) {
    var lines = clean(text).split("\n")
    var longest = 0

    for (var i = 0; i < lines.length; i++) {
      longest = Math.max(longest, lines[i].length)
    }

    return Math.min(424, Math.max(160, longest * 7 + 32))
  }

  function measureBodyHeight(text, width) {
    var lines = clean(text).split("\n")
    var charsPerLine = Math.max(18, Math.floor((width - 32) / 7))
    var visualLines = 0

    for (var i = 0; i < lines.length; i++) {
      visualLines += Math.max(1, Math.ceil(lines[i].length / charsPerLine))
    }

    return Math.min(280, Math.max(40, visualLines * 14 + 24))
  }

  function showFor(item, text, nextAccent, nextForeground) {
    if (!item) return

    if (!text) {
      clear()
      return
    }

    hoverToken += 1
    showTimer.stop()
    hideTimer.stop()
    tooltipVisible = false

    targetItem = item
    richTooltip = hasMarkup(text)
    tooltipText = richTooltip ? normalizeRich(text) : clean(text)
    accent = nextAccent
    foreground = nextForeground
    bodyWidth = measureWidth(text)
    popupHeight = contentTop + measureBodyHeight(text, bodyWidth)
    position()

    showTimer.restart()
  }

  function hideFor(item) {
    if (item && targetItem !== item) return
    clear()
  }

  function clear() {
    hoverToken += 1
    showTimer.stop()
    hideTimer.stop()
    tooltipVisible = false
    richTooltip = false
    tooltipText = ""
    targetItem = null
  }

  function position() {
    if (!panelWindow || !targetItem) return

    var point = panelWindow.mapFromItem(targetItem, targetItem.width / 2, targetItem.height)
    var desiredX = point.x - bodyWidth / 2 - joinRadius
    var maxX = Math.max(8, panelWindow.width - popupWidth - 8)

    popupX = Math.round(Math.max(8, Math.min(desiredX, maxX)))
    popupY = Math.round(panelWindow.height - connectorOverlap)
    attachX = Math.round(point.x - popupX)
  }

  Timer {
    id: showTimer
    interval: 150
    repeat: false
    property int token: root.hoverToken
    onRunningChanged: if (running) token = root.hoverToken
    onTriggered: if (token === root.hoverToken && root.targetItem && root.tooltipText !== "") {
      root.tooltipVisible = true
    }
  }

  Timer {
    id: hideTimer
    interval: 90
    repeat: false
    onTriggered: root.clear()
  }

  PopupWindow {
    id: tooltipWindow

    anchor {
      window: root.panelWindow
      rect {
        x: root.popupX
        y: root.popupY
        width: root.popupWidth
        height: root.popupHeight
      }
    }
    visible: root.tooltipVisible && root.tooltipText !== ""
    color: "transparent"
    grabFocus: false
    implicitWidth: root.popupWidth
    implicitHeight: root.popupHeight

    Rectangle {
      id: tooltipBody

      implicitWidth: root.popupWidth
      implicitHeight: root.popupHeight
      color: "transparent"
      border.width: 0

      readonly property real cornerRadius: 8
      readonly property real joinRadius: root.joinRadius

      Shape {
        anchors.fill: parent
        asynchronous: true
        containsMode: Shape.FillContains

        ShapePath {
          fillColor: root.panelColor
          strokeWidth: 0
          startX: 0
          startY: root.bodyTop

          PathQuad {
            x: tooltipBody.joinRadius
            y: root.contentTop
            controlX: tooltipBody.joinRadius
            controlY: root.bodyTop
          }
          PathLine { x: tooltipBody.joinRadius; y: tooltipBody.height - tooltipBody.cornerRadius }
          PathQuad {
            x: tooltipBody.joinRadius + tooltipBody.cornerRadius
            y: tooltipBody.height
            controlX: tooltipBody.joinRadius
            controlY: tooltipBody.height
          }
          PathLine { x: tooltipBody.width - tooltipBody.joinRadius - tooltipBody.cornerRadius; y: tooltipBody.height }
          PathQuad {
            x: tooltipBody.width - tooltipBody.joinRadius
            y: tooltipBody.height - tooltipBody.cornerRadius
            controlX: tooltipBody.width - tooltipBody.joinRadius
            controlY: tooltipBody.height
          }
          PathLine { x: tooltipBody.width - tooltipBody.joinRadius; y: root.contentTop }
          PathQuad {
            x: tooltipBody.width
            y: root.bodyTop
            controlX: tooltipBody.width - tooltipBody.joinRadius
            controlY: root.bodyTop
          }
          PathLine { x: 0; y: root.bodyTop }
        }
      }

      Text {
        id: tooltipLabel

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.joinRadius + 16
        anchors.rightMargin: root.joinRadius + 16
        anchors.topMargin: root.contentTop + 12
        anchors.bottomMargin: 12
        width: root.bodyWidth - 32
        text: root.tooltipText
        textFormat: root.richTooltip ? Text.RichText : Text.PlainText
        wrapMode: Text.Wrap
        color: root.foreground
        linkColor: root.accent
        font.family: "BlexMono Nerd Font Propo"
        font.pixelSize: 11
        lineHeight: 1.12
      }
    }
  }
}
