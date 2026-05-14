import QtQuick
import "../components"

LacunaRect {
  id: root

  signal triggered()
  signal secondaryTriggered()
  signal scrolled(int delta)

  property alias text: label.text
  property string tooltip: ""
  property color accent: "#88c0d0"
  property color foreground: "#d8dee9"
  property color background: "#101315"
  property bool active: false
  property int minButtonWidth: 24
  property bool compact: false
  property bool accentText: true
  property string leadingImageSource: ""
  property int leadingImageRevision: 0
  readonly property string leadingImageDisplaySource: leadingImageSource === "" ? "" : leadingImageSource + "?revision=" + leadingImageRevision
  property int leadingImageSize: compact ? 12 : 16
  property int contentVerticalOffset: 0
  property int contentHorizontalPadding: compact ? 8 : 16
  property int labelPixelSize: compact ? 11 : 12
  property int labelFontWeight: active ? Font.DemiBold : Font.Normal
  property bool labelHoverPulse: false
  property real labelHoverScale: 1.08
  property real labelHoverPulseLift: 0.025
  property real labelAnimatedPixelSize: labelPixelSize
  property real hoverPulseAmount: 0
  property real hoverRevealAmount: 0
  readonly property real labelAnimatedScale: labelHoverPulse ? 1 + hoverRevealAmount * ((labelHoverScale - 1) + hoverPulseAmount * labelHoverPulseLift) : 1
  readonly property real hoverGlowOpacity: labelHoverPulse && !sweepActive ? hoverRevealAmount * (0.34 + hoverPulseAmount * 0.22) : 0
  readonly property real hoverHighlightOpacity: labelHoverPulse && !sweepActive ? hoverRevealAmount * 0.035 : 0
  readonly property bool hovered: clickArea.containsMouse
  property bool sweepActive: false
  property color sweepColor: accent
  property real sweepPosition: -0.35
  property var tooltipHost: null

  onLabelPixelSizeChanged: labelAnimatedPixelSize = labelPixelSize

  width: Math.max(minButtonWidth, content.implicitWidth + contentHorizontalPadding)
  height: compact ? 24 : 32
  radius: 0
  color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.08) : "transparent"
  border.color: "transparent"
  border.width: 0
  clip: true

  Behavior on hoverRevealAmount {
    NumberAnimation {
      duration: 180
      easing.type: Easing.OutCubic
    }
  }

  function showTooltip() {
    if (tooltipHost && tooltip !== "") {
      tooltipHost.showFor(root, tooltip, accent, foreground)
    }
  }

  function hideTooltip() {
    if (tooltipHost) {
      tooltipHost.hideFor(root)
    }
  }

  function baseTextColor() {
    return root.active || root.accentText ? root.accent : root.foreground
  }

  function textSweepColor(index, count) {
    var base = baseTextColor()
    var sweep = root.sweepColor
    var center = (index + 0.5) / Math.max(1, count)
    var distance = Math.abs(center - root.sweepPosition)
    var intensity = Math.max(0, 1 - distance / 0.16) * 0.62

    return Qt.rgba(
      base.r + (sweep.r - base.r) * intensity,
      base.g + (sweep.g - base.g) * intensity,
      base.b + (sweep.b - base.b) * intensity,
      1
    )
  }

  NumberAnimation on sweepPosition {
    from: -0.35
    to: 1.35
    duration: 2400
    loops: Animation.Infinite
    running: root.sweepActive && root.visible
  }

  Rectangle {
    anchors.fill: parent
    color: root.accent
    opacity: root.hoverHighlightOpacity
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 2
    color: root.accent
    opacity: root.active ? 0.9 : 0
  }

  Row {
    id: content
    anchors.centerIn: parent
    anchors.verticalCenterOffset: root.contentVerticalOffset
    spacing: image.visible && label.text.length > 0 ? 4 : 0

    Image {
      id: image
      anchors.verticalCenter: parent.verticalCenter
      visible: root.leadingImageSource !== ""
      source: root.leadingImageDisplaySource
      width: root.leadingImageSize
      height: root.leadingImageSize
      sourceSize.width: width
      sourceSize.height: height
      fillMode: Image.PreserveAspectFit
      cache: false
      smooth: true
      mipmap: true
    }

    Item {
      id: labelSlot
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.sweepActive
      implicitWidth: label.implicitWidth
      implicitHeight: label.implicitHeight

      Text {
        id: label
        anchors.centerIn: parent
        z: 2
        color: root.baseTextColor()
        font.family: "BlexMono Nerd Font Propo"
        font.pixelSize: Math.round(root.labelAnimatedPixelSize)
        font.weight: root.labelFontWeight
        scale: root.labelAnimatedScale
        transformOrigin: Item.Center
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      Text {
        anchors.centerIn: label
        anchors.horizontalCenterOffset: -1
        z: 1
        text: label.text
        color: root.accent
        opacity: root.hoverGlowOpacity
        font.family: label.font.family
        font.pixelSize: label.font.pixelSize
        font.weight: label.font.weight
        scale: root.labelAnimatedScale + 0.08
        transformOrigin: Item.Center
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      Text {
        anchors.centerIn: label
        anchors.horizontalCenterOffset: 1
        z: 1
        text: label.text
        color: root.accent
        opacity: root.hoverGlowOpacity
        font.family: label.font.family
        font.pixelSize: label.font.pixelSize
        font.weight: label.font.weight
        scale: root.labelAnimatedScale + 0.08
        transformOrigin: Item.Center
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      Text {
        anchors.centerIn: label
        anchors.verticalCenterOffset: -1
        z: 1
        text: label.text
        color: root.accent
        opacity: root.hoverGlowOpacity
        font.family: label.font.family
        font.pixelSize: label.font.pixelSize
        font.weight: label.font.weight
        scale: root.labelAnimatedScale + 0.08
        transformOrigin: Item.Center
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      Text {
        anchors.centerIn: label
        anchors.verticalCenterOffset: 1
        z: 1
        text: label.text
        color: root.accent
        opacity: root.hoverGlowOpacity
        font.family: label.font.family
        font.pixelSize: label.font.pixelSize
        font.weight: label.font.weight
        scale: root.labelAnimatedScale + 0.08
        transformOrigin: Item.Center
        elide: Text.ElideRight
        maximumLineCount: 1
      }
    }

    Row {
      id: sweepLabel
      anchors.verticalCenter: parent.verticalCenter
      visible: root.sweepActive
      spacing: 0

      Repeater {
        model: label.text.length

        Text {
          required property int index

          text: label.text.charAt(index)
          color: root.textSweepColor(index, label.text.length)
          font.family: label.font.family
          font.pixelSize: label.font.pixelSize
          font.weight: label.font.weight
          maximumLineCount: 1
        }
      }
    }
  }

  LacunaStateLayer {
    id: clickArea

    stateColor: root.accent
    showFill: false
    onContainsMouseChanged: {
      root.hoverRevealAmount = containsMouse ? 1 : 0
      if (containsMouse) root.showTooltip()
      else root.hideTooltip()
    }
    onTriggered: root.triggered()
    onSecondaryClicked: root.secondaryTriggered()
    onScrolled: function(delta) {
      root.scrolled(delta)
    }
  }

  SequentialAnimation {
    running: root.labelHoverPulse && root.hovered && !root.sweepActive
    loops: Animation.Infinite

    NumberAnimation {
      target: root
      property: "hoverPulseAmount"
      from: 0
      to: 1
      duration: 900
      easing.type: Easing.InOutSine
    }

    NumberAnimation {
      target: root
      property: "hoverPulseAmount"
      from: 1
      to: 0
      duration: 900
      easing.type: Easing.InOutSine
    }

    onStopped: root.hoverPulseAmount = 0
  }

}
