import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

PopupWindow {
  id: root
  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  property bool open: false
  property bool reduceMotion: false
  property var snapshot: ({})
  property var history: []
  property int temperatureF: 0
  property int warmF: 150
  property int criticalF: 185
  property color accentColor: "#d8dee9"
  property color normalColor: bar && bar.accent ? bar.accent : "#d8dee9"
  property color warningColor: "#ebcb8b"
  property color urgentColor: bar ? bar.urgent : "#d42b5b"
  property int panelWidth: 520
  property int panelHeight: 620
  property int joinRadius: bar && bar.resolvedCornerRadius !== undefined ? Math.max(0, Math.round(Number(bar.resolvedCornerRadius) || 0)) : 14
  property int cornerRadius: joinRadius
  property int margin: 8
  property bool shadowEnabled: false
  property int shadowOffsetX: 2
  property int shadowOffsetY: 3
  property real reveal: open ? 1 : 0

  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  readonly property string attachmentEdge: bar && /^(top|bottom|left|right)$/.test(bar.position) ? bar.position : "top"
  readonly property var primary: snapshot.primary || ({})
  readonly property var hottest: snapshot.hottest || ({})
  readonly property var sensors: snapshot.sensors || []
  readonly property string state: temperatureF >= criticalF ? "CRITICAL" : temperatureF >= warmF ? "WARM" : "NOMINAL"
  readonly property color background: opaque(bar ? bar.background : "#101315")
  readonly property color foreground: bar ? bar.foreground : "#d8dee9"
  readonly property color whisper: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.48)
  readonly property color soft: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.78)
  readonly property color seam: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  readonly property color stateColor: temperatureF >= criticalF ? urgentColor : temperatureF >= warmF ? warningColor : normalColor
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property int shadowBlurMax: 28
  readonly property int shadowMargin: shadowEnabled
    ? Math.ceil(shadowBlurMax + Math.max(Math.abs(shadowOffsetX), Math.abs(shadowOffsetY)))
    : 0
  readonly property int shadowFarLeftMargin: shadowEnabled
    ? Math.ceil(shadowMargin + shadowBlurMax * 0.6 + Math.max(0, -shadowOffsetX)) : 0
  readonly property int shadowFarRightMargin: shadowEnabled
    ? Math.ceil(shadowMargin + shadowBlurMax * 0.6 + Math.max(0, shadowOffsetX)) : 0
  readonly property int shadowFarTopMargin: shadowEnabled
    ? Math.ceil(shadowMargin + shadowBlurMax * 0.6 + Math.max(0, -shadowOffsetY)) : 0
  readonly property int shadowFarBottomMargin: shadowEnabled
    ? Math.ceil(shadowMargin + shadowBlurMax * 0.6 + Math.max(0, shadowOffsetY)) : 0
  readonly property int shadowLeftMargin: attachmentEdge === "left" ? 0 : (attachmentEdge === "right" ? shadowFarLeftMargin : shadowMargin)
  readonly property int shadowRightMargin: attachmentEdge === "right" ? 0 : (attachmentEdge === "left" ? shadowFarRightMargin : shadowMargin)
  readonly property int shadowTopMargin: attachmentEdge === "top" ? 0 : (attachmentEdge === "bottom" ? shadowFarTopMargin : shadowMargin)
  readonly property int shadowBottomMargin: attachmentEdge === "bottom" ? 0 : (attachmentEdge === "top" ? shadowFarBottomMargin : shadowMargin)
  function opaque(value) { var c = typeof value === "string" ? Qt.color(value) : value; return Qt.rgba(c.r, c.g, c.b, 1) }
  function close() { if (owner && typeof owner.close === "function") owner.close(); else open = false }
  function loadFrameSettings(raw) {
    try {
      var frame = JSON.parse(String(raw || "{}")).frame || {}
      shadowEnabled = frame.shadow === true
      shadowOffsetX = isFinite(Number(frame.shadowOffsetX)) ? Number(frame.shadowOffsetX) : 2
      shadowOffsetY = isFinite(Number(frame.shadowOffsetY)) ? Number(frame.shadowOffsetY) : 3
    } catch (error) { shadowEnabled = false }
  }

  LacunaTokens { id: tokens }
  MotionTokens {
    id: motionTokens
    animationDisabled: root.reduceMotion
  }

  FileView {
    path: root.configHome + "/omarchy/lacuna/settings.json"; watchChanges: true; printErrors: false
    onLoaded: root.loadFrameSettings(text()); onFileChanged: reload(); onLoadFailed: root.loadFrameSettings("")
  }

  Behavior on reveal { NumberAnimation { duration: motionTokens.reveal; easing.type: Easing.OutCubic } }
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
    if (open) bar.requestPopout(root)
    else if (bar.activePopout === root) bar.releasePopout(root)
  }
  HyprlandFocusGrab { active: root.open; windows: root.anchorWindow ? [root, root.anchorWindow] : [root]; onCleared: root.close() }
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
      width: root.implicitWidth; height: root.implicitHeight
      Item { id: shadowSource; anchors.fill: parent; visible: root.shadowEnabled; BarFlyoutSurface { bar: root.bar; x: root.shadowLeftMargin
          y: root.shadowTopMargin; panelWidth: root.panelWidth; panelHeight: root.panelHeight; joinRadius: root.joinRadius; cornerRadius: root.cornerRadius; panelColor: root.background; attachmentEdge: root.attachmentEdge } }
      LacunaDropShadow { source: shadowSource; shadowEnabled: root.shadowEnabled; shadowColor: "black"; shadowOpacity: 0.62; shadowBlur: 0.85; blurMax: root.shadowBlurMax; shadowHorizontalOffset: root.shadowOffsetX; shadowVerticalOffset: root.shadowOffsetY }
      BarFlyoutSurface { bar: root.bar; id: surface; x: root.shadowLeftMargin
        y: root.shadowTopMargin; panelWidth: root.panelWidth; panelHeight: root.panelHeight; joinRadius: root.joinRadius; cornerRadius: root.cornerRadius; panelColor: root.background; attachmentEdge: root.attachmentEdge }

      Column {
        x: surface.x + surface.panelLeft + tokens.spaceXLarge
        y: surface.y + surface.panelTop + tokens.spaceXLarge
        width: root.panelWidth - tokens.spaceXLarge * 2
        spacing: tokens.spaceNormal
        opacity: Math.max(0, Math.min(1, (root.reveal - 0.55) / 0.45))

        Row {
          width: parent.width
          InstrumentText { width: parent.width - thermalLive.width; text: "THERMAL / SENSOR ARRAY"; color: root.foreground; font.family: tokens.displayFont; font.pixelSize: tokens.textTitle; font.bold: true; font.letterSpacing: tokens.trackingTitle; renderType: Text.NativeRendering }
          InstrumentText { id: thermalLive; text: "● LIVE"; color: root.stateColor; font.family: tokens.monoFont; font.pixelSize: tokens.textSmall }
        }

        Item {
          width: parent.width; height: 238
          InstrumentText { id: thermalValue; anchors.left: parent.left; anchors.top: parent.top; text: root.temperatureF + "°"; color: root.stateColor; font.family: tokens.displayFont; font.pixelSize: tokens.textTelemetry; font.weight: Font.Normal; font.letterSpacing: tokens.trackingTitle }
          Column {
            anchors.left: thermalValue.right; anchors.leftMargin: tokens.spaceNormal; anchors.verticalCenter: thermalValue.verticalCenter
            InstrumentText { text: root.state; color: root.stateColor; font.family: tokens.monoFont; font.pixelSize: tokens.textSmall }
            InstrumentText { text: (root.primary.device || "NO CPU SENSOR") + " / " + (root.primary.label || "—"); color: root.whisper; font.family: tokens.monoFont; font.pixelSize: tokens.textHint }
          }
          Canvas {
            id: thermalTrace
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 176
            opacity: root.reveal >= 0.7 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: motionTokens.quick; easing.type: Easing.OutCubic } }
            onPaint: {
              var ctx = getContext("2d"); ctx.reset(); var maxValue = Math.max(200, root.criticalF + 10)
              ctx.strokeStyle = root.seam; ctx.lineWidth = 1
              for (var column = 1; column < 10; column++) { var gx = column * width / 10; ctx.globalAlpha = column % 5 === 0 ? 0.8 : 0.35; ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, height); ctx.stroke() }
              ctx.globalAlpha = 1
              function yFor(value) { return height - 4 - Number(value || 0) * (height - 8) / maxValue }
              ctx.lineWidth = 1; ctx.strokeStyle = root.seam
              var warmY = yFor(root.warmF); var criticalY = yFor(root.criticalF)
              ctx.beginPath(); ctx.moveTo(0, warmY); ctx.lineTo(width / 2 - 11, warmY); ctx.moveTo(width / 2 + 11, warmY); ctx.lineTo(width, warmY); ctx.stroke()
              ctx.strokeStyle = Qt.rgba(root.urgentColor.r, root.urgentColor.g, root.urgentColor.b, 0.5)
              ctx.beginPath(); ctx.moveTo(0, criticalY); ctx.lineTo(width / 2 - 11, criticalY); ctx.moveTo(width / 2 + 11, criticalY); ctx.lineTo(width, criticalY); ctx.stroke()
              if (!root.history || root.history.length < 2) return
              ctx.strokeStyle = root.stateColor; ctx.lineWidth = 2; ctx.beginPath()
              for (var i = 0; i < root.history.length; i++) { var x = i * width / Math.max(1, root.history.length - 1); var y = yFor(root.history[i]); if (i === 0 || i % 15 === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y) }
              ctx.stroke()
            }
            Connections { target: root; function onHistoryChanged() { thermalTrace.requestPaint() } }
            onWidthChanged: requestPaint(); onHeightChanged: requestPaint()
          }
        }

        Row {
          width: parent.width
          InstrumentText { width: parent.width / 2; text: "WARM  " + root.warmF + "°F"; color: root.whisper; font.family: tokens.monoFont; font.pixelSize: tokens.textSmall }
          InstrumentText { width: parent.width / 2; horizontalAlignment: Text.AlignRight; text: "CRITICAL  " + root.criticalF + "°F"; color: root.whisper; font.family: tokens.monoFont; font.pixelSize: tokens.textSmall }
        }
        Item { width: parent.width; height: 1; Rectangle { width: parent.width / 2 - 11; height: 1; color: root.seam } Rectangle { x: parent.width / 2 + 11; width: parent.width / 2 - 11; height: 1; color: root.seam } }
        InstrumentText { text: "SENSOR FIELD / " + root.sensors.length + " CHANNELS"; color: root.whisper; font.family: tokens.monoFont; font.pixelSize: tokens.textSmall }

        Flickable {
          width: parent.width; height: 250; contentWidth: width; contentHeight: sensorColumn.implicitHeight; clip: true
          boundsBehavior: Flickable.StopAtBounds; interactive: contentHeight > height
          Column {
            id: sensorColumn; width: parent.width; spacing: 0
            Repeater {
              model: root.sensors
              Item {
                required property var modelData
                width: sensorColumn.width; height: 38
                readonly property bool hottest: modelData.id === root.hottest.id
                Rectangle { x: 7; y: 0; width: 1; height: parent.height; color: root.seam }
                Rectangle { x: 4; anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; color: parent.hottest ? root.stateColor : root.background; border.width: 1; border.color: parent.hottest ? root.stateColor : root.seam }
                InstrumentText { anchors.left: parent.left; anchors.leftMargin: 22; anchors.top: parent.top; text: modelData.group + " / " + modelData.label; color: parent.hottest ? root.foreground : root.soft; font.family: tokens.monoFont; font.pixelSize: tokens.textNormal }
                InstrumentText { anchors.left: parent.left; anchors.leftMargin: 22; anchors.bottom: parent.bottom; text: modelData.device; color: root.whisper; font.family: tokens.monoFont; font.pixelSize: tokens.textHint }
                InstrumentText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.fahrenheit + "°F  " + Number(modelData.celsius).toFixed(1) + "°C"; color: parent.hottest ? root.stateColor : root.foreground; font.family: tokens.monoFont; font.pixelSize: tokens.textPrimary }
                Rectangle { anchors.left: parent.left; anchors.leftMargin: 150; anchors.right: parent.right; anchors.rightMargin: 108; anchors.bottom: parent.bottom; height: 2; color: root.seam }
                Rectangle { anchors.left: parent.left; anchors.leftMargin: 150; anchors.bottom: parent.bottom; height: 2; width: Math.max(0, (parent.width - 258) * Math.min(120, Number(modelData.celsius)) / 120); color: parent.hottest ? root.stateColor : root.normalColor }
              }
            }
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
}
