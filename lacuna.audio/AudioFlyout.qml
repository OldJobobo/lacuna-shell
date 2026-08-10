import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland

PopupWindow {
  id: root

  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  property var service: null

  property bool open: false
  property bool reduceMotion: false
  property int panelWidth: 392
  property int panelHeight: 430
  property int joinRadius: bar && bar.resolvedCornerRadius !== undefined ? Math.max(0, Math.round(Number(bar.resolvedCornerRadius) || 0)) : 14
  property int cornerRadius: joinRadius
  property int margin: 8
  property color accentColor: "#89b4fa"
  property string fontFamily: bar ? bar.fontFamily : "Hack Nerd Font Propo"

  readonly property var activeService: service || fallbackService
  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  readonly property string attachmentEdge: bar && /^(top|bottom|left|right)$/.test(bar.position) ? bar.position : "top"
  readonly property int contentPadding: 14
  readonly property int innerWidth: panelWidth - contentPadding * 2
  readonly property color surfaceBackground: opaqueColor(bar ? bar.background : "#101315")
  readonly property color panelColor: Qt.rgba(surfaceBackground.r, surfaceBackground.g, surfaceBackground.b, 0.98)
  readonly property color foreground: bar ? bar.foreground : "#d8dee9"
  readonly property color panelFill: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.045)
  readonly property color panelHover: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.11)
  readonly property color lineColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.14)
  readonly property color dimColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.60)

  function space(value) {
    return Math.round(Number(value || 0))
  }

  function opaqueColor(colorValue) {
    var c = colorValue
    if (typeof c === "string") c = Qt.color(c)
    return Qt.rgba(c.r, c.g, c.b, 1)
  }

  function close() {
    if (owner && "close" in owner) owner.close()
    else root.open = false
  }

  MotionTokens {
    id: motionTokens
    animationDisabled: root.reduceMotion
  }

  property real reveal: open ? 1 : 0
  Behavior on reveal { NumberAnimation { duration: motionTokens.reveal; easing.type: Easing.OutCubic } }
  readonly property real contentOpacity: Math.max(0, Math.min(1, (reveal - 0.3) / 0.7))

  visible: !(bar && bar.fullscreenSuppressed === true) && (open || reveal > 0.001)
  onVisibleChanged: {
    if (!visible && bar && typeof bar.clearPopoutBorderGap === "function")
      bar.clearPopoutBorderGap(coordinatorKey)
  }
  color: "transparent"
  implicitWidth: surface.fullWidth
  implicitHeight: surface.fullHeight

  onOpenChanged: {
    if (!bar) return
    if (open) bar.requestPopout(root)
    else if (bar.activePopout === root) bar.releasePopout(root)
  }

  QtObject {
    id: fallbackService
    property bool hasSink: false
    property bool hasSource: false
    property bool outputMuted: true
    property bool inputMuted: true
    property real outputVolume: 0
    property real inputVolume: 0
    property int outputPercent: 0
    property int inputPercent: 0
    property string outputIcon: ""
    property string inputIcon: "󰍭"
    property string outputLabel: "No output"
    property string inputLabel: "No input"
    property string outputMood: "Muted"
    property var sinks: []
    property var sources: []
    property var streams: []
    function setOutputVolume(value) {}
    function toggleOutputMute() {}
    function toggleInputMute() {}
    function setDefaultSink(node) {}
    function setDefaultSource(node) {}
    function nodeLabel(node) { return "Unknown" }
    function streamLabel(node) { return "Stream" }
    function setStreamVolume(node, value) {}
    function toggleStreamMute(node) {}
  }

  HyprlandFocusGrab {
    active: root.open
    windows: root.anchorWindow ? [root, root.anchorWindow] : [root]
    onCleared: root.close()
  }

  anchor {
    id: popupAnchor
    window: root.anchorWindow
    adjustment: PopupAdjustment.Slide
    edges: Edges.Top | Edges.Left
    gravity: root.attachmentEdge === "bottom"
      ? Edges.Top | Edges.Right
      : (root.attachmentEdge === "right" ? Edges.Bottom | Edges.Left : Edges.Bottom | Edges.Right)
    rect.width: 1
    rect.height: 1

    onAnchoring: {
      if (!root.anchorWindow || !root.bar) return
      var target = root.anchorItem
      var localX = target.width / 2 - surface.fullWidth / 2
      var localY = target.height - surface.attachmentOverlap

      if (root.attachmentEdge === "bottom") {
        localY = -surface.fullHeight + surface.attachmentOverlap
      } else if (root.attachmentEdge === "left") {
        localX = target.width - surface.attachmentOverlap
        localY = target.height / 2 - surface.fullHeight / 2
      } else if (root.attachmentEdge === "right") {
        localX = -surface.fullWidth + surface.attachmentOverlap
        localY = target.height / 2 - surface.fullHeight / 2
      }

      var point = root.anchorWindow.contentItem.mapFromItem(target, localX, localY)
      if (root.attachmentEdge === "top" || root.attachmentEdge === "bottom")
        point.x = surface.constrainedHorizontalPopupX(point.x, root.anchorWindow.width,
          root.implicitWidth, 0, root.margin)
      else
        point.y = Math.max(root.margin, Math.min(point.y, root.anchorWindow.height - root.implicitHeight - root.margin))
      popupAnchor.rect.x = Math.round(point.x)
      popupAnchor.rect.y = Math.round(point.y)
      if (typeof root.bar.setPopoutBorderGap === "function") {
        var gapStart = root.attachmentEdge === "top" || root.attachmentEdge === "bottom"
          ? popupAnchor.rect.x : popupAnchor.rect.y
        var gapLength = surface.borderGapLength
        root.bar.setPopoutBorderGap(root.coordinatorKey, gapStart, gapLength)
      }
    }
  }
  Item {
    id: clipper
    readonly property bool horizontalReveal: root.attachmentEdge === "top" || root.attachmentEdge === "bottom"
    x: root.attachmentEdge === "right" ? root.implicitWidth - width : 0
    y: root.attachmentEdge === "bottom" ? root.implicitHeight - height : 0
    width: horizontalReveal ? root.implicitWidth : Math.round(root.implicitWidth * root.reveal)
    height: horizontalReveal ? Math.round(root.implicitHeight * root.reveal) : root.implicitHeight
    clip: true

    Item {
      id: stage
      x: -clipper.x
      y: -clipper.y
      width: root.implicitWidth
      height: root.implicitHeight

      BarFlyoutSurface {
        bar: root.bar
        id: surface
        panelWidth: root.panelWidth
        panelHeight: root.panelHeight
        joinRadius: root.joinRadius
        cornerRadius: root.cornerRadius
        panelColor: root.panelColor
        attachmentEdge: root.attachmentEdge
      }

      Item {
        x: surface.panelLeft + root.contentPadding
        y: surface.panelTop + root.contentPadding
        width: root.innerWidth
        height: root.panelHeight - root.contentPadding * 2
        opacity: root.contentOpacity

        Rectangle {
          id: hero
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: root.space(126)
          radius: 0
          color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.075)

          Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: root.space(12)
            anchors.topMargin: root.space(11)
            text: "LACUNA AUDIO"
            color: root.dimColor
            font.family: root.fontFamily
            font.pixelSize: 11
            font.bold: true
          }

          Text {
            id: outputIcon
            anchors.left: parent.left
            anchors.leftMargin: root.space(12)
            anchors.verticalCenter: parent.verticalCenter
            text: activeService.outputIcon
            color: root.accentColor
            font.family: root.fontFamily
            font.pixelSize: 34
          }

          Column {
            anchors.left: outputIcon.right
            anchors.leftMargin: root.space(12)
            anchors.right: parent.right
            anchors.rightMargin: root.space(12)
            anchors.verticalCenter: outputIcon.verticalCenter
            spacing: root.space(3)

            Text {
              width: parent.width
              text: activeService.outputMuted ? "Muted" : activeService.outputPercent + "%"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: 20
              font.bold: true
            }

            Text {
              width: parent.width
              text: activeService.outputLabel + " / " + activeService.outputMood
              color: root.dimColor
              font.family: root.fontFamily
              font.pixelSize: 13
              elide: Text.ElideRight
            }
          }

          Slider {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: root.space(12)
            from: 0
            to: 150
            value: activeService.outputPercent
            live: true
            onMoved: activeService.setOutputVolume(value / 100)
          }
        }

        Row {
          id: actions
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: hero.bottom
          anchors.topMargin: root.space(10)
          spacing: root.space(7)

          ActionChip {
            text: activeService.outputMuted ? "UNMUTE" : "MUTE"
            accent: root.accentColor
            onTriggered: activeService.toggleOutputMute()
          }

          ActionChip {
            text: activeService.inputMuted ? "MIC OFF" : "MIC ON"
            accent: root.dimColor
            enabled: activeService.hasSource
            onTriggered: activeService.toggleInputMute()
          }
        }

        Text {
          id: outputTitle
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: actions.bottom
          anchors.topMargin: root.space(16)
          text: "OUTPUT DEVICES"
          color: root.dimColor
          font.family: root.fontFamily
          font.pixelSize: 11
          font.bold: true
        }

        Flickable {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: outputTitle.bottom
          anchors.topMargin: root.space(8)
          anchors.bottom: parent.bottom
          clip: true
          contentWidth: width
          contentHeight: deviceColumn.implicitHeight
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: deviceColumn
            width: parent.width
            spacing: root.space(7)

            Repeater {
              model: activeService.sinks
              DeviceSlat {
                required property var modelData
                width: parent ? parent.width : 0
                label: modelData.label
                selected: modelData.selected === true
                onTriggered: activeService.setDefaultSink(modelData)
              }
            }

            Repeater {
              model: activeService.sources
              DeviceSlat {
                required property var modelData
                width: parent ? parent.width : 0
                label: "MIC / " + modelData.label
                selected: modelData.selected === true
                onTriggered: activeService.setDefaultSource(modelData)
              }
            }

            Text {
              width: parent.width
              visible: activeService.streams.length > 0
              height: visible ? implicitHeight + root.space(9) : 0
              verticalAlignment: Text.AlignBottom
              text: "PLAYBACK STREAMS"
              color: root.dimColor
              font.family: root.fontFamily
              font.pixelSize: 11
              font.bold: true
            }

            Repeater {
              model: activeService.streams
              StreamSlat {
                required property var modelData
                width: parent ? parent.width : 0
                row: modelData
              }
            }
          }
        }
      }
    }
  }

  component ActionChip: Rectangle {
    id: chip
    signal triggered()
    property string text: ""
    property color accent: root.accentColor
    property bool enabled: true
    width: label.implicitWidth + root.space(16)
    height: root.space(24)
    radius: 0
    color: chipMouse.containsMouse && enabled ? Qt.rgba(accent.r, accent.g, accent.b, 0.18) : Qt.rgba(accent.r, accent.g, accent.b, 0.075)
    border.width: 1
    border.color: Qt.rgba(accent.r, accent.g, accent.b, enabled ? 0.35 : 0.15)
    opacity: enabled ? 1 : 0.48
    Text {
      id: label
      anchors.centerIn: parent
      text: chip.text
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: 11
      font.bold: true
    }
    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: chip.enabled
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.triggered()
    }
  }

  component DeviceSlat: Rectangle {
    id: slat
    signal triggered()
    property string label: ""
    property bool selected: false
    height: root.space(42)
    radius: 0
    color: selected ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12) : (slatMouse.containsMouse ? root.panelHover : root.panelFill)
    border.width: 1
    border.color: selected ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.42) : root.lineColor
    Text {
      anchors.left: parent.left
      anchors.right: status.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: root.space(12)
      anchors.rightMargin: root.space(8)
      text: slat.label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: 13
      elide: Text.ElideRight
    }
    Text {
      id: status
      anchors.right: parent.right
      anchors.rightMargin: root.space(12)
      anchors.verticalCenter: parent.verticalCenter
      text: slat.selected ? "ACTIVE" : "USE"
      color: slat.selected ? root.accentColor : root.dimColor
      font.family: root.fontFamily
      font.pixelSize: 11
      font.bold: true
    }
    MouseArea {
      id: slatMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: slat.triggered()
    }
  }

  component StreamSlat: Rectangle {
    id: streamSlat

    required property var row
    readonly property bool muted: row ? row.muted === true : true
    readonly property int percent: row ? Number(row.percent || 0) : 0

    height: root.space(68)
    radius: 0
    color: streamMouse.containsMouse ? root.panelHover : root.panelFill
    border.width: 1
    border.color: root.lineColor

    Text {
      id: streamMute
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.leftMargin: root.space(11)
      anchors.topMargin: root.space(10)
      width: root.space(22)
      text: streamSlat.muted ? "󰝟" : "󰕾"
      color: streamSlat.muted ? root.dimColor : root.accentColor
      font.family: root.fontFamily
      font.pixelSize: 16
      horizontalAlignment: Text.AlignHCenter

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: activeService.toggleStreamMute(streamSlat.row)
      }
    }

    Text {
      anchors.left: streamMute.right
      anchors.right: streamPercent.left
      anchors.top: parent.top
      anchors.leftMargin: root.space(8)
      anchors.rightMargin: root.space(8)
      anchors.topMargin: root.space(10)
      text: streamSlat.row ? streamSlat.row.label : "Stream"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: 13
      elide: Text.ElideRight
    }

    Text {
      id: streamPercent
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.rightMargin: root.space(11)
      anchors.topMargin: root.space(11)
      width: root.space(38)
      text: streamSlat.percent + "%"
      color: root.dimColor
      font.family: root.fontFamily
      font.pixelSize: 11
      font.bold: true
      horizontalAlignment: Text.AlignRight
    }

    Slider {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: root.space(11)
      anchors.rightMargin: root.space(11)
      anchors.bottomMargin: root.space(7)
      from: 0
      to: 150
      value: streamSlat.percent
      live: true
      onMoved: activeService.setStreamVolume(streamSlat.row, value / 100)
    }

    MouseArea {
      id: streamMouse
      anchors.fill: parent
      acceptedButtons: Qt.NoButton
      hoverEnabled: true
    }
  }
}
