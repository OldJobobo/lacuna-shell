import QtQuick

QtObject {
  id: root

  property real panelWidth: 0
  property real surfaceX: 0
  property real sidebarHeight: 0
  property bool anchorRight: false

  property real connectorWidth: 0
  property real connectorOverlap: 0
  property real panelRadius: 0
  property real flyoutY: 0
  property real flyoutWidth: 0
  property real flyoutHeight: 0
  property string geometrySemanticKey: ""
  property real flyoutProgress: 0
  property bool flyoutRenderable: false
  property bool geometryTransitionEnabled: false
  property bool reducedMotion: false
  property int geometryAnimationDuration: 180
  property real panelGeometryProgress: 1
  property int panelGeometryRevision: 0
  property string targetPanelGeometryKey: ""
  property bool geometryRequestScheduled: false
  property var fromPanelGeometry: emptyPanelGeometry()
  property var targetPanelGeometry: emptyPanelGeometry()

  readonly property real connectorEpsilon: 0.001
  readonly property real clampedFlyoutProgress: Math.max(0, Math.min(1, flyoutProgress))
  readonly property real clampedPanelGeometryProgress: Math.max(0, Math.min(1, panelGeometryProgress))
  readonly property var requestedPanelGeometry: makePanelGeometry(
    flyoutY, flyoutWidth, flyoutHeight, connectorWidth, connectorOverlap, anchorRight, panelRadius)
  readonly property string panelGeometryKey: [
    geometrySemanticKey,
    Number(flyoutY),
    Number(flyoutWidth),
    Number(flyoutHeight),
    Number(connectorWidth),
    Number(connectorOverlap),
    Number(panelRadius),
    anchorRight
  ].join("|")
  readonly property var effectivePanelGeometry: interpolatePanelGeometry(
    fromPanelGeometry, targetPanelGeometry, clampedPanelGeometryProgress)
  readonly property bool panelGeometryTransitionActive: panelGeometryProgress < 0.999
  readonly property var geometryAnimationController: panelGeometryAnimation

  readonly property real effectiveFlyoutY: Number(effectivePanelGeometry.flyoutY || 0)
  readonly property real effectiveFlyoutWidth: Number(effectivePanelGeometry.flyoutWidth || 0)
  readonly property real effectiveFlyoutHeight: Number(effectivePanelGeometry.flyoutHeight || 0)
  readonly property real effectiveConnectorWidth: Number(effectivePanelGeometry.connectorWidth || 0)
  readonly property real effectiveConnectorOverlap: Number(effectivePanelGeometry.connectorOverlap || 0)
  readonly property real effectivePanelRadius: Number(effectivePanelGeometry.panelRadius || 0)
  readonly property bool effectiveAnchorRight: effectivePanelGeometry.anchorRight === true
  readonly property bool effectiveConnectorVisible: flyoutRenderable
    && effectiveConnectorWidth > connectorEpsilon
  readonly property real panelSurfaceWidth: panelWidth + effectiveConnectorWidth
  readonly property real sidebarX: effectiveAnchorRight ? effectiveFlyoutWidth + effectiveConnectorWidth : 0

  readonly property real sidebarMaskX: Math.max(0, surfaceX)
  readonly property real sidebarMaskY: 0
  readonly property real sidebarMaskWidth: effectiveAnchorRight
    ? Math.max(0, sidebarX + panelSurfaceWidth - Math.max(0, surfaceX))
    : Math.max(0, panelSurfaceWidth + Math.min(0, surfaceX))
  readonly property real sidebarMaskHeight: sidebarHeight

  readonly property real connectorX: effectiveAnchorRight ? effectiveFlyoutWidth : panelWidth
  readonly property real connectorY: effectiveFlyoutY - effectiveConnectorWidth
  readonly property real connectorMaskX: connectorX
  readonly property real connectorMaskY: connectorY
  readonly property real connectorMaskWidth: flyoutRenderable && effectiveConnectorVisible ? effectiveConnectorWidth : 0
  readonly property real connectorMaskHeight: flyoutRenderable && effectiveConnectorVisible
    ? effectiveFlyoutHeight + effectiveConnectorWidth * 2 : 0

  readonly property real flyoutCurrentWidth: Math.max(0, effectiveFlyoutWidth * clampedFlyoutProgress)
  readonly property real flyoutX: effectiveAnchorRight ? 0 : panelWidth + effectiveConnectorWidth
  readonly property real flyoutMaskX: effectiveAnchorRight ? effectiveFlyoutWidth - flyoutCurrentWidth : flyoutX
  readonly property real flyoutMaskY: effectiveFlyoutY
  readonly property real flyoutMaskWidth: flyoutRenderable ? flyoutCurrentWidth : 0
  readonly property real flyoutMaskHeight: flyoutRenderable ? effectiveFlyoutHeight : 0

  function emptyPanelGeometry() {
    return makePanelGeometry(0, 0, 0, 0, 0, false, 0)
  }

  function makePanelGeometry(y, width, height, connector, overlap, right, radius) {
    return {
      flyoutY: Math.max(0, Number(y) || 0),
      flyoutWidth: Math.max(0, Number(width) || 0),
      flyoutHeight: Math.max(0, Number(height) || 0),
      connectorWidth: Math.max(0, Number(connector) || 0),
      connectorOverlap: Math.max(0, Number(overlap) || 0),
      panelRadius: Math.max(0, Number(radius) || 0),
      anchorRight: right === true
    }
  }

  function copyPanelGeometry(value) {
    var source = value && typeof value === "object" ? value : ({})
    return makePanelGeometry(source.flyoutY, source.flyoutWidth, source.flyoutHeight,
      source.connectorWidth, source.connectorOverlap, source.anchorRight, source.panelRadius)
  }

  function interpolateValue(from, to, progress) {
    return Number(from || 0) + (Number(to || 0) - Number(from || 0)) * progress
  }

  function pixelSnap(value) {
    return Math.round(Number(value) || 0)
  }

  function interpolatePanelGeometry(from, to, progress) {
    var start = copyPanelGeometry(from)
    var end = copyPanelGeometry(to)
    var p = Math.max(0, Math.min(1, Number(progress) || 0))
    // Snap once at the transaction boundary. Every paint, shadow, border,
    // offset, and compositor-mask consumer then receives identical pixel
    // geometry instead of narrowing fractional values independently.
    return {
      flyoutY: pixelSnap(interpolateValue(start.flyoutY, end.flyoutY, p)),
      flyoutWidth: pixelSnap(interpolateValue(start.flyoutWidth, end.flyoutWidth, p)),
      flyoutHeight: pixelSnap(interpolateValue(start.flyoutHeight, end.flyoutHeight, p)),
      connectorWidth: pixelSnap(interpolateValue(start.connectorWidth, end.connectorWidth, p)),
      connectorOverlap: pixelSnap(interpolateValue(start.connectorOverlap, end.connectorOverlap, p)),
      panelRadius: pixelSnap(interpolateValue(start.panelRadius, end.panelRadius, p)),
      anchorRight: p < 0.5 ? start.anchorRight : end.anchorRight
    }
  }

  function requestPanelGeometry(geometry, key) {
    var nextKey = String(key || "")
    if (nextKey === targetPanelGeometryKey) return false
    // Capture the currently painted shape before invalidating an older request.
    var current = copyPanelGeometry(effectivePanelGeometry)
    panelGeometryAnimation.stop()
    fromPanelGeometry = current
    targetPanelGeometry = copyPanelGeometry(geometry)
    targetPanelGeometryKey = nextKey
    panelGeometryRevision += 1
    if (reducedMotion || !geometryTransitionEnabled || geometryAnimationDuration <= 0) {
      panelGeometryProgress = 1
      fromPanelGeometry = copyPanelGeometry(targetPanelGeometry)
      return true
    }
    panelGeometryProgress = 0
    panelGeometryAnimation.restart()
    return true
  }

  function schedulePanelGeometryRequest() {
    if (geometryRequestScheduled) return
    geometryRequestScheduled = true
    Qt.callLater(function() {
      geometryRequestScheduled = false
      requestPanelGeometry(requestedPanelGeometry, panelGeometryKey)
    })
  }

  function commitPanelGeometry() {
    panelGeometryAnimation.stop()
    panelGeometryProgress = 1
    fromPanelGeometry = copyPanelGeometry(targetPanelGeometry)
  }

  onPanelGeometryKeyChanged: schedulePanelGeometryRequest()
  onReducedMotionChanged: if (reducedMotion && panelGeometryTransitionActive) commitPanelGeometry()

  Component.onCompleted: schedulePanelGeometryRequest()

  property NumberAnimation panelGeometryAnimation: NumberAnimation {
    target: root
    property: "panelGeometryProgress"
    from: 0
    to: 1
    duration: root.geometryAnimationDuration
    easing.type: Easing.OutCubic
    onFinished: root.commitPanelGeometry()
  }
}
