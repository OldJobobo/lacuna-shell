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
  property string mode: "cpu"
  property int cpuPercent: 0
  property int memoryPercent: 0
  property int diskPercent: 0
  property var cpuHistory: []
  property var memoryHistory: []
  property var diskHistory: []
  property var snapshot: ({})
  property color cpuAccent: "#d8dee9"
  property color memoryAccent: "#d8dee9"
  property color diskAccent: "#d8dee9"
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
  readonly property color background: opaque(bar ? bar.background : "#101315")
  readonly property color foreground: bar ? bar.foreground : "#d8dee9"
  readonly property color whisper: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.48)
  readonly property color soft: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.78)
  readonly property color seam: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  readonly property color accent: mode === "memory" ? memoryAccent : mode === "disk" ? diskAccent : cpuAccent
  readonly property int value: mode === "memory" ? memoryPercent : mode === "disk" ? diskPercent : cpuPercent
  readonly property var history: mode === "memory" ? memoryHistory : mode === "disk" ? diskHistory : cpuHistory
  readonly property string title: mode === "memory" ? "SYSTEM / MEMORY" : mode === "disk" ? "SYSTEM / STORAGE" : "SYSTEM / PROCESSOR"
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
  function opaque(value) {
    var c = typeof value === "string" ? Qt.color(value) : value
    return Qt.rgba(c.r, c.g, c.b, 1)
  }
  function close() {
    if (owner && typeof owner.close === "function") owner.close()
    else open = false
  }
  function bytes(value) {
    var n = Number(value || 0)
    if (n <= 0) return "—"
    var units = ["B", "KB", "MB", "GB", "TB"]
    var index = Math.min(units.length - 1, Math.floor(Math.log(n) / Math.log(1024)))
    return (n / Math.pow(1024, index)).toFixed(index >= 3 ? 1 : 0) + " " + units[index]
  }
  function uptime(seconds) {
    var total = Number(seconds || 0)
    var days = Math.floor(total / 86400)
    var hours = Math.floor(total % 86400 / 3600)
    return days > 0 ? days + "D " + hours + "H" : hours + "H " + Math.floor(total % 3600 / 60) + "M"
  }
  function detailTiles() {
    var cpu = snapshot.cpu || {}
    var memory = snapshot.memory || {}
    var disk = snapshot.rootFilesystem || {}
    if (mode === "memory") return [
      { label: "USED", value: bytes(memory.used) }, { label: "AVAILABLE", value: bytes(memory.available) },
      { label: "CACHE", value: bytes(memory.cached) }, { label: "SWAP", value: bytes(memory.swapUsed) + " / " + bytes(memory.swapTotal) }
    ]
    if (mode === "disk") return [
      { label: "USED", value: bytes(disk.used) }, { label: "FREE", value: bytes(disk.available) },
      { label: "CAPACITY", value: bytes(disk.total) }, { label: "DEVICE", value: disk.device || "—" }
    ]
    var load = cpu.load || []
    return [
      { label: "LOAD 1 / 5 / 15", value: load.length ? load.join("  ") : "—" }, { label: "LOGICAL CORES", value: String(cpu.cores || "—") },
      { label: "MEAN CLOCK", value: cpu.frequencyMhz ? (cpu.frequencyMhz / 1000).toFixed(2) + " GHZ" : "—" }, { label: "UPTIME", value: uptime(cpu.uptimeSeconds) }
    ]
  }
  function rows() {
    if (mode === "memory") return snapshot.topMemory || []
    if (mode === "disk") return snapshot.filesystems || []
    return snapshot.topCpu || []
  }
  function rowTitle(row) { return mode === "disk" ? (row.mount || "—") : (row.name || "—") }
  function rowMeta(row) {
    if (mode === "disk") return (row.device || "—") + "  /  " + bytes(row.used) + " OF " + bytes(row.total)
    return "PID " + row.pid + "  /  " + row.user + "  /  " + row.elapsed
  }
  function rowValue(row) { return mode === "memory" ? Number(row.memory || 0).toFixed(1) + "%" : mode === "disk" ? row.percent + "%" : Number(row.cpu || 0).toFixed(1) + "%" }
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
    path: root.configHome + "/omarchy/lacuna/settings.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadFrameSettings(text())
    onFileChanged: reload()
    onLoadFailed: root.loadFrameSettings("")
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
      width: root.implicitWidth; height: root.implicitHeight
      Item {
        id: shadowSource
        anchors.fill: parent
        visible: root.shadowEnabled
        BarFlyoutSurface { bar: root.bar; x: root.shadowLeftMargin
          y: root.shadowTopMargin; panelWidth: root.panelWidth; panelHeight: root.panelHeight; joinRadius: root.joinRadius; cornerRadius: root.cornerRadius; panelColor: root.background; attachmentEdge: root.attachmentEdge }
      }
      LacunaDropShadow {
        source: shadowSource; shadowEnabled: root.shadowEnabled; shadowColor: "black"; shadowOpacity: 0.62
        shadowBlur: 0.85; blurMax: root.shadowBlurMax; shadowHorizontalOffset: root.shadowOffsetX; shadowVerticalOffset: root.shadowOffsetY
      }
      BarFlyoutSurface {
        bar: root.bar
        id: surface
        x: root.shadowLeftMargin
        y: root.shadowTopMargin
        panelWidth: root.panelWidth; panelHeight: root.panelHeight; joinRadius: root.joinRadius; cornerRadius: root.cornerRadius; panelColor: root.background
        attachmentEdge: root.attachmentEdge
      }

      Column {
        x: surface.x + surface.panelLeft + tokens.spaceXLarge
        y: surface.y + surface.panelTop + tokens.spaceXLarge
        width: root.panelWidth - tokens.spaceXLarge * 2
        spacing: tokens.spaceNormal
        opacity: Math.max(0, Math.min(1, (root.reveal - 0.55) / 0.45))

        Row {
          width: parent.width
          InstrumentText {
            width: parent.width - liveLabel.width
            text: root.title
            color: root.foreground
            font.family: tokens.displayFont; font.pixelSize: tokens.textTitle; font.bold: true
            font.letterSpacing: tokens.trackingTitle
            renderType: Text.NativeRendering
          }
          InstrumentText { id: liveLabel; text: "● LIVE"; color: root.accent; font.family: tokens.monoFont; font.pixelSize: tokens.textSmall }
        }

        Item {
          width: parent.width; height: 238
          InstrumentText {
            id: heroValue
            anchors.left: parent.left; anchors.top: parent.top
            text: String(root.value).padStart(2, "0")
            color: root.value >= 90 ? root.urgentColor : root.foreground
            font.family: tokens.displayFont; font.pixelSize: tokens.textTelemetry; font.weight: Font.Normal
            font.letterSpacing: tokens.trackingTitle
          }
          InstrumentText {
            anchors.left: heroValue.right; anchors.leftMargin: tokens.spaceNormal; anchors.baseline: heroValue.baseline
            text: "%  /  300 SEC BUFFER"
            color: root.whisper; font.family: tokens.monoFont; font.pixelSize: tokens.textSmall
          }
          Canvas {
            id: trace
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: 176
            opacity: root.reveal >= 0.7 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: motionTokens.quick; easing.type: Easing.OutCubic } }
            onPaint: {
              var ctx = getContext("2d"); ctx.reset(); var values = root.history
              ctx.strokeStyle = root.seam; ctx.lineWidth = 1
              for (var grid = 1; grid < 5; grid++) { var gy = grid * height / 5; ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width / 2 - 11, gy); ctx.moveTo(width / 2 + 11, gy); ctx.lineTo(width, gy); ctx.stroke() }
              for (var column = 1; column < 10; column++) { var gx = column * width / 10; ctx.globalAlpha = column % 5 === 0 ? 0.8 : 0.35; ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, height); ctx.stroke() }
              ctx.globalAlpha = 1
              if (!values || values.length < 2) return
              for (var echo = 3; echo >= 0; echo--) {
                ctx.globalAlpha = echo === 0 ? 1 : 0.08 + (3 - echo) * 0.04; ctx.strokeStyle = root.accent; ctx.lineWidth = echo === 0 ? 2 : 1; ctx.beginPath()
                for (var i = 0; i < values.length; i++) { var x = i * width / Math.max(1, values.length - 1); var y = height - 5 - Math.max(0, Math.min(100, Number(values[i]) - echo * 5)) * (height - 10) / 100; if (i === 0 || i % 15 === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y) }
                ctx.stroke()
              }
              ctx.globalAlpha = 1; ctx.fillStyle = root.accent; ctx.fillRect(width - 2, 0, 2, height)
            }
            Connections { target: root; function onHistoryChanged() { trace.requestPaint() } }
            onWidthChanged: requestPaint(); onHeightChanged: requestPaint()
          }

          Row {
            id: allocationField
            visible: root.mode === "memory"
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: 8; spacing: 2
            readonly property var memory: root.snapshot.memory || ({})
            readonly property real total: Math.max(1, Number(memory.total || 0))
            readonly property real cacheRatio: Math.max(0, Math.min(1, Number(memory.cached || 0) / total))
            readonly property real availableRatio: Math.max(0, Math.min(1, Number(memory.available || 0) / total))
            readonly property real activeRatio: Math.max(0, 1 - cacheRatio - availableRatio)
            Rectangle { width: Math.max(0, (allocationField.width - 4) * allocationField.activeRatio); height: parent.height; color: root.accent }
            Rectangle { width: Math.max(0, (allocationField.width - 4) * allocationField.cacheRatio); height: parent.height; color: root.soft }
            Rectangle { width: Math.max(0, (allocationField.width - 4) * allocationField.availableRatio); height: parent.height; color: root.seam }
          }
        }

        Item { width: parent.width; height: 1; Rectangle { width: parent.width / 2 - 11; height: 1; color: root.seam } Rectangle { x: parent.width / 2 + 11; width: parent.width / 2 - 11; height: 1; color: root.seam } }

        Grid {
          width: parent.width; columns: 4; columnSpacing: tokens.spaceLarge; rowSpacing: tokens.spaceNormal
          Repeater {
            model: root.detailTiles()
            Item {
              required property var modelData
              width: (parent.width - tokens.spaceLarge * 3) / 4; height: 42
              InstrumentText { text: modelData.label; color: root.whisper; font.family: tokens.monoFont; font.pixelSize: tokens.textHint }
              InstrumentText { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; text: modelData.value; color: root.soft; font.family: tokens.monoFont; font.pixelSize: tokens.textNormal; elide: Text.ElideRight }
            }
          }
        }

        InstrumentText { text: root.mode === "disk" ? "CHANNEL BANK / PHYSICAL FILESYSTEMS" : "PROCESS BANK / READ ONLY"; color: root.whisper; font.family: tokens.monoFont; font.pixelSize: tokens.textSmall }
        Repeater {
          model: root.rows()
          Item {
            required property var modelData
            width: parent.width; height: 34
            Rectangle {
              visible: root.mode === "disk"
              anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.bottomMargin: 1
              width: Math.max(0, (parent.width / 2 - 11) * Math.min(100, Number(modelData.percent || 0)) / 100)
              height: 2; color: root.accent
            }
            Rectangle {
              visible: root.mode === "disk"
              anchors.left: parent.horizontalCenter; anchors.leftMargin: 11; anchors.bottom: parent.bottom; anchors.bottomMargin: 1
              width: Math.max(0, (parent.width / 2 - 11) * Math.min(100, Number(modelData.percent || 0)) / 100)
              height: 2; color: root.accent
            }
            Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: parent.width / 2 - 11; height: 1; color: root.seam }
            Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: parent.width / 2 - 11; height: 1; color: root.seam }
            InstrumentText { anchors.left: parent.left; anchors.top: parent.top; width: parent.width - 56; text: root.rowTitle(modelData); color: root.foreground; font.family: tokens.monoFont; font.pixelSize: tokens.textNormal; elide: Text.ElideRight }
            InstrumentText { anchors.left: parent.left; anchors.bottom: parent.bottom; text: root.rowMeta(modelData); color: root.whisper; font.family: tokens.monoFont; font.pixelSize: tokens.textHint }
            InstrumentText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.rowValue(modelData); color: root.accent; font.family: tokens.monoFont; font.pixelSize: tokens.textPrimary }
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
