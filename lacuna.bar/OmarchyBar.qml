import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "BarModel.js" as BarModel
import "BarResponsiveModel.js" as BarResponsiveModel
import "PanelIndicatorModel.js" as PanelIndicatorModel
import "PanelNavigationModel.js" as PanelNavigationModel
import "PortraitBarModel.js" as PortraitBarModel
import "ScreenModel.js" as ScreenModel

Item {
  id: root

  // The omarchy-shell host injects omarchyPath from OMARCHY_PATH.
  required property string omarchyPath
  // Injected by the host shell so bar slots can resolve enabled widgets.
  required property var barWidgetRegistry
  // Injected by the host shell every time shell.json is reloaded. Holds the
  // `bar:` subtree: position, centerAnchor, layout. The host owns file IO;
  // the bar just renders whatever it's handed. The bar exposes the shell font
  // through its proportional Nerd Font family so shell chrome does not fall
  // back to the mono variants used by terminals/editors.
  required property var barConfig
  // Injected by the host shell. Used for shell-wide actions such as opening
  // settings and persisting inline widget state.
  property var shell: null
  // Manifest for the active bar option. Present for custom bars and useful for
  // diagnostics; the built-in bar does not otherwise need it.
  property var manifest: null
  property var menuToggleHandler: null
  property bool portraitSplitEnabled: true
  readonly property bool lacunaFrameHost: true
  // Mirrors the on-disk `bar-off` flag so the user can hide the bar without
  // killing the entire shell. Wired to BarPanel.visible below; updated by the
  // FileView watcher further down.
  property bool barHidden: false
  property string home: Quickshell.env("HOME")
  property string omarchyConfigDir: home + "/.config/omarchy"
  property var fallbackBarConfig: ({
    position: "top",
    transparent: false,
    centerAnchor: "omarchy.clock",
    layout: { left: [], center: [], right: [] }
  })
  property var layoutConfig: fallbackBarConfig.layout
  property string centerAnchor: ""
  property bool centerSectionHovered: false
  property bool centerSectionRevealHeld: false
  property bool centerHoverRevealSuppressed: false
  property int barConfigSerial: 0
  property string position: "top"
  // Resolves through fontconfig at paint time, then maps common mono family
  // names to their proportional Nerd Font variants. Omarchy font selection
  // still owns the base family; Lacuna only prevents shell UI from rendering
  // with the terminal/editor mono face.
  property string fontFamily: proportionalFontFamily(Style.font.family)
  // Bound to the central Color singleton so the bar tracks shell.toml's
  // [bar] section. Property names kept for the rest of this file's bindings.
  property color themeForeground: Color.bar.text
  property color foreground: themeForeground
  property color barForeground: themeForeground
  property color background: opaqueColor(Color.bar.background)
  property color urgent: Color.bar.active
  // The outer Lacuna frame host injects the optional frame-border treatment
  // so plugin-owned flyouts can continue the same outline around exposed edges.
  property bool frameBorderEnabled: false
  property bool fullFrameEnabled: false
  property int resolvedCornerRadius: Math.max(0, Math.round(Style.cornerRadius))
  property bool barOutlineEnabled: false
  property var barOutlineInsetsProvider: null
  property var popoutAvoidanceInsetsProvider: null
  property var fullscreenSuppressionProvider: null
  property color frameBorderColor: Color.popups.border
  // Theme accent, exposed to bar widgets (e.g. lacuna.bar-seam breathing glow,
  // active-state accents). Theme-derived; mirrors the menu's accent role.
  property color accent: Color.accent

  function proportionalFontFamily(value) {
    var text = String(value || "").replace(/^\s+|\s+$/g, "")
    if (text.length === 0 || text === "monospace") return "Hack Nerd Font Propo"
    if (text.indexOf(" Propo") !== -1) return text
    if (text === "Hack Nerd Font" || text === "Hack Nerd Font Mono" || text === "Hack") return "Hack Nerd Font Propo"
    if (text === "BlexMono Nerd Font" || text === "BlexMono Nerd Font Mono") return "BlexMono Nerd Font Propo"
    if (text === "JetBrainsMono Nerd Font" || text === "JetBrainsMono Nerd Font Mono" || text === "JetBrains Mono") return "JetBrainsMono Nerd Font Propo"
    if (text.indexOf(" Nerd Font Mono") !== -1) return text.replace(" Nerd Font Mono", " Nerd Font Propo")
    if (text.indexOf(" Nerd Font") !== -1) return text + " Propo"
    return text
  }

  Behavior on barForeground { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  Behavior on background { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  Behavior on urgent { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  property var tooltipTarget: null
  property var pendingTooltipTarget: null
  property string tooltipText: ""
  property string pendingTooltipText: ""
  property bool tooltipShown: false
  property int tooltipRequest: 0
  property var activePopout: null
  property var activePopoutBorderGap: ({})
  property bool editMode: false
  property string activeInteractionScreenName: ""
  property var activePopupContext: ({})
  property var barDragSource: null
  property var barDragTarget: null
  property bool barDragAfter: false
  property var barDragWindow: null
  property var barDragScreen: null
  property url barDragImageUrl: ""
  property real barDragSceneX: 0
  property real barDragSceneY: 0
  property real barDragScreenX: 0
  property real barDragScreenY: 0
  property real barDragOffsetX: 0
  property real barDragOffsetY: 0
  property var configControls: []
  property var clickTargets: []
  property var debugModuleSlots: []
  readonly property var validBarScreens: ScreenModel.validScreens(Quickshell.screens)
  readonly property var portraitCompanionScreens: validBarScreens.filter(function(screen) {
    return root.portraitSplitEffective(screen)
  })

  function screenName(screen) {
    return ScreenModel.screenName(screen)
  }

  function popupContextFor(surfacePosition, anchorItem, moduleId, owningScreen) {
    var window = targetWindow(anchorItem)
    var screen = window && window.screen ? window.screen : owningScreen
    if (!screen) screen = ScreenModel.fallbackScreen(validBarScreens, activeInteractionScreenName)
    var point = { x: 0, y: 0 }
    if (anchorItem && window && window.contentItem) {
      try {
        point = window.contentItem.mapFromItem(anchorItem, 0, 0)
      } catch (e) {
      }
    }
    return {
      screenName: screenName(screen),
      anchor: {
        x: Math.round(point.x),
        y: Math.round(point.y),
        width: Math.max(0, Math.round(anchorItem ? anchorItem.width : 0)),
        height: Math.max(0, Math.round(anchorItem ? anchorItem.height : 0))
      },
      barPosition: surfacePosition,
      vertical: surfacePosition === "left" || surfacePosition === "right",
      moduleId: String(moduleId || "")
    }
  }

  function popupContext(anchorItem, moduleId) {
    return popupContextFor(position, anchorItem, moduleId)
  }

  function activateInteractionFor(surfacePosition, anchorItem, moduleId, owningScreen) {
    var context = popupContextFor(surfacePosition, anchorItem, moduleId, owningScreen)
    activeInteractionScreenName = context.screenName
    activePopupContext = context
    clearTooltip()
    return context
  }

  function activateInteraction(anchorItem, moduleId) {
    return activateInteractionFor(position, anchorItem, moduleId)
  }

  function toggleMenu(payloadJson) {
    if (typeof menuToggleHandler !== "function") return false
    return menuToggleHandler(payloadJson || "{}", activePopupContext)
  }

  function reconcileScreens() {
    if (ScreenModel.hasScreen(validBarScreens, activeInteractionScreenName)) return
    if (activePopout && typeof activePopout.close === "function") activePopout.close()
    activePopout = null
    clearTooltip()
    clearBarDrag()
    var fallback = ScreenModel.fallbackScreen(validBarScreens, "")
    activeInteractionScreenName = screenName(fallback)
    activePopupContext = ({})
  }

  onValidBarScreensChanged: reconcileScreens()

  function registerClickTarget(target) {
    if (!target || clickTargets.indexOf(target) !== -1) return
    var next = clickTargets.slice()
    next.push(target)
    clickTargets = next
  }

  function unregisterClickTarget(target) {
    var next = clickTargets.filter(function(item) { return item !== target })
    clickTargets = next
  }

  function registerDebugModuleSlot(slot) {
    if (!slot || debugModuleSlots.indexOf(slot) !== -1) return
    var next = debugModuleSlots.slice()
    next.push(slot)
    debugModuleSlots = next
  }

  function unregisterDebugModuleSlot(slot) {
    var next = debugModuleSlots.filter(function(item) { return item !== slot })
    debugModuleSlots = next
  }

  // Match Omarchy's multi-monitor bar contract: return every live instance of
  // a widget id so BarWidget.broadcast() refreshes all output-local copies.
  function moduleWidgets(pluginId) {
    var id = String(pluginId || "")
    var items = []
    if (!id) return items
    for (var i = 0; i < debugModuleSlots.length; i++) {
      var slot = debugModuleSlots[i]
      if (!slot || slot.moduleName !== id || !slot.activeItem) continue
      items.push(slot.activeItem)
    }
    return items
  }

  function findPanelWidget(pluginId) {
    var id = String(pluginId || "")
    if (!id) return null
    var candidates = []
    for (var i = 0; i < debugModuleSlots.length; i++) {
      var slot = debugModuleSlots[i]
      if (!slot || slot.moduleName !== id || !slot.activeItem) continue
      var item = slot.activeItem
      if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
      candidates.push(slot)
    }
    var chosen = BarModel.pickDrawnSlot(candidates)
    return chosen ? chosen.activeItem : null
  }

  function summonBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item) return false
    item.open()
    return true
  }

  function hideBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item) return false
    item.close()
    return true
  }

  function isBarWidgetOpen(pluginId) {
    var item = findPanelWidget(pluginId)
    return !!item && item.opened === true
  }

  function registerConfigControl(control) {
    if (!control || configControls.indexOf(control) !== -1) return
    var next = configControls.slice()
    next.push(control)
    configControls = next
  }

  function unregisterConfigControl(control) {
    var next = configControls.filter(function(item) { return item !== control })
    configControls = next
  }

  function debugBarGeometry() {
    var out = []
    for (var i = 0; i < debugModuleSlots.length; i++) {
      var slot = debugModuleSlots[i]
      if (!slot || !slot.activeItem) continue
      var point = { x: slot.x, y: slot.y }
      try {
        point = slot.mapToItem(null, 0, 0)
      } catch (e) {
      }
      out.push({
        id: slot.moduleName,
        section: slot.region,
        band: slot.band,
        screenName: slot.surfaceScreenName,
        barPosition: slot.surfaceContext ? slot.surfaceContext.position : root.position,
        registered: slot.registered === true,
        qmlCustom: slot.qmlCustom === true,
        commandCustom: slot.commandCustom === true,
        x: Math.round(point.x),
        y: Math.round(point.y),
        width: Math.round(slot.width),
        height: Math.round(slot.height),
        visible: slot.visible === true && slot.width > 0 && slot.height > 0,
        itemVisible: slot.activeItem.visible === true,
        itemWidth: Math.round(slot.activeItem.implicitWidth || 0),
        itemHeight: Math.round(slot.activeItem.implicitHeight || 0),
        naturalWidth: Number(slot.naturalWidth || 0),
        availableLength: slot.moduleList ? Number(slot.moduleList.availableLength || 0) : 0,
        overflowVisible: slot.overflowVisible === true,
        priority: root.responsivePriority(slot.moduleName, slot.region),
        compactBar: root.compactBar,
        widthClass: slot.surfaceContext ? slot.surfaceContext.widthClass : "",
        logicalWidth: slot.surfaceContext ? slot.surfaceContext.logicalWidth : 0,
        outputScale: slot.surfaceContext ? slot.surfaceContext.outputScale : 1,
        recording: "recording" in slot.activeItem ? slot.activeItem.recording === true : undefined,
        polledRecording: "polledRecording" in slot.activeItem ? slot.activeItem.polledRecording === true : undefined,
        recordingServiceResolved: "recordingService" in slot.activeItem ? slot.activeItem.recordingService !== null : undefined
      })
    }
    return out
  }

  function targetWindow(target) {
    return target && target.QsWindow ? target.QsWindow.window : null
  }

  function targetBelongsToWindow(target, window) {
    return !!target && !!window && targetWindow(target) === window
  }

  function slotWindow(slot) {
    if (!slot) return null
    return targetWindow(slot.activeItem) || targetWindow(slot)
  }

  function sameWindow(left, right) {
    if (!left || !right) return false
    if (left === right) return true
    return !!left.screen && !!right.screen && !!left.screen.name && !!right.screen.name && left.screen.name === right.screen.name
  }

  function targetTooltipHovered(target) {
    return !!target && target.visible !== false && target.opacity !== 0 && target.tooltipHovered === true
  }

  function clearTooltip() {
    tooltipTimer.stop()
    pendingTooltipTarget = null
    pendingTooltipText = ""
    tooltipTarget = null
    tooltipText = ""
    tooltipShown = false
  }

  function prepareSlotForResponsiveHide(slot) {
    BarResponsiveModel.prepareSlotForHide(root, slot)
  }

  function clearBarDrag() {
    barDragSource = null
    barDragWindow = null
    barDragScreen = null
    barDragImageUrl = ""
    barDragTarget = null
    barDragAfter = false
    barDragSceneX = 0
    barDragSceneY = 0
    barDragScreenX = 0
    barDragScreenY = 0
    barDragOffsetX = 0
    barDragOffsetY = 0
  }

  function enterEditMode() {
    editMode = true
    clearTooltip()
  }

  function exitEditMode() {
    editMode = false
    clearBarDrag()
  }

  function toggleEditMode() {
    if (editMode) exitEditMode()
    else enterEditMode()
  }

  function barDragScreenPoint(scenePoint) {
    var x = scenePoint ? scenePoint.x : 0
    var y = scenePoint ? scenePoint.y : 0
    var window = barDragWindow
    if (!window || !window.screen) return { x: x, y: y }

    if (root.position === "bottom")
      y += Math.max(0, window.screen.height - window.height)
    else if (root.position === "right")
      x += Math.max(0, window.screen.width - window.width)

    return { x: x, y: y }
  }

  function captureBarDragGhost(slot) {
    var item = slot && slot.activeItem ? slot.activeItem : null
    barDragImageUrl = ""
    if (!item || typeof item.grabToImage !== "function") return

    var grabWidth = Math.max(1, Math.ceil(item.width || item.implicitWidth || slot.width || 1))
    var grabHeight = Math.max(1, Math.ceil(item.height || item.implicitHeight || slot.height || 1))
    item.grabToImage(function(result) {
      if (root.barDragSource !== slot || !result || !result.url) return
      root.barDragImageUrl = result.url
    }, Qt.size(grabWidth, grabHeight))
  }

  function requestPopoutFor(surfacePosition, owner, anchorItem, moduleId, owningScreen) {
    var anchor = anchorItem || (owner && owner.anchorItem ? owner.anchorItem : null)
    var ownerModule = moduleId || (owner && owner.owner && owner.owner.moduleName ? owner.owner.moduleName : "")
    activateInteractionFor(surfacePosition, anchor, ownerModule, owningScreen)
    if (activePopout === owner) return
    if (activePopout) {
      if ("closeForPopoutSwitch" in activePopout) activePopout.closeForPopoutSwitch()
      else if ("close" in activePopout) activePopout.close()
    }
    if (activePopoutBorderGap.owner !== owner) activePopoutBorderGap = ({})
    activePopout = owner
  }

  function setPopoutBorderGapFor(surfacePosition, owner, start, length, owningScreen) {
    if (!owner || (activePopout && activePopout !== owner)) return
    activePopoutBorderGap = {
      owner: owner,
      screenName: root.screenName(owningScreen),
      edge: surfacePosition,
      start: Math.max(0, Number(start || 0)),
      length: Math.max(0, Number(length || 0))
    }
  }

  function clearPopoutBorderGap(owner) {
    if (activePopoutBorderGap.owner === owner) activePopoutBorderGap = ({})
  }

  function requestPopout(owner, anchorItem, moduleId) {
    requestPopoutFor(position, owner, anchorItem, moduleId)
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  readonly property bool vertical: position === "left" || position === "right"
  readonly property int barSize: vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  readonly property bool compactBar: !vertical && barSize <= 26
  readonly property int outerMargin: compactBar ? 2 : Style.space(8)
  readonly property int sectionGap: compactBar ? 6 : Style.space(4)

  function normalizePosition(value) {
    return BarModel.normalizePosition(value)
  }

  // Apply tray-pinning on top of the shared layout normalization so the
  // bar host and scriptable config helpers can't drift on entry shape.
  function normalizeLayout(layout) {
    var normalized = Util.normalizeLayout(Util.isPlainObject(layout) ? layout : fallbackBarConfig.layout)
    return {
      left:   pinTrayToInner(normalized.left,   "left"),
      center: pinTrayToInner(normalized.center, "center"),
      right:  pinTrayToInner(normalized.right,  "right")
    }
  }

  // The tray drawer reveals inward (away from the bar edge). Place it at the
  // section's inner edge: start of the right section, end of the left/center
  // sections. The drawer's reserved space then sits next to the bar center,
  // not stranded mid-section.
  function pinTrayToInner(entries, section) {
    return BarModel.pinTrayToInner(entries, section)
  }

  function applyBarConfig() {
    var config = Util.isPlainObject(barConfig) ? barConfig : fallbackBarConfig

    position = normalizePosition(config.position)
    centerAnchor = Util.canonicalWidgetId(config.centerAnchor || "")
    layoutConfig = normalizeLayout(config.layout)
    barConfigSerial++
  }

  onBarConfigChanged: applyBarConfig()

  function layoutEntries(region) {
    var serial = barConfigSerial
    var entries = layoutConfig ? layoutConfig[region] : null
    return Array.isArray(entries) ? entries : []
  }

  readonly property var portraitLayouts: {
    var serial = barConfigSerial
    return PortraitBarModel.routeLayout(layoutConfig, function(value) { return root.canonicalWidgetId(value) })
  }

  function portraitSplitEffective(screen) {
    return portraitSplitEnabled && !vertical && ScreenModel.isPortrait(screen)
  }

  function oppositeHorizontalPosition() {
    return position === "bottom" ? "top" : "bottom"
  }

  function panelNavigationSlots(region, screenNameValue, bandValue) {
    return PanelNavigationModel.panelNavigationSlots(
      layoutEntries(region), debugModuleSlots, String(region || ""),
      String(screenNameValue || ""), String(bandValue || ""))
  }

  // Omarchy 4.0's shell routes positional panel hotkeys through the active bar.
  // Count only panel-capable slots that Lacuna actually draws, in shell.json
  // layout order. Any visible responsive/portrait copy is sufficient because
  // the returned id is opened through the bar's normal multi-output routing.
  function panelWidgetIdAt(region, index) {
    return PanelNavigationModel.panelWidgetIdAt(
      layoutEntries(String(region || "")), debugModuleSlots,
      String(region || ""), index)
  }

  function switchPanelFrom(owner, direction) {
    if (!owner) return false

    var currentSlot = null
    for (var i = 0; i < debugModuleSlots.length; i++) {
      var slot = debugModuleSlots[i]
      if (slot && slot.activeItem === owner) {
        currentSlot = slot
        break
      }
    }
    if (!currentSlot) return false

    var slots = panelNavigationSlots(currentSlot.region, currentSlot.surfaceScreenName, currentSlot.band)
    if (slots.length < 2) return false

    var currentIndex = -1
    for (var j = 0; j < slots.length; j++) {
      if (slots[j] === currentSlot) {
        currentIndex = j
        break
      }
    }
    if (currentIndex < 0) return false

    var step = direction < 0 ? -1 : 1
    var nextSlot = slots[(currentIndex + step + slots.length) % slots.length]
    if (!nextSlot || !nextSlot.activeItem || nextSlot.activeItem === owner) return false

    nextSlot.activeItem.open()
    return true
  }

  function entrySettings(entry) {
    return BarModel.entrySettings(entry)
  }

  function entryId(entry) {
    return BarModel.entryId(entry)
  }

  function moduleString(entry, key, fallback) {
    return BarModel.moduleString(entry, key, fallback)
  }

  function entryIndex(entries, name) {
    return BarModel.entryIndex(entries, name)
  }

  function entriesBefore(entries, name) {
    return BarModel.entriesBefore(entries, name)
  }

  function entriesAfter(entries, name) {
    return BarModel.entriesAfter(entries, name)
  }

  function canonicalWidgetId(name) {
    return Util.canonicalWidgetId(name)
  }

  function responsivePriority(name, region) {
    var id = canonicalWidgetId(name)
    if (id === "lacuna.menu-button") return 1000
    if (id === "lacuna.clock" || id === "omarchy.clock") return 980
    if (id === "lacuna.workspaces" || id === "omarchy.workspaces") return 960
    if (id === "lacuna.bar-size-pill") return 950
    if (id === "lacuna.screen-recording") return 940
    if (id === "lacuna.system-update") return 920
    if (id === "lacuna.notifications" || id === "omarchy.notifications") return 900
    if (id === "lacuna.power" || id === "omarchy.power") return 880
    if (id === "lacuna.audio" || id === "omarchy.audio") return 860
    if (id === "lacuna.network" || id === "omarchy.network") return 840
    if (id === "lacuna.bluetooth" || id === "omarchy.bluetooth") return 820
    if (id === "lacuna.tray" || id === "omarchy.tray") return 800
    if (id === "lacuna.codex-usage" || id === "lacuna.claude-usage") return 700
    if (id === "lacuna.weather") return 680
    if (id === "lacuna.temperature") return 640
    if (id === "lacuna.system-stats") return 620
    if (id === "lacuna.mpris" || id === "omarchy.mpris") return 600
    if (id === "lacuna.theme" || id === "lacuna.wallpaper") return 440
    if (id === "lacuna.nightlight" || id === "lacuna.idle-inhibitor") return 420
    if (id === "lacuna.voxtype") return 400
    if (id === "lacuna.bar-seam") return 80
    return region === "center" ? 300 : 500
  }

  function expandPath(path) {
    return BarModel.expandPath(path, home)
  }

  function customModuleSafeName(name) {
    return BarModel.customModuleSafeName(name)
  }

  function customModuleType(entry) {
    return BarModel.customModuleType(entry)
  }

  function customModuleSource(entry) {
    var source = BarModel.customModulePath(entry, home, omarchyConfigDir)
    return source ? Util.fileUrl(source) : ""
  }

  Component.onCompleted: applyBarConfig()

  function setCenterSectionHovered(hovered) {
    centerSectionHovered = hovered
    if (hovered) {
      centerSectionRevealTimer.stop()
      centerSectionRevealHeld = true
    } else {
      centerSectionRevealTimer.restart()
    }
  }

  Timer {
    id: centerSectionRevealTimer
    interval: 120
    onTriggered: root.centerSectionRevealHeld = root.centerSectionHovered
  }

  function run(command) {
    if (!command) return

    Util.execDetached(command)
  }

  function openConfigPanel() {
    for (var i = 0; i < configControls.length; i++) {
      var control = configControls[i]
      if (!control || control.visible !== true || typeof control.openPanel !== "function") continue
      control.openPanel()
      return true
    }
    return false
  }

  function rawLayoutSection(config, region) {
    if (!Util.isPlainObject(config.bar)) config.bar = {}
    if (!Util.isPlainObject(config.bar.layout)) config.bar.layout = {}
    if (!Array.isArray(config.bar.layout[region])) config.bar.layout[region] = []

    return config.bar.layout[region]
  }

  function rawEntryIndex(entries, name) {
    for (var i = 0; i < entries.length; i++) {
      if (root.entryId(entries[i]) === name) return i
    }

    return -1
  }

  function validLayout(layout) {
    if (!Util.isPlainObject(layout)) return false
    var regions = ["left", "center", "right"]
    var seen = {}
    for (var r = 0; r < regions.length; r++) {
      var entries = layout[regions[r]]
      if (!Array.isArray(entries)) return false
      for (var i = 0; i < entries.length; i++) {
        var id = entryId(entries[i])
        if (!id || seen[id]) return false
        seen[id] = true
      }
    }
    return true
  }

  function moveModuleInConfig(config, fromRegion, fromName, toRegion, beforeName) {
    var fromEntries = rawLayoutSection(config, fromRegion)
    var toEntries = rawLayoutSection(config, toRegion)
    var fromIndex = rawEntryIndex(fromEntries, fromName)
    if (fromIndex < 0) return false

    var toIndex = beforeName ? rawEntryIndex(toEntries, beforeName) : toEntries.length
    if (toIndex < 0) toIndex = toEntries.length

    if (fromRegion === toRegion && fromIndex === toIndex) return false

    var movedEntry = fromEntries[fromIndex]
    fromEntries.splice(fromIndex, 1)

    if (fromRegion === toRegion && fromIndex < toIndex) toIndex -= 1
    if (toIndex < 0) toIndex = 0
    if (toIndex > toEntries.length) toIndex = toEntries.length
    if (fromRegion === toRegion && fromIndex === toIndex) {
      fromEntries.splice(fromIndex, 0, movedEntry)
      return false
    }

    toEntries.splice(toIndex, 0, movedEntry)
    if (!validLayout(config.bar.layout)) {
      toEntries.splice(toIndex, 1)
      fromEntries.splice(fromIndex, 0, movedEntry)
      return false
    }
    return true
  }

  function dropBarModule(source, toRegion, beforeName) {
    if (!source || !source.region || !source.moduleName || !toRegion) return false
    if (source.region === toRegion && source.moduleName === beforeName) return false
    if (!root.shell || typeof root.shell.mutateShellConfig !== "function") return false

    var changed = false
    root.shell.mutateShellConfig(function(config) {
      changed = moveModuleInConfig(config, source.region, source.moduleName, toRegion, beforeName)
    })
    return changed
  }

  function moduleDropAtScene(scenePoint, sourceSlot) {
    var sourceWindow = root.slotWindow(sourceSlot) || root.barDragWindow
    for (var i = 0; i < debugModuleSlots.length; i++) {
      var slot = debugModuleSlots[i]
      if (!slot || slot === sourceSlot || !slot.dragEnabled || slot.band !== sourceSlot.band || !slot.visible || slot.width <= 0 || slot.height <= 0) continue
      if (sourceWindow && !root.sameWindow(root.slotWindow(slot), sourceWindow)) continue

      var slotPoint = { x: slot.x, y: slot.y }
      try {
        slotPoint = slot.mapToItem(null, 0, 0)
      } catch (e) {
      }

      if (scenePoint.x >= slotPoint.x && scenePoint.x <= slotPoint.x + slot.width &&
          scenePoint.y >= slotPoint.y && scenePoint.y <= slotPoint.y + slot.height) {
        return {
          slot: slot,
          after: root.vertical ? scenePoint.y > slotPoint.y + slot.height / 2 : scenePoint.x > slotPoint.x + slot.width / 2
        }
      }
    }

    return null
  }

  function visibleModuleSlot(region, name, sourceSlot) {
    var sourceWindow = root.slotWindow(sourceSlot) || root.barDragWindow
    for (var i = 0; i < debugModuleSlots.length; i++) {
      var slot = debugModuleSlots[i]
      if (!slot || slot === sourceSlot || slot.band !== sourceSlot.band || slot.region !== region || slot.moduleName !== name ||
          !slot.visible || slot.width <= 0 || slot.height <= 0) continue
      if (sourceWindow && !root.sameWindow(root.slotWindow(slot), sourceWindow)) continue
      return slot
    }

    return null
  }

  function nextVisibleModuleName(region, afterName, sourceSlot) {
    var entries = layoutEntries(region)
    var found = false
    for (var i = 0; i < entries.length; i++) {
      var name = entryId(entries[i])
      if (!found) {
        found = name === afterName
        continue
      }

      if (visibleModuleSlot(region, name, sourceSlot)) return name
    }

    return ""
  }

  function dropBarModuleAtTarget(sourceSlot, targetSlot, afterTarget) {
    if (!sourceSlot || !targetSlot) return false

    var beforeName = afterTarget ? nextVisibleModuleName(targetSlot.region, targetSlot.moduleName, sourceSlot) : targetSlot.moduleName
    return dropBarModule(sourceSlot, targetSlot.region, beforeName)
  }

  function moduleTargetClickable(target) {
    return target
      && target.visible !== false
      && target.opacity !== 0
      && target.interactive !== false
      && target.pressable !== false
      && target.concealed !== true
      && typeof target.triggerPress === "function"
  }

  function moduleClickTargetAt(slot, localX, localY) {
    for (var i = clickTargets.length - 1; i >= 0; i--) {
      var target = clickTargets[i]
      if (!moduleTargetClickable(target)) continue

      var targetPoint = { x: localX, y: localY }
      try {
        targetPoint = slot.mapToItem(target, localX, localY)
      } catch (e) {
        continue
      }

      if (targetPoint.x >= 0 && targetPoint.x <= target.width &&
          targetPoint.y >= 0 && targetPoint.y <= target.height) {
        return target
      }
    }

    if (moduleTargetClickable(slot.activeItem)) return slot.activeItem
    return null
  }

  function pressModuleClickTarget(slot, button, localX, localY) {
    var target = moduleClickTargetAt(slot, localX, localY)
    if (!target) return false

    slot.surfaceContext.activateInteraction(slot.activeItem || slot, slot.moduleName)
    target.triggerPress(button)
    return true
  }

  function opaqueColor(colorValue) {
    var c = colorValue
    if (typeof c === "string") c = Qt.color(c)
    return Qt.rgba(c.r, c.g, c.b, 1)
  }

  function runProcess(process) {
    if (!process.running)
      process.running = true
  }

  function showTooltip(target, text) {
    clearTooltip()

    if (!targetTooltipHovered(target) || !text) {
      tooltipRequest += 1
      return
    }

    var request = tooltipRequest + 1
    tooltipRequest = request
    pendingTooltipTarget = target
    pendingTooltipText = text

    Qt.callLater(function() {
      if (request !== tooltipRequest) return
      if (!targetTooltipHovered(pendingTooltipTarget)) {
        clearTooltip()
        return
      }
      tooltipTarget = pendingTooltipTarget
      tooltipText = pendingTooltipText
      pendingTooltipTarget = null
      pendingTooltipText = ""
      tooltipTimer.restart()
    })
  }

  function hideTooltip(target) {
    if (tooltipTarget !== target && pendingTooltipTarget !== target) return

    tooltipRequest += 1
    clearTooltip()
  }

  Timer {
    id: tooltipTimer
    interval: 400
    onTriggered: {
      if (root.targetTooltipHovered(root.tooltipTarget)) root.tooltipShown = true
      else root.clearTooltip()
    }
  }

  Timer {
    interval: 100
    running: root.tooltipShown
    repeat: true
    onTriggered: if (!root.targetTooltipHovered(root.tooltipTarget)) root.hideTooltip(root.tooltipTarget)
  }

  // Presence of the `bar-off` flag = bar hidden. Watching the parent toggles
  // directory because FileView can't observe a file that doesn't exist yet,
  // and the flag is created/removed by `omarchy-toggle-bar`.
  Process {
    id: barHiddenProbe
    running: true
    command: ["bash", "-lc", "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo yes || echo no"]
    stdout: SplitParser { onRead: function(line) { root.barHidden = String(line).trim() === "yes" } }
  }
  FileView {
    path: root.home + "/.local/state/omarchy/toggles"
    watchChanges: true
    printErrors: false
    onFileChanged: barHiddenProbe.running = true
  }

  Variants {
    model: root.validBarScreens

    delegate: Component {
      BarPanel {
        required property var modelData

        screen: modelData
        surfacePosition: root.position
        surfaceLayout: root.portraitSplitEffective(modelData) ? root.portraitLayouts.primary : root.layoutConfig
        band: "primary"
        splitActive: true
        dragEnabled: true
        centerAnchorEnabled: true
      }
    }
  }

  // Companion bars occupy the opposite horizontal edge and cannot overlap
  // the primary bar, so only portrait outputs that actually use the split
  // need a mapped surface.
  Variants {
    model: root.portraitCompanionScreens

    delegate: Component {
      BarPanel {
        required property var modelData

        screen: modelData
        surfacePosition: root.oppositeHorizontalPosition()
        surfaceLayout: root.portraitLayouts.companion
        band: "companion"
        splitActive: root.portraitSplitEffective(modelData)
        dragEnabled: false
        centerAnchorEnabled: false
      }
    }
  }

  Variants {
    model: root.validBarScreens

    delegate: Component {
      DragGhostPanel {
        required property var modelData

        screen: modelData
        ghostScreen: modelData
      }
    }
  }

  function popoutAvoidanceInsetsFor(screen, surfacePosition) {
    if (typeof root.popoutAvoidanceInsetsProvider !== "function")
      return { left: 0, right: 0, top: 0, bottom: 0 }
    var value = root.popoutAvoidanceInsetsProvider(screen, surfacePosition)
    return value && typeof value === "object" ? value : ({ left: 0, right: 0, top: 0, bottom: 0 })
  }

  function fullscreenSuppressedFor(screen) {
    return typeof root.fullscreenSuppressionProvider === "function"
      && root.fullscreenSuppressionProvider(screen) === true
  }

  function dismissTransientUiForScreen(screen) {
    var name = root.screenName(screen)
    if (name !== "" && root.activeInteractionScreenName === name) {
      if (root.activePopout && typeof root.activePopout.close === "function")
        root.activePopout.close()
      root.activePopout = null
      root.activePopoutBorderGap = ({})
      root.activePopupContext = ({})
    }
    root.clearTooltip()
    if (root.barDragScreen && root.screenName(root.barDragScreen) === name)
      root.clearBarDrag()
  }

  component SurfaceBarContext: QtObject {
    required property string surfacePosition
    property var owningScreen: null

    readonly property string position: surfacePosition
    readonly property bool vertical: position === "left" || position === "right"
    readonly property int barSize: root.barSize
    readonly property bool compactBar: root.compactBar
    readonly property real logicalWidth: owningScreen ? Number(owningScreen.width || 0) : 0
    readonly property real logicalHeight: owningScreen ? Number(owningScreen.height || 0) : 0
    readonly property real outputScale: owningScreen ? Number(owningScreen.devicePixelRatio || 1) : 1
    readonly property string widthClass: BarResponsiveModel.widthClass(logicalWidth)
    readonly property color foreground: root.foreground
    readonly property color barForeground: root.barForeground
    readonly property color background: root.background
    readonly property color accent: root.accent
    readonly property color urgent: root.urgent
    readonly property bool frameBorderEnabled: root.frameBorderEnabled
    readonly property bool fullFrameEnabled: root.fullFrameEnabled
    readonly property int resolvedCornerRadius: root.resolvedCornerRadius
    readonly property color frameBorderColor: root.frameBorderColor
    readonly property string fontFamily: root.fontFamily
    readonly property var shell: root.shell
    readonly property string omarchyPath: root.omarchyPath
    readonly property var manifest: root.manifest
    readonly property var activePopout: root.activePopout
    readonly property bool editMode: root.editMode
    readonly property bool lacunaFrameHost: root.lacunaFrameHost
    readonly property var layout: root.layoutConfig
    readonly property var popupAvoidanceInsets: root.popoutAvoidanceInsetsFor(owningScreen, position)
    readonly property bool fullscreenSuppressed: root.fullscreenSuppressedFor(owningScreen)

    function popupContext(anchorItem, moduleId) {
      return root.popupContextFor(position, anchorItem, moduleId, owningScreen)
    }

    function activateInteraction(anchorItem, moduleId) {
      return root.activateInteractionFor(position, anchorItem, moduleId, owningScreen)
    }

    function requestPopout(owner, anchorItem, moduleId) {
      return root.requestPopoutFor(position, owner, anchorItem, moduleId, owningScreen)
    }

    function setPopoutBorderGap(owner, start, length) {
      root.setPopoutBorderGapFor(position, owner, start, length, owningScreen)
    }

    function clearPopoutBorderGap(owner) { root.clearPopoutBorderGap(owner) }
    function registerClickTarget(target) { root.registerClickTarget(target) }
    function unregisterClickTarget(target) { root.unregisterClickTarget(target) }
    function releasePopout(owner) { root.releasePopout(owner) }
    function showTooltip(target, text) { root.showTooltip(target, text) }
    function hideTooltip(target) { root.hideTooltip(target) }
    function run(command) { root.run(command) }
    function moduleWidgets(pluginId) { return root.moduleWidgets(pluginId) }
    function switchPanelFrom(owner, direction) { return root.switchPanelFrom(owner, direction) }
    function toggleMenu(payloadJson) { return root.toggleMenu(payloadJson) }
    function openConfigPanel() { return root.openConfigPanel() }
    function enterEditMode() { root.enterEditMode() }
    function exitEditMode() { root.exitEditMode() }
  }

  component BarPanel: PanelWindow {
    id: barWindow

    required property string surfacePosition
    required property var surfaceLayout
    required property string band
    property bool splitActive: false
    property bool dragEnabled: true
    property bool centerAnchorEnabled: true
    readonly property bool surfaceVertical: surfacePosition === "left" || surfacePosition === "right"
    readonly property bool fullscreenSuppressed: root.fullscreenSuppressedFor(screen)
    readonly property bool configuredSurfaceActive: band === "primary" ? !root.barHidden : splitActive && !root.barHidden
    readonly property bool surfaceActive: configuredSurfaceActive && !fullscreenSuppressed
    readonly property string surfaceScreenName: root.screenName(screen)

    onFullscreenSuppressedChanged: if (fullscreenSuppressed) root.dismissTransientUiForScreen(screen)
    readonly property var outlineInsets: typeof root.barOutlineInsetsProvider === "function"
      ? root.barOutlineInsetsProvider(screen, surfacePosition) : ({ left: 0, right: 0, top: 0, bottom: 0 })
    readonly property real outlineLeftInset: Math.max(0, Number(outlineInsets.left || 0))
    readonly property real outlineRightInset: Math.max(0, Number(outlineInsets.right || 0))
    readonly property real outlineTopInset: Math.max(0, Number(outlineInsets.top || 0))
    readonly property real outlineBottomInset: Math.max(0, Number(outlineInsets.bottom || 0))
    readonly property var popoutBorderGap: root.activePopoutBorderGap
    readonly property bool popoutBorderGapActive: popoutBorderGap
      && popoutBorderGap.screenName === surfaceScreenName
      && popoutBorderGap.edge === surfacePosition
      && Number(popoutBorderGap.length || 0) > 0
    readonly property real outlineAxisStart: surfaceVertical ? outlineTopInset : outlineLeftInset
    readonly property real outlineAxisEnd: surfaceVertical
      ? Math.max(outlineAxisStart, height - outlineBottomInset)
      : Math.max(outlineAxisStart, width - outlineRightInset)
    readonly property real popoutBorderGapStart: popoutBorderGapActive
      ? Math.max(outlineAxisStart, Math.min(outlineAxisEnd, Number(popoutBorderGap.start || 0)))
      : outlineAxisEnd
    readonly property real popoutBorderGapEnd: popoutBorderGapActive
      ? Math.max(popoutBorderGapStart, Math.min(outlineAxisEnd,
          Number(popoutBorderGap.start || 0) + Number(popoutBorderGap.length || 0)))
      : outlineAxisEnd

    visible: band === "companion" ? true : !root.barHidden

    anchors {
      top: barWindow.surfacePosition === "top" || barWindow.surfaceVertical
      bottom: barWindow.surfacePosition === "bottom" || barWindow.surfaceVertical
      left: barWindow.surfacePosition === "left" || !barWindow.surfaceVertical
      right: barWindow.surfacePosition === "right" || !barWindow.surfaceVertical
    }

    implicitWidth: barWindow.surfaceVertical ? (barWindow.surfaceActive ? root.barSize : 0) : 0
    implicitHeight: barWindow.surfaceVertical ? 0 : (barWindow.surfaceActive ? root.barSize : 0)
    color: barWindow.surfaceActive ? root.background : "transparent"
    WlrLayershell.namespace: band === "companion" ? "lacuna-bar-portrait-companion" : "omarchy-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: barWindow.surfaceActive ? ExclusionMode.Auto : ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
      Region {
        width: barWindow.surfaceActive ? barWindow.width : 0
        height: barWindow.surfaceActive ? barWindow.height : 0
      }
    }

    SurfaceBarContext {
      id: surfaceBarContext
      surfacePosition: barWindow.surfacePosition
      owningScreen: barWindow.screen
    }

    Loader {
      anchors.fill: parent
      active: barWindow.band === "primary" || barWindow.surfaceActive
      visible: barWindow.surfaceActive
      sourceComponent: barWindow.surfaceVertical ? verticalBar : horizontalBar
    }

    // Standalone mode paints only the exposed shell seam, never a closed box.
    // Insets remove segments owned by an attached sidebar or open bar flyout.
    Repeater {
      model: ["top", "bottom"]
      delegate: Item {
        required property string modelData
        visible: barWindow.surfaceActive && root.barOutlineEnabled
          && barWindow.surfacePosition === modelData
        anchors.fill: parent
        z: 100

        Rectangle {
          x: barWindow.outlineAxisStart
          y: modelData === "top" ? Math.max(0, parent.height - 1) : 0
          width: Math.max(0, barWindow.popoutBorderGapStart - barWindow.outlineAxisStart)
          height: 1
          color: root.frameBorderColor
        }

        Rectangle {
          x: barWindow.popoutBorderGapEnd
          y: modelData === "top" ? Math.max(0, parent.height - 1) : 0
          width: Math.max(0, barWindow.outlineAxisEnd - barWindow.popoutBorderGapEnd)
          height: 1
          color: root.frameBorderColor
        }
      }
    }

    Repeater {
      model: ["left", "right"]
      delegate: Item {
        required property string modelData
        visible: barWindow.surfaceActive && root.barOutlineEnabled
          && barWindow.surfacePosition === modelData
        anchors.fill: parent
        z: 100

        Rectangle {
          x: modelData === "left" ? Math.max(0, parent.width - 1) : 0
          y: barWindow.outlineAxisStart
          width: 1
          height: Math.max(0, barWindow.popoutBorderGapStart - barWindow.outlineAxisStart)
          color: root.frameBorderColor
        }

        Rectangle {
          x: modelData === "left" ? Math.max(0, parent.width - 1) : 0
          y: barWindow.popoutBorderGapEnd
          width: 1
          height: Math.max(0, barWindow.outlineAxisEnd - barWindow.popoutBorderGapEnd)
          color: root.frameBorderColor
        }
      }
    }

    PopupWindow {
      id: tooltipWindow

      visible: root.tooltipShown && root.tooltipTarget !== null && root.tooltipText !== "" && root.targetBelongsToWindow(root.tooltipTarget, barWindow)
      color: "transparent"
      implicitWidth: Math.ceil(tooltipBubble.implicitWidth)
      implicitHeight: Math.ceil(tooltipBubble.implicitHeight)

      anchor {
        id: tooltipAnchor
        window: barWindow
        adjustment: PopupAdjustment.Slide
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        rect.width: 1
        rect.height: 1

        onAnchoring: {
          var target = root.tooltipTarget
          if (!root.targetBelongsToWindow(target, barWindow)) return

          var popupWidth = tooltipWindow.implicitWidth
          var popupHeight = tooltipWindow.implicitHeight
          var localX = target.width / 2 - popupWidth / 2
          var localY = target.height + 6

          if (barWindow.surfacePosition === "bottom") {
            localY = -popupHeight - 6
          } else if (barWindow.surfacePosition === "left") {
            localX = target.width + 6
            localY = target.height / 2 - popupHeight / 2
          } else if (barWindow.surfacePosition === "right") {
            localX = -popupWidth - 6
            localY = target.height / 2 - popupHeight / 2
          }

          var point = barWindow.contentItem.mapFromItem(target, localX, localY)
          tooltipAnchor.rect.x = Math.round(point.x)
          tooltipAnchor.rect.y = Math.round(point.y)
        }
      }

      BorderSurface {
        id: tooltipBubble
        implicitWidth: tooltipLabel.implicitWidth + 20
        implicitHeight: tooltipLabel.implicitHeight + 14
        color: Color.tooltip.background
        borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
        radius: Style.cornerRadius

        Text {
          id: tooltipLabel
          anchors.centerIn: parent
          text: root.tooltipText
          color: Color.tooltip.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }
    }

    Component {
      id: horizontalBar

      Item {
        id: horizontalRoot
        anchors.fill: parent

        readonly property var responsivePlan: BarResponsiveModel.horizontalPlan(
          width,
          root.outerMargin,
          root.sectionGap,
          centerModules.anchorNaturalLength,
          root.barSize
        )
        readonly property int centerBudget: responsivePlan.centerLength
        readonly property int sideBudget: responsivePlan.sideLength

        CenterModules {
          id: centerModules
          anchors.fill: parent
          entries: barWindow.surfaceLayout.center
          surfaceContext: surfaceBarContext
          band: barWindow.band
          dragEnabled: barWindow.dragEnabled
          centerAnchorEnabled: barWindow.centerAnchorEnabled
          surfaceVertical: barWindow.surfaceVertical
          surfaceScreenName: barWindow.surfaceScreenName
          availableLength: horizontalRoot.centerBudget
        }

        LeftModules {
          anchors.left: parent.left
          anchors.leftMargin: root.outerMargin
          anchors.verticalCenter: parent.verticalCenter
          entries: barWindow.surfaceLayout.left
          surfaceContext: surfaceBarContext
          band: barWindow.band
          dragEnabled: barWindow.dragEnabled
          surfaceVertical: barWindow.surfaceVertical
          surfaceScreenName: barWindow.surfaceScreenName
          availableLength: horizontalRoot.sideBudget
          overflowEnabled: true
        }

        RightModules {
          flowAlignment: "end"
          anchors.right: parent.right
          anchors.rightMargin: root.outerMargin
          anchors.verticalCenter: parent.verticalCenter
          entries: barWindow.surfaceLayout.right
          surfaceContext: surfaceBarContext
          band: barWindow.band
          dragEnabled: barWindow.dragEnabled
          surfaceVertical: barWindow.surfaceVertical
          surfaceScreenName: barWindow.surfaceScreenName
          availableLength: horizontalRoot.sideBudget
          overflowEnabled: true
        }
      }
    }

    Component {
      id: verticalBar

      Item {
        anchors.fill: parent

        CenterModules {
          anchors.fill: parent
          entries: barWindow.surfaceLayout.center
          surfaceContext: surfaceBarContext
          band: barWindow.band
          dragEnabled: barWindow.dragEnabled
          centerAnchorEnabled: barWindow.centerAnchorEnabled
          surfaceVertical: barWindow.surfaceVertical
          surfaceScreenName: barWindow.surfaceScreenName
        }

        LeftModules {
          anchors.top: parent.top
          anchors.topMargin: root.outerMargin
          anchors.horizontalCenter: parent.horizontalCenter
          entries: barWindow.surfaceLayout.left
          surfaceContext: surfaceBarContext
          band: barWindow.band
          dragEnabled: barWindow.dragEnabled
          surfaceVertical: barWindow.surfaceVertical
          surfaceScreenName: barWindow.surfaceScreenName
        }

        RightModules {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: root.outerMargin
          anchors.horizontalCenter: parent.horizontalCenter
          entries: barWindow.surfaceLayout.right
          surfaceContext: surfaceBarContext
          band: barWindow.band
          dragEnabled: barWindow.dragEnabled
          surfaceVertical: barWindow.surfaceVertical
          surfaceScreenName: barWindow.surfaceScreenName
        }
      }
    }
  }

  Component { id: emptyModuleComponent; Item { implicitWidth: 0; implicitHeight: 0; visible: false } }

  component DragGhostPanel: PanelWindow {
    id: ghostWindow

    required property var ghostScreen
    readonly property bool screenMatches: root.barDragScreen === ghostScreen ||
      (root.barDragScreen && ghostScreen && root.barDragScreen.name && ghostScreen.name && root.barDragScreen.name === ghostScreen.name)
    readonly property bool active: root.barDragSource && root.barDragScreen && screenMatches
      && !root.fullscreenSuppressedFor(ghostScreen)
    readonly property var sourceItem: root.barDragSource ? root.barDragSource.activeItem : null
    readonly property int ghostPadding: Style.space(1)
    readonly property int ghostWidth: sourceItem ? Math.max(1, Math.ceil(sourceItem.width)) : 1
    readonly property int ghostHeight: sourceItem ? Math.max(1, Math.ceil(sourceItem.height)) : 1

    visible: active && sourceItem !== null
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-bar-drag-ghost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Visual-only drag feedback. Keep the input region empty so the ghost can
    // sit under the cursor without stealing the MouseArea's active pointer grab.
    mask: Region {}

    Item {
      visible: ghostWindow.visible
      x: Math.round(root.barDragScreenX - root.barDragOffsetX - ghostWindow.ghostPadding)
      y: Math.round(root.barDragScreenY - root.barDragOffsetY - ghostWindow.ghostPadding)
      width: ghostWindow.ghostWidth + ghostWindow.ghostPadding * 2
      height: ghostWindow.ghostHeight + ghostWindow.ghostPadding * 2

      BorderSurface {
        anchors.fill: parent
        color: root.background
        borderSpec: Border.flat(root.barForeground, 1)
        radius: Math.min(Style.cornerRadius, height / 2)
        opacity: 0.94
      }

      Image {
        anchors.fill: parent
        anchors.margins: ghostWindow.ghostPadding
        source: root.barDragImageUrl
        fillMode: Image.Stretch
        smooth: true
        opacity: 0.84
      }
    }
  }

  component LeftModules: ModuleList {
    region: "left"
  }

  component RightModules: ModuleList {
    region: "right"
  }

  component CenterModules: Item {
    id: centerRoot

    required property var entries
    required property var surfaceContext
    required property string band
    required property bool dragEnabled
    required property bool centerAnchorEnabled
    required property bool surfaceVertical
    required property string surfaceScreenName
    property real availableLength: 0
    readonly property bool hasAnchor: centerAnchorEnabled && root.entryIndex(entries, root.centerAnchor) !== -1
    readonly property int anchorIndex: root.entryIndex(entries, root.centerAnchor)
    readonly property var anchorEntry: anchorIndex === -1 ? null : entries[anchorIndex]
    readonly property real anchorNaturalLength: centerLoader.item ? Number(centerLoader.item.anchorNaturalLength || 0) : 0

    Loader {
      id: centerLoader
      anchors.fill: parent
      sourceComponent: centerRoot.surfaceVertical ? verticalCenterModules : horizontalCenterModules
    }

    Component {
      id: horizontalCenterModules

      Item {
        id: horizontalCenterLayout
        anchors.centerIn: parent
        width: centerRoot.availableLength
        height: parent.height
        clip: true
        readonly property real anchorNaturalLength: centerRoot.hasAnchor ? centerAnchorModule.naturalWidth : 0
        readonly property real satelliteAvailableLength: Math.max(
          0,
          Math.floor((centerRoot.availableLength - anchorNaturalLength) / 2)
        )

        HoverHandler {
          onHoveredChanged: root.setCenterSectionHovered(hovered)
        }

        ModuleList {
          visible: !centerRoot.hasAnchor
          entries: centerRoot.entries
          region: "center"
          surfaceContext: centerRoot.surfaceContext
          band: centerRoot.band
          dragEnabled: centerRoot.dragEnabled
          surfaceVertical: centerRoot.surfaceVertical
          surfaceScreenName: centerRoot.surfaceScreenName
          flowAlignment: "center"
          anchors.centerIn: parent
          availableLength: centerRoot.availableLength
          overflowEnabled: true
        }

        ModuleList {
          visible: centerRoot.hasAnchor
          entries: root.entriesBefore(centerRoot.entries, root.centerAnchor)
          region: "center"
          surfaceContext: centerRoot.surfaceContext
          band: centerRoot.band
          dragEnabled: centerRoot.dragEnabled
          surfaceVertical: centerRoot.surfaceVertical
          surfaceScreenName: centerRoot.surfaceScreenName
          flowAlignment: "end"
          anchors.right: centerConfigControl.visible ? centerConfigControl.left : centerAnchorModule.left
          anchors.verticalCenter: centerAnchorModule.verticalCenter
          availableLength: Math.max(0, horizontalCenterLayout.satelliteAvailableLength - (centerConfigControl.visible ? centerConfigControl.width : 0))
          overflowEnabled: true
        }

        ModuleSlot {
          id: centerAnchorModule
          visible: centerRoot.hasAnchor
          entry: centerRoot.anchorEntry
          region: "center"
          surfaceContext: centerRoot.surfaceContext
          band: centerRoot.band
          dragEnabled: centerRoot.dragEnabled
          surfaceVertical: centerRoot.surfaceVertical
          surfaceScreenName: centerRoot.surfaceScreenName
          anchors.centerIn: parent
          width: Math.min(implicitWidth, centerRoot.availableLength)
          clip: width < implicitWidth
        }

        BarConfigControl {
          id: centerConfigControl

          surfaceContext: centerRoot.surfaceContext
          visible: centerRoot.hasAnchor && centerAnchorModule.moduleName === "omarchy.clock" && horizontalCenterLayout.satelliteAvailableLength >= implicitWidth
          clockHovered: centerAnchorModule.hovered
          centerHovered: root.centerSectionRevealHeld && !root.centerHoverRevealSuppressed
          anchors.right: centerAnchorModule.left
          anchors.verticalCenter: centerAnchorModule.verticalCenter
        }

        ModuleList {
          visible: centerRoot.hasAnchor
          entries: root.entriesAfter(centerRoot.entries, root.centerAnchor)
          region: "center"
          surfaceContext: centerRoot.surfaceContext
          band: centerRoot.band
          dragEnabled: centerRoot.dragEnabled
          surfaceVertical: centerRoot.surfaceVertical
          surfaceScreenName: centerRoot.surfaceScreenName
          anchors.left: centerAnchorModule.right
          anchors.verticalCenter: centerAnchorModule.verticalCenter
          availableLength: horizontalCenterLayout.satelliteAvailableLength
          overflowEnabled: true
        }
      }
    }

    Component {
      id: verticalCenterModules

      Item {
        anchors.fill: parent
        readonly property real anchorNaturalLength: 0

        HoverHandler {
          onHoveredChanged: root.setCenterSectionHovered(hovered)
        }

        ModuleList {
          visible: !centerRoot.hasAnchor
          entries: centerRoot.entries
          region: "center"
          surfaceContext: centerRoot.surfaceContext
          band: centerRoot.band
          dragEnabled: centerRoot.dragEnabled
          surfaceVertical: centerRoot.surfaceVertical
          surfaceScreenName: centerRoot.surfaceScreenName
          anchors.centerIn: parent
          availableLength: 0
        }

        ModuleList {
          visible: centerRoot.hasAnchor
          entries: root.entriesBefore(centerRoot.entries, root.centerAnchor)
          region: "center"
          surfaceContext: centerRoot.surfaceContext
          band: centerRoot.band
          dragEnabled: centerRoot.dragEnabled
          surfaceVertical: centerRoot.surfaceVertical
          surfaceScreenName: centerRoot.surfaceScreenName
          anchors.bottom: centerConfigControl.visible ? centerConfigControl.top : centerAnchorModule.top
          anchors.horizontalCenter: centerAnchorModule.horizontalCenter
        }

        ModuleSlot {
          id: centerAnchorModule
          visible: centerRoot.hasAnchor
          entry: centerRoot.anchorEntry
          region: "center"
          surfaceContext: centerRoot.surfaceContext
          band: centerRoot.band
          dragEnabled: centerRoot.dragEnabled
          surfaceVertical: centerRoot.surfaceVertical
          surfaceScreenName: centerRoot.surfaceScreenName
          anchors.centerIn: parent
        }

        BarConfigControl {
          id: centerConfigControl

          surfaceContext: centerRoot.surfaceContext
          visible: centerRoot.hasAnchor && centerAnchorModule.moduleName === "omarchy.clock"
          clockHovered: centerAnchorModule.hovered
          centerHovered: root.centerSectionRevealHeld && !root.centerHoverRevealSuppressed
          anchors.bottom: centerAnchorModule.top
          anchors.horizontalCenter: centerAnchorModule.horizontalCenter
        }

        ModuleList {
          visible: centerRoot.hasAnchor
          entries: root.entriesAfter(centerRoot.entries, root.centerAnchor)
          region: "center"
          surfaceContext: centerRoot.surfaceContext
          band: centerRoot.band
          dragEnabled: centerRoot.dragEnabled
          surfaceVertical: centerRoot.surfaceVertical
          surfaceScreenName: centerRoot.surfaceScreenName
          anchors.top: centerAnchorModule.bottom
          anchors.horizontalCenter: centerAnchorModule.horizontalCenter
        }
      }
    }
  }

  component BarConfigControl: Item {
    id: configControl

    required property var surfaceContext
    property bool clockHovered: false
    property bool centerHovered: false
    property bool openWhenReady: false

    readonly property var panelItem: configPanelLoader.item
    readonly property bool panelOpen: panelItem ? panelItem.opened === true : false
    readonly property bool revealed: visible && (clockHovered || centerHovered || controlHover.hovered || panelOpen)

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    width: implicitWidth
    height: implicitHeight
    z: 500

    HoverHandler { id: controlHover }

    Component.onCompleted: root.registerConfigControl(configControl)
    Component.onDestruction: root.unregisterConfigControl(configControl)

    function configurePanel(panel) {
      if (!panel) return
      panel.bar = root
      panel.anchorItem = button
    }

    function openPanel() {
      if (!panelItem) {
        openWhenReady = true
        return
      }
      panelItem.open()
    }

    function togglePanel() {
      if (!panelItem) {
        openPanel()
        return
      }
      panelItem.toggle()
    }

    WidgetButton {
      id: button

      anchors.fill: parent
      bar: root
      text: ""
      keepSpace: true
      concealed: !configControl.revealed
      dimmed: configControl.revealed && !controlHover.hovered && !configControl.panelOpen
      interactive: configControl.revealed
      horizontalMargin: 6.5
      verticalPadding: 6
      tooltipText: "Bar config"
      onPressed: function(b) {
        if (b === Qt.LeftButton) configControl.togglePanel()
      }
    }

    Loader {
      id: configPanelLoader

      // Destroy the Overlay KeyboardPanel immediately when fullscreen starts;
      // close animations must never retain paint or a full-screen input mask.
      active: configControl.surfaceContext && !configControl.surfaceContext.fullscreenSuppressed
      source: Qt.resolvedUrl("BarConfigPanel.qml")
      onLoaded: {
        configControl.configurePanel(item)
        if (configControl.openWhenReady) {
          configControl.openWhenReady = false
          item.open()
        }
      }
    }
  }

  component ModuleList: Loader {
    id: moduleListRoot

    property var entries: []
    property string region: ""
    property var surfaceContext: null
    property string band: "primary"
    property bool dragEnabled: true
    property bool surfaceVertical: root.vertical
    property string surfaceScreenName: ""
    property real availableLength: 0
    property bool overflowEnabled: false
    property string flowAlignment: "start"
    property int overflowSerial: 0

    visible: entries.length > 0
    // Hidden center arrangements must not instantiate duplicate widgets or IPC handlers.
    active: visible && entries.length > 0
    sourceComponent: moduleListRoot.surfaceVertical ? verticalModuleList : horizontalModuleList
    width: overflowEnabled && !surfaceVertical ? Math.max(0, availableLength) : (item ? item.implicitWidth : 0)
    height: item ? item.implicitHeight : 0

    onEntriesChanged: scheduleOverflowUpdate()
    onAvailableLengthChanged: {
      updateOverflow()
      scheduleOverflowUpdate()
    }
    onOverflowEnabledChanged: scheduleOverflowUpdate()
    onItemChanged: scheduleOverflowUpdate()

    function scheduleOverflowUpdate() {
      overflowSerial++
      Qt.callLater(updateOverflow)
    }

    function updateOverflow() {
      var serial = overflowSerial
      var repeater = item && item.slotRepeater ? item.slotRepeater : null
      if (!repeater) return

      var slots = []
      for (var i = 0; i < repeater.count; i++) {
        var slot = repeater.itemAt(i)
        if (!slot) continue

        var natural = moduleListRoot.surfaceVertical ? Math.ceil(slot.naturalHeight) : Math.ceil(slot.naturalWidth)
        if (!slot.contentVisible || natural <= 0) {
          if (slot.overflowVisible) root.prepareSlotForResponsiveHide(slot)
          slot.overflowVisible = false
          continue
        }

        slots.push({
          slot: slot,
          length: natural,
          priority: root.responsivePriority(slot.moduleName, moduleListRoot.region),
          index: i
        })
      }

      if (moduleListRoot.surfaceVertical || !moduleListRoot.overflowEnabled) {
        for (var showIndex = 0; showIndex < slots.length; showIndex++) slots[showIndex].slot.overflowVisible = true
        return
      }

      var result = BarResponsiveModel.fit(slots, availableLength)
      if (serial !== overflowSerial) return
      for (var slotIndex = 0; slotIndex < slots.length; slotIndex++) {
        var nextVisible = result.visible[slotIndex] === true
        if (slots[slotIndex].slot.overflowVisible && !nextVisible)
          root.prepareSlotForResponsiveHide(slots[slotIndex].slot)
        slots[slotIndex].slot.overflowVisible = nextVisible
      }
    }

    Component {
      id: horizontalModuleList

      Item {
        property alias slotRepeater: moduleRepeater
        implicitWidth: moduleRow.implicitWidth
        implicitHeight: moduleRow.implicitHeight
        clip: moduleListRoot.overflowEnabled

        Row {
          id: moduleRow
          width: implicitWidth
          height: implicitHeight
          x: moduleListRoot.flowAlignment === "end"
            ? parent.width - width
            : (moduleListRoot.flowAlignment === "center" ? (parent.width - width) / 2 : 0)
          spacing: 0

          Repeater {
            id: moduleRepeater
            model: moduleListRoot.entries
            onItemAdded: moduleListRoot.scheduleOverflowUpdate()
            onItemRemoved: moduleListRoot.scheduleOverflowUpdate()

            ModuleSlot {
              required property var modelData
              entry: modelData
              region: moduleListRoot.region
              moduleList: moduleListRoot
              surfaceContext: moduleListRoot.surfaceContext
              band: moduleListRoot.band
              dragEnabled: moduleListRoot.dragEnabled
              surfaceVertical: moduleListRoot.surfaceVertical
              surfaceScreenName: moduleListRoot.surfaceScreenName
            }
          }
        }
      }
    }

    Component {
      id: verticalModuleList

      Column {
        property alias slotRepeater: moduleRepeater
        spacing: 0

        Repeater {
          id: moduleRepeater
          model: moduleListRoot.entries
          onItemAdded: moduleListRoot.scheduleOverflowUpdate()
          onItemRemoved: moduleListRoot.scheduleOverflowUpdate()

          ModuleSlot {
            required property var modelData
            entry: modelData
            region: moduleListRoot.region
            moduleList: moduleListRoot
            surfaceContext: moduleListRoot.surfaceContext
            band: moduleListRoot.band
            dragEnabled: moduleListRoot.dragEnabled
            surfaceVertical: moduleListRoot.surfaceVertical
            surfaceScreenName: moduleListRoot.surfaceScreenName
          }
        }
      }
    }
  }

  component ModuleSlot: Item {
    id: slot

    required property var entry
    required property var surfaceContext
    property string region: ""
    property var moduleList: null
    property string band: "primary"
    property bool dragEnabled: true
    property bool surfaceVertical: root.vertical
    property string surfaceScreenName: ""
    property bool overflowVisible: true
    readonly property string moduleName: root.entryId(entry)
    readonly property var moduleSettings: root.entrySettings(entry)
    readonly property string customType: root.customModuleType(entry)
    // Re-evaluate when the registry mutates (Component reference changes,
    // plugin enabled/disabled, etc.). Reading the `widgets` property creates
    // the binding dependency — the wrapped function call alone wouldn't.
    readonly property var registryComponent: {
      var w = root.barWidgetRegistry.widgets
      if (customType) return null
      var registryName = root.canonicalWidgetId(moduleName)
      return w[registryName] ? w[registryName].component : null
    }
    readonly property bool qmlCustom: customType === "qml"
    readonly property bool commandCustom: customType === "command"
    readonly property bool registered: registryComponent !== null
    readonly property var activeItem: {
      if (registered) return registryLoader.item
      if (qmlCustom) return qmlLoader.item
      return componentLoader.item
    }
    readonly property bool hovered: moduleHover.hovered
    readonly property bool dragSource: root.barDragSource === slot
    readonly property bool panelOpen: root.activePopout === slot.activeItem
    readonly property real panelIndicatorExtent: PanelIndicatorModel.extent(
      slot.surfaceVertical,
      activeItem,
      slot.width,
      slot.height,
      Style.space(10)
    )
    readonly property real openIndicatorInlineOffset: {
      var item = slot.activeItem
      if (!item || !("openIndicatorInlineOffset" in item)) return 0
      var offset = Number(item.openIndicatorInlineOffset)
      return isFinite(offset) ? offset : 0
    }

    readonly property real itemImplicitWidth: activeItem ? Number(activeItem.implicitWidth || 0) : 0
    readonly property real itemImplicitHeight: activeItem ? Number(activeItem.implicitHeight || 0) : 0
    readonly property bool contentVisible: activeItem && (itemImplicitWidth > 0 || itemImplicitHeight > 0)
    readonly property real naturalWidth: contentVisible ? (surfaceVertical ? root.barSize : itemImplicitWidth) : 0
    readonly property real naturalHeight: contentVisible ? itemImplicitHeight : 0

    visible: overflowVisible && contentVisible
    implicitWidth: contentVisible ? (surfaceVertical ? root.barSize : naturalWidth) : 0
    implicitHeight: contentVisible ? naturalHeight : 0
    width: implicitWidth
    height: implicitHeight
    z: modulePointer.dragging ? 100 : 0

    onNaturalWidthChanged: if (moduleList) moduleList.scheduleOverflowUpdate()
    onNaturalHeightChanged: if (moduleList) moduleList.scheduleOverflowUpdate()
    onContentVisibleChanged: if (moduleList) moduleList.scheduleOverflowUpdate()

    Component.onCompleted: root.registerDebugModuleSlot(slot)
    Component.onDestruction: {
      if (root.barDragSource === slot) root.clearBarDrag()
      root.unregisterDebugModuleSlot(slot)
    }

    HoverHandler { id: moduleHover }

    BorderSurface {
      visible: slot.dragEnabled && (root.editMode || slot.dragSource)
      anchors.fill: parent
      anchors.margins: Style.space(1)
      color: root.background
      borderSpec: Border.flat(root.barForeground, 1)
      radius: Math.min(Style.cornerRadius, height / 2)
      opacity: slot.dragSource ? 0.32 : 0.12
    }

    Loader {
      id: componentLoader
      active: !slot.surfaceContext.fullscreenSuppressed && !slot.qmlCustom && !slot.registered
      sourceComponent: slot.commandCustom ? customCommandModuleComponent : emptyModuleComponent
      anchors.fill: parent
      opacity: slot.dragSource ? 0.22 : 1.0
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Loader {
      id: registryLoader
      active: !slot.surfaceContext.fullscreenSuppressed && slot.registered
      sourceComponent: slot.registered ? slot.registryComponent : null
      anchors.fill: parent
      opacity: slot.dragSource ? 0.22 : 1.0
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Loader {
      id: qmlLoader
      active: !slot.surfaceContext.fullscreenSuppressed && slot.qmlCustom
      source: slot.qmlCustom ? root.customModuleSource(slot.entry) : ""
      anchors.fill: parent
      opacity: slot.dragSource ? 0.22 : 1.0
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Rectangle {
      id: openPanelIndicator

      readonly property int inset: Style.space(2)

      visible: opacity > 0
      opacity: slot.panelOpen && !slot.dragSource ? 0.9 : 0
      color: Color.accent
      radius: Math.min(width, height) / 2
      width: slot.surfaceVertical ? Style.space(2) : slot.panelIndicatorExtent
      height: slot.surfaceVertical ? slot.panelIndicatorExtent : Style.space(2)
      x: slot.surfaceVertical
        ? (slot.surfaceContext.position === "left" ? parent.width - width - inset : inset)
        : (slot.openIndicatorInlineOffset === 0 ? Math.round((parent.width - width) / 2) : (parent.width - width) / 2 + slot.openIndicatorInlineOffset)
      y: slot.surfaceVertical
        ? (slot.openIndicatorInlineOffset === 0 ? Math.round((parent.height - height) / 2) : (parent.height - height) / 2 + slot.openIndicatorInlineOffset)
        : (slot.surfaceContext.position === "top" ? parent.height - height - inset : inset)
      z: 50

      Behavior on opacity {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
      }
    }

    Rectangle {
      visible: !slot.surfaceVertical && root.barDragTarget === slot && !root.barDragAfter
      anchors {
        left: parent.left
        top: parent.top
        bottom: parent.bottom
      }
      width: 2
      color: root.barForeground
      opacity: 0.9
    }

    Rectangle {
      visible: !slot.surfaceVertical && root.barDragTarget === slot && root.barDragAfter
      anchors {
        right: parent.right
        top: parent.top
        bottom: parent.bottom
      }
      width: 2
      color: root.barForeground
      opacity: 0.9
    }

    Rectangle {
      visible: slot.surfaceVertical && root.barDragTarget === slot && !root.barDragAfter
      anchors {
        left: parent.left
        right: parent.right
        top: parent.top
      }
      height: 2
      color: root.barForeground
      opacity: 0.9
    }

    Rectangle {
      visible: slot.surfaceVertical && root.barDragTarget === slot && root.barDragAfter
      anchors {
        left: parent.left
        right: parent.right
        bottom: parent.bottom
      }
      height: 2
      color: root.barForeground
      opacity: 0.9
    }

    MouseArea {
      id: modulePointer

      property bool dragging: false
      property bool suppressClick: false
      property real pressedX: 0
      property real pressedY: 0
      readonly property bool canReorder: slot.dragEnabled && root.editMode && root.shell && typeof root.shell.mutateShellConfig === "function"
      readonly property real dragThreshold: Style.space(4)

      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      enabled: slot.visible && slot.width > 0 && slot.height > 0
      propagateComposedEvents: true
      cursorShape: root.moduleClickTargetAt(slot, mouseX, mouseY) ? Qt.PointingHandCursor : Qt.ArrowCursor
      // Do not assign drag.target here: ModuleSlot is owned by Row/Column
      // positioners, and mutating slot.x/slot.y can leave stale offsets that
      // make neighboring modules overlap after a small aborted drag.

      onPressed: function(mouse) {
        dragging = false
        suppressClick = false
        pressedX = mouse.x
        pressedY = mouse.y
        root.clearBarDrag()
      }

      onPositionChanged: function(mouse) {
        if (!canReorder || !(mouse.buttons & Qt.LeftButton)) return

        var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
        if (distance >= dragThreshold) {
          if (!dragging) {
            root.barDragWindow = root.targetWindow(slot.activeItem) || root.targetWindow(slot)
            root.barDragScreen = root.barDragWindow ? root.barDragWindow.screen : null
            root.barDragOffsetX = pressedX
            root.barDragOffsetY = pressedY
            root.captureBarDragGhost(slot)
            root.barDragSource = slot
          }
          dragging = true
          root.hideTooltip(slot.activeItem)
        }

        if (dragging) {
          var scenePoint = slot.mapToItem(null, mouse.x, mouse.y)
          var screenPoint = root.barDragScreenPoint(scenePoint)
          root.barDragSceneX = scenePoint.x
          root.barDragSceneY = scenePoint.y
          root.barDragScreenX = screenPoint.x
          root.barDragScreenY = screenPoint.y

          var drop = root.moduleDropAtScene(scenePoint, slot)
          root.barDragTarget = drop ? drop.slot : null
          root.barDragAfter = drop ? drop.after : false
        }
      }

      onReleased: function(mouse) {
        var wasDragging = dragging
        var targetSlot = root.barDragTarget
        var afterTarget = root.barDragAfter

        if (wasDragging) suppressClick = true

        dragging = false
        root.clearBarDrag()

        if (wasDragging && targetSlot) {
          root.dropBarModuleAtTarget(slot, targetSlot, afterTarget)
          mouse.accepted = true
        } else if (!wasDragging) {
          mouse.accepted = false
        }
      }

      onCanceled: {
        dragging = false
        suppressClick = false
        root.clearBarDrag()
      }

      onClicked: function(mouse) {
        if (suppressClick) {
          suppressClick = false
          mouse.accepted = true
          return
        }

        if (!root.pressModuleClickTarget(slot, mouse.button, mouse.x, mouse.y)) mouse.accepted = false
      }
    }

    onActiveItemChanged: Qt.callLater(injectProps)
    onModuleSettingsChanged: injectProps()

    function injectProps() {
      var target = activeItem
      if (!target) return
      if ("bar" in target) target.bar = surfaceContext
      if ("moduleName" in target) target.moduleName = moduleName
      if ("settings" in target) target.settings = moduleSettings
    }

    Component {
      id: customCommandModuleComponent
      CustomCommandModule { entry: slot.entry }
    }
  }

  component CustomCommandModule: WidgetButton {
    id: customRoot

    required property var entry
    readonly property string moduleName: root.entryId(entry)
    readonly property var settings: root.entrySettings(entry)
    property string outputText: ""
    property string outputTooltip: ""
    property bool outputActive: false

    function setting(name, fallback) {
      var value = settings ? settings[name] : undefined
      return value === undefined || value === null ? fallback : value
    }

    function update(raw) {
      var data = Util.parseModuleJson(raw)
      var klass = data.class || data.alt || ""

      outputText = data.text || String(raw || "").trim()
      outputTooltip = data.tooltip || String(setting("tooltip", ""))
      outputActive = klass === "active" || (Array.isArray(klass) && klass.indexOf("active") !== -1)
    }

    bar: slot.surfaceContext
    text: outputText || String(setting("text", ""))
    tooltipText: outputTooltip || String(setting("tooltip", ""))
    active: outputActive
    keepSpace: setting("keepSpace", false) === true
    horizontalMargin: Number(setting("horizontalMargin", 7.5))
    verticalPadding: Number(setting("verticalPadding", 6))
    fontSize: Number(setting("fontSize", 12))

    onPressed: function(button) {
      var command = ""
      if (button === Qt.RightButton)
        command = String(setting("onRightClick", ""))
      else if (button === Qt.MiddleButton)
        command = String(setting("onMiddleClick", ""))
      else
        command = String(setting("onClick", ""))

      if (command) root.run(command)
    }

    Process {
      id: customProc
      command: ["bash", "-lc", String(customRoot.setting("exec", ""))]
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: customRoot.update(text)
      }
    }

    Timer {
      interval: Math.max(1, Number(customRoot.setting("interval", 5))) * 1000
      running: String(customRoot.setting("exec", "")) !== ""
      repeat: true
      triggeredOnStart: true
      onTriggered: root.runProcess(customProc)
    }
  }
}
