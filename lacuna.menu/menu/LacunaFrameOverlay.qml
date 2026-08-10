import QtQuick
import QtQuick.Shapes
import "../components"

Item {
  id: root

  property string mode: "off"
  property bool shadowEnabled: false
  property bool borderEnabled: false
  property bool borderOnly: false
  property var borderGeometryRecord: null
  property string barPosition: "top"
  property int barSize: 0
  property int barBottomY: 0
  property real frameWidth: 0
  property int frameThickness: 8
  property int frameRadius: 14
  property bool moldingPieces: true
  property real progress: 1
  property color frameColor: "#101315"
  property color borderColor: Qt.rgba(1, 1, 1, 1)
  property real borderWidth: 1
  property real outputScale: 1
  property color shadowColor: "black"
  property real shadowOpacity: 0.88
  property real shadowBlur: 0.85
  property int shadowBlurMax: 28
  property real shadowOffsetX: 2
  property real shadowOffsetY: 3

  property real sidebarX: 0
  property real sidebarY: 0
  property real sidebarWidth: 0
  property real sidebarHeight: 0
  property real sidebarMoldingWidth: 0
  property bool sidebarMoldingVisible: false
  property bool leftEdgeOccupied: true
  property bool rightEdgeOccupied: false

  property real connectorX: 0
  property real connectorY: 0
  property real connectorWidth: 0
  property real connectorHeight: 0
  property bool connectorVisible: false

  property real flyoutX: 0
  property real flyoutY: 0
  property real flyoutWidth: 0
  property real flyoutHeight: 0
  property bool flyoutVisible: false

  readonly property bool frameEnabled: mode === "fullframe"
  readonly property bool borderFrameEnabled: frameEnabled || borderOnly
  readonly property bool hasBorderGeometryRecord: borderGeometryRecord
    && typeof borderGeometryRecord === "object"
  readonly property bool fullFrame: mode === "fullframe"
  readonly property real clampedProgress: Math.max(0, Math.min(1, progress))
  readonly property real edgeProgress: smoothEdgeProgress(clampedProgress)
  readonly property int t: Math.max(1, frameThickness)
  readonly property int effectiveBarSize: Math.max(0, barSize)
  readonly property real effectiveFrameWidth: frameWidth > 0 ? frameWidth : width
  readonly property bool topBar: barPosition === "top"
  readonly property bool bottomBar: barPosition === "bottom"
  readonly property bool leftBar: barPosition === "left"
  readonly property bool rightBar: barPosition === "right"
  readonly property real curveKappa: lacunaGeometry.curveKappa

  LacunaGeometry { id: lacunaGeometry }
  readonly property real moldingSize: Math.max(0, frameRadius)
  readonly property real frameAlpha: 1
  readonly property color solidFrameColor: Qt.rgba(frameColor.r, frameColor.g, frameColor.b, 1)
  readonly property real shadowAlphaCompensation: 1
  readonly property real shadowExtent: Math.max(14, shadowBlurMax + Math.max(Math.abs(shadowOffsetX), Math.abs(shadowOffsetY)))
  property real barEdgeCasterSize: frameThickness
  readonly property real barEdgeCasterOverrun: 100
  readonly property real barEdgeShadowOpacity: Math.min(1, shadowOpacity * 1.35)
  readonly property real surfaceShadowOpacity: Math.min(1, shadowOpacity * 0.42)
  readonly property real surfaceShadowSize: Math.max(12, Math.min(34, shadowExtent))
  readonly property bool sidebarOnRight: rightEdgeOccupied && !leftEdgeOccupied
  readonly property real sidebarOccupiedWidth: sidebarWidth + (sidebarMoldingVisible ? sidebarMoldingWidth : 0)
  readonly property real fallbackBorderLeft: Math.max(0, leftEdgeOccupied ? sidebarX + sidebarWidth : (leftBar ? effectiveBarSize : t))
  readonly property real fallbackBorderTop: Math.max(0, topBar ? barBottomY : t)
  readonly property real fallbackBorderRight: Math.max(fallbackBorderLeft + 1, effectiveFrameWidth - (rightEdgeOccupied ? Math.max(0, effectiveFrameWidth - sidebarX) : (rightBar ? effectiveBarSize : t)))
  readonly property real fallbackBorderBottom: Math.max(fallbackBorderTop + 1, height - (bottomBar ? effectiveBarSize : t))
  readonly property real borderLeft: hasBorderGeometryRecord ? Number(borderGeometryRecord.holeX) : fallbackBorderLeft
  readonly property real borderTop: hasBorderGeometryRecord ? Number(borderGeometryRecord.holeY) : fallbackBorderTop
  readonly property real borderRight: hasBorderGeometryRecord ? Number(borderGeometryRecord.holeRight) : fallbackBorderRight
  readonly property real borderBottom: hasBorderGeometryRecord ? Number(borderGeometryRecord.holeBottom) : fallbackBorderBottom
  readonly property real borderInset: Math.max(0, borderWidth / 2)
  readonly property real moldingBorderWidth: borderWidth + (outputScale <= 1.25 ? 0.5 : 0)
  readonly property real strokeLeft: borderLeft + borderInset
  readonly property real strokeTop: borderTop + borderInset
  readonly property real strokeRight: borderRight - borderInset
  readonly property real strokeBottom: borderBottom - borderInset
  readonly property real borderGeometryRadius: hasBorderGeometryRecord
    ? Math.max(0, Number(borderGeometryRecord.contentRadius) || 0)
    : (moldingPieces ? moldingSize : 0)
  readonly property real borderRadius: borderGeometryRadius > 0
    ? Math.max(0, Math.min(borderGeometryRadius, (borderRight - borderLeft) / 2, (borderBottom - borderTop) / 2) - borderInset)
    : 0
  readonly property bool effectiveLeftEdgeOccupied: hasBorderGeometryRecord
    ? borderGeometryRecord.leftEdgeOccupied === true : leftEdgeOccupied
  readonly property bool effectiveRightEdgeOccupied: hasBorderGeometryRecord
    ? borderGeometryRecord.rightEdgeOccupied === true : rightEdgeOccupied
  readonly property bool leftAttachmentGapVisible: effectiveLeftEdgeOccupied && flyoutVisible && flyoutHeight > 0
  readonly property bool rightAttachmentGapVisible: effectiveRightEdgeOccupied && flyoutVisible && flyoutHeight > 0
  // The straight frame rail meets the connector at its outer cubic tangents,
  // not at the flyout body's square attachment corners. Using flyoutY here
  // leaves the rail visibly running through both molding curves.
  readonly property real attachedOutlineTop: connectorVisible && connectorHeight > 0
    ? connectorY : flyoutY
  readonly property real attachedOutlineBottom: connectorVisible && connectorHeight > 0
    ? connectorY + connectorHeight : flyoutY + flyoutHeight
  readonly property real attachmentGapTop: Math.max(strokeTop + borderRadius, attachedOutlineTop + borderInset)
  readonly property real attachmentGapBottom: Math.min(strokeBottom - borderRadius, attachedOutlineBottom - borderInset)
  readonly property bool attachmentGapRenderable: attachmentGapBottom > attachmentGapTop + borderWidth
  readonly property real rightVerticalUpperEndY: rightAttachmentGapVisible && attachmentGapRenderable ? attachmentGapTop : strokeBottom - borderRadius
  readonly property real rightVerticalLowerStartY: rightAttachmentGapVisible && attachmentGapRenderable ? attachmentGapBottom : strokeBottom - borderRadius
  readonly property real leftVerticalLowerEndY: leftAttachmentGapVisible && attachmentGapRenderable ? attachmentGapBottom : strokeTop + borderRadius
  readonly property real leftVerticalUpperStartY: leftAttachmentGapVisible && attachmentGapRenderable ? attachmentGapTop : strokeTop + borderRadius
  readonly property real horizontalBarShadowX: leftEdgeOccupied ? Math.max(0, sidebarX + sidebarOccupiedWidth) : 0
  readonly property real horizontalBarShadowRightInset: rightEdgeOccupied ? Math.max(0, effectiveFrameWidth - sidebarX + (sidebarMoldingVisible ? sidebarMoldingWidth : 0)) : 0
  readonly property real horizontalBarShadowWidth: Math.max(0, effectiveFrameWidth - horizontalBarShadowX - horizontalBarShadowRightInset + barEdgeCasterOverrun)
  readonly property real sidebarJoinTop: Math.max(-sidebarMoldingWidth, barBottomY - 1)
  readonly property real sidebarJoinHeight: Math.max(0, sidebarHeight - sidebarJoinTop)

  visible: (frameEnabled || (borderOnly && borderEnabled)) && clampedProgress > 0.001
  enabled: false

  function smoothEdgeProgress(value) {
    var p = Math.max(0, Math.min(1, value))
    return p * p * p * (p * (p * 6 - 15) + 10)
  }

  Item {
    id: frameSource

    anchors.fill: parent
    z: 1

    Rectangle {
      visible: root.fullFrame && !root.topBar
      x: 0
      y: -root.t + root.t * root.edgeProgress
      width: root.effectiveFrameWidth
      height: root.t
      color: root.solidFrameColor
      opacity: root.frameAlpha
    }

    Rectangle {
      visible: root.fullFrame && !root.bottomBar
      x: 0
      y: parent.height - root.t * root.edgeProgress
      width: root.effectiveFrameWidth
      height: root.t
      color: root.solidFrameColor
      opacity: root.frameAlpha
    }

    Rectangle {
      visible: root.fullFrame && !root.leftBar && !root.leftEdgeOccupied
      x: -root.t + root.t * root.edgeProgress
      y: 0
      width: root.t
      height: parent.height
      color: root.solidFrameColor
      opacity: root.frameAlpha
    }

    Shape {
      id: fullFrameTopLeftMolding

      visible: root.fullFrame && root.moldingPieces && root.topBar && !root.leftBar && !root.leftEdgeOccupied && root.moldingSize > 0
      x: -root.moldingSize + (root.t + root.moldingSize) * root.edgeProgress
      y: root.barBottomY
      width: root.moldingSize
      height: root.moldingSize
      asynchronous: false
      antialiasing: true
      opacity: root.frameAlpha
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        fillColor: root.solidFrameColor
        strokeWidth: 0
        startX: 0
        startY: 0

        PathLine {
          x: 0
          y: root.moldingSize
        }
        PathCubic {
          x: root.moldingSize
          y: 0
          control1X: 0
          control1Y: root.moldingSize * (1 - root.curveKappa)
          control2X: root.moldingSize * root.curveKappa
          control2Y: 0
        }
        PathLine {
          x: 0
          y: 0
        }
      }
    }

    Rectangle {
      visible: root.fullFrame && !root.rightBar && !root.rightEdgeOccupied
      x: root.effectiveFrameWidth - root.t * root.edgeProgress
      y: 0
      width: root.t
      height: parent.height
      color: root.solidFrameColor
      opacity: root.frameAlpha
    }

    Shape {
      id: fullFrameTopRightMolding

      visible: root.fullFrame && root.moldingPieces && root.topBar && !root.rightBar && !root.rightEdgeOccupied && root.moldingSize > 0
      x: root.effectiveFrameWidth - (root.t + root.moldingSize) * root.edgeProgress
      y: root.barBottomY
      width: root.moldingSize
      height: root.moldingSize
      asynchronous: false
      antialiasing: true
      opacity: root.frameAlpha
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        fillColor: root.solidFrameColor
        strokeWidth: 0
        startX: root.moldingSize
        startY: 0

        PathLine {
          x: root.moldingSize
          y: root.moldingSize
        }
        PathCubic {
          x: 0
          y: 0
          control1X: root.moldingSize
          control1Y: root.moldingSize * (1 - root.curveKappa)
          control2X: root.moldingSize * (1 - root.curveKappa)
          control2Y: 0
        }
        PathLine {
          x: root.moldingSize
          y: 0
        }
      }
    }

    Shape {
      id: fullFrameBottomRightMolding

      visible: root.fullFrame && root.moldingPieces && !root.bottomBar && !root.rightBar && !root.rightEdgeOccupied && root.moldingSize > 0
      x: root.effectiveFrameWidth - (root.t + root.moldingSize) * root.edgeProgress
      y: parent.height - (root.t + root.moldingSize) * root.edgeProgress
      width: root.moldingSize
      height: root.moldingSize
      asynchronous: false
      antialiasing: true
      opacity: root.frameAlpha
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        fillColor: root.solidFrameColor
        strokeWidth: 0
        startX: root.moldingSize
        startY: root.moldingSize

        PathLine {
          x: 0
          y: root.moldingSize
        }
        PathCubic {
          x: root.moldingSize
          y: 0
          control1X: root.moldingSize * (1 - root.curveKappa)
          control1Y: root.moldingSize
          control2X: root.moldingSize
          control2Y: root.moldingSize * (1 - root.curveKappa)
        }
        PathLine {
          x: root.moldingSize
          y: root.moldingSize
        }
      }
    }

    Shape {
      id: fullFrameBottomLeftMolding

      visible: root.fullFrame && root.moldingPieces && !root.bottomBar && root.leftEdgeOccupied && root.sidebarMoldingVisible && root.moldingSize > 0
      x: root.sidebarX + root.sidebarWidth
      y: parent.height - (root.t + root.moldingSize) * root.edgeProgress
      width: root.moldingSize
      height: root.moldingSize
      asynchronous: false
      antialiasing: true
      opacity: root.frameAlpha
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        fillColor: root.solidFrameColor
        strokeWidth: 0
        startX: 0
        startY: root.moldingSize

        PathLine {
          x: root.moldingSize
          y: root.moldingSize
        }
        PathCubic {
          x: 0
          y: 0
          control1X: root.moldingSize * (1 - root.curveKappa)
          control1Y: root.moldingSize
          control2X: 0
          control2Y: root.moldingSize * (1 - root.curveKappa)
        }
        PathLine {
          x: 0
          y: root.moldingSize
        }
      }
    }

    Shape {
      id: fullFrameBottomLeftEdgeMolding

      visible: root.fullFrame && root.moldingPieces && !root.bottomBar && !root.leftBar && !root.leftEdgeOccupied && root.moldingSize > 0
      x: -root.moldingSize + (root.t + root.moldingSize) * root.edgeProgress
      y: parent.height - (root.t + root.moldingSize) * root.edgeProgress
      width: root.moldingSize
      height: root.moldingSize
      asynchronous: false
      antialiasing: true
      opacity: root.frameAlpha
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        fillColor: root.solidFrameColor
        strokeWidth: 0
        startX: 0
        startY: root.moldingSize

        PathLine {
          x: root.moldingSize
          y: root.moldingSize
        }
        PathCubic {
          x: 0
          y: 0
          control1X: root.moldingSize * (1 - root.curveKappa)
          control1Y: root.moldingSize
          control2X: 0
          control2Y: root.moldingSize * (1 - root.curveKappa)
        }
        PathLine {
          x: 0
          y: root.moldingSize
        }
      }
    }

  }

  LacunaDropShadow {
    source: frameSource
    shadowEnabled: root.shadowEnabled
    shadowColor: root.shadowColor
    shadowOpacity: root.shadowOpacity * root.shadowAlphaCompensation
    shadowBlur: root.shadowBlur
    blurMax: root.shadowBlurMax
    shadowHorizontalOffset: root.shadowOffsetX
    shadowVerticalOffset: root.shadowOffsetY
    z: -2
  }

  Shape {
    id: frameBorderSource

    anchors.fill: parent
    visible: root.borderFrameEnabled && root.borderEnabled && root.clampedProgress > 0.001
    asynchronous: false
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer
    z: 2

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.borderColor
      strokeWidth: root.borderWidth
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.MiterJoin
      startX: root.strokeLeft + root.borderRadius
      startY: root.strokeTop

      PathLine {
        x: root.strokeRight - root.borderRadius
        y: root.strokeTop
      }
      PathCubic {
        x: root.strokeRight
        y: root.strokeTop + root.borderRadius
        control1X: root.strokeRight - root.borderRadius * (1 - root.curveKappa)
        control1Y: root.strokeTop
        control2X: root.strokeRight
        control2Y: root.strokeTop + root.borderRadius * (1 - root.curveKappa)
      }
      PathLine {
        x: root.strokeRight
        y: root.rightVerticalUpperEndY
      }
      PathMove {
        x: root.strokeRight
        y: root.rightVerticalLowerStartY
      }
      PathLine {
        x: root.strokeRight
        y: root.strokeBottom - root.borderRadius
      }
      PathCubic {
        x: root.strokeRight - root.borderRadius
        y: root.strokeBottom
        control1X: root.strokeRight
        control1Y: root.strokeBottom - root.borderRadius * (1 - root.curveKappa)
        control2X: root.strokeRight - root.borderRadius * (1 - root.curveKappa)
        control2Y: root.strokeBottom
      }
      PathLine {
        x: root.strokeLeft + root.borderRadius
        y: root.strokeBottom
      }
      PathCubic {
        x: root.strokeLeft
        y: root.strokeBottom - root.borderRadius
        control1X: root.strokeLeft + root.borderRadius * (1 - root.curveKappa)
        control1Y: root.strokeBottom
        control2X: root.strokeLeft
        control2Y: root.strokeBottom - root.borderRadius * (1 - root.curveKappa)
      }
      PathLine {
        x: root.strokeLeft
        y: root.leftVerticalLowerEndY
      }
      PathMove {
        x: root.strokeLeft
        y: root.leftVerticalUpperStartY
      }
      PathLine {
        x: root.strokeLeft
        y: root.strokeTop + root.borderRadius
      }
      PathCubic {
        x: root.strokeLeft + root.borderRadius
        y: root.strokeTop
        control1X: root.strokeLeft
        control1Y: root.strokeTop + root.borderRadius * (1 - root.curveKappa)
        control2X: root.strokeLeft + root.borderRadius * (1 - root.curveKappa)
        control2Y: root.strokeTop
      }
    }

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.borderColor
      strokeWidth: root.borderRadius > 0 ? root.moldingBorderWidth : 0
      capStyle: ShapePath.FlatCap

      startX: root.strokeRight - root.borderRadius
      startY: root.strokeTop
      PathCubic {
        x: root.strokeRight
        y: root.strokeTop + root.borderRadius
        control1X: root.strokeRight - root.borderRadius * (1 - root.curveKappa)
        control1Y: root.strokeTop
        control2X: root.strokeRight
        control2Y: root.strokeTop + root.borderRadius * (1 - root.curveKappa)
      }
      PathMove {
        x: root.strokeRight
        y: root.strokeBottom - root.borderRadius
      }
      PathCubic {
        x: root.strokeRight - root.borderRadius
        y: root.strokeBottom
        control1X: root.strokeRight
        control1Y: root.strokeBottom - root.borderRadius * (1 - root.curveKappa)
        control2X: root.strokeRight - root.borderRadius * (1 - root.curveKappa)
        control2Y: root.strokeBottom
      }
      PathMove {
        x: root.strokeLeft + root.borderRadius
        y: root.strokeBottom
      }
      PathCubic {
        x: root.strokeLeft
        y: root.strokeBottom - root.borderRadius
        control1X: root.strokeLeft + root.borderRadius * (1 - root.curveKappa)
        control1Y: root.strokeBottom
        control2X: root.strokeLeft
        control2Y: root.strokeBottom - root.borderRadius * (1 - root.curveKappa)
      }
      PathMove {
        x: root.strokeLeft
        y: root.strokeTop + root.borderRadius
      }
      PathCubic {
        x: root.strokeLeft + root.borderRadius
        y: root.strokeTop
        control1X: root.strokeLeft
        control1Y: root.strokeTop + root.borderRadius * (1 - root.curveKappa)
        control2X: root.strokeLeft + root.borderRadius * (1 - root.curveKappa)
        control2Y: root.strokeTop
      }
    }
  }

  Item {
    id: barEdgeShadowLayer

    anchors.fill: parent
    visible: root.shadowEnabled
    z: -1

    Rectangle {
      visible: root.topBar && root.horizontalBarShadowWidth > 0
      x: root.horizontalBarShadowX
      y: root.barBottomY
      width: root.horizontalBarShadowWidth
      height: root.barEdgeCasterSize * root.edgeProgress
      gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, root.barEdgeShadowOpacity * 0.66) }
        GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, root.barEdgeShadowOpacity * 0.32) }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
      }
    }

    Rectangle {
      visible: root.bottomBar && root.horizontalBarShadowWidth > 0
      x: root.horizontalBarShadowX
      y: parent.height - root.barEdgeCasterSize * root.edgeProgress
      width: root.horizontalBarShadowWidth
      height: root.barEdgeCasterSize
      gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
        GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, root.barEdgeShadowOpacity * 0.24) }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, root.barEdgeShadowOpacity * 0.52) }
      }
    }

    Rectangle {
      visible: root.leftBar
      x: -root.barEdgeCasterSize + root.barEdgeCasterSize * root.edgeProgress
      y: 0
      width: root.barEdgeCasterSize
      height: parent.height
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, root.barEdgeShadowOpacity * 0.52) }
        GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, root.barEdgeShadowOpacity * 0.24) }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
      }
    }

    Rectangle {
      visible: root.rightBar
      x: root.effectiveFrameWidth - root.barEdgeCasterSize * root.edgeProgress
      y: 0
      width: root.barEdgeCasterSize
      height: parent.height
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
        GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, root.barEdgeShadowOpacity * 0.24) }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, root.barEdgeShadowOpacity * 0.52) }
      }
    }
  }
}
