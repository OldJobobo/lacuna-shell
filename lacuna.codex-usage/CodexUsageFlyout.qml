import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

PopupWindow {
  id: root

  required property Item anchorItem
  required property QtObject bar
  property var owner: null

  property bool open: false
  property bool reduceMotion: false
  property int panelWidth: 292
  property int joinRadius: bar && bar.resolvedCornerRadius !== undefined ? Math.max(0, Math.round(Number(bar.resolvedCornerRadius) || 0)) : 14
  property int cornerRadius: joinRadius
  property int margin: 8

  property int leftPercent: 100
  property int usedPercent: 0
  property bool activeBlock: false
  property bool sessionAvailable: false
  property string resetText: ""
  property string planText: ""
  property string sourceText: ""
  property string sourceEventText: ""
  property string sourceFileText: ""
  property bool weekActive: false
  property int weekLeftPercent: 100
  property int weekUsedPercent: 0
  property string weekResetText: ""

  property color accentColor: "#d8dee9"
  property color weekAccentColor: accentColor
  property color foreground: "#d8dee9"
  property color mutedColor: "#8a929c"
  property color trackColor: "#2a2f35"
  property color panelColor: "#0e1113"
  property string fontFamily: "Hack Nerd Font Propo"
  property url iconSource: ""

  signal refreshRequested()

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
  readonly property var coordinatorKey: owner || root
  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  readonly property string attachmentEdge: bar && /^(top|bottom|left|right)$/.test(bar.position) ? bar.position : "top"
  readonly property int contentPadding: 14
  readonly property int innerWidth: panelWidth - contentPadding * 2
  readonly property string planLabel: planText.length > 0 ? planText : "Unknown"
  readonly property string resetLabel: resetText.length > 0 ? resetText : "unknown"
  readonly property string weekResetLabel: weekResetText.length > 0 ? weekResetText : "unknown"
  readonly property string sourceLabel: sourceText.length > 0 ? sourceText : "local Codex token_count event"

  function loadFrameSettings(raw) {
    try {
      var data = JSON.parse(String(raw || "{}"))
      var frame = data.frame || {}
      shadowEnabled = frame.shadow === true
      var ox = Number(frame.shadowOffsetX)
      shadowOffsetX = isFinite(ox) ? ox : 2
      var oy = Number(frame.shadowOffsetY)
      shadowOffsetY = isFinite(oy) ? oy : 3
    } catch (e) {
      shadowEnabled = false
    }
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
  implicitWidth: surface.fullWidth + shadowLeftMargin + shadowRightMargin
  implicitHeight: surface.fullHeight + shadowTopMargin + shadowBottomMargin

  onOpenChanged: {
    if (!bar) return
    if (open) {
      bar.requestPopout(coordinatorKey)
      root.refreshRequested()
    } else if (bar.activePopout === coordinatorKey) {
      bar.releasePopout(coordinatorKey)
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
        x: 0
        y: 0
        width: root.implicitWidth
        height: root.implicitHeight
        visible: root.shadowEnabled
        z: -2

        BarFlyoutSurface {
          bar: root.bar
          x: root.shadowLeftMargin
          y: root.shadowTopMargin
          panelWidth: root.panelWidth
          panelHeight: Math.round(content.implicitHeight + root.contentPadding * 2)
          joinRadius: root.joinRadius
          cornerRadius: root.cornerRadius
          panelColor: root.panelColor
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
        panelHeight: Math.round(content.implicitHeight + root.contentPadding * 2)
        joinRadius: root.joinRadius
        cornerRadius: root.cornerRadius
        panelColor: root.panelColor
        attachmentEdge: root.attachmentEdge
      }

      Column {
        id: content
        x: surface.x + surface.panelLeft + root.contentPadding
        y: surface.y + surface.panelTop + root.contentPadding
        width: root.innerWidth
        spacing: 12
        opacity: root.contentOpacity

        Item {
          width: parent.width
          height: 22

          Image {
            id: headerIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: String(root.iconSource) !== ""
            source: root.iconSource
            width: 16
            height: 16
            sourceSize.width: 16
            sourceSize.height: 16
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
          }

          Text {
            anchors.left: headerIcon.visible ? headerIcon.right : parent.left
            anchors.leftMargin: headerIcon.visible ? 8 : 0
            anchors.verticalCenter: parent.verticalCenter
            text: "Codex"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
          }

          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: chipText.implicitWidth + 16
            height: 20
            radius: 10
            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.14)

            Text {
              id: chipText
              anchors.centerIn: parent
              text: root.sessionAvailable
                ? (root.activeBlock ? (root.leftPercent + "% 5h") : (root.leftPercent + "% left"))
                : "weekly only"
              color: root.accentColor
              font.family: root.fontFamily
              font.pixelSize: 11
              font.weight: Font.DemiBold
              renderType: Text.NativeRendering
            }
          }
        }

        Column {
          width: parent.width
          spacing: 5
          opacity: root.sessionAvailable ? 1 : 0.38

          Item {
            width: parent.width
            height: meterTitle.implicitHeight

            Text {
              id: meterTitle
              anchors.left: parent.left
              text: "5h limit"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: 11
              font.weight: Font.DemiBold
              renderType: Text.NativeRendering
            }

            Text {
              anchors.right: parent.right
              text: root.sessionAvailable ? (root.activeBlock ? (root.usedPercent + "% used") : "idle") : "suppressed"
              color: root.accentColor
              font.family: root.fontFamily
              font.pixelSize: 11
              font.weight: Font.DemiBold
              renderType: Text.NativeRendering
            }
          }

          Rectangle {
            width: parent.width
            height: 7
            radius: 3.5
            color: root.trackColor

            Rectangle {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              width: root.sessionAvailable && root.activeBlock ? Math.max(height, Math.round(parent.width * root.usedPercent / 100)) : 0
              radius: 3.5
              color: root.accentColor
              opacity: 0.92
              Behavior on width { NumberAnimation { duration: motionTokens.quick; easing.type: Easing.OutCubic } }
            }
          }

          Item {
            width: parent.width
            height: meterLeft.implicitHeight

            Text {
              id: meterLeft
              anchors.left: parent.left
              text: root.sessionAvailable ? (root.activeBlock ? (root.leftPercent + "% left") : "idle") : "not reported"
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: 11
              renderType: Text.NativeRendering
            }

            Text {
              anchors.right: parent.right
              text: root.sessionAvailable && root.activeBlock ? ("resets " + root.resetLabel) : ""
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: 11
              elide: Text.ElideRight
              renderType: Text.NativeRendering
            }
          }
        }

        Column {
          visible: root.weekActive
          width: parent.width
          spacing: 5

          Item {
            width: parent.width
            height: weekMeterTitle.implicitHeight

            Text {
              id: weekMeterTitle
              anchors.left: parent.left
              text: "Weekly limit"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: 11
              font.weight: Font.DemiBold
              renderType: Text.NativeRendering
            }

            Text {
              anchors.right: parent.right
              text: root.weekUsedPercent + "% used"
              color: root.weekAccentColor
              font.family: root.fontFamily
              font.pixelSize: 11
              font.weight: Font.DemiBold
              renderType: Text.NativeRendering
            }
          }

          Rectangle {
            width: parent.width
            height: 7
            radius: 3.5
            color: root.trackColor

            Rectangle {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              width: Math.max(height, Math.round(parent.width * root.weekUsedPercent / 100))
              radius: 3.5
              color: root.weekAccentColor
              opacity: 0.92
              Behavior on width { NumberAnimation { duration: motionTokens.quick; easing.type: Easing.OutCubic } }
            }
          }

          Item {
            width: parent.width
            height: weekMeterLeft.implicitHeight

            Text {
              id: weekMeterLeft
              anchors.left: parent.left
              text: root.weekLeftPercent + "% left"
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: 11
              renderType: Text.NativeRendering
            }

            Text {
              anchors.right: parent.right
              text: "resets " + root.weekResetLabel
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: 11
              elide: Text.ElideRight
              renderType: Text.NativeRendering
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
        }

        Column {
          width: parent.width
          spacing: 7

          Repeater {
            model: root.detailRows
            delegate: Item {
              required property var modelData
              width: content.width
              height: 16

              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                color: root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: 12
                renderType: Text.NativeRendering
              }

              Text {
                anchors.right: parent.right
                anchors.left: parent.horizontalCenter
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.value
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
                renderType: Text.NativeRendering
              }
            }
          }
        }

        Item {
          width: parent.width
          height: 16

          Text {
            anchors.left: parent.left
            anchors.right: refreshButton.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.sourceLabel
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.4)
            font.family: root.fontFamily
            font.pixelSize: 10
            elide: Text.ElideRight
            renderType: Text.NativeRendering
          }

          Text {
            id: refreshButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Refresh"
            color: refreshHover.containsMouse ? root.accentColor : root.mutedColor
            font.family: root.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering

            MouseArea {
              id: refreshHover
              anchors.fill: parent
              anchors.margins: -6
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.refreshRequested()
            }
          }
        }
      }
    }
  }

  readonly property var detailRows: {
    var rows = []
    rows.push({ label: "Plan", value: root.planLabel })
    rows.push({ label: "Resets", value: root.resetLabel })
    if (root.sourceEventText.length > 0)
      rows.push({ label: "Source event", value: root.sourceEventText })
    if (root.sourceFileText.length > 0)
      rows.push({ label: "Source file", value: root.sourceFileText })
    return rows
  }
}
