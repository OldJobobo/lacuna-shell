import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import "../lacuna.menu/components"

PanelWindow {
  id: root

  readonly property alias foregroundBorderSource: frameBorderPaint
  property var targetScreen: null
  property var geometryRecord: null
  property var shadowGeometryRecord: null
  property bool active: false
  property bool suppressed: false
  property string barPosition: "top"
  property int barSize: 0
  property int frameThickness: 8
  property int frameRadius: 14
  property bool moldingPieces: true
  property color frameColor: "#17105a"
  property bool shadowEnabled: false
  property int shadowOffsetX: 2
  property int shadowOffsetY: 3
  property real shadowOpacity: 0.62
  property real shadowBlur: 0.85
  property int shadowBlurMax: 28
  property bool topEdgeOccupied: false
  property bool bottomEdgeOccupied: false
  property bool leftEdgeOccupied: false
  property bool rightEdgeOccupied: false
  property real leftOccupiedWidth: 0
  property real rightOccupiedWidth: 0
  property bool borderEnabled: false
  property color borderColor: Qt.rgba(1, 1, 1, 1)
  property bool attachedFlyoutVisible: false
  property real attachedFlyoutX: 0
  property real attachedFlyoutY: 0
  property real attachedFlyoutWidth: 0
  property real attachedFlyoutHeight: 0
  property var barPopoutBorderGap: null
  property real paintOcclusionLeft: 0
  property real paintOcclusionRight: 0
  property real shadowOcclusionLeft: 0
  property real shadowOcclusionRight: 0
  // Live reveal-hole overrides let the existing frame shadow wrap transient
  // sidebar geometry without rebuilding or replacing the frame caster.
  property real shadowHoleLeftOverride: -1
  property real shadowHoleRightOverride: -1

  readonly property bool hasGeometryRecord: geometryRecord && typeof geometryRecord === "object"
  readonly property int t: hasGeometryRecord ? Math.max(1, Number(geometryRecord.thickness) || 1) : Math.max(1, frameThickness)
  readonly property int r: hasGeometryRecord ? Math.max(0, Number(geometryRecord.contentRadius) || 0) : Math.max(0, frameRadius)
  readonly property real leftOcclusion: hasGeometryRecord ? Math.max(0, Number(geometryRecord.leftOccupiedWidth) || 0) : (leftEdgeOccupied ? Math.max(0, leftOccupiedWidth) : 0)
  readonly property real rightOcclusion: hasGeometryRecord ? Math.max(0, Number(geometryRecord.rightOccupiedWidth) || 0) : (rightEdgeOccupied ? Math.max(0, rightOccupiedWidth) : 0)
  readonly property bool topBar: (hasGeometryRecord ? String(geometryRecord.barPosition || "") : barPosition) === "top"
  readonly property bool bottomBar: (hasGeometryRecord ? String(geometryRecord.barPosition || "") : barPosition) === "bottom"
  readonly property bool leftBar: (hasGeometryRecord ? String(geometryRecord.barPosition || "") : barPosition) === "left"
  readonly property bool rightBar: (hasGeometryRecord ? String(geometryRecord.barPosition || "") : barPosition) === "right"
  readonly property int effectiveBarSize: hasGeometryRecord ? Math.max(0, Number(geometryRecord.barSize) || 0) : Math.max(0, barSize)
  readonly property bool effectiveTopEdgeOccupied: hasGeometryRecord ? geometryRecord.topEdgeOccupied === true : topEdgeOccupied
  readonly property bool effectiveBottomEdgeOccupied: hasGeometryRecord ? geometryRecord.bottomEdgeOccupied === true : bottomEdgeOccupied
  readonly property bool effectiveLeftEdgeOccupied: hasGeometryRecord ? geometryRecord.leftEdgeOccupied === true : leftEdgeOccupied
  readonly property bool effectiveRightEdgeOccupied: hasGeometryRecord ? geometryRecord.rightEdgeOccupied === true : rightEdgeOccupied
  readonly property bool effectiveMoldingPieces: hasGeometryRecord ? r > 0 : moldingPieces
  readonly property int topInset: topBar || effectiveTopEdgeOccupied ? effectiveBarSize : t
  readonly property int bottomInset: bottomBar || effectiveBottomEdgeOccupied ? effectiveBarSize : t
  readonly property int leftInset: leftBar ? effectiveBarSize : t
  readonly property int rightInset: rightBar ? effectiveBarSize : t
  // The frame never paints the strip occupied by the bar: the bar itself is
  // the frame edge on its side. Map order of the vendored bar window is not
  // ours to control, so bar-over-frame correctness must come from geometry,
  // not stacking.
  readonly property real outerX: hasGeometryRecord ? Number(geometryRecord.outerX || 0) : (leftBar ? effectiveBarSize : 0)
  readonly property real outerY: hasGeometryRecord ? Number(geometryRecord.outerY || 0) : (topBar || effectiveTopEdgeOccupied ? effectiveBarSize : 0)
  readonly property real outerRight: hasGeometryRecord ? Number(geometryRecord.outerRight || width) : (rightBar ? Math.max(outerX + 1, width - effectiveBarSize) : width)
  readonly property real outerBottom: hasGeometryRecord ? Number(geometryRecord.outerBottom || height) : (bottomBar || effectiveBottomEdgeOccupied ? Math.max(outerY + 1, height - effectiveBarSize) : height)
  readonly property real paintLeft: Math.max(outerX, Math.max(0, paintOcclusionLeft))
  readonly property real paintRight: Math.min(outerRight, width - Math.max(0, paintOcclusionRight))
  readonly property real shadowPaintLeft: Math.max(outerX, Math.max(0, shadowOcclusionLeft))
  readonly property real shadowPaintRight: Math.min(outerRight, width - Math.max(0, shadowOcclusionRight))
  readonly property real holeX: hasGeometryRecord ? Number(geometryRecord.holeX || 0) : Math.max(0, effectiveLeftEdgeOccupied ? leftOcclusion : leftInset)
  readonly property real holeY: hasGeometryRecord ? Number(geometryRecord.holeY || 0) : Math.max(0, topInset)
  readonly property real holeRight: hasGeometryRecord ? Number(geometryRecord.holeRight || holeX + 1) : Math.max(holeX + 1, width - (effectiveRightEdgeOccupied ? rightOcclusion : rightInset))
  readonly property real holeBottom: hasGeometryRecord ? Number(geometryRecord.holeBottom || holeY + 1) : Math.max(holeY + 1, height - bottomInset)
  readonly property real holeWidth: Math.max(1, holeRight - holeX)
  readonly property real holeHeight: Math.max(1, holeBottom - holeY)
  // Shadow caster hole consumes the same effective geometry transaction as
  // frame fill and border. With the frame off it collapses to the bar edge
  // alone, preserving the bar shadow independently of frame/menu visibility.
  readonly property bool hasShadowGeometryRecord: shadowGeometryRecord && typeof shadowGeometryRecord === "object"
  readonly property bool shadowFrameRenderable: !suppressed && (hasShadowGeometryRecord
    ? shadowGeometryRecord.framed === true : isRenderable)
  readonly property string shadowBarPosition: hasShadowGeometryRecord
    ? String(shadowGeometryRecord.barPosition || "") : (topBar ? "top" : bottomBar ? "bottom" : leftBar ? "left" : "right")
  readonly property int shadowBarSize: hasShadowGeometryRecord
    ? Math.max(0, Number(shadowGeometryRecord.barSize) || 0) : effectiveBarSize
  readonly property bool shadowTopEdgeOccupied: hasShadowGeometryRecord
    ? shadowGeometryRecord.topEdgeOccupied === true : effectiveTopEdgeOccupied
  readonly property bool shadowBottomEdgeOccupied: hasShadowGeometryRecord
    ? shadowGeometryRecord.bottomEdgeOccupied === true : effectiveBottomEdgeOccupied
  readonly property real shadowRecordHoleX: hasShadowGeometryRecord ? Number(shadowGeometryRecord.holeX || 0) : holeX
  readonly property real shadowRecordHoleY: hasShadowGeometryRecord ? Number(shadowGeometryRecord.holeY || 0) : holeY
  readonly property real shadowRecordHoleRight: hasShadowGeometryRecord ? Number(shadowGeometryRecord.holeRight || width) : holeRight
  readonly property real shadowRecordHoleBottom: hasShadowGeometryRecord ? Number(shadowGeometryRecord.holeBottom || height) : holeBottom
  readonly property real shadowRecordRadius: hasShadowGeometryRecord ? Math.max(0, Number(shadowGeometryRecord.contentRadius) || 0) : holeRadius
  readonly property real casterHoleX: shadowFrameRenderable
    ? (shadowHoleLeftOverride >= 0 ? shadowHoleLeftOverride : shadowRecordHoleX)
    : (shadowBarPosition === "left" ? shadowBarSize : 0)
  readonly property real casterHoleY: shadowFrameRenderable ? shadowRecordHoleY : (shadowBarPosition === "top" || shadowTopEdgeOccupied ? shadowBarSize : 0)
  readonly property real casterHoleRight: shadowFrameRenderable
    ? (shadowHoleRightOverride >= 0 ? shadowHoleRightOverride : shadowRecordHoleRight)
    : (shadowBarPosition === "right" ? Math.max(casterHoleX + 1, width - shadowBarSize) : width)
  readonly property real casterHoleBottom: shadowFrameRenderable ? shadowRecordHoleBottom : (shadowBarPosition === "bottom" || shadowBottomEdgeOccupied ? Math.max(casterHoleY + 1, height - shadowBarSize) : height)
  readonly property real casterHoleRadius: shadowFrameRenderable
    ? Math.max(0, Math.min(shadowRecordRadius, (casterHoleRight - casterHoleX) / 2, (casterHoleBottom - casterHoleY) / 2))
    : 0
  readonly property real minArcRadius: 0
  readonly property real holeRadius: effectiveMoldingPieces ? Math.max(0, Math.min(r, holeWidth / 2, holeHeight / 2)) : 0
  readonly property bool isRenderable: !suppressed
    && (hasGeometryRecord ? geometryRecord.framed === true : active)
    && width > 0 && height > 0 && holeWidth > 0 && holeHeight > 0
  readonly property real curveKappa: lacunaGeometry.curveKappa
  readonly property color effectiveFrameColor: isRenderable
    ? Qt.rgba(frameColor.r, frameColor.g, frameColor.b, 1)
    : "transparent"

  LacunaGeometry { id: lacunaGeometry }

  // Always mapped: within a Wayland layer, stacking is map order only.
  // Mapping this surface when the user enables the frame would stack it
  // above the bar and sidebar (mapped at startup) and paint the frame over
  // them. It stays mapped with fully transparent, click-through content
  // while inactive; isRenderable gates all paint.
  visible: true
  screen: targetScreen
  color: "transparent"
  WlrLayershell.namespace: "lacuna-bar-frame"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  mask: Region {}

  Item {
    anchors.fill: parent

    // Hidden silhouette for the drop shadow. Unlike the painted frame it
    // covers the bar strip too, so the blur is cast from the bar's inner
    // edge; the clip below keeps the rendered shadow off the bar itself.
    Shape {
      id: frameShadowCaster

      visible: false
      anchors.fill: parent
      layer.enabled: true
      asynchronous: false
      antialiasing: true
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        strokeWidth: -1
        fillColor: "#000000"
        fillRule: ShapePath.OddEvenFill
        startX: 0
        startY: 0

        PathLine { x: frameShadowCaster.width; y: 0 }
        PathLine { x: frameShadowCaster.width; y: frameShadowCaster.height }
        PathLine { x: 0; y: frameShadowCaster.height }
        PathLine { x: 0; y: 0 }

        PathMove {
          x: root.casterHoleX + root.casterHoleRadius
          y: root.casterHoleY
        }
        PathLine {
          x: root.casterHoleRight - root.casterHoleRadius
          y: root.casterHoleY
        }
        PathArc {
          x: root.casterHoleRight
          y: root.casterHoleY + root.casterHoleRadius
          radiusX: root.casterHoleRadius
          radiusY: root.casterHoleRadius
          direction: PathArc.Clockwise
        }
        PathLine {
          x: root.casterHoleRight
          y: root.casterHoleBottom - root.casterHoleRadius
        }
        PathArc {
          x: root.casterHoleRight - root.casterHoleRadius
          y: root.casterHoleBottom
          radiusX: root.casterHoleRadius
          radiusY: root.casterHoleRadius
          direction: PathArc.Clockwise
        }
        PathLine {
          x: root.casterHoleX + root.casterHoleRadius
          y: root.casterHoleBottom
        }
        PathArc {
          x: root.casterHoleX
          y: root.casterHoleBottom - root.casterHoleRadius
          radiusX: root.casterHoleRadius
          radiusY: root.casterHoleRadius
          direction: PathArc.Clockwise
        }
        PathLine {
          x: root.casterHoleX
          y: root.casterHoleY + root.casterHoleRadius
        }
        PathArc {
          x: root.casterHoleX + root.casterHoleRadius
          y: root.casterHoleY
          radiusX: root.casterHoleRadius
          radiusY: root.casterHoleRadius
          direction: PathArc.Clockwise
        }
      }
    }

    Item {
      id: frameShadowMask

      anchors.fill: parent
      visible: false
      layer.enabled: true

      ShaderEffectSource {
        anchors.fill: parent
        sourceItem: frameShadowCaster
        live: true
      }

      Rectangle {
        visible: root.attachedFlyoutVisible
          && root.attachedFlyoutWidth > 0 && root.attachedFlyoutHeight > 0
        x: root.attachedFlyoutX
        y: root.attachedFlyoutY
        width: root.attachedFlyoutWidth
        height: root.attachedFlyoutHeight
        color: "white"
      }
    }

    Item {
      id: shadowClip

      // Only the content side of the chrome shows the cast shadow; the bar
      // strip is excluded because the frame must never draw over the bar.
      x: root.shadowPaintLeft
      y: root.outerY
      width: Math.max(0, root.shadowPaintRight - root.shadowPaintLeft)
      height: Math.max(0, root.outerBottom - root.outerY)
      clip: true
      z: 0

      Item {
        x: -root.shadowPaintLeft
        y: -root.outerY
        width: root.width
        height: root.height

        LacunaDropShadow {
          source: frameShadowCaster
          shadowEnabled: !root.suppressed && root.shadowEnabled && root.width > 0 && root.height > 0
          shadowOpacity: root.shadowOpacity
          shadowBlur: root.shadowBlur
          blurMax: root.shadowBlurMax
          shadowHorizontalOffset: root.shadowOffsetX
          shadowVerticalOffset: root.shadowOffsetY
          shadowOnly: true
          shadowMaskSource: frameShadowMask
        }
      }
    }

    // The frame surface can stack above the host-owned bar. Constrain paint
    // to the content-side rectangle at the scene-graph level so Shape
    // antialiasing cannot leak a transient row into the bar while radius or
    // molding geometry is rebuilt.
    Item {
      id: framePaintClip

      x: root.paintLeft
      y: root.outerY
      width: Math.max(0, root.paintRight - root.paintLeft)
      height: Math.max(0, root.outerBottom - root.outerY)
      clip: true
      z: 1

      Item {
        x: -root.paintLeft
        y: -root.outerY
        width: root.width
        height: root.height

        Shape {
          id: frameSource

          anchors.fill: parent
          asynchronous: false
          antialiasing: true
          preferredRendererType: Shape.CurveRenderer

          ShapePath {
        strokeWidth: -1
        fillColor: root.effectiveFrameColor
        fillRule: ShapePath.OddEvenFill
        startX: root.isRenderable ? (root.outerX + root.minArcRadius) : -0.75
        startY: root.isRenderable ? root.outerY : -1

        PathLine {
          x: root.isRenderable ? (root.outerRight - root.minArcRadius) : 0
          y: root.isRenderable ? root.outerY : -1
        }
        PathArc {
          x: root.isRenderable ? root.outerRight : 0
          y: root.isRenderable ? (root.outerY + root.minArcRadius) : -0.75
          radiusX: root.isRenderable ? root.minArcRadius : 0
          radiusY: root.isRenderable ? root.minArcRadius : 0
          direction: PathArc.Clockwise
        }
        PathLine {
          x: root.isRenderable ? root.outerRight : 0
          y: root.isRenderable ? (root.outerBottom - root.minArcRadius) : 0
        }
        PathArc {
          x: root.isRenderable ? (root.outerRight - root.minArcRadius) : -0.25
          y: root.isRenderable ? root.outerBottom : 0
          radiusX: root.isRenderable ? root.minArcRadius : 0
          radiusY: root.isRenderable ? root.minArcRadius : 0
          direction: PathArc.Clockwise
        }
        PathLine {
          x: root.isRenderable ? (root.outerX + root.minArcRadius) : -1
          y: root.isRenderable ? root.outerBottom : 0
        }
        PathArc {
          x: root.isRenderable ? root.outerX : -1
          y: root.isRenderable ? (root.outerBottom - root.minArcRadius) : -0.25
          radiusX: root.isRenderable ? root.minArcRadius : 0
          radiusY: root.isRenderable ? root.minArcRadius : 0
          direction: PathArc.Clockwise
        }
        PathLine {
          x: root.isRenderable ? root.outerX : -1
          y: root.isRenderable ? (root.outerY + root.minArcRadius) : -1
        }
        PathArc {
          x: root.isRenderable ? (root.outerX + root.minArcRadius) : -0.75
          y: root.isRenderable ? root.outerY : -1
          radiusX: root.isRenderable ? root.minArcRadius : 0
          radiusY: root.isRenderable ? root.minArcRadius : 0
          direction: PathArc.Clockwise
        }

        PathMove {
          x: root.isRenderable ? (root.holeX + root.holeRadius) : -2.75
          y: root.isRenderable ? root.holeY : -3
        }
        PathLine {
          x: root.isRenderable ? (root.holeRight - root.holeRadius) : -2
          y: root.isRenderable ? root.holeY : -3
        }
        PathArc {
          x: root.isRenderable ? root.holeRight : -2
          y: root.isRenderable ? (root.holeY + root.holeRadius) : -2.75
          radiusX: root.isRenderable ? root.holeRadius : 0
          radiusY: root.isRenderable ? root.holeRadius : 0
          direction: PathArc.Clockwise
        }
        PathLine {
          x: root.isRenderable ? root.holeRight : -2
          y: root.isRenderable ? (root.holeBottom - root.holeRadius) : -2
        }
        PathArc {
          x: root.isRenderable ? (root.holeRight - root.holeRadius) : -2.25
          y: root.isRenderable ? root.holeBottom : -2
          radiusX: root.isRenderable ? root.holeRadius : 0
          radiusY: root.isRenderable ? root.holeRadius : 0
          direction: PathArc.Clockwise
        }
        PathLine {
          x: root.isRenderable ? (root.holeX + root.holeRadius) : -3
          y: root.isRenderable ? root.holeBottom : -2
        }
        PathArc {
          x: root.isRenderable ? root.holeX : -3
          y: root.isRenderable ? (root.holeBottom - root.holeRadius) : -2.25
          radiusX: root.isRenderable ? root.holeRadius : 0
          radiusY: root.isRenderable ? root.holeRadius : 0
          direction: PathArc.Clockwise
        }
        PathLine {
          x: root.isRenderable ? root.holeX : -3
          y: root.isRenderable ? (root.holeY + root.holeRadius) : -3
        }
        PathArc {
          x: root.isRenderable ? (root.holeX + root.holeRadius) : -2.75
          y: root.isRenderable ? root.holeY : -3
          radiusX: root.isRenderable ? root.holeRadius : 0
          radiusY: root.isRenderable ? root.holeRadius : 0
          direction: PathArc.Clockwise
        }
      }
    }

        // Compose border paint inside the same authoritative outer clip as the
        // frame fill. The translated item restores monitor-local coordinates.
        LacunaFrameBorderWindow {
          id: frameBorderPaint

          anchors.fill: parent
          z: 2
          active: root.active && root.borderEnabled
          suppressed: root.suppressed
          geometryRecord: root.geometryRecord
          barPosition: root.hasGeometryRecord ? String(root.geometryRecord.barPosition || "top") : root.barPosition
          barSize: root.effectiveBarSize
          frameThickness: root.t
          frameRadius: root.r
          moldingPieces: root.effectiveMoldingPieces
          borderColor: root.borderColor
          outputScale: root.targetScreen && root.targetScreen.devicePixelRatio !== undefined
            ? Number(root.targetScreen.devicePixelRatio) : 1
          topEdgeOccupied: root.effectiveTopEdgeOccupied
          bottomEdgeOccupied: root.effectiveBottomEdgeOccupied
          leftEdgeOccupied: root.effectiveLeftEdgeOccupied
          rightEdgeOccupied: root.effectiveRightEdgeOccupied
          leftOccupiedWidth: root.leftOcclusion
          rightOccupiedWidth: root.rightOcclusion
          attachedFlyoutVisible: root.attachedFlyoutVisible
          attachedFlyoutY: root.attachedFlyoutY
          attachedFlyoutHeight: root.attachedFlyoutHeight
          barPopoutBorderGap: root.barPopoutBorderGap
        }
      }
    }
  }
}
