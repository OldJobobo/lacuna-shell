import QtQuick

Rectangle {
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
  property int leadingImageSize: compact ? 12 : 16
  property int contentVerticalOffset: 0
  property int contentHorizontalPadding: compact ? 8 : 16
  property int labelPixelSize: compact ? 11 : 12
  property int labelFontWeight: active ? Font.DemiBold : Font.Normal
  property bool labelHoverPulse: false
  property real labelHoverScale: 1.18
  property real labelPulseScale: 1.0
  property bool hovered: false
  property bool sweepActive: false
  property color sweepColor: accent
  property real sweepPosition: -0.35
  property var tooltipHost: null

  width: Math.max(minButtonWidth, content.implicitWidth + contentHorizontalPadding)
  height: compact ? 24 : 32
  radius: 0
  color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.08) : "transparent"
  border.color: "transparent"
  border.width: 0
  clip: true

  function showTooltip() {
    if (tooltipHost) {
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
      source: root.leadingImageSource
      width: root.leadingImageSize
      height: root.leadingImageSize
      sourceSize.width: width
      sourceSize.height: height
      fillMode: Image.PreserveAspectFit
      cache: false
      smooth: true
      mipmap: true
    }

    Text {
      id: label
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.sweepActive
      color: root.baseTextColor()
      font.family: "BlexMono Nerd Font Propo"
      font.pixelSize: root.labelPixelSize
      font.weight: root.labelFontWeight
      elide: Text.ElideRight
      maximumLineCount: 1
      scale: root.labelHoverPulse && root.hovered ? root.labelPulseScale : 1
      transformOrigin: Item.Center

      Behavior on scale {
        NumberAnimation {
          duration: 120
          easing.type: Easing.OutCubic
        }
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

  MouseArea {
    id: clickArea

    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: {
      root.hovered = true
      root.labelPulseScale = root.labelHoverScale
      root.showTooltip()
    }
    onExited: {
      root.hovered = false
      root.labelPulseScale = 1.0
      root.hideTooltip()
    }
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.secondaryTriggered()
      else root.triggered()
    }
    onWheel: function(wheel) {
      root.scrolled(wheel.angleDelta.y)
    }
  }

  SequentialAnimation {
    running: root.labelHoverPulse && root.hovered && !root.sweepActive
    loops: Animation.Infinite

    NumberAnimation {
      target: root
      property: "labelPulseScale"
      from: root.labelHoverScale
      to: root.labelHoverScale + 0.08
      duration: 420
      easing.type: Easing.InOutSine
    }

    NumberAnimation {
      target: root
      property: "labelPulseScale"
      from: root.labelHoverScale + 0.08
      to: root.labelHoverScale
      duration: 520
      easing.type: Easing.InOutSine
    }

    onStopped: root.labelPulseScale = 1.0
  }

}
