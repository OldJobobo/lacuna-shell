import QtQuick
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
  property int panelHeight: 410
  property int joinRadius: bar && bar.resolvedCornerRadius !== undefined ? Math.max(0, Math.round(Number(bar.resolvedCornerRadius) || 0)) : 14
  property int cornerRadius: joinRadius
  property int margin: 8
  property color accentColor: "#89b4fa"
  property color urgentColor: "#f38ba8"
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

  function space(value) { return Math.round(Number(value || 0)) }
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
    if (open) {
      bar.requestPopout(root)
      if (activeService && typeof activeService.refresh === "function") activeService.refresh()
    } else if (bar.activePopout === root) {
      bar.releasePopout(root)
    }
  }

  QtObject {
    id: fallbackService
    property bool hasBattery: false
    property bool onBattery: false
    property bool charging: false
    property bool discharging: false
    property bool full: false
    property bool low: false
    property int percent: 0
    property string icon: ""
    property string modeLabel: "AC power"
    property string activeProfile: ""
    property string activeProfileIcon: "󰂄"
    property string activeProfileLabel: "Profile"
    property var batteryInfo: ({})
    property var systemInfo: ({})
    property var profiles: []
    function refresh() {}
    function setProfile(profile) {}
    function profileIcon(name) { return "󰂄" }
    function profileLabel(name) { return String(name || "Profile") }
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
          height: root.space(138)
          radius: 0
          color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.075)

          Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: root.space(12)
            anchors.topMargin: root.space(11)
            text: "LACUNA POWER"
            color: root.dimColor
            font.family: root.fontFamily
            font.pixelSize: 11
            font.bold: true
          }

          Text {
            id: powerIcon
            anchors.left: parent.left
            anchors.leftMargin: root.space(12)
            anchors.verticalCenter: parent.verticalCenter
            text: activeService.icon
            color: activeService.low ? root.urgentColor : root.accentColor
            font.family: root.fontFamily
            font.pixelSize: 34
          }

          Column {
            anchors.left: powerIcon.right
            anchors.leftMargin: root.space(12)
            anchors.right: parent.right
            anchors.rightMargin: root.space(12)
            anchors.verticalCenter: powerIcon.verticalCenter
            spacing: root.space(3)
            Text {
              width: parent.width
              text: activeService.hasBattery ? activeService.percent + "%" : "AC power"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: 20
              font.bold: true
            }
            Text {
              width: parent.width
              text: activeService.modeLabel + " / " + activeService.activeProfileLabel
              color: root.dimColor
              font.family: root.fontFamily
              font.pixelSize: 13
              elide: Text.ElideRight
            }
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: root.space(12)
            height: root.space(8)
            radius: 0
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10)
            Rectangle {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              width: Math.max(0, Math.min(parent.width, parent.width * activeService.percent / 100))
              radius: 0
              color: activeService.low ? root.urgentColor : root.accentColor
            }
          }
        }

        Text {
          id: profileTitle
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: hero.bottom
          anchors.topMargin: root.space(16)
          text: "Power profile"
          color: root.dimColor
          font.family: root.fontFamily
          font.pixelSize: 11
          font.bold: true
        }

        Row {
          id: profiles
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: profileTitle.bottom
          anchors.topMargin: root.space(8)
          spacing: root.space(7)

          Repeater {
            model: activeService.profiles
            ActionChip {
              required property var modelData
              text: activeService.profileIcon(modelData) + " " + activeService.profileLabel(modelData).toUpperCase()
              accent: modelData === activeService.activeProfile ? root.accentColor : root.dimColor
              onTriggered: activeService.setProfile(modelData)
            }
          }
        }

        Grid {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: profiles.bottom
          anchors.topMargin: root.space(18)
          columns: 2
          columnSpacing: root.space(8)
          rowSpacing: root.space(8)

          StatTile { label: "TIME LEFT"; value: activeService.batteryInfo.time || activeService.batteryInfo.remaining || "n/a" }
          StatTile { label: "DRAW"; value: activeService.batteryInfo.rate || activeService.batteryInfo.draw || "n/a" }
          StatTile { label: "CPU"; value: activeService.systemInfo.cpu || activeService.systemInfo.load || "n/a" }
          StatTile { label: "MEM"; value: activeService.systemInfo.memory || activeService.systemInfo.mem || "n/a" }
        }

        ActionChip {
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          text: "REFRESH"
          accent: root.accentColor
          onTriggered: activeService.refresh()
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

  component StatTile: Rectangle {
    property string label: ""
    property string value: ""
    width: (root.innerWidth - root.space(8)) / 2
    height: root.space(58)
    radius: 0
    color: root.panelFill
    border.width: 1
    border.color: root.lineColor
    Text {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.leftMargin: root.space(10)
      anchors.topMargin: root.space(8)
      text: parent.label
      color: root.dimColor
      font.family: root.fontFamily
      font.pixelSize: 11
      font.bold: true
    }
    Text {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: root.space(10)
      anchors.rightMargin: root.space(10)
      anchors.bottomMargin: root.space(8)
      text: parent.value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: 14
      elide: Text.ElideRight
    }
  }
}
