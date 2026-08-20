import Quickshell
import QtQuick
import qs.Commons
import "../lacuna.menu/menu"
import "../lacuna.menu/services"
import "ScreenModel.js" as ScreenModel

Item {
  id: root

  property string omarchyPath: ""
  property var barWidgetRegistry: null
  property var barConfig: ({})
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property bool lacunaFrameHost: true

  readonly property bool barHidden: omarchyBar.barItem && omarchyBar.barItem.barHidden === true
  readonly property string position: validBarPosition(barConfig && barConfig.position ? barConfig.position : "top")
  readonly property bool vertical: position === "left" || position === "right"
  readonly property int barSize: Math.round(vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal)
  readonly property var lacunaState: resolveLacunaState()
  readonly property var lacunaSettings: lacunaState && lacunaState.data ? lacunaState.data : ({})
  readonly property var geometrySettings: lacunaSettings && lacunaSettings.geometry ? lacunaSettings.geometry : ({})
  readonly property string cornerMode: validCornerMode(geometrySettings.cornerMode)
  readonly property int customCornerRadius: Math.max(0, Math.min(32, Math.round(numberSetting(geometrySettings.cornerRadius, 14))))
  readonly property int resolvedCornerRadius: cornerMode === "square" ? 0
    : (cornerMode === "custom" ? customCornerRadius : Math.max(0, Math.round(Style.cornerRadius)))
  readonly property var frameSettings: lacunaSettings && lacunaSettings.frame ? lacunaSettings.frame : ({})
  readonly property var barPresentationSettings: lacunaSettings && lacunaSettings.barPresentation ? lacunaSettings.barPresentation : ({})
  readonly property bool portraitSplitEnabled: barPresentationSettings.portraitSplit !== false
  readonly property string frameMode: validFrameMode(frameSettings.mode)
  readonly property bool frameEnabled: frameMode === "fullframe"
  readonly property int frameThickness: positiveInt(frameSettings.thickness, 8)
  readonly property int frameRadius: resolvedCornerRadius
  // Universal shell corners own trim visibility; legacy molding toggles are ignored.
  readonly property bool frameMoldingPieces: resolvedCornerRadius > 0
  readonly property bool frameShadow: frameSettings.shadow === true
  readonly property bool frameBorder: frameSettings.border === true
  readonly property int frameShadowOffsetX: numberSetting(frameSettings.shadowOffsetX, 2)
  readonly property int frameShadowOffsetY: numberSetting(frameSettings.shadowOffsetY, 3)
  readonly property bool hostedMenuOpen: hostedMenu.menuState && hostedMenu.menuState.open === true
  readonly property bool hostedSidebarVisible: hostedMenu.sidebarSurfaceVisible === true
  readonly property bool hostedSidebarOnLeft: hostedSidebarVisible && !hostedMenu.panelOnRight
  readonly property bool hostedSidebarOnRight: hostedSidebarVisible && hostedMenu.panelOnRight
  // The full-frame cutout is cast from the visible sidebar body edge.
  // The molding inset belongs to the sidebar join; including it here pushes
  // the cutout and shadow past the actual frame edge.
  readonly property real hostedSidebarFrameOcclusionWidth: hostedSidebarVisible
    ? Math.max(0, Number(hostedMenu.panelWidth || 0))
    : 0
  readonly property bool reducedMotion: lacunaSettings && lacunaSettings.reduceMotion === true
  readonly property string requestedFrameGeometryKey: resolveRequestedFrameGeometryKey()
  property var fromFrameGeometrySnapshot: ({ key: "", records: ({}) })
  property var targetFrameGeometrySnapshot: ({ key: "", records: ({}) })
  property real frameGeometryProgress: 1
  property int lacunaFrameGeometryRevision: 0
  readonly property var effectiveFrameGeometrySnapshot: interpolateFrameGeometrySnapshot(
    fromFrameGeometrySnapshot, targetFrameGeometrySnapshot, frameGeometryProgress)
  readonly property string lacunaFrameGeometryKey: targetFrameGeometrySnapshot.key || requestedFrameGeometryKey
  readonly property string lacunaBarSourceDir: manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""
  readonly property string lacunaRepoDir: lacunaBarSourceDir.replace(/\/lacuna\.bar\/?$/, "")
  readonly property string lacunaMenuSourceDir: lacunaRepoDir ? lacunaRepoDir + "/lacuna.menu" : ""
  readonly property var hostedMenuManifest: ({
    id: "lacuna.menu",
    __sourceDir: lacunaMenuSourceDir
  })
  readonly property var validBarScreens: ScreenModel.validScreens(Quickshell.screens)

  property NumberAnimation frameGeometryAnimation: NumberAnimation {
    target: root
    property: "frameGeometryProgress"
    from: 0
    to: 1
    duration: 250
    easing.type: Easing.OutCubic
    onFinished: root.commitFrameGeometrySnapshot()
  }

  onRequestedFrameGeometryKeyChanged: Qt.callLater(root.requestFrameGeometrySnapshot)
  onEffectiveFrameGeometrySnapshotChanged: lacunaFrameGeometryRevision += 1
  onReducedMotionChanged: if (reducedMotion) commitFrameGeometrySnapshot()
  Component.onCompleted: requestFrameGeometrySnapshot()

  function resolveLacunaState() {
    if (root.shell && typeof root.shell.ensureService === "function") {
      var ensured = root.shell.ensureService("lacuna.state")
      if (ensured) return ensured
    }
    if (root.shell && typeof root.shell.serviceFor === "function") {
      var service = root.shell.serviceFor("lacuna.state")
      if (service) return service
    }
    return null
  }

  function validBarPosition(value) {
    var next = String(value || "top")
    if (next === "top" || next === "bottom" || next === "left" || next === "right") return next
    return "top"
  }

  function validCornerMode(value) {
    var next = String(value || "theme").toLowerCase()
    if (next === "square" || next === "custom") return next
    return "theme"
  }

  function validFrameMode(value) {
    var next = String(value || "off")
    if (next === "off" || next === "sidebar" || next === "fullframe") return next
    return "off"
  }

  function positiveInt(value, fallback) {
    var parsed = Number(value)
    return isFinite(parsed) && parsed > 0 ? Math.round(parsed) : fallback
  }

  function numberSetting(value, fallback) {
    var parsed = Number(value)
    return isFinite(parsed) ? Math.round(parsed) : fallback
  }

  function portraitSplitEffective(screen) {
    return root.portraitSplitEnabled && !root.vertical && ScreenModel.isPortrait(screen)
  }

  function portraitCompanionEdge(screen) {
    if (!root.portraitSplitEffective(screen)) return ""
    return root.position === "top" ? "bottom" : "top"
  }

  function portraitSplitGeometrySignature() {
    var values = []
    var screens = root.validBarScreens || []
    for (var i = 0; i < screens.length; i++) {
      values.push(ScreenModel.screenName(screens[i]) + ":" + root.portraitCompanionEdge(screens[i]))
    }
    values.sort()
    return values.join(",")
  }

  function fullscreenWorkspaceOnScreen(screen) {
    return hostedMenu && typeof hostedMenu.fullscreenWorkspaceOnScreen === "function"
      ? hostedMenu.fullscreenWorkspaceOnScreen(screen) : false
  }

  function hostedSidebarOccupiesEdge(edge, screen) {
    // Autohide is always overlay-only. Keep the frame's exclusive reserve in
    // place while the transient sidebar paints above it so pointer reveal never
    // causes application-window reflow.
    if (hostedMenu.sidebarAutoHideEnabled === true) return false
    if (!hostedSidebarVisibleOnScreen(screen)) return false
    return (edge === "left" && hostedSidebarOnLeft) || (edge === "right" && hostedSidebarOnRight)
  }

  function hostedSidebarVisibleOnScreen(screen) {
    if (!hostedSidebarVisible) return false
    if (hostedMenu && typeof hostedMenu.sidebarVisibleOnScreen === "function") {
      return hostedMenu.sidebarVisibleOnScreen(screen)
    }
    return hostedMenu.sidebarScreen === screen
  }

  function barOutlineInsetsFor(screen, barPosition) {
    var result = { left: 0, right: 0, top: 0, bottom: 0 }
    if (!hostedSidebarVisibleOnScreen(screen)) return result
    if (barPosition !== "top" && barPosition !== "bottom") return result
    // The bar rail meets the sidebar's top molding tangent. A flyout connector
    // interrupts the vertical sidebar edge farther down, so its wider radius
    // must not move this top tangent and open a short horizontal border gap.
    var surfaceInset = root.frameMoldingPieces ? root.frameRadius : 0
    var sidebarExtent = Math.max(0, Number(hostedMenu.panelWidth || 0))
      + Math.max(0, surfaceInset)
    // One physical-pixel overlap closes the antialias seam between separate
    // bar and sidebar windows without carrying either rail behind the other.
    var tangentInset = Math.max(0, sidebarExtent - 1)
    if (hostedMenu.panelOnRight) result.right = tangentInset
    else result.left = tangentInset
    return result
  }

  function barFlyoutAvoidanceInsetsFor(screen, barPosition) {
    var result = { left: 0, right: 0, top: 0, bottom: 0 }
    if (!hostedMenu.sidebarState || hostedMenu.sidebarState.collapsed === true) return result
    return barOutlineInsetsFor(screen, barPosition)
  }

  function hostedFlyoutVisibleOnScreen(screen) {
    if (!hostedSidebarVisibleOnScreen(screen)) return false
    if (hostedMenu && typeof hostedMenu.frameBorderAttachedFlyoutVisibleOnScreen === "function") {
      return hostedMenu.frameBorderAttachedFlyoutVisibleOnScreen(screen)
    }
    return hostedMenu.frameBorderAttachedFlyoutVisible === true
  }

  function barPopoutBorderGapFor(screen) {
    var gap = omarchyBar && omarchyBar.activePopoutBorderGap
      ? omarchyBar.activePopoutBorderGap : ({})
    if (!gap || Number(gap.length || 0) <= 0) return null
    if (String(gap.screenName || "") !== ScreenModel.screenName(screen)) return null
    var edge = String(gap.edge || "")
    var companionEdge = root.portraitCompanionEdge(screen)
    if (edge !== root.position && edge !== companionEdge) return null
    return gap
  }

  function frameScreenKey(screen) {
    var name = ScreenModel.screenName(screen)
    if (name !== "") return name
    var screens = root.validBarScreens || []
    var index = screens.indexOf(screen)
    return "screen-" + Math.max(0, index) + "-" + Number(screen && screen.width || 0)
      + "x" + Number(screen && screen.height || 0)
  }

  function selectedOutputGeometrySignature() {
    var values = []
    var screens = root.validBarScreens || []
    for (var i = 0; i < screens.length; i++) {
      var screen = screens[i]
      var occupiedEdge = root.hostedSidebarOccupiesEdge("left", screen) ? "left"
        : root.hostedSidebarOccupiesEdge("right", screen) ? "right" : ""
      values.push([
        frameScreenKey(screen),
        Number(screen && screen.width || 0),
        Number(screen && screen.height || 0),
        root.portraitCompanionEdge(screen),
        occupiedEdge,
        occupiedEdge === "" ? 0 : root.hostedSidebarFrameOcclusionWidth
      ].join(":"))
    }
    values.sort()
    return values.join(",")
  }

  function resolveRequestedFrameGeometryKey() {
    return [
      frameMode,
      frameThickness,
      frameRadius,
      frameMoldingPieces,
      position,
      barSize,
      portraitSplitEnabled,
      selectedOutputGeometrySignature()
    ].join("|")
  }

  function copyFrameRecord(value) {
    var source = value && typeof value === "object" ? value : ({})
    var next = {}
    for (var key in source) next[key] = source[key]
    return next
  }

  function copyFrameGeometrySnapshot(value) {
    var source = value && typeof value === "object" ? value : ({})
    var sourceRecords = source.records && typeof source.records === "object" ? source.records : ({})
    var records = {}
    for (var key in sourceRecords) records[key] = copyFrameRecord(sourceRecords[key])
    return { key: String(source.key || ""), records: records }
  }

  function interpolateFrameRecord(from, to, progress) {
    var start = from && typeof from === "object" ? from : to
    var end = to && typeof to === "object" ? to : from
    if (!start || !end) return ({})
    var p = Math.max(0, Math.min(1, Number(progress) || 0))
    var next = {}
    var numeric = {
      screenWidth: true, screenHeight: true, thickness: true, radius: true,
      barSize: true, leftOccupiedWidth: true, rightOccupiedWidth: true,
      outerX: true, outerY: true, outerRight: true, outerBottom: true,
      holeX: true, holeY: true, holeRight: true, holeBottom: true,
      contentX: true, contentY: true, contentWidth: true, contentHeight: true,
      contentRadius: true, bleed: true
    }
    for (var key in end) {
      if (numeric[key]) next[key] = Math.round(Number(start[key] || 0)
        + (Number(end[key] || 0) - Number(start[key] || 0)) * p)
      else next[key] = p < 0.5 ? start[key] : end[key]
    }
    next.framed = p < 0.999 ? (start.framed === true || end.framed === true) : end.framed === true
    next.moldingPieces = p < 0.5 ? start.moldingPieces === true : end.moldingPieces === true
    return next
  }

  function interpolateFrameGeometrySnapshot(from, to, progress) {
    var start = from && from.records ? from.records : ({})
    var end = to && to.records ? to.records : ({})
    var records = {}
    for (var key in end) records[key] = interpolateFrameRecord(start[key] || end[key], end[key], progress)
    return { key: String(to && to.key || ""), records: records }
  }

  function calculateFrameRecord(screen) {
    var screenWidth = screen && screen.width !== undefined ? Number(screen.width) : 0
    var screenHeight = screen && screen.height !== undefined ? Number(screen.height) : 0
    var t = Math.max(1, root.frameThickness)
    var companionEdge = root.portraitCompanionEdge(screen)
    var topInset = root.position === "top" || companionEdge === "top" ? Math.max(0, root.barSize) : t
    var bottomInset = root.position === "bottom" || companionEdge === "bottom" ? Math.max(0, root.barSize) : t
    var leftInset = root.position === "left" ? Math.max(0, root.barSize) : t
    var rightInset = root.position === "right" ? Math.max(0, root.barSize) : t
    // Autohide is transient Overlay paint. Keep the persistent frame and every
    // background consumer on one stable geometry transaction; the Overlay
    // border follows the sidebar's actual mask from the menu animation clock.
    var sidebarOnLeft = root.hostedSidebarOccupiesEdge("left", screen)
    var sidebarOnRight = root.hostedSidebarOccupiesEdge("right", screen)
    var leftOcclusion = sidebarOnLeft ? root.hostedSidebarFrameOcclusionWidth : 0
    var rightOcclusion = sidebarOnRight ? root.hostedSidebarFrameOcclusionWidth : 0
    var holeX = Math.max(0, leftOcclusion > 0 ? leftOcclusion : leftInset)
    var holeY = Math.max(0, topInset)
    var holeRight = Math.max(holeX + 1, screenWidth - (rightOcclusion > 0 ? rightOcclusion : rightInset))
    var holeBottom = Math.max(holeY + 1, screenHeight - bottomInset)
    var framed = root.frameEnabled && screenWidth > 0 && screenHeight > 0
    var bleed = framed ? Math.max(t + 2, Math.ceil(root.frameRadius * 0.5)) : 0
    var contentX = framed ? Math.max(0, holeX - bleed) : 0
    var contentY = framed ? Math.max(0, holeY - bleed) : 0
    var contentRight = framed ? Math.min(screenWidth, holeRight + bleed) : screenWidth
    var contentBottom = framed ? Math.min(screenHeight, holeBottom + bleed) : screenHeight
    return {
      screenKey: frameScreenKey(screen),
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      framed: framed,
      moldingPieces: root.frameMoldingPieces,
      thickness: t,
      radius: root.frameRadius,
      contentRadius: framed && root.frameMoldingPieces ? root.frameRadius : 0,
      barPosition: root.position,
      barSize: root.barSize,
      topEdgeOccupied: companionEdge === "top",
      bottomEdgeOccupied: companionEdge === "bottom",
      leftEdgeOccupied: sidebarOnLeft,
      rightEdgeOccupied: sidebarOnRight,
      leftOccupiedWidth: leftOcclusion,
      rightOccupiedWidth: rightOcclusion,
      outerX: root.position === "left" ? Math.max(0, root.barSize) : 0,
      outerY: root.position === "top" || companionEdge === "top" ? Math.max(0, root.barSize) : 0,
      outerRight: root.position === "right" ? Math.max(1, screenWidth - Math.max(0, root.barSize)) : screenWidth,
      outerBottom: root.position === "bottom" || companionEdge === "bottom" ? Math.max(1, screenHeight - Math.max(0, root.barSize)) : screenHeight,
      holeX: holeX,
      holeY: holeY,
      holeRight: holeRight,
      holeBottom: holeBottom,
      contentX: contentX,
      contentY: contentY,
      contentWidth: Math.max(1, contentRight - contentX),
      contentHeight: Math.max(1, contentBottom - contentY),
      bleed: bleed
    }
  }

  function buildFrameGeometrySnapshot(key) {
    var records = {}
    var screens = root.validBarScreens || []
    for (var i = 0; i < screens.length; i++) {
      var record = calculateFrameRecord(screens[i])
      records[record.screenKey] = record
    }
    return { key: String(key || requestedFrameGeometryKey), records: records }
  }

  function requestFrameGeometrySnapshot() {
    var key = root.requestedFrameGeometryKey
    if (key === targetFrameGeometrySnapshot.key) return false
    var current = copyFrameGeometrySnapshot(effectiveFrameGeometrySnapshot)
    var target = buildFrameGeometrySnapshot(key)
    frameGeometryAnimation.stop()
    fromFrameGeometrySnapshot = current.records && Object.keys(current.records).length > 0 ? current : target
    targetFrameGeometrySnapshot = target
    if (reducedMotion) {
      commitFrameGeometrySnapshot()
    } else {
      frameGeometryProgress = 0
      frameGeometryAnimation.restart()
    }
    return true
  }

  function commitFrameGeometrySnapshot() {
    frameGeometryAnimation.stop()
    frameGeometryProgress = 1
    fromFrameGeometrySnapshot = copyFrameGeometrySnapshot(targetFrameGeometrySnapshot)
  }

  function lacunaFrameGeometryRecord(screen) {
    var records = effectiveFrameGeometrySnapshot && effectiveFrameGeometrySnapshot.records
      ? effectiveFrameGeometrySnapshot.records : ({})
    return records[frameScreenKey(screen)] || calculateFrameRecord(screen)
  }

  // MultiEffect can flash when its Shape source is rebuilt on every animation
  // tick. Keep the shadow caster on the immutable target record while paint,
  // video, and vignette continue to consume the interpolated effective record.
  // Sidebar disclosure covers the one-time caster endpoint switch.
  function lacunaTargetFrameGeometryRecord(screen) {
    var records = targetFrameGeometrySnapshot && targetFrameGeometrySnapshot.records
      ? targetFrameGeometrySnapshot.records : ({})
    return records[frameScreenKey(screen)] || calculateFrameRecord(screen)
  }

  function lacunaFrameContentRect(screen) {
    var record = lacunaFrameGeometryRecord(screen)
    return {
      x: record.contentX,
      y: record.contentY,
      width: record.contentWidth,
      height: record.contentHeight,
      radius: record.contentRadius,
      bleed: record.bleed,
      framed: record.framed,
      innerX: record.holeX,
      innerY: record.holeY,
      innerWidth: Math.max(1, record.holeRight - record.holeX),
      innerHeight: Math.max(1, record.holeBottom - record.holeY),
      revision: root.lacunaFrameGeometryRevision,
      geometryKey: root.lacunaFrameGeometryKey,
      screenKey: record.screenKey
    }
  }

  function debugBarGeometry() {
    var value = omarchyBar.debugBarGeometry()
    var next = value && typeof value === "object" ? value : ({})
    next.lacunaFrameGeometryRevision = root.lacunaFrameGeometryRevision
    next.lacunaFrameGeometryKey = root.lacunaFrameGeometryKey
    next.lacunaFrameSelectedOutputs = root.selectedOutputGeometrySignature()
    return next
  }

  function openConfigPanel() {
    return omarchyBar.openConfigPanel()
  }

  function summonBarWidget(pluginId) {
    return omarchyBar.summonBarWidget(pluginId)
  }

  function hideBarWidget(pluginId) {
    return omarchyBar.hideBarWidget(pluginId)
  }

  function isBarWidgetOpen(pluginId) {
    return omarchyBar.isBarWidgetOpen(pluginId)
  }

  function panelWidgetIdAt(region, index) {
    return omarchyBar.panelWidgetIdAt(region, index)
  }

  function openMenu(payloadJson) {
    hostedMenu.open(payloadJson || "{}")
    return true
  }

  function closeMenu() {
    hostedMenu.close()
    return true
  }

  function toggleMenu(payloadJson) {
    if (hostedMenuOpen) hostedMenu.close()
    else hostedMenu.open(payloadJson || "{}")
    return true
  }

  function contextualMenuPayload(payloadJson, popupContext) {
    var payload = {}
    try {
      var parsed = JSON.parse(String(payloadJson || "{}"))
      if (parsed && typeof parsed === "object") payload = parsed
    } catch (e) {
    }
    payload.popupContext = popupContext || ({})
    return JSON.stringify(payload)
  }

  Theme {
    id: barTheme
  }

  // The single always-mapped Top frame owns fill, shadow, and optional border
  // paint. The hosted menu lives at Overlay, so its sidebar and flyouts remain
  // above this frame regardless of runtime map order.
  Variants {
    model: root.validBarScreens

    LacunaFrameWindow {
      id: frameWindow
      required property var modelData

      readonly property string outputName: modelData && modelData.name !== undefined
        ? String(modelData.name) : ""
      readonly property real sidebarPaintOcclusion:
        typeof hostedMenu.sidebarPaintOcclusionWidthFor === "function"
          ? hostedMenu.sidebarPaintOcclusionWidthFor(modelData) : 0
      readonly property real sidebarMoldingOcclusion: sidebarPaintOcclusion > 0.001
        && root.frameMoldingPieces ? root.frameRadius : 0

      QtObject {
        id: foregroundFrameBridge
        readonly property var borderSource: frameWindow.foregroundBorderSource
        readonly property real offsetX: 0
        readonly property real offsetY: 0
      }

      Component.onCompleted: {
        if (root.lacunaState && typeof root.lacunaState.publishForegroundFrameSource === "function")
          root.lacunaState.publishForegroundFrameSource(outputName, "bar", foregroundFrameBridge)
      }
      Component.onDestruction: {
        if (root.lacunaState && typeof root.lacunaState.clearForegroundFrameSource === "function")
          root.lacunaState.clearForegroundFrameSource(outputName, "bar", foregroundFrameBridge)
      }

      targetScreen: modelData
      geometryRecord: root.lacunaFrameGeometryRecord(modelData)
      shadowGeometryRecord: root.lacunaFrameGeometryRecord(modelData)
      active: geometryRecord && geometryRecord.framed === true
      suppressed: root.fullscreenWorkspaceOnScreen(modelData)
      barPosition: root.position
      barSize: root.barSize
      frameThickness: root.frameThickness
      frameRadius: root.frameRadius
      moldingPieces: root.frameMoldingPieces
      frameColor: barTheme.panelBackground
      shadowEnabled: root.frameShadow
      shadowOffsetX: root.frameShadowOffsetX
      shadowOffsetY: root.frameShadowOffsetY
      topEdgeOccupied: root.portraitCompanionEdge(modelData) === "top"
      bottomEdgeOccupied: root.portraitCompanionEdge(modelData) === "bottom"
      leftEdgeOccupied: root.hostedSidebarVisibleOnScreen(modelData) && !hostedMenu.panelOnRight
      rightEdgeOccupied: root.hostedSidebarVisibleOnScreen(modelData) && hostedMenu.panelOnRight
      leftOccupiedWidth: root.hostedSidebarFrameOcclusionWidth
      rightOccupiedWidth: root.hostedSidebarFrameOcclusionWidth
      // The hosted Overlay menu owns the complete border on its screen so the
      // sidebar and all four corners share one scene-graph renderer.
      borderEnabled: root.frameBorder && !hostedMenu.ownsHostFrameBorderOnScreen(modelData)
      borderColor: barTheme.frameBorder
      attachedFlyoutVisible: root.hostedFlyoutVisibleOnScreen(modelData)
      attachedFlyoutX: hostedMenu.frameShadowAttachedFlyoutXFor
        ? hostedMenu.frameShadowAttachedFlyoutXFor(modelData) : 0
      attachedFlyoutY: hostedMenu.frameBorderAttachedFlyoutYFor ? hostedMenu.frameBorderAttachedFlyoutYFor(modelData) : hostedMenu.frameBorderAttachedFlyoutY
      attachedFlyoutWidth: hostedMenu.frameShadowAttachedFlyoutWidthFor
        ? hostedMenu.frameShadowAttachedFlyoutWidthFor(modelData) : 0
      attachedFlyoutHeight: hostedMenu.frameBorderAttachedFlyoutHeightFor ? hostedMenu.frameBorderAttachedFlyoutHeightFor(modelData) : hostedMenu.frameBorderAttachedFlyoutHeight
      barPopoutBorderGap: root.barPopoutBorderGapFor(modelData)
      // Frame paint stays clipped at the live sidebar body. The authoritative
      // shadow uses an inverse source mask, so its clip can begin beneath the
      // opaque molding while only the inward blur reaches the reveal.
      paintOcclusionLeft: !hostedMenu.panelOnRight ? frameWindow.sidebarPaintOcclusion : 0
      paintOcclusionRight: hostedMenu.panelOnRight ? frameWindow.sidebarPaintOcclusion : 0
      shadowOcclusionLeft: !hostedMenu.panelOnRight ? frameWindow.sidebarPaintOcclusion : 0
      shadowOcclusionRight: hostedMenu.panelOnRight ? frameWindow.sidebarPaintOcclusion : 0
      shadowHoleLeftOverride: !hostedMenu.panelOnRight
        && frameWindow.sidebarPaintOcclusion > 0.001
          ? frameWindow.sidebarPaintOcclusion : -1
      shadowHoleRightOverride: hostedMenu.panelOnRight
        && frameWindow.sidebarPaintOcclusion > 0.001
          ? frameWindow.width - frameWindow.sidebarPaintOcclusion : -1
    }
  }

  OmarchyBarAdapter {
    id: omarchyBar

    omarchyPath: root.omarchyPath
    shell: root.shell
    manifest: root.manifest
    pluginRegistry: root.pluginRegistry
    barWidgetRegistry: root.barWidgetRegistry
    barConfig: root.barConfig
    portraitSplitEnabled: root.portraitSplitEnabled
    frameBorderEnabled: root.frameBorder
    fullFrameEnabled: root.frameEnabled
    resolvedCornerRadius: root.resolvedCornerRadius
    barOutlineEnabled: root.frameBorder && !root.frameEnabled
    barOutlineInsetsProvider: function(screen, barPosition) {
      return root.barOutlineInsetsFor(screen, barPosition)
    }
    popoutAvoidanceInsetsProvider: function(screen, barPosition) {
      return root.barFlyoutAvoidanceInsetsFor(screen, barPosition)
    }
    fullscreenSuppressionProvider: function(screen) {
      return root.fullscreenWorkspaceOnScreen(screen)
    }
    frameBorderColor: barTheme.frameBorder
    menuToggleHandler: function(payloadJson, popupContext) {
      return root.toggleMenu(root.contextualMenuPayload(payloadJson, popupContext))
    }
  }

  // The full-frame paint surface is intentionally exclusion-ignored because it
  // spans the whole monitor. Add invisible one-edge layer-shell surfaces for
  // non-bar frame edges so Hyprland shrinks the work area before applying
  // gaps_out. When the hosted sidebar occupies an edge, that sidebar's own
  // reserve owns the workarea there; keeping an extra frame reserve would leave
  // a visible frameThickness gap at the bar end.
  // Frame reserve exclusive zones must never be arranged before the bar
  // windows: at shell start with fullframe already enabled the reserves are
  // created first (the vendored bar maps on its own schedule) and their
  // zones inset the bar itself — seen live as a frameThickness-wide
  // background gap at the bar's outer corner on every monitor. Reserves
  // therefore activate only after a startup settle window, so they always
  // arrange after the bars; runtime frame toggles are unaffected.
  property bool frameReservesReady: false

  Timer {
    id: frameReserveSettleTimer
    interval: 1200
    running: true
    repeat: false
    onTriggered: root.frameReservesReady = true
  }

  Variants {
    model: Quickshell.screens

    Item {
      id: frameReserveScreen
      required property var modelData
      readonly property var screenData: modelData
      readonly property string screenNamespace: screenData && screenData.name
        ? String(screenData.name).replace(/[^A-Za-z0-9_-]/g, "-")
        : "screen"

      Variants {
        model: ["top", "bottom", "left", "right"]

        LacunaFrameReserveWindow {
          required property var modelData

          readonly property string edgeName: String(modelData)

          targetScreen: frameReserveScreen.screenData
          active: root.frameEnabled
            && root.frameReservesReady
            && !root.fullscreenWorkspaceOnScreen(frameReserveScreen.screenData)
            && edgeName !== root.position
            && edgeName !== root.portraitCompanionEdge(frameReserveScreen.screenData)
            && !root.hostedSidebarOccupiesEdge(edgeName, frameReserveScreen.screenData)
          edge: edgeName
          reserveSize: root.frameThickness
          layerNamespace: "lacuna-bar-frame-reserve-" + frameReserveScreen.screenNamespace
        }
      }
    }
  }

  MenuWindow {
    id: hostedMenu

    omarchyPath: root.omarchyPath
    shell: root.shell
    manifest: root.hostedMenuManifest
    pluginRegistry: root.pluginRegistry
    barWidgetRegistry: root.barWidgetRegistry
    hostManaged: true
    hostBarSize: root.barSize
    hostFrameBorderEnabled: root.frameBorder
    hostFrameGeometryProvider: function(screen) {
      return root.lacunaFrameGeometryRecord(screen)
    }
    hostBarPopoutBorderGapProvider: function(screen) {
      return root.barPopoutBorderGapFor(screen)
    }
  }
}
