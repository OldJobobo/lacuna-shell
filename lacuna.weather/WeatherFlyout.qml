import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

PopupWindow {
  id: root

  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  property var weatherState: null
  property bool open: false
  property bool reduceMotion: false
  property int panelWidth: 430
  property int panelHeight: 380
  property int joinRadius: bar && bar.resolvedCornerRadius !== undefined ? Math.max(0, Math.round(Number(bar.resolvedCornerRadius) || 0)) : 14
  property int cornerRadius: joinRadius
  property int margin: 8
  property color accentColor: "#89b4fa"
  property color urgentColor: bar ? bar.urgent : "#d42b5b"
  property string fontFamily: bar ? bar.fontFamily : "Hack Nerd Font Propo"
  property bool shadowEnabled: false
  property int shadowOffsetX: 2
  property int shadowOffsetY: 3

  readonly property var coordinatorKey: owner || root
  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  readonly property string attachmentEdge: bar && /^(top|bottom|left|right)$/.test(bar.position) ? bar.position : "top"
  readonly property color foreground: bar ? bar.foreground : "#d8dee9"
  readonly property color background: opaqueColor(bar ? bar.background : "#101315")
  readonly property color whisper: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.48)
  readonly property color soft: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.76)
  readonly property color seam: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.16)
  readonly property string displayFontFamily: tokens.displayFont
  readonly property int displayHeroWeight: tokens.displayTelemetryWeight
  readonly property real displayTitleTracking: tokens.trackingTitle
  readonly property int contentPadding: 16
  readonly property int innerWidth: panelWidth - contentPadding * 2
  readonly property int contentSpacing: tokens.spaceNormal
  readonly property int headerHeight: 20
  readonly property int heroHeight: hasData ? 132 : 267
  readonly property int dividerHeight: hasData ? 1 : 0
  readonly property int forecastLabelHeight: hasData ? 14 : 0
  readonly property int forecastHeight: hasData ? 108 : 0
  readonly property int footerHeight: hasData ? 18 : 0
  readonly property int weatherContentHeight: headerHeight + heroHeight + dividerHeight
    + forecastLabelHeight + forecastHeight + footerHeight + contentSpacing * 5
  readonly property bool contentFitsPanel: weatherContentHeight + contentPadding * 2 <= panelHeight
  readonly property int shadowBlurMax: 28
  readonly property int shadowMargin: shadowEnabled
    ? Math.ceil(shadowBlurMax + Math.max(Math.abs(shadowOffsetX), Math.abs(shadowOffsetY)))
    : 0
  readonly property int shadowFarLeftMargin: shadowEnabled
    ? Math.ceil(shadowMargin + shadowBlurMax * 0.6 + Math.max(0, -shadowOffsetX))
    : 0
  readonly property int shadowFarRightMargin: shadowEnabled
    ? Math.ceil(shadowMargin + shadowBlurMax * 0.6 + Math.max(0, shadowOffsetX))
    : 0
  readonly property int shadowFarTopMargin: shadowEnabled
    ? Math.ceil(shadowMargin + shadowBlurMax * 0.6 + Math.max(0, -shadowOffsetY))
    : 0
  readonly property int shadowFarBottomMargin: shadowEnabled
    ? Math.ceil(shadowMargin + shadowBlurMax * 0.6 + Math.max(0, shadowOffsetY))
    : 0
  readonly property int shadowLeftMargin: attachmentEdge === "left"
    ? 0
    : (attachmentEdge === "right" ? shadowFarLeftMargin : shadowMargin)
  readonly property int shadowRightMargin: attachmentEdge === "right"
    ? 0
    : (attachmentEdge === "left" ? shadowFarRightMargin : shadowMargin)
  readonly property int shadowTopMargin: attachmentEdge === "top"
    ? 0
    : (attachmentEdge === "bottom" ? shadowFarTopMargin : shadowMargin)
  readonly property int shadowBottomMargin: attachmentEdge === "bottom"
    ? 0
    : (attachmentEdge === "top" ? shadowFarBottomMargin : shadowMargin)
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property bool hasData: weatherState && weatherState.hasData
  readonly property var current: hasData ? weatherState.current : ({})
  readonly property var forecastDays: weatherState && weatherState.forecastDays ? weatherState.forecastDays : []
  readonly property string statusLabel: weatherState ? weatherState.statusLabel : "OFFLINE"
  readonly property color statusColor: statusLabel === "LIVE" ? accentColor : (statusLabel === "STALE" ? urgentColor : whisper)
  readonly property string lastUpdatedText: weatherState && weatherState.lastUpdated && weatherState.lastUpdated.getTime() > 0
    ? "UPDATED " + Qt.formatTime(weatherState.lastUpdated, "h:mm AP")
    : "NOT UPDATED"

  function opaqueColor(value) {
    var color = typeof value === "string" ? Qt.color(value) : value
    return Qt.rgba(color.r, color.g, color.b, 1)
  }

  function close() {
    if (owner && typeof owner.close === "function") owner.close()
    else open = false
  }

  function retry() {
    if (weatherState && typeof weatherState.refresh === "function") weatherState.refresh(true)
  }

  function loadFrameSettings(raw) {
    try {
      var frame = JSON.parse(String(raw || "{}")).frame || {}
      shadowEnabled = frame.shadow === true
      var ox = Number(frame.shadowOffsetX)
      var oy = Number(frame.shadowOffsetY)
      shadowOffsetX = isFinite(ox) ? ox : 2
      shadowOffsetY = isFinite(oy) ? oy : 3
    } catch (error) {
      shadowEnabled = false
    }
  }

  LacunaTokens { id: tokens }
  MotionTokens {
    id: motionTokens
    animationDisabled: root.reduceMotion
  }

  FileView {
    path: root.configHome + "/omarchy/lacuna/settings.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadFrameSettings(text())
    onFileChanged: reload()
    onLoadFailed: root.loadFrameSettings("")
  }

  property real reveal: open ? 1 : 0
  readonly property real contentOpacity: Math.max(0, Math.min(1, (reveal - 0.28) / 0.72))

  Behavior on reveal {
    NumberAnimation { duration: motionTokens.reveal; easing.type: Easing.OutCubic }
  }

  visible: !(bar && bar.fullscreenSuppressed === true) && (open || reveal > 0.001)
  onVisibleChanged: {
    if (!visible && bar && typeof bar.clearPopoutBorderGap === "function")
      bar.clearPopoutBorderGap(coordinatorKey)
  }
  color: "transparent"
  implicitWidth: surface.fullWidth + shadowLeftMargin + shadowRightMargin
  implicitHeight: surface.fullHeight + shadowTopMargin + shadowBottomMargin

  onOpenChanged: {
    if (!bar) return
    if (open) {
      bar.requestPopout(coordinatorKey, anchorItem, owner ? owner.moduleName : "")
      retry()
    } else if (bar.activePopout === coordinatorKey) {
      bar.releasePopout(coordinatorKey)
    }
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
      var localX = target.width / 2 - (root.shadowLeftMargin + surface.fullWidth / 2)
      var localY = target.height - root.shadowTopMargin - surface.attachmentOverlap

      if (root.attachmentEdge === "bottom") {
        localY = -(root.shadowTopMargin + surface.fullHeight) + surface.attachmentOverlap
      } else if (root.attachmentEdge === "left") {
        localX = target.width - root.shadowLeftMargin - surface.attachmentOverlap
        localY = target.height / 2 - (root.shadowTopMargin + surface.fullHeight / 2)
      } else if (root.attachmentEdge === "right") {
        localX = -(root.shadowLeftMargin + surface.fullWidth) + surface.attachmentOverlap
        localY = target.height / 2 - (root.shadowTopMargin + surface.fullHeight / 2)
      }

      var point = root.anchorWindow.contentItem.mapFromItem(target, localX, localY)
      if (root.attachmentEdge === "top" || root.attachmentEdge === "bottom")
        point.x = surface.constrainedHorizontalPopupX(point.x, root.anchorWindow.width,
          root.implicitWidth, root.shadowLeftMargin, root.margin)
      else
        point.y = Math.max(root.margin, Math.min(point.y, root.anchorWindow.height - root.implicitHeight - root.margin))
      popupAnchor.rect.x = Math.round(point.x)
      popupAnchor.rect.y = Math.round(point.y)
      if (typeof root.bar.setPopoutBorderGap === "function") {
        var gapStart = root.attachmentEdge === "top" || root.attachmentEdge === "bottom"
          ? popupAnchor.rect.x + root.shadowLeftMargin
          : popupAnchor.rect.y + root.shadowTopMargin
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

      Item {
        id: shadowSource
        anchors.fill: parent
        visible: root.shadowEnabled
        z: -2

        BarFlyoutSurface {
          bar: root.bar
          x: root.shadowLeftMargin
          y: root.shadowTopMargin
          panelWidth: root.panelWidth
          panelHeight: root.panelHeight
          joinRadius: root.joinRadius
          cornerRadius: root.cornerRadius
          panelColor: root.background
          attachmentEdge: root.attachmentEdge
        }
      }

      LacunaDropShadow {
        source: shadowSource
        shadowEnabled: root.shadowEnabled
        shadowColor: "black"
        shadowOpacity: 0.62
        shadowBlur: 0.85
        blurMax: root.shadowBlurMax
        shadowHorizontalOffset: root.shadowOffsetX
        shadowVerticalOffset: root.shadowOffsetY
        z: -1
      }

      BarFlyoutSurface {
        bar: root.bar
        id: surface
        x: root.shadowLeftMargin
        y: root.shadowTopMargin
        panelWidth: root.panelWidth
        panelHeight: root.panelHeight
        joinRadius: root.joinRadius
        cornerRadius: root.cornerRadius
        panelColor: root.background
        attachmentEdge: root.attachmentEdge
      }

      Column {
        id: weatherContent
        x: surface.x + surface.panelLeft + root.contentPadding
        y: surface.y + surface.panelTop + root.contentPadding
        width: root.innerWidth
        spacing: root.contentSpacing
        opacity: root.contentOpacity

        Item {
          width: parent.width
          height: root.headerHeight

          InstrumentText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - statusText.width - tokens.spaceNormal
            text: "WEATHER / CONDITIONS"
            color: root.foreground
            font.family: root.displayFontFamily
            font.pixelSize: tokens.textTitle
            font.bold: true
            font.letterSpacing: root.displayTitleTracking
          }

          InstrumentText {
            id: statusText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "● " + root.statusLabel
            color: root.statusColor
            font.pixelSize: tokens.textSmall
          }
        }

        Item {
          width: parent.width
          height: root.heroHeight

          Item {
            anchors.fill: parent
            visible: root.hasData

            InstrumentText {
              id: heroIcon
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.topMargin: 22
              text: root.current.icon || "󰖐"
              color: root.accentColor
              font.pixelSize: 46
            }

            InstrumentText {
              id: heroTemperature
              anchors.left: heroIcon.right
              anchors.leftMargin: tokens.spaceLarge
              anchors.top: parent.top
              anchors.topMargin: 4
              text: root.current.temperature || "—"
              color: root.foreground
              font.family: root.displayFontFamily
              font.pixelSize: tokens.textTelemetry
              font.weight: root.displayHeroWeight
              font.letterSpacing: root.displayTitleTracking
            }

            InstrumentText {
              anchors.left: heroTemperature.left
              anchors.top: heroTemperature.bottom
              anchors.topMargin: -4
              width: 172
              text: root.current.description || "Current conditions"
              color: root.soft
              font.pixelSize: tokens.textPrimary
              elide: Text.ElideRight
            }

            Column {
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.topMargin: 10
              width: 168
              spacing: tokens.spaceLarge

              InstrumentText {
                width: parent.width
                text: String(root.current.location || "CURRENT LOCATION").toUpperCase()
                color: root.accentColor
                font.family: root.displayFontFamily
                font.pixelSize: tokens.textPrimary
                font.bold: true
                font.letterSpacing: tokens.trackingTitleCompact
                elide: Text.ElideRight
              }

              StatRow { label: "FEELS"; value: root.current.feelsLike || "—" }
              StatRow { label: "WIND"; value: root.current.wind || "—" }
              StatRow { label: "HUMID"; value: root.current.humidity || "—" }
            }
          }

          Column {
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: tokens.spaceLarge
            visible: !root.hasData

            InstrumentText {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: root.weatherState && root.weatherState.loading ? "FETCHING FORECAST…" : "FORECAST UNAVAILABLE"
              color: root.foreground
              font.family: root.displayFontFamily
              font.pixelSize: tokens.textTitle
              font.bold: true
              font.letterSpacing: root.displayTitleTracking
            }

            InstrumentText {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: root.weatherState && root.weatherState.errorText !== "" ? root.weatherState.errorText : "Waiting for current conditions"
              color: root.whisper
              font.pixelSize: tokens.textNormal
            }

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              visible: !(root.weatherState && root.weatherState.loading)
              width: retryLabel.implicitWidth + 24
              height: 30
              color: retryMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.14) : "transparent"
              border.width: 1
              border.color: root.accentColor

              InstrumentText {
                id: retryLabel
                anchors.centerIn: parent
                text: "RETRY"
                color: root.accentColor
                font.pixelSize: tokens.textSmall
              }

              MouseArea { id: retryMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.retry() }
            }
          }
        }

        Rectangle {
          visible: root.hasData
          width: parent.width
          height: root.dividerHeight
          color: root.seam
        }

        InstrumentText {
          visible: root.hasData
          width: parent.width
          height: root.forecastLabelHeight
          text: "FORECAST / 3 DAYS"
          color: root.whisper
          font.pixelSize: tokens.textSmall
        }

        Item {
          visible: root.hasData
          width: parent.width
          height: root.forecastHeight

          Row {
            anchors.fill: parent

            Repeater {
              model: root.forecastDays.length > 0 ? root.forecastDays : 3

              Item {
                id: forecastCell
                required property int index
                property var day: root.forecastDays.length > index ? root.forecastDays[index] : null
                width: root.innerWidth / 3
                height: parent ? parent.height : 0

                Rectangle {
                  visible: forecastCell.index > 0
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: 1
                  color: root.seam
                }

                InstrumentText {
                  anchors.top: parent.top
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: forecastCell.day && root.weatherState ? root.weatherState.forecastDayName(forecastCell.day).toUpperCase() : "—"
                  color: root.foreground
                  font.family: root.displayFontFamily
                  font.pixelSize: tokens.textPrimary
                  font.bold: true
                  font.letterSpacing: tokens.trackingTitleCompact
                }

                InstrumentText {
                  anchors.centerIn: parent
                  anchors.verticalCenterOffset: -2
                  text: forecastCell.day && forecastCell.day.icon ? forecastCell.day.icon : "󰖐"
                  color: forecastCell.day ? root.accentColor : root.whisper
                  font.pixelSize: 28
                }

                Row {
                  anchors.bottom: parent.bottom
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: tokens.spaceNormal

                  InstrumentText {
                    text: forecastCell.day && root.weatherState ? root.weatherState.forecastTemperature(forecastCell.day, "max") : "—"
                    color: root.foreground
                    font.pixelSize: tokens.textPrimary
                  }
                  InstrumentText {
                    text: forecastCell.day && root.weatherState ? root.weatherState.forecastTemperature(forecastCell.day, "min") : "—"
                    color: root.whisper
                    font.pixelSize: tokens.textPrimary
                  }
                }
              }
            }
          }
        }

        Item {
          visible: root.hasData
          width: parent.width
          height: root.footerHeight

          InstrumentText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.lastUpdatedText
            color: root.whisper
            font.pixelSize: tokens.textHint
          }

          InstrumentText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.62
            horizontalAlignment: Text.AlignRight
            text: root.weatherState ? root.weatherState.errorText : ""
            color: root.statusLabel === "STALE" ? root.urgentColor : root.whisper
            font.pixelSize: tokens.textHint
            elide: Text.ElideRight
          }
        }
      }
    }
  }

  component InstrumentText: Text {
    font.family: tokens.monoFont
    font.letterSpacing: tokens.trackingBody
    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    maximumLineCount: 1
    elide: Text.ElideRight
  }

  component StatRow: Item {
    required property string label
    required property string value
    width: parent ? parent.width : 0
    height: 14

    InstrumentText {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: parent.label
      color: root.whisper
      font.pixelSize: tokens.textSmall
    }

    InstrumentText {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: parent.value
      color: root.foreground
      font.pixelSize: tokens.textNormal
    }
  }
}
