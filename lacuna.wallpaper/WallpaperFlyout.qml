import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

PopupWindow {
  id: root

  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  property bool open: false
  property bool reduceMotion: false
  property string backgroundPath: ""
  property string wallpaperTitle: ""
  property color accentColor: "#89b4fa"
  property int panelWidth: 400
  property int panelHeight: 330
  property int joinRadius: bar && bar.resolvedCornerRadius !== undefined ? Math.max(0, Math.round(Number(bar.resolvedCornerRadius) || 0)) : 14
  property int cornerRadius: joinRadius
  property int margin: 8

  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  readonly property string attachmentEdge: bar && /^(top|bottom|left|right)$/.test(bar.position) ? bar.position : "top"
  readonly property string fontFamily: tokens.monoFont
  readonly property color foreground: bar ? bar.foreground : "#d8dee9"
  readonly property color background: opaque(bar ? bar.background : "#101315")
  readonly property color whisper: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.48)
  readonly property color soft: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.78)
  readonly property color seam: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  readonly property string fileName: backgroundPath ? backgroundPath.split("/").pop() : "No active file"
  property bool shadowEnabled: false
  property int shadowOffsetX: 2
  property int shadowOffsetY: 3
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
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string lacunaSettingsPath: configHome + "/omarchy/lacuna/settings.json"
  property real reveal: open ? 1 : 0

  LacunaTokens { id: tokens }
  MotionTokens {
    id: motionTokens
    animationDisabled: root.reduceMotion
  }

  function opaque(value) {
    var c = typeof value === "string" ? Qt.color(value) : value
    return Qt.rgba(c.r, c.g, c.b, 1)
  }

  function close() {
    if (owner && typeof owner.close === "function") owner.close()
    else open = false
  }

  function localFileUrl(path) {
    var value = String(path || "")
    if (value === "") return ""
    return "file://" + encodeURIComponent(value).replace(/%2F/gi, "/")
  }

  function loadFrameSettings(raw) {
    try {
      var frame = JSON.parse(String(raw || "{}")).frame || {}
      shadowEnabled = frame.shadow === true
      var ox = Number(frame.shadowOffsetX)
      var oy = Number(frame.shadowOffsetY)
      shadowOffsetX = isFinite(ox) ? ox : 2
      shadowOffsetY = isFinite(oy) ? oy : 3
    } catch (e) {
      shadowEnabled = false
    }
  }

  FileView {
    path: root.lacunaSettingsPath
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
        x: surface.x + surface.panelLeft + tokens.spaceXLarge
        y: surface.y + surface.panelTop + tokens.spaceXLarge
        width: root.panelWidth - tokens.spaceXLarge * 2
        spacing: tokens.spaceLarge
        opacity: Math.max(0, Math.min(1, (root.reveal - 0.55) / 0.45))

        Row {
          width: parent.width
          Text { text: "ACTIVE WALLPAPER"; color: root.whisper; font.family: tokens.monoFont; font.pixelSize: tokens.textSmall; renderType: Text.NativeRendering }
        }

        Rectangle {
          width: parent.width
          height: 202
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
          clip: true
          Image {
            anchors.fill: parent
            source: root.localFileUrl(root.backgroundPath)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
          }
        }

        Item {
          width: parent.width
          height: 1
          Rectangle { width: parent.width / 2 - 11; height: 1; color: root.seam }
          Rectangle { x: parent.width / 2 + 11; width: parent.width / 2 - 11; height: 1; color: root.seam }
        }

        Text {
          width: parent.width
          text: root.wallpaperTitle || "No Wallpaper"
          color: root.foreground
          font.family: tokens.displayFont
          font.pixelSize: tokens.textTitle
          font.bold: true
          font.letterSpacing: tokens.trackingTitle
          renderType: Text.NativeRendering
          textFormat: Text.PlainText
          elide: Text.ElideRight
          maximumLineCount: 1
        }

        Text {
          width: parent.width
          text: root.fileName
          color: root.whisper
          font.family: tokens.monoFont
          font.pixelSize: tokens.textSmall
          renderType: Text.NativeRendering
          textFormat: Text.PlainText
          elide: Text.ElideMiddle
          maximumLineCount: 1
        }
      }
    }
  }
}
