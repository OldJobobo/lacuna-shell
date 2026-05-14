import Quickshell
import QtQuick
import QtQuick.Shapes
import "../components"

Item {
  id: root

  // Inputs from the bar
  required property var panelWindow
  property int panelSurfaceY: 0
  property int panelSurfaceHeight: panelWindow ? panelWindow.height : 0
  property color accent: "#88c0d0"
  property color foreground: "#d8dee9"
  property color panelColor: "#101315"

  // Layout — single source of truth, derived from design tokens
  readonly property int maxBodyWidth: 360
  readonly property int minBodyWidth: 96
  readonly property int paddingX: tokens.spaceXLarge
  readonly property int paddingY: tokens.spaceLarge
  readonly property int scoopRadius: tokens.spaceXLarge
  readonly property int bodyRadius: tokens.spaceNormal
  readonly property int barOverlap: 1
  readonly property int screenMargin: tokens.spaceNormal
  readonly property int textPixelSize: tokens.textSmall
  readonly property real textLineHeight: 1.22
  readonly property int showDelayMs: 150

  readonly property color opaquePanelColor: Qt.rgba(panelColor.r, panelColor.g, panelColor.b, 1)

  // Hover state
  property var targetItem: null
  property string tooltipText: ""
  property bool richTooltip: false
  property bool tooltipVisible: false
  property int hoverToken: 0

  // Derived geometry — body sized from real text metrics, not char-count guesses
  readonly property int measuredContentWidth: Math.ceil(measurer.contentWidth)
  readonly property int measuredContentHeight: Math.ceil(measurer.contentHeight)
  readonly property int bodyContentWidth: Math.max(
    minBodyWidth - 2 * paddingX,
    Math.min(maxBodyWidth - 2 * paddingX, measuredContentWidth)
  )
  readonly property int bodyContentHeight: Math.max(textPixelSize, measuredContentHeight)
  readonly property int bodyWidth: bodyContentWidth + 2 * paddingX
  readonly property int bodyHeight: bodyContentHeight + 2 * paddingY
  readonly property int popupWidth: bodyWidth + 2 * scoopRadius
  readonly property int popupHeight: barOverlap + scoopRadius + bodyHeight

  // Anchor position
  property int popupX: 0
  property int popupY: 0

  LacunaTokens {
    id: tokens
  }

  function clean(text) {
    return String(text || "")
      .replace(/<br\s*\/?>/gi, "\n")
      .replace(/<[^>]+>/g, "")
      .replace(/&nbsp;/g, " ")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&amp;/g, "&")
  }

  function hasMarkup(text) {
    return /<[^>]+>/.test(String(text || ""))
  }

  function normalizeRich(text) {
    return String(text || "")
      .replace(/<span([^>]*)foreground=['"]([^'"]+)['"]([^>]*)>/gi, "<font color=\"$2\">")
      .replace(/<\/span>/gi, "</font>")
      .replace(/\n/g, "<br/>")
  }

  function showFor(item, text, nextAccent, nextForeground) {
    if (!item) return

    if (!text) {
      clear()
      return
    }

    hoverToken += 1
    showTimer.stop()
    tooltipVisible = false

    targetItem = item
    richTooltip = hasMarkup(text)
    tooltipText = richTooltip ? normalizeRich(text) : clean(text)
    accent = nextAccent
    foreground = nextForeground
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
    tooltipVisible = false
    richTooltip = false
    tooltipText = ""
    targetItem = null
  }

  function position() {
    if (!panelWindow || !targetItem) return

    var center = panelWindow.mapFromItem(targetItem, targetItem.width / 2, targetItem.height)
    var desiredX = center.x - popupWidth / 2
    var maxX = Math.max(screenMargin, panelWindow.width - popupWidth - screenMargin)

    popupX = Math.round(Math.max(screenMargin, Math.min(desiredX, maxX)))
    popupY = Math.round(panelSurfaceY + panelSurfaceHeight - barOverlap)
  }

  // Re-anchor if the body resizes after the user hovers a new item
  onPopupWidthChanged: if (tooltipVisible) position()
  onPopupHeightChanged: if (tooltipVisible) position()

  // Off-screen measurer — gives us the real rendered text size
  Text {
    id: measurer
    visible: false
    text: root.tooltipText
    textFormat: root.richTooltip ? Text.RichText : Text.PlainText
    wrapMode: Text.Wrap
    width: root.maxBodyWidth - 2 * root.paddingX
    font.family: tokens.monoFont
    font.pixelSize: root.textPixelSize
    lineHeight: root.textLineHeight
    renderType: Text.NativeRendering
  }

  Timer {
    id: showTimer
    interval: root.showDelayMs
    repeat: false
    property int token: root.hoverToken
    onRunningChanged: if (running) token = root.hoverToken
    onTriggered: if (token === root.hoverToken && root.targetItem && root.tooltipText !== "") {
      root.tooltipVisible = true
    }
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

    // Tooltip silhouette: a rounded body suspended below the bar, joined on each
    // side by a concave fillet that makes the bar appear to flow into the body.
    Shape {
      anchors.fill: parent
      asynchronous: true
      containsMode: Shape.FillContains

      ShapePath {
        fillColor: root.opaquePanelColor
        strokeWidth: 0

        startX: 0
        startY: root.barOverlap

        // Top edge — flush with the bar bottom
        PathLine { x: root.popupWidth; y: root.barOverlap }

        // Top-right: concave scoop into the body.
        PathQuad {
          x: root.popupWidth - root.scoopRadius
          y: root.barOverlap + root.scoopRadius
          controlX: root.popupWidth - root.scoopRadius
          controlY: root.barOverlap
        }

        // Right side of body
        PathLine {
          x: root.popupWidth - root.scoopRadius
          y: root.popupHeight - root.bodyRadius
        }

        // Bottom-right corner
        PathQuad {
          x: root.popupWidth - root.scoopRadius - root.bodyRadius
          y: root.popupHeight
          controlX: root.popupWidth - root.scoopRadius
          controlY: root.popupHeight
        }

        // Bottom edge
        PathLine {
          x: root.scoopRadius + root.bodyRadius
          y: root.popupHeight
        }

        // Bottom-left corner
        PathQuad {
          x: root.scoopRadius
          y: root.popupHeight - root.bodyRadius
          controlX: root.scoopRadius
          controlY: root.popupHeight
        }

        // Left side of body
        PathLine {
          x: root.scoopRadius
          y: root.barOverlap + root.scoopRadius
        }

        // Top-left: concave scoop back up to the bar.
        PathQuad {
          x: 0
          y: root.barOverlap
          controlX: root.scoopRadius
          controlY: root.barOverlap
        }
      }
    }

    Text {
      id: tooltipLabel
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.leftMargin: root.scoopRadius + root.paddingX
      anchors.topMargin: root.barOverlap + root.scoopRadius + root.paddingY
      width: root.bodyContentWidth
      text: root.tooltipText
      textFormat: root.richTooltip ? Text.RichText : Text.PlainText
      wrapMode: Text.Wrap
      color: root.foreground
      linkColor: root.accent
      font.family: tokens.monoFont
      font.pixelSize: root.textPixelSize
      lineHeight: root.textLineHeight
      renderType: Text.NativeRendering
    }
  }
}
