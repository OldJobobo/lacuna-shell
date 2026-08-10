import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import "NetworkModel.js" as Model

PopupWindow {
  id: root

  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  property var service: null

  property bool open: false
  property bool reduceMotion: false
  property int panelWidth: 392
  property int panelHeight: 520
  property int joinRadius: bar && bar.resolvedCornerRadius !== undefined ? Math.max(0, Math.round(Number(bar.resolvedCornerRadius) || 0)) : 14
  property int cornerRadius: joinRadius
  property int margin: 8
  property string passwordSsid: ""
  property string passwordText: ""
  property color accentColor: "#89b4fa"
  property color urgentColor: "#f38ba8"
  property string fontFamily: bar ? bar.fontFamily : "Hack Nerd Font Propo"

  readonly property var activeService: service || fallbackService
  readonly property var wifiNetworks: activeService && activeService.wifiNetworks ? activeService.wifiNetworks : []
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

  function rowTitle(index) {
    return Model.wifiSectionTitle(wifiNetworks, index)
  }

  function rowStatus(row) {
    if (!row) return ""
    if (activeService && activeService.actionSsid === row.ssid && activeService.actionKind === "connect") return "CONNECTING"
    if (activeService && activeService.actionSsid === row.ssid && activeService.actionKind === "disconnect") return "DISCONNECTING"
    if (activeService && activeService.actionSsid === row.ssid && activeService.actionKind === "forget") return "FORGETTING"
    if (row.connected) return "ONLINE"
    if (row.known) return "KNOWN"
    return activeService && activeService.isProtected(row.security) ? "LOCKED" : "OPEN"
  }

  function activateRow(row) {
    if (!activeService || !row || activeService.busy) return
    if (row.connected) {
      activeService.disconnect(row.network)
    } else if (activeService.isProtected(row.security) && !row.known) {
      passwordSsid = row.ssid
      passwordText = ""
    } else {
      activeService.connectKnown(row.ssid)
    }
  }

  MotionTokens {
    id: motionTokens
    animationDisabled: root.reduceMotion
  }

  property real reveal: open ? 1 : 0
  Behavior on reveal {
    NumberAnimation { duration: motionTokens.reveal; easing.type: Easing.OutCubic }
  }

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
      if (activeService && typeof activeService.refresh === "function") activeService.refresh(true)
    } else if (bar.activePopout === root) {
      bar.releasePopout(root)
    }
  }

  QtObject {
    id: fallbackService
    property string displayTitle: "Network"
    property string displayLabel: "Loading"
    property string icon: "󰤮"
    property bool connected: false
    property bool wifiEnabled: false
    property bool networkManagerAvailable: false
    property bool wifiStationAvailable: false
    property bool scanning: false
    property bool busy: false
    property string lastError: ""
    property string actionSsid: ""
    property string actionKind: ""
    property var wifiNetworks: []
    function refresh(scanWifi) {}
    function toggleWifi() {}
    function isProtected(security) { return false }
    function canForgetNetwork(row) { return false }
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
        id: content
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
          height: root.space(112)
          radius: 0
          color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.075)

          Text {
            id: eyebrow
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: root.space(12)
            anchors.topMargin: root.space(11)
            text: "LACUNA NETWORK"
            color: root.dimColor
            font.family: root.fontFamily
            font.pixelSize: 11
            font.bold: true
          }

          Text {
            id: heroIcon
            anchors.left: parent.left
            anchors.top: eyebrow.bottom
            anchors.leftMargin: root.space(12)
            anchors.topMargin: root.space(8)
            text: activeService.icon
            color: root.accentColor
            font.family: root.fontFamily
            font.pixelSize: 32
          }

          Column {
            anchors.left: heroIcon.right
            anchors.leftMargin: root.space(12)
            anchors.right: parent.right
            anchors.rightMargin: root.space(12)
            anchors.verticalCenter: heroIcon.verticalCenter
            spacing: root.space(2)

            Text {
              width: parent.width
              text: activeService.displayTitle
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: 18
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: activeService.displayLabel
              color: root.dimColor
              font.family: root.fontFamily
              font.pixelSize: 13
              elide: Text.ElideRight
            }
          }

          Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: root.space(10)
            spacing: root.space(7)

            ActionChip {
              text: activeService.scanning ? "SCANNING" : "SCAN"
              enabled: !activeService.scanning
              accent: root.accentColor
              onTriggered: activeService.refresh(true)
            }

            ActionChip {
              text: activeService.wifiEnabled ? "WIFI ON" : "WIFI OFF"
              accent: activeService.wifiEnabled ? root.accentColor : root.dimColor
              onTriggered: activeService.toggleWifi()
            }
          }
        }

        Text {
          id: errorBanner
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: hero.bottom
          anchors.topMargin: root.space(9)
          height: activeService.lastError !== "" ? root.space(22) : 0
          visible: activeService.lastError !== ""
          text: activeService.lastError
          color: root.urgentColor
          font.family: root.fontFamily
          font.pixelSize: 11
          elide: Text.ElideRight
        }

        Text {
          id: sectionTitle
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: errorBanner.visible ? errorBanner.bottom : hero.bottom
          anchors.topMargin: root.space(14)
          text: activeService.networkManagerAvailable ? "SIGNALS IN RANGE" : "NETWORKMANAGER UNAVAILABLE"
          color: root.dimColor
          font.family: root.fontFamily
          font.pixelSize: 11
          font.bold: true
        }

        Flickable {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: sectionTitle.bottom
          anchors.topMargin: root.space(8)
          anchors.bottom: parent.bottom
          clip: true
          contentWidth: width
          contentHeight: networkColumn.implicitHeight
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: networkColumn
            width: parent.width
            spacing: root.space(7)

            Repeater {
              model: root.wifiNetworks

              Column {
                required property int index
                required property var modelData

                width: parent ? parent.width : 0
                spacing: root.space(5)

                Text {
                  width: parent.width
                  visible: root.rowTitle(index) !== ""
                  text: root.rowTitle(index).toUpperCase()
                  color: root.dimColor
                  font.family: root.fontFamily
                  font.pixelSize: 11
                  font.bold: true
                }

                NetworkSlat {
                  width: parent.width
                  row: modelData
                  statusText: root.rowStatus(modelData)
                  passwordOpen: root.passwordSsid === modelData.ssid
                }
              }
            }

            Text {
              width: parent.width
              visible: root.wifiNetworks.length === 0
              text: activeService.wifiStationAvailable ? "No signals found" : "No Wi-Fi adapter found"
              color: root.dimColor
              font.family: root.fontFamily
              font.pixelSize: 13
              horizontalAlignment: Text.AlignHCenter
              topPadding: root.space(38)
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
    color: chipMouse.containsMouse && enabled
      ? Qt.rgba(accent.r, accent.g, accent.b, 0.18)
      : Qt.rgba(accent.r, accent.g, accent.b, 0.075)
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

  component SignalBars: Row {
    id: bars

    property int strength: 0
    property color accent: root.accentColor

    spacing: root.space(3)
    height: root.space(20)

    Repeater {
      model: 5
      Rectangle {
        width: root.space(3)
        height: root.space(5 + index * 3)
        anchors.bottom: parent.bottom
        radius: 0
        color: bars.accent
        opacity: bars.strength >= (index + 1) * 20 ? 0.95 : 0.18
      }
    }
  }

  component NetworkSlat: Rectangle {
    id: slat

    required property var row
    property string statusText: ""
    property bool passwordOpen: false

    height: passwordOpen ? root.space(112) : root.space(60)
    radius: 0
    color: row && row.connected
      ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, slatMouse.containsMouse ? 0.18 : 0.11)
      : (slatMouse.containsMouse ? root.panelHover : root.panelFill)
    border.width: 1
    border.color: row && row.connected ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.42) : root.lineColor

    MouseArea {
      id: slatMouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton
      cursorShape: Qt.PointingHandCursor
      onClicked: root.activateRow(row)
    }

    Text {
      id: ssidText
      anchors.left: parent.left
      anchors.right: signalBars.left
      anchors.top: parent.top
      anchors.leftMargin: root.space(12)
      anchors.rightMargin: root.space(10)
      anchors.topMargin: root.space(10)
      text: row ? (row.ssid || "Hidden network") : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: 13
      font.bold: row && row.connected
      elide: Text.ElideRight
    }

    Text {
      anchors.left: ssidText.left
      anchors.right: ssidText.right
      anchors.top: ssidText.bottom
      anchors.topMargin: root.space(3)
      text: statusText + " / " + (row ? row.signal : 0) + "%"
      color: root.dimColor
      font.family: root.fontFamily
      font.pixelSize: 11
      elide: Text.ElideRight
    }

    SignalBars {
      id: signalBars
      anchors.right: actionColumn.left
      anchors.rightMargin: root.space(10)
      anchors.verticalCenter: passwordOpen ? undefined : parent.verticalCenter
      anchors.top: passwordOpen ? parent.top : undefined
      anchors.topMargin: passwordOpen ? root.space(14) : 0
      strength: row ? row.signal : 0
      accent: row && row.connected ? root.accentColor : root.foreground
    }

    Column {
      id: actionColumn
      anchors.right: parent.right
      anchors.rightMargin: root.space(8)
      anchors.verticalCenter: passwordOpen ? undefined : parent.verticalCenter
      anchors.top: passwordOpen ? parent.top : undefined
      anchors.topMargin: passwordOpen ? root.space(8) : 0
      spacing: root.space(5)

      ActionChip {
        text: row && row.connected ? "DROP" : "JOIN"
        accent: row && row.connected ? root.dimColor : root.accentColor
        enabled: !activeService.busy
        onTriggered: root.activateRow(row)
      }

      ActionChip {
        visible: activeService.canForgetNetwork(row)
        text: "FORGET"
        accent: root.dimColor
        enabled: !activeService.busy
        onTriggered: activeService.forget(row)
      }
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: root.space(8)
      height: passwordOpen ? root.space(36) : 0
      visible: passwordOpen
      radius: 0
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.055)
      border.width: 1
      border.color: root.lineColor

      TextField {
        anchors.left: parent.left
        anchors.right: joinSecret.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.space(8)
        anchors.rightMargin: root.space(6)
        placeholderText: "passphrase"
        echoMode: TextInput.Password
        text: root.passwordText
        background: null
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: 13
        onTextChanged: root.passwordText = text
        onAccepted: {
          activeService.connectWithPassphrase(row.ssid, root.passwordText)
          root.passwordSsid = ""
        }
      }

      ActionChip {
        id: joinSecret
        anchors.right: cancelSecret.left
        anchors.rightMargin: root.space(5)
        anchors.verticalCenter: parent.verticalCenter
        text: "SEND"
        accent: root.accentColor
        enabled: root.passwordText.length > 0 && !activeService.busy
        onTriggered: {
          activeService.connectWithPassphrase(row.ssid, root.passwordText)
          root.passwordSsid = ""
        }
      }

      ActionChip {
        id: cancelSecret
        anchors.right: parent.right
        anchors.rightMargin: root.space(5)
        anchors.verticalCenter: parent.verticalCenter
        text: "X"
        accent: root.dimColor
        onTriggered: root.passwordSsid = ""
      }
    }
  }
}
