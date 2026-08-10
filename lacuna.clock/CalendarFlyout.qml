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
  property date liveDate: new Date()
  property int panelWidth: 350
  property int panelHeight: 440
  property int joinRadius: bar && bar.resolvedCornerRadius !== undefined ? Math.max(0, Math.round(Number(bar.resolvedCornerRadius) || 0)) : 14
  property int cornerRadius: joinRadius
  property int margin: 8
  property color accentColor: "#89b4fa"
  property string fontFamily: bar ? bar.fontFamily : "Hack Nerd Font Propo"
  property bool shadowEnabled: false
  property int shadowOffsetX: 2
  property int shadowOffsetY: 3

  readonly property var coordinatorKey: owner || root
  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  readonly property string attachmentEdge: bar && /^(top|bottom|left|right)$/.test(bar.position) ? bar.position : "top"
  readonly property color foreground: bar ? bar.foreground : "#d8dee9"
  readonly property color background: opaqueColor(bar ? bar.background : "#101315")
  readonly property color mutedColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.52)
  readonly property color softColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.76)
  readonly property color lineColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.14)
  readonly property string displayFontFamily: tokens.displayFont
  readonly property int displayHeroWeight: tokens.displayTelemetryWeight
  readonly property real displayTitleTracking: tokens.trackingTitle
  readonly property int contentPadding: 16
  readonly property int innerWidth: panelWidth - contentPadding * 2
  readonly property int contentSpacing: 4
  readonly property int heroHeight: 78
  readonly property int dividerHeight: 1
  readonly property int navigationHeight: 32
  readonly property int weekdayHeight: 18
  readonly property int monthGridHeight: 224
  readonly property int footerHeight: 30
  readonly property int calendarContentHeight: heroHeight + dividerHeight + navigationHeight
    + weekdayHeight + monthGridHeight + footerHeight + contentSpacing * 5
  readonly property bool contentFitsPanel: calendarContentHeight + contentPadding * 2 <= panelHeight
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
  readonly property string lacunaSettingsPath: configHome + "/omarchy/lacuna/settings.json"
  readonly property date selectedDate: calendar.selectedDate
  readonly property date viewedMonth: calendar.viewedMonth
  readonly property var cells: calendar.cells

  function opaqueColor(value) {
    var color = typeof value === "string" ? Qt.color(value) : value
    return Qt.rgba(color.r, color.g, color.b, 1)
  }

  function close() {
    if (owner && typeof owner.close === "function") owner.close()
    else open = false
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

  function showPreviousMonth() { calendar.showPreviousMonth() }
  function showNextMonth() { calendar.showNextMonth() }
  function showToday() { calendar.showToday() }
  function selectCell(cell) { calendar.selectCell(cell) }

  CalendarState {
    id: calendar
    liveDate: root.liveDate
  }

  LacunaTokens { id: tokens }
  MotionTokens {
    id: motionTokens
    animationDisabled: root.reduceMotion
  }

  FileView {
    path: root.lacunaSettingsPath
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
    if (open)
      bar.requestPopout(coordinatorKey, anchorItem, owner ? owner.moduleName : "")
    else if (bar.activePopout === coordinatorKey)
      bar.releasePopout(coordinatorKey)
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
        x: surface.x + surface.panelLeft + root.contentPadding
        y: surface.y + surface.panelTop + root.contentPadding
        width: root.innerWidth
        spacing: root.contentSpacing
        opacity: root.contentOpacity

        Item {
          width: parent.width
          height: root.heroHeight

          Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: Qt.formatDate(calendar.selectedDate, "MMMM yyyy")
            color: root.accentColor
            font.family: root.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.letterSpacing: 0.7
            renderType: Text.NativeRendering
          }

          Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 22
            text: Qt.formatDateTime(root.liveDate, "h:mm AP")
            color: root.foreground
            font.family: root.displayFontFamily
            font.pixelSize: 28
            font.weight: root.displayHeroWeight
            font.letterSpacing: root.displayTitleTracking
            renderType: Text.NativeRendering
          }

          Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: Qt.formatDate(calendar.selectedDate, "dddd, MMMM d, yyyy")
            color: root.softColor
            font.family: root.fontFamily
            font.pixelSize: 13
            elide: Text.ElideRight
            renderType: Text.NativeRendering
          }
        }

        Rectangle {
          width: parent.width
          height: root.dividerHeight
          color: root.lineColor
        }

        Item {
          width: parent.width
          height: root.navigationHeight

          Rectangle {
            id: previousButton
            anchors.left: parent.left
            width: 32
            height: 32
            color: previousMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12) : "transparent"
            border.width: 1
            border.color: root.lineColor
            Text { anchors.centerIn: parent; text: "‹"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: 20 }
            MouseArea { id: previousMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.showPreviousMonth() }
          }

          Text {
            anchors.centerIn: parent
            text: Qt.formatDate(calendar.viewedMonth, "MMMM yyyy")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
          }

          Rectangle {
            id: nextButton
            anchors.right: parent.right
            width: 32
            height: 32
            color: nextMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12) : "transparent"
            border.width: 1
            border.color: root.lineColor
            Text { anchors.centerIn: parent; text: "›"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: 20 }
            MouseArea { id: nextMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.showNextMonth() }
          }
        }

        Grid {
          width: parent.width
          height: root.weekdayHeight
          columns: 7
          columnSpacing: 4

          Repeater {
            model: calendar.weekdayLabels
            delegate: Text {
              required property string modelData
              width: (root.innerWidth - 24) / 7
              horizontalAlignment: Text.AlignHCenter
              text: modelData
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: 10
              font.weight: Font.DemiBold
              renderType: Text.NativeRendering
            }
          }
        }

        Grid {
          id: monthGrid
          width: parent.width
          height: root.monthGridHeight
          columns: 7
          rowSpacing: 4
          columnSpacing: 4

          Repeater {
            model: calendar.cells
            delegate: Item {
              id: dayCell
              required property var modelData
              readonly property bool isToday: modelData.key === calendar.todayKey
              readonly property bool isSelected: modelData.key === calendar.selectedKey
              width: (root.innerWidth - 24) / 7
              height: 34

              Rectangle {
                anchors.fill: parent
                color: dayCell.isToday
                  ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.24)
                  : (cellMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07) : "transparent")
                border.width: dayCell.isSelected ? 1 : 0
                border.color: dayCell.isToday ? root.accentColor : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.42)
              }

              Text {
                anchors.centerIn: parent
                text: dayCell.modelData.day
                color: dayCell.isToday
                  ? root.foreground
                  : (dayCell.modelData.inMonth ? root.softColor : root.mutedColor)
                font.family: root.fontFamily
                font.pixelSize: 12
                font.weight: dayCell.isToday ? Font.Bold : Font.Normal
                renderType: Text.NativeRendering
              }

              MouseArea {
                id: cellMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.selectCell(dayCell.modelData)
              }
            }
          }
        }

        Item {
          width: parent.width
          height: root.footerHeight

          Rectangle {
            anchors.right: parent.right
            width: todayText.implicitWidth + 20
            height: 30
            color: todayMouse.containsMouse
              ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
              : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.10)
            border.width: 1
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.34)

            Text {
              id: todayText
              anchors.centerIn: parent
              text: "Today"
              color: root.accentColor
              font.family: root.fontFamily
              font.pixelSize: 11
              font.weight: Font.DemiBold
              renderType: Text.NativeRendering
            }

            MouseArea { id: todayMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.showToday() }
          }
        }
      }
    }
  }
}
