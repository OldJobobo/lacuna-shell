import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
  id: root

  property int panelWidth: 344
  property int panelHeight: 420
  property int joinRadius: 13
  property int cornerRadius: 14
  property color panelColor: "#101315"
  property string attachmentEdge: "top"
  property var bar: null
  property bool borderEnabled: bar && bar.frameBorderEnabled === true
  property color borderColor: bar && bar.frameBorderColor ? bar.frameBorderColor : Color.popups.border
  property real borderWidth: 1
  // Popup windows overlap their bar edge by one pixel so the connector fill
  // and its outline meet the bar without a compositor-sized seam.
  readonly property int attachmentOverlap: bar && bar.fullFrameEnabled === true ? 0 : 1
  // Let the bar rail resume one pixel beneath the far connector endpoint. This
  // hides the half-pixel Shape cap at the right-hand top-bar join.
  readonly property real borderGapLength: horizontalAttachment
    ? Math.max(0, fullWidth - 1) : Math.max(0, fullHeight - 1)

  LacunaGeometry { id: lacunaGeometry }
  readonly property real curveKappa: lacunaGeometry.curveKappa
  readonly property bool horizontalAttachment: attachmentEdge === "top" || attachmentEdge === "bottom"
  readonly property int fullWidth: panelWidth + (horizontalAttachment ? joinRadius * 2 : joinRadius)
  readonly property int fullHeight: panelHeight + (horizontalAttachment ? joinRadius : joinRadius * 2)
  readonly property int panelLeft: attachmentEdge === "left" ? joinRadius : (horizontalAttachment ? joinRadius : 0)
  readonly property int panelTop: attachmentEdge === "top" ? joinRadius : (horizontalAttachment ? 0 : joinRadius)
  readonly property int panelRight: panelLeft + panelWidth
  readonly property int panelBottom: panelTop + panelHeight
  readonly property real borderInset: Math.max(0, borderWidth / 2)
  readonly property real strokeCornerRadius: Math.max(0, cornerRadius - borderInset)

  implicitWidth: fullWidth
  implicitHeight: fullHeight

  function constrainedHorizontalPopupX(preferredX, windowWidth, popupWidth, surfaceOffsetX, popupMargin) {
    var margin = Math.max(0, Number(popupMargin) || 0)
    var normalMin = margin
    var normalMax = Math.max(normalMin, Number(windowWidth) - Number(popupWidth) - margin)
    var insets = bar && bar.popupAvoidanceInsets ? bar.popupAvoidanceInsets : ({})
    var leftInset = Math.max(0, Number(insets.left) || 0)
    var rightInset = Math.max(0, Number(insets.right) || 0)
    var surfaceOffset = Math.max(0, Number(surfaceOffsetX) || 0)
    var avoidedMin = Math.max(normalMin, leftInset - surfaceOffset)
    var avoidedMax = Math.min(normalMax,
      Number(windowWidth) - rightInset - surfaceOffset - root.fullWidth)
    // If the output cannot fit both surfaces, retain normal screen clamping;
    // otherwise keep the complete molded flyout outside the expanded sidebar.
    if (avoidedMin > avoidedMax)
      return Math.max(normalMin, Math.min(Number(preferredX), normalMax))
    return Math.max(avoidedMin, Math.min(Number(preferredX), avoidedMax))
  }

  Shape {
    anchors.fill: parent
    visible: root.attachmentEdge === "top"
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: root.panelColor; strokeWidth: 0; startX: 0; startY: 0
      PathLine { x: root.fullWidth; y: 0 }
      PathCubic {
        x: root.panelRight; y: root.panelTop
        control1X: root.fullWidth - root.joinRadius * root.curveKappa; control1Y: 0
        control2X: root.panelRight; control2Y: root.joinRadius * (1 - root.curveKappa)
      }
      PathLine { x: root.panelRight; y: root.panelBottom - root.cornerRadius }
      PathCubic {
        x: root.panelRight - root.cornerRadius; y: root.panelBottom
        control1X: root.panelRight; control1Y: root.panelBottom - root.cornerRadius * (1 - root.curveKappa)
        control2X: root.panelRight - root.cornerRadius * (1 - root.curveKappa); control2Y: root.panelBottom
      }
      PathLine { x: root.panelLeft + root.cornerRadius; y: root.panelBottom }
      PathCubic {
        x: root.panelLeft; y: root.panelBottom - root.cornerRadius
        control1X: root.panelLeft + root.cornerRadius * (1 - root.curveKappa); control1Y: root.panelBottom
        control2X: root.panelLeft; control2Y: root.panelBottom - root.cornerRadius * (1 - root.curveKappa)
      }
      PathLine { x: root.panelLeft; y: root.panelTop }
      PathCubic {
        x: 0; y: 0
        control1X: root.panelLeft; control1Y: root.joinRadius * (1 - root.curveKappa)
        control2X: root.joinRadius * root.curveKappa; control2Y: 0
      }
    }
  }

  Shape {
    anchors.fill: parent
    visible: root.attachmentEdge === "bottom"
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: root.panelColor; strokeWidth: 0; startX: 0; startY: root.fullHeight
      PathLine { x: root.fullWidth; y: root.fullHeight }
      PathCubic {
        x: root.panelRight; y: root.panelBottom
        control1X: root.fullWidth - root.joinRadius * root.curveKappa; control1Y: root.fullHeight
        control2X: root.panelRight; control2Y: root.fullHeight - root.joinRadius * (1 - root.curveKappa)
      }
      PathLine { x: root.panelRight; y: root.panelTop + root.cornerRadius }
      PathCubic {
        x: root.panelRight - root.cornerRadius; y: root.panelTop
        control1X: root.panelRight; control1Y: root.panelTop + root.cornerRadius * (1 - root.curveKappa)
        control2X: root.panelRight - root.cornerRadius * (1 - root.curveKappa); control2Y: root.panelTop
      }
      PathLine { x: root.panelLeft + root.cornerRadius; y: root.panelTop }
      PathCubic {
        x: root.panelLeft; y: root.panelTop + root.cornerRadius
        control1X: root.panelLeft + root.cornerRadius * (1 - root.curveKappa); control1Y: root.panelTop
        control2X: root.panelLeft; control2Y: root.panelTop + root.cornerRadius * (1 - root.curveKappa)
      }
      PathLine { x: root.panelLeft; y: root.panelBottom }
      PathCubic {
        x: 0; y: root.fullHeight
        control1X: root.panelLeft; control1Y: root.fullHeight - root.joinRadius * (1 - root.curveKappa)
        control2X: root.joinRadius * root.curveKappa; control2Y: root.fullHeight
      }
    }
  }

  Shape {
    anchors.fill: parent
    visible: root.attachmentEdge === "left"
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: root.panelColor; strokeWidth: 0; startX: 0; startY: 0
      PathLine { x: 0; y: root.fullHeight }
      PathCubic {
        x: root.panelLeft; y: root.panelBottom
        control1X: 0; control1Y: root.fullHeight - root.joinRadius * root.curveKappa
        control2X: root.joinRadius * (1 - root.curveKappa); control2Y: root.panelBottom
      }
      PathLine { x: root.panelRight - root.cornerRadius; y: root.panelBottom }
      PathCubic {
        x: root.panelRight; y: root.panelBottom - root.cornerRadius
        control1X: root.panelRight - root.cornerRadius * (1 - root.curveKappa); control1Y: root.panelBottom
        control2X: root.panelRight; control2Y: root.panelBottom - root.cornerRadius * (1 - root.curveKappa)
      }
      PathLine { x: root.panelRight; y: root.panelTop + root.cornerRadius }
      PathCubic {
        x: root.panelRight - root.cornerRadius; y: root.panelTop
        control1X: root.panelRight; control1Y: root.panelTop + root.cornerRadius * (1 - root.curveKappa)
        control2X: root.panelRight - root.cornerRadius * (1 - root.curveKappa); control2Y: root.panelTop
      }
      PathLine { x: root.panelLeft; y: root.panelTop }
      PathCubic {
        x: 0; y: 0
        control1X: root.joinRadius * (1 - root.curveKappa); control1Y: root.panelTop
        control2X: 0; control2Y: root.joinRadius * root.curveKappa
      }
    }
  }

  Shape {
    anchors.fill: parent
    visible: root.attachmentEdge === "right"
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: root.panelColor; strokeWidth: 0; startX: root.fullWidth; startY: 0
      PathLine { x: root.fullWidth; y: root.fullHeight }
      PathCubic {
        x: root.panelRight; y: root.panelBottom
        control1X: root.fullWidth; control1Y: root.fullHeight - root.joinRadius * root.curveKappa
        control2X: root.panelRight + root.joinRadius * root.curveKappa; control2Y: root.panelBottom
      }
      PathLine { x: root.panelLeft + root.cornerRadius; y: root.panelBottom }
      PathCubic {
        x: root.panelLeft; y: root.panelBottom - root.cornerRadius
        control1X: root.panelLeft + root.cornerRadius * (1 - root.curveKappa); control1Y: root.panelBottom
        control2X: root.panelLeft; control2Y: root.panelBottom - root.cornerRadius * (1 - root.curveKappa)
      }
      PathLine { x: root.panelLeft; y: root.panelTop + root.cornerRadius }
      PathCubic {
        x: root.panelLeft + root.cornerRadius; y: root.panelTop
        control1X: root.panelLeft; control1Y: root.panelTop + root.cornerRadius * (1 - root.curveKappa)
        control2X: root.panelLeft + root.cornerRadius * (1 - root.curveKappa); control2Y: root.panelTop
      }
      PathLine { x: root.panelRight; y: root.panelTop }
      PathCubic {
        x: root.fullWidth; y: 0
        control1X: root.panelRight + root.joinRadius * root.curveKappa; control1Y: root.panelTop
        control2X: root.fullWidth; control2Y: root.joinRadius * root.curveKappa
      }
    }
  }

  // Continue the frame outline around the exposed panel edges and connector
  // molding curves while leaving the attachment span open. The one-pixel
  // overlap joins those curve endpoints cleanly to the bar border.
  Shape {
    anchors.fill: parent
    visible: root.borderEnabled && root.attachmentEdge === "top"
    asynchronous: false
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.borderColor
      strokeWidth: root.borderWidth
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.MiterJoin
      startX: root.fullWidth
      startY: root.borderInset
      PathLine { x: root.fullWidth - root.borderInset; y: root.borderInset }
      PathCubic {
        x: root.panelRight - root.borderInset; y: root.panelTop + root.borderInset
        control1X: root.fullWidth - root.borderInset - root.joinRadius * root.curveKappa; control1Y: root.borderInset
        control2X: root.panelRight - root.borderInset; control2Y: root.panelTop + root.borderInset - root.joinRadius * root.curveKappa
      }
      PathLine { x: root.panelRight - root.borderInset; y: root.panelBottom - root.cornerRadius }
      PathCubic {
        x: root.panelRight - root.cornerRadius; y: root.panelBottom - root.borderInset
        control1X: root.panelRight - root.borderInset; control1Y: root.panelBottom - root.cornerRadius + root.strokeCornerRadius * (1 - root.curveKappa)
        control2X: root.panelRight - root.cornerRadius + root.strokeCornerRadius * (1 - root.curveKappa); control2Y: root.panelBottom - root.borderInset
      }
      PathLine { x: root.panelLeft + root.cornerRadius; y: root.panelBottom - root.borderInset }
      PathCubic {
        x: root.panelLeft + root.borderInset; y: root.panelBottom - root.cornerRadius
        control1X: root.panelLeft + root.cornerRadius - root.strokeCornerRadius * (1 - root.curveKappa); control1Y: root.panelBottom - root.borderInset
        control2X: root.panelLeft + root.borderInset; control2Y: root.panelBottom - root.cornerRadius + root.strokeCornerRadius * (1 - root.curveKappa)
      }
      PathLine { x: root.panelLeft + root.borderInset; y: root.panelTop + root.borderInset }
      PathCubic {
        x: root.borderInset; y: root.borderInset
        control1X: root.panelLeft + root.borderInset; control1Y: root.panelTop + root.borderInset - root.joinRadius * root.curveKappa
        control2X: root.borderInset + root.joinRadius * root.curveKappa; control2Y: root.borderInset
      }
    }
  }

  Shape {
    anchors.fill: parent
    visible: root.borderEnabled && root.attachmentEdge === "bottom"
    asynchronous: false
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.borderColor
      strokeWidth: root.borderWidth
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.MiterJoin
      startX: root.fullWidth - root.borderInset
      startY: root.fullHeight - root.borderInset
      PathCubic {
        x: root.panelRight - root.borderInset; y: root.panelBottom - root.borderInset
        control1X: root.fullWidth - root.borderInset - root.joinRadius * root.curveKappa; control1Y: root.fullHeight - root.borderInset
        control2X: root.panelRight - root.borderInset; control2Y: root.panelBottom - root.borderInset + root.joinRadius * root.curveKappa
      }
      PathLine { x: root.panelRight - root.borderInset; y: root.panelTop + root.cornerRadius }
      PathCubic {
        x: root.panelRight - root.cornerRadius; y: root.panelTop + root.borderInset
        control1X: root.panelRight - root.borderInset; control1Y: root.panelTop + root.cornerRadius - root.strokeCornerRadius * (1 - root.curveKappa)
        control2X: root.panelRight - root.cornerRadius + root.strokeCornerRadius * (1 - root.curveKappa); control2Y: root.panelTop + root.borderInset
      }
      PathLine { x: root.panelLeft + root.cornerRadius; y: root.panelTop + root.borderInset }
      PathCubic {
        x: root.panelLeft + root.borderInset; y: root.panelTop + root.cornerRadius
        control1X: root.panelLeft + root.cornerRadius - root.strokeCornerRadius * (1 - root.curveKappa); control1Y: root.panelTop + root.borderInset
        control2X: root.panelLeft + root.borderInset; control2Y: root.panelTop + root.cornerRadius - root.strokeCornerRadius * (1 - root.curveKappa)
      }
      PathLine { x: root.panelLeft + root.borderInset; y: root.panelBottom - root.borderInset }
      PathCubic {
        x: root.borderInset; y: root.fullHeight - root.borderInset
        control1X: root.panelLeft + root.borderInset; control1Y: root.panelBottom - root.borderInset + root.joinRadius * root.curveKappa
        control2X: root.borderInset + root.joinRadius * root.curveKappa; control2Y: root.fullHeight - root.borderInset
      }
    }
  }

  Shape {
    anchors.fill: parent
    visible: root.borderEnabled && root.attachmentEdge === "left"
    asynchronous: false
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.borderColor
      strokeWidth: root.borderWidth
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.MiterJoin
      startX: root.borderInset
      startY: root.fullHeight - root.borderInset
      PathCubic {
        x: root.panelLeft + root.borderInset; y: root.panelBottom - root.borderInset
        control1X: root.borderInset; control1Y: root.fullHeight - root.borderInset - root.joinRadius * root.curveKappa
        control2X: root.panelLeft + root.borderInset - root.joinRadius * root.curveKappa; control2Y: root.panelBottom - root.borderInset
      }
      PathLine { x: root.panelRight - root.cornerRadius; y: root.panelBottom - root.borderInset }
      PathCubic {
        x: root.panelRight - root.borderInset; y: root.panelBottom - root.cornerRadius
        control1X: root.panelRight - root.cornerRadius + root.strokeCornerRadius * (1 - root.curveKappa); control1Y: root.panelBottom - root.borderInset
        control2X: root.panelRight - root.borderInset; control2Y: root.panelBottom - root.cornerRadius + root.strokeCornerRadius * (1 - root.curveKappa)
      }
      PathLine { x: root.panelRight - root.borderInset; y: root.panelTop + root.cornerRadius }
      PathCubic {
        x: root.panelRight - root.cornerRadius; y: root.panelTop + root.borderInset
        control1X: root.panelRight - root.borderInset; control1Y: root.panelTop + root.cornerRadius - root.strokeCornerRadius * (1 - root.curveKappa)
        control2X: root.panelRight - root.cornerRadius + root.strokeCornerRadius * (1 - root.curveKappa); control2Y: root.panelTop + root.borderInset
      }
      PathLine { x: root.panelLeft + root.borderInset; y: root.panelTop + root.borderInset }
      PathCubic {
        x: root.borderInset; y: root.borderInset
        control1X: root.panelLeft + root.borderInset - root.joinRadius * root.curveKappa; control1Y: root.panelTop + root.borderInset
        control2X: root.borderInset; control2Y: root.borderInset + root.joinRadius * root.curveKappa
      }
    }
  }

  Shape {
    anchors.fill: parent
    visible: root.borderEnabled && root.attachmentEdge === "right"
    asynchronous: false
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.borderColor
      strokeWidth: root.borderWidth
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.MiterJoin
      startX: root.fullWidth - root.borderInset
      startY: root.fullHeight - root.borderInset
      PathCubic {
        x: root.panelRight - root.borderInset; y: root.panelBottom - root.borderInset
        control1X: root.fullWidth - root.borderInset; control1Y: root.fullHeight - root.borderInset - root.joinRadius * root.curveKappa
        control2X: root.panelRight - root.borderInset + root.joinRadius * root.curveKappa; control2Y: root.panelBottom - root.borderInset
      }
      PathLine { x: root.panelLeft + root.cornerRadius; y: root.panelBottom - root.borderInset }
      PathCubic {
        x: root.panelLeft + root.borderInset; y: root.panelBottom - root.cornerRadius
        control1X: root.panelLeft + root.cornerRadius - root.strokeCornerRadius * (1 - root.curveKappa); control1Y: root.panelBottom - root.borderInset
        control2X: root.panelLeft + root.borderInset; control2Y: root.panelBottom - root.cornerRadius + root.strokeCornerRadius * (1 - root.curveKappa)
      }
      PathLine { x: root.panelLeft + root.borderInset; y: root.panelTop + root.cornerRadius }
      PathCubic {
        x: root.panelLeft + root.cornerRadius; y: root.panelTop + root.borderInset
        control1X: root.panelLeft + root.borderInset; control1Y: root.panelTop + root.cornerRadius - root.strokeCornerRadius * (1 - root.curveKappa)
        control2X: root.panelLeft + root.cornerRadius - root.strokeCornerRadius * (1 - root.curveKappa); control2Y: root.panelTop + root.borderInset
      }
      PathLine { x: root.panelRight - root.borderInset; y: root.panelTop + root.borderInset }
      PathCubic {
        x: root.fullWidth - root.borderInset; y: root.borderInset
        control1X: root.panelRight - root.borderInset + root.joinRadius * root.curveKappa; control1Y: root.panelTop + root.borderInset
        control2X: root.fullWidth - root.borderInset; control2Y: root.borderInset + root.joinRadius * root.curveKappa
      }
    }
  }
}
