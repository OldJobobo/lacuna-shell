import QtQuick
import QtQuick.Shapes
import "../lacuna.menu/components"

// In-window frame-border paint. Despite the legacy filename this is an Item,
// not a layer-shell window; LacunaFrameWindow owns the mapped surface.
Item {
  id: root

  property bool active: false
  property bool suppressed: false
  property var geometryRecord: null
  property string barPosition: "top"
  property int barSize: 0
  property int frameThickness: 8
  property int frameRadius: 14
  property bool moldingPieces: true
  property color borderColor: Qt.rgba(1, 1, 1, 1)
  property real borderWidth: 1
  property real outputScale: 1
  property bool topEdgeOccupied: false
  property bool bottomEdgeOccupied: false
  property bool leftEdgeOccupied: false
  property bool rightEdgeOccupied: false
  property real leftOccupiedWidth: 0
  property real rightOccupiedWidth: 0
  property bool attachedFlyoutVisible: false
  property real attachedFlyoutY: 0
  property real attachedFlyoutHeight: 0
  // Screen-axis interval reported by the active bar-owned flyout.
  property var barPopoutBorderGap: null

  readonly property bool hasGeometryRecord: geometryRecord && typeof geometryRecord === "object"
  readonly property int t: hasGeometryRecord ? Math.max(1, Number(geometryRecord.thickness) || 1) : Math.max(1, frameThickness)
  readonly property int r: hasGeometryRecord ? Math.max(0, Number(geometryRecord.contentRadius) || 0) : Math.max(0, frameRadius)
  readonly property bool effectiveTopEdgeOccupied: hasGeometryRecord ? geometryRecord.topEdgeOccupied === true : topEdgeOccupied
  readonly property bool effectiveBottomEdgeOccupied: hasGeometryRecord ? geometryRecord.bottomEdgeOccupied === true : bottomEdgeOccupied
  readonly property bool effectiveLeftEdgeOccupied: hasGeometryRecord ? geometryRecord.leftEdgeOccupied === true : leftEdgeOccupied
  readonly property bool effectiveRightEdgeOccupied: hasGeometryRecord ? geometryRecord.rightEdgeOccupied === true : rightEdgeOccupied
  readonly property real leftOcclusion: hasGeometryRecord ? Math.max(0, Number(geometryRecord.leftOccupiedWidth) || 0) : (effectiveLeftEdgeOccupied ? Math.max(0, leftOccupiedWidth) : 0)
  readonly property real rightOcclusion: hasGeometryRecord ? Math.max(0, Number(geometryRecord.rightOccupiedWidth) || 0) : (effectiveRightEdgeOccupied ? Math.max(0, rightOccupiedWidth) : 0)
  readonly property string effectiveBarPosition: hasGeometryRecord ? String(geometryRecord.barPosition || "top") : barPosition
  readonly property bool topBar: effectiveBarPosition === "top"
  readonly property bool bottomBar: effectiveBarPosition === "bottom"
  readonly property bool leftBar: effectiveBarPosition === "left"
  readonly property bool rightBar: effectiveBarPosition === "right"
  readonly property int effectiveBarSize: hasGeometryRecord ? Math.max(0, Number(geometryRecord.barSize) || 0) : Math.max(0, barSize)
  readonly property int topInset: topBar || effectiveTopEdgeOccupied ? effectiveBarSize : t
  readonly property int bottomInset: bottomBar || effectiveBottomEdgeOccupied ? effectiveBarSize : t
  readonly property int leftInset: leftBar ? effectiveBarSize : t
  readonly property int rightInset: rightBar ? effectiveBarSize : t
  readonly property real holeX: hasGeometryRecord ? Number(geometryRecord.holeX) : Math.max(0, effectiveLeftEdgeOccupied ? leftOcclusion : leftInset)
  readonly property real holeY: hasGeometryRecord ? Number(geometryRecord.holeY) : Math.max(0, topInset)
  readonly property real holeRight: hasGeometryRecord ? Number(geometryRecord.holeRight) : Math.max(holeX, width - (effectiveRightEdgeOccupied ? rightOcclusion : rightInset))
  readonly property real holeBottom: hasGeometryRecord ? Number(geometryRecord.holeBottom) : Math.max(holeY, height - bottomInset)
  readonly property real holeWidth: Math.max(0, holeRight - holeX)
  readonly property real holeHeight: Math.max(0, holeBottom - holeY)
  readonly property bool effectiveMoldingPieces: hasGeometryRecord ? r > 0 : moldingPieces
  readonly property real holeRadius: effectiveMoldingPieces ? Math.max(0, Math.min(r, holeWidth / 2, holeHeight / 2)) : 0
  readonly property real borderInset: Math.max(0, borderWidth / 2)
  readonly property real moldingBorderWidth: borderWidth + (outputScale <= 1.25 ? 0.5 : 0)
  readonly property real borderLeft: holeX + borderInset
  readonly property real borderTop: holeY + borderInset
  readonly property real borderRight: holeRight - borderInset
  readonly property real borderBottom: holeBottom - borderInset
  readonly property real borderRadius: Math.max(0, holeRadius - borderInset)
  readonly property string barGapEdge: barPopoutBorderGap && barPopoutBorderGap.edge
    ? String(barPopoutBorderGap.edge) : ""
  readonly property real barGapStart: barPopoutBorderGap
    ? Math.max(0, Number(barPopoutBorderGap.start) || 0) : 0
  readonly property real barGapEnd: barPopoutBorderGap
    ? Math.max(barGapStart, barGapStart + Math.max(0, Number(barPopoutBorderGap.length) || 0)) : barGapStart
  readonly property bool barGapActive: barGapEdge !== "" && barGapEnd > barGapStart
  readonly property real horizontalGapMinimum: borderLeft + borderRadius
  readonly property real horizontalGapMaximum: borderRight - borderRadius
  readonly property real verticalGapMinimum: borderTop + borderRadius
  readonly property real verticalGapMaximum: borderBottom - borderRadius
  readonly property real clampedBarHorizontalGapStart: Math.max(horizontalGapMinimum, Math.min(horizontalGapMaximum, barGapStart))
  readonly property real clampedBarHorizontalGapEnd: Math.max(clampedBarHorizontalGapStart, Math.min(horizontalGapMaximum, barGapEnd))
  readonly property real clampedBarVerticalGapStart: Math.max(verticalGapMinimum, Math.min(verticalGapMaximum, barGapStart))
  readonly property real clampedBarVerticalGapEnd: Math.max(clampedBarVerticalGapStart, Math.min(verticalGapMaximum, barGapEnd))
  readonly property bool topBarGapVisible: barGapActive && barGapEdge === "top" && clampedBarHorizontalGapEnd > clampedBarHorizontalGapStart
  readonly property bool bottomBarGapVisible: barGapActive && barGapEdge === "bottom" && clampedBarHorizontalGapEnd > clampedBarHorizontalGapStart
  readonly property real topHorizontalLeftEndX: topBarGapVisible ? clampedBarHorizontalGapStart : horizontalGapMaximum
  readonly property real topHorizontalRightStartX: topBarGapVisible ? clampedBarHorizontalGapEnd : horizontalGapMaximum
  readonly property real bottomHorizontalRightEndX: bottomBarGapVisible ? clampedBarHorizontalGapEnd : horizontalGapMinimum
  readonly property real bottomHorizontalLeftStartX: bottomBarGapVisible ? clampedBarHorizontalGapStart : horizontalGapMinimum
  readonly property bool leftAttachmentGapVisible: effectiveLeftEdgeOccupied && attachedFlyoutVisible && attachedFlyoutHeight > 0
  readonly property bool rightAttachmentGapVisible: effectiveRightEdgeOccupied && attachedFlyoutVisible && attachedFlyoutHeight > 0
  readonly property real attachmentGapTop: Math.max(verticalGapMinimum, attachedFlyoutY + borderInset)
  readonly property real attachmentGapBottom: Math.min(verticalGapMaximum, attachedFlyoutY + attachedFlyoutHeight - borderInset)
  readonly property bool attachmentGapRenderable: attachmentGapBottom > attachmentGapTop + borderWidth
  readonly property bool rightBarGapVisible: barGapActive && barGapEdge === "right" && clampedBarVerticalGapEnd > clampedBarVerticalGapStart
  readonly property bool leftBarGapVisible: barGapActive && barGapEdge === "left" && clampedBarVerticalGapEnd > clampedBarVerticalGapStart
  readonly property var rightVerticalGaps: composeVerticalGaps(
    rightAttachmentGapVisible && attachmentGapRenderable, attachmentGapTop, attachmentGapBottom,
    rightBarGapVisible, clampedBarVerticalGapStart, clampedBarVerticalGapEnd)
  readonly property var leftVerticalGaps: composeVerticalGaps(
    leftAttachmentGapVisible && attachmentGapRenderable, attachmentGapTop, attachmentGapBottom,
    leftBarGapVisible, clampedBarVerticalGapStart, clampedBarVerticalGapEnd)
  readonly property real rightVerticalUpperEndY: rightVerticalGaps.firstStart
  readonly property real rightVerticalLowerStartY: rightVerticalGaps.firstEnd
  readonly property real rightVerticalSecondUpperEndY: rightVerticalGaps.secondStart
  readonly property real rightVerticalSecondLowerStartY: rightVerticalGaps.secondEnd
  readonly property real leftVerticalLowerEndY: leftVerticalGaps.secondEnd
  readonly property real leftVerticalUpperStartY: leftVerticalGaps.secondStart
  readonly property real leftVerticalSecondLowerEndY: leftVerticalGaps.firstEnd
  readonly property real leftVerticalSecondUpperStartY: leftVerticalGaps.firstStart
  readonly property bool isRenderable: active && !suppressed
    && (!hasGeometryRecord || geometryRecord.framed === true)
    && width > 0 && height > 0
    && borderRight > borderLeft && borderBottom > borderTop
  readonly property real curveKappa: lacunaGeometry.curveKappa

  LacunaGeometry { id: lacunaGeometry }

  function composeVerticalGaps(firstVisible, firstStart, firstEnd, secondVisible, secondStart, secondEnd) {
    var gaps = []
    if (firstVisible) gaps.push({ start: firstStart, end: firstEnd })
    if (secondVisible) gaps.push({ start: secondStart, end: secondEnd })
    gaps.sort(function(a, b) { return a.start - b.start })
    if (gaps.length === 0) {
      return { firstStart: verticalGapMaximum, firstEnd: verticalGapMaximum,
        secondStart: verticalGapMaximum, secondEnd: verticalGapMaximum }
    }
    if (gaps.length === 1) {
      return { firstStart: gaps[0].start, firstEnd: gaps[0].end,
        secondStart: verticalGapMaximum, secondEnd: verticalGapMaximum }
    }
    if (gaps[1].start <= gaps[0].end) {
      return { firstStart: gaps[0].start, firstEnd: Math.max(gaps[0].end, gaps[1].end),
        secondStart: verticalGapMaximum, secondEnd: verticalGapMaximum }
    }
    return { firstStart: gaps[0].start, firstEnd: gaps[0].end,
      secondStart: gaps[1].start, secondEnd: gaps[1].end }
  }

  visible: isRenderable

  Shape {
    id: frameBorderSource

    anchors.fill: parent
    visible: root.isRenderable
    asynchronous: false
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.borderColor
      strokeWidth: root.borderWidth
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.MiterJoin
      startX: root.borderLeft + root.borderRadius
      startY: root.borderTop

      PathLine { x: root.topHorizontalLeftEndX; y: root.borderTop }
      PathMove { x: root.topHorizontalRightStartX; y: root.borderTop }
      PathLine { x: root.borderRight - root.borderRadius; y: root.borderTop }
      PathCubic {
        x: root.borderRight
        y: root.borderTop + root.borderRadius
        control1X: root.borderRight - root.borderRadius * (1 - root.curveKappa)
        control1Y: root.borderTop
        control2X: root.borderRight
        control2Y: root.borderTop + root.borderRadius * (1 - root.curveKappa)
      }
      PathLine {
        x: root.borderRight
        y: root.rightVerticalUpperEndY
      }
      PathMove { x: root.borderRight; y: root.rightVerticalLowerStartY }
      PathLine { x: root.borderRight; y: root.rightVerticalSecondUpperEndY }
      PathMove { x: root.borderRight; y: root.rightVerticalSecondLowerStartY }
      PathLine { x: root.borderRight; y: root.borderBottom - root.borderRadius }
      PathCubic {
        x: root.borderRight - root.borderRadius
        y: root.borderBottom
        control1X: root.borderRight
        control1Y: root.borderBottom - root.borderRadius * (1 - root.curveKappa)
        control2X: root.borderRight - root.borderRadius * (1 - root.curveKappa)
        control2Y: root.borderBottom
      }
      PathLine { x: root.bottomHorizontalRightEndX; y: root.borderBottom }
      PathMove { x: root.bottomHorizontalLeftStartX; y: root.borderBottom }
      PathLine { x: root.borderLeft + root.borderRadius; y: root.borderBottom }
      PathCubic {
        x: root.borderLeft
        y: root.borderBottom - root.borderRadius
        control1X: root.borderLeft + root.borderRadius * (1 - root.curveKappa)
        control1Y: root.borderBottom
        control2X: root.borderLeft
        control2Y: root.borderBottom - root.borderRadius * (1 - root.curveKappa)
      }
      PathLine { x: root.borderLeft; y: root.leftVerticalLowerEndY }
      PathMove { x: root.borderLeft; y: root.leftVerticalUpperStartY }
      PathLine { x: root.borderLeft; y: root.leftVerticalSecondLowerEndY }
      PathMove { x: root.borderLeft; y: root.leftVerticalSecondUpperStartY }
      PathLine { x: root.borderLeft; y: root.borderTop + root.borderRadius }
      PathCubic {
        x: root.borderLeft + root.borderRadius
        y: root.borderTop
        control1X: root.borderLeft
        control1Y: root.borderTop + root.borderRadius * (1 - root.curveKappa)
        control2X: root.borderLeft + root.borderRadius * (1 - root.curveKappa)
        control2Y: root.borderTop
      }
    }

    // At 1x output scale, a one-pixel cubic spreads its coverage across the
    // pixel grid and reads thinner/jaggier than the connected axis-aligned
    // rails. Repaint only the four frame molding corners with a half-pixel
    // optical allowance; straight frame-border segments remain one pixel.
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.borderColor
      strokeWidth: root.borderRadius > 0 ? root.moldingBorderWidth : 0
      capStyle: ShapePath.FlatCap

      startX: root.borderRight - root.borderRadius
      startY: root.borderTop
      PathCubic {
        x: root.borderRight
        y: root.borderTop + root.borderRadius
        control1X: root.borderRight - root.borderRadius * (1 - root.curveKappa)
        control1Y: root.borderTop
        control2X: root.borderRight
        control2Y: root.borderTop + root.borderRadius * (1 - root.curveKappa)
      }
      PathMove {
        x: root.borderRight
        y: root.borderBottom - root.borderRadius
      }
      PathCubic {
        x: root.borderRight - root.borderRadius
        y: root.borderBottom
        control1X: root.borderRight
        control1Y: root.borderBottom - root.borderRadius * (1 - root.curveKappa)
        control2X: root.borderRight - root.borderRadius * (1 - root.curveKappa)
        control2Y: root.borderBottom
      }
      PathMove {
        x: root.borderLeft + root.borderRadius
        y: root.borderBottom
      }
      PathCubic {
        x: root.borderLeft
        y: root.borderBottom - root.borderRadius
        control1X: root.borderLeft + root.borderRadius * (1 - root.curveKappa)
        control1Y: root.borderBottom
        control2X: root.borderLeft
        control2Y: root.borderBottom - root.borderRadius * (1 - root.curveKappa)
      }
      PathMove {
        x: root.borderLeft
        y: root.borderTop + root.borderRadius
      }
      PathCubic {
        x: root.borderLeft + root.borderRadius
        y: root.borderTop
        control1X: root.borderLeft
        control1Y: root.borderTop + root.borderRadius * (1 - root.curveKappa)
        control2X: root.borderLeft + root.borderRadius * (1 - root.curveKappa)
        control2Y: root.borderTop
      }
    }
  }
}
