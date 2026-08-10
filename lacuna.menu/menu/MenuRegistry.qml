import QtQuick

Item {
  id: root

  property string lacunaPath: ""
  property bool sidebarExclusive: true
  property bool sidebarCollapsed: false
  property string sidebarDefaultMode: "off"
  property string sidebarMonitorPolicy: "auto"
  property var sidebarMonitorNames: []
  property var sidebarMonitorOptions: []
  property bool sidebarAutoHideEnabled: false
  property int sidebarAutoHideHotZoneWidth: 3
  property int sidebarAutoHideRevealDelayMs: 120
  property int sidebarAutoHideHideDelayMs: 350
  property bool compact: false
  property string barSizeMode: "full"
  property bool desktopClockEnabled: false
  property string desktopClockAnchor: "bottom-right"
  property int desktopClockOffsetX: 0
  property int desktopClockOffsetY: 0
  property real desktopClockScale: 1
  property bool desktopClockUse12Hour: false
  property string designStyle: "lacuna"
  property string colorProfile: "semantic"
  property string cornerMode: "theme"
  property int cornerRadius: 14
  property int resolvedCornerRadius: 0
  property string quickLaunchLayout: "list"
  property string dailyLaunchLayout: "list"
  property string shortcutsLayout: "list"
  property string controlsLayout: "grid"
  property string shellSettingsSurface: "flyout"
  property bool instantRestart: false
  property string frameMode: "off"
  property string frameReserveMode: "auto"
  property bool frameShadow: false
  property bool frameBorder: false
  property bool portraitSplit: true
  property var mediaProviders: ({})
  property var backgroundEffects: ({})
  property var backgroundVignette: ({})
  property var shellBarConfig: ({})
  property string shellBarPosition: "top"
  property bool shellBarTransparent: false
  property string shellBarCenterAnchor: ""
  property int shellIdleScreensaver: 150
  property int shellIdleLock: 300
  property var shellPlugins: []
  property var barWidgetRegistry: null
  property var pluginRegistry: null
  property int catalogRevision: 0
  property var appCatalog: null
  property var customQuickLaunchApps: []
  property var customQuickLaunchNames: ({})
  property var preferredApps: ({})
  property string settingsPersistenceState: "idle"
  property string settingsPersistenceError: ""
  property int settingsRequestedRevision: 0
  property int settingsConfirmedRevision: 0

  onBarWidgetRegistryChanged: catalogRevision++
  // The app-backed views (quick launch, daily launch) depend on this data,
  // which loads asynchronously. Bump catalogRevision when it arrives so menu
  // consumers rebuild their item models instead of staying empty until a
  // manual refresh (e.g. clicking a section header).
  onAppCatalogChanged: catalogRevision++
  onCustomQuickLaunchAppsChanged: catalogRevision++
  onCustomQuickLaunchNamesChanged: catalogRevision++
  onPreferredAppsChanged: catalogRevision++

  Connections {
    target: root.barWidgetRegistry
    function onChanged() { root.catalogRevision++ }
  }

  function item(kind, icon, label, hint, view, command, tone, priority, layout, danger, group, action, iconSource, switchVisible, switchChecked) {
    return entries.entry({
      kind: kind,
      icon: icon,
      iconSource: iconSource || "",
      label: label,
      hint: hint,
      view: view,
      command: command,
      action: action || "",
      tone: tone,
      priority: priority,
      layout: layout,
      danger: danger === true,
      group: group || "",
      switchVisible: switchVisible === true,
      switchChecked: switchChecked === true
    })
  }

  function grid(group, rows) {
    return entries.grid(group, rows)
  }

  function titleFor(view) {
    if (view === "main") return "Lacuna"
    if (view === "customize") return "Customize"
    if (view === "controls") return "Controls"
    if (view === "system") return "System"
    if (view === "apps") return "Apps"
    if (view === "apps-all") return "All Apps"
    if (view === "lacuna" || view === "lacuna-preferences" || view === "lacuna-clock" || view === "lacuna-preferred-apps") return "Lacuna Settings"
    if (view === "lacuna-shell") return "Runtime"
    if (view.indexOf("apps-") === 0) return categoryTitle(view.substring(5))
    return "Utility Sidebar"
  }

  function shellQuote(value) { return commands.shellQuote(value) }
  function shellDoubleQuote(value) { return commands.shellDoubleQuote(value) }
  function hyprExec(command) { return commands.hyprExec(command) }
  function shellIpcCommand(target, method) { return commands.shellIpcCommand(target, method) }
  function terminalCommand(command, title, holdOpen) { return commands.terminalCommand(command, title, holdOpen) }
  function terminalLaunchCommand(command, title) { return commands.terminalLaunchCommand(command, title) }
  function desktopExecCommand(execLine) { return commands.desktopExecCommand(execLine) }
  function openTerminalCommand() { return commands.openTerminalCommand() }
  function restartLacunaCommand() { return commands.restartLacunaCommand() }
  function openLogCommand() { return commands.openLogCommand() }
  function editPluginCommand() { return commands.editPluginCommand() }
  function editShellConfigCommand() { return commands.editShellConfigCommand() }
  function fontListCommand() { return commands.fontListCommand() }
  function debugCommand() { return commands.debugCommand() }
  function debugIdleCommand() { return commands.debugIdleCommand() }
  function switchThemeCommand() { return commands.switchThemeCommand() }
  function switchBackgroundCommand() { return commands.switchBackgroundCommand() }

  function categories() { return appModel.categories() }
  function categoryMeta(category) { return appModel.categoryMeta(category) }
  function categoryTitle(category) { return appModel.categoryTitle(category) }
  function appIcon(app) { return appModel.appIcon(app) }
  function appIconSource(app) { return appModel.appIconSource(app) }
  function appEntry(app, quickAdd) { return appModel.appEntry(app, quickAdd) }
  function customQuickLaunchContains(id) { return appModel.customQuickLaunchContains(id) }
  function roleMeta(role) { return appModel.roleMeta(role) }
  function preferredAppValue(role) { return appModel.preferredAppValue(role) }
  function preferredAppHint(role) { return appModel.preferredAppHint(role) }
  function roleEntry(role, priority) { return appModel.roleEntry(role, priority) }
  function roleSettingsItem(role) { return appModel.roleSettingsItem(role) }
  function customQuickLaunchItems() { return appModel.customQuickLaunchItems() }
  function preferredAppItems(priority) { return appModel.preferredAppItems(priority) }
  function appItems(category) { return appModel.appItems(category) }

  function designStyleName() {
    if (root.designStyle === "omarchy") return "Omarchy"
    if (root.designStyle === "material") return "Material"
    return "Lacuna"
  }

  function designStyleHint() {
    if (root.designStyle === "omarchy") return "Native Omarchy borders and containment"
    if (root.designStyle === "material") return "Softer tonal surfaces and clearer states"
    return "Flat compact Lacuna linework"
  }

  function cornerModeName() {
    if (root.cornerMode === "square") return "Square"
    if (root.cornerMode === "custom") return "Custom"
    return "Theme"
  }

  function cornerModeHint() {
    if (root.cornerMode === "square") return "Keep Lacuna surfaces and application windows square"
    if (root.cornerMode === "custom") return "Use " + root.cornerRadius + " px for Lacuna surfaces and application windows"
    return "Follow the active Omarchy theme's " + root.resolvedCornerRadius + " px window rounding"
  }

  function cornerRadiusHint() {
    return root.cornerMode === "custom"
      ? "Adjust the live shell and application-window radius"
      : "Saved custom radius; changing it switches all corners to Custom"
  }

  function barSizeModeName() {
    if (root.barSizeMode === "theme") return "Theme"
    return root.barSizeMode === "compact" ? "Compact" : "Full"
  }

  function barSizeModeHint() {
    if (root.barSizeMode === "theme") return "Use the active Omarchy theme bar sizing"
    return root.barSizeMode === "compact" ? "Compact topbar, sidebar, and rail sizing" : "Full topbar, sidebar, and rail sizing"
  }

  function frameReserveModeName() {
    if (root.frameReserveMode === "comfort") return "Comfort"
    if (root.frameReserveMode === "flush") return "Flush"
    return "Auto"
  }

  function frameReserveModeHint() {
    if (root.frameReserveMode === "comfort") return "Always reserve room for Lacuna frame shadows"
    if (root.frameReserveMode === "flush") return "Keep tiled windows flush to the visible Lacuna frame"
    return "Collapse extra frame reserve on single-window or fullscreen workspaces"
  }

  function shellBarPositionHint() {
    if (root.shellBarPosition === "right") return "Bar is anchored to the right edge"
    if (root.shellBarPosition === "bottom") return "Bar is anchored to the bottom edge"
    if (root.shellBarPosition === "left") return "Bar is anchored to the left edge"
    return "Bar is anchored to the top edge"
  }

  function shellBarLayoutSection(section) {
    var bar = root.shellBarConfig || {}
    var layout = bar.layout || {}
    var list = layout[String(section || "")]
    return Array.isArray(list) ? list : []
  }

  function shellBarSectionSummary(section) {
    var count = shellBarLayoutSection(section).length
    if (count === 0) return "Empty"
    if (count === 1) return "1 widget"
    return count + " widgets"
  }

  function shellBarWidgetSettings(id) {
    var sections = ["left", "center", "right"]
    for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
      var entries = shellBarLayoutSection(sections[sectionIndex])
      for (var entryIndex = 0; entryIndex < entries.length; entryIndex++) {
        var entry = entries[entryIndex]
        if (entry && String(entry.id || "") === String(id || "")) return entry
      }
    }
    return ({})
  }

  function workspacesActiveOnly() {
    return shellBarWidgetSettings("lacuna.workspaces").activeWorkspaceOnly === true
  }

  function secondsName(value) {
    var seconds = Math.max(0, Math.round(Number(value) || 0))
    if (seconds % 60 === 0) return String(seconds / 60) + "m"
    return String(seconds) + "s"
  }

  function shellIdleScreensaverName() { return secondsName(root.shellIdleScreensaver) }
  function shellIdleLockName() { return secondsName(root.shellIdleLock) }

  function backgroundEffectsEnabled() {
    return !root.backgroundEffects || root.backgroundEffects.enabled !== false
  }

  function backgroundEffectOptions() {
    return [
      { value: "trackingLines", label: "VHS" },
      { value: "crt", label: "CRT" },
      { value: "filmGrain", label: "Film Grain" },
      { value: "dustMotes", label: "Dust Motes" },
      { value: "auroraDrift", label: "Aurora" },
      { value: "rainfall", label: "Rain" },
      { value: "cinematicLight", label: "Cinematic Light" },
      { value: "godRays", label: "God Rays" }
    ]
  }

  function normalizeBackgroundEffectId(effectId) {
    var id = String(effectId || "").trim()
    if (id === "trackingLines" || id === "filmGrain" || id === "dustMotes" || id === "auroraDrift" || id === "rainfall" || id === "cinematicLight" || id === "godRays" || id === "crt") return id
    return ""
  }

  function activeBackgroundEffects() {
    var source = root.backgroundEffects && Array.isArray(root.backgroundEffects.activeEffects)
      ? root.backgroundEffects.activeEffects
      : [root.backgroundEffects && root.backgroundEffects.activeEffect ? root.backgroundEffects.activeEffect : "trackingLines"]
    var seen = {}
    var stack = []
    for (var i = 0; i < source.length; i++) {
      var id = normalizeBackgroundEffectId(source[i])
      if (id === "" || seen[id] === true) continue
      seen[id] = true
      stack.push(id)
    }
    return stack
  }

  function activeBackgroundEffect() {
    var stack = activeBackgroundEffects()
    if (stack.length > 0) return stack[0]
    return "trackingLines"
  }

  function backgroundEffectStackIndex(effectId) {
    var id = String(effectId || "")
    var stack = activeBackgroundEffects()
    for (var i = 0; i < stack.length; i++) {
      if (stack[i] === id) return i
    }
    return -1
  }

  function backgroundEffectStackCount() {
    return activeBackgroundEffects().length
  }

  function backgroundEffectEnabled(effectId) {
    if (!backgroundEffectsEnabled()) return false
    var effects = root.backgroundEffects && root.backgroundEffects.effects ? root.backgroundEffects.effects : ({})
    var effect = effects[String(effectId || "")]
    if (effect && typeof effect === "object" && effect.enabled === false) return false
    return backgroundEffectStackIndex(effectId) >= 0
  }

  function backgroundEffectName(effectId) {
    if (effectId === "trackingLines") return "Tracking Lines"
    if (effectId === "crt") return "CRT"
    if (effectId === "filmGrain") return "Film Grain"
    if (effectId === "dustMotes") return "Dust Motes"
    if (effectId === "auroraDrift") return "Aurora Drift"
    if (effectId === "rainfall") return "Rainfall"
    if (effectId === "cinematicLight") return "Cinematic Light"
    if (effectId === "godRays") return "God Rays"
    return "Background Effect"
  }

  function backgroundEffectHint(effectId) {
    if (effectId === "trackingLines") {
      return backgroundEffectEnabled(effectId) ? "VHS tracking animation is in the stack" : "VHS tracking animation is available"
    }
    if (effectId === "crt") {
      return backgroundEffectEnabled(effectId) ? "CRT scanline animation is in the stack" : "CRT scanline animation is available"
    }
    if (effectId === "filmGrain") {
      return backgroundEffectEnabled(effectId) ? "Film grain texture is in the stack" : "Film grain texture is available"
    }
    if (effectId === "dustMotes") {
      return backgroundEffectEnabled(effectId) ? "Drifting dust motes are in the stack" : "Dust mote drift is available"
    }
    if (effectId === "auroraDrift") {
      return backgroundEffectEnabled(effectId) ? "Aurora ribbon animation is in the stack" : "Aurora ribbon animation is available"
    }
    if (effectId === "rainfall") {
      return backgroundEffectEnabled(effectId) ? "Rain animation is in the stack" : "Rain animation is available"
    }
    if (effectId === "cinematicLight") {
      return backgroundEffectEnabled(effectId) ? "Cinematic light animation is in the stack" : "Cinematic light animation is available"
    }
    if (effectId === "godRays") {
      return backgroundEffectEnabled(effectId) ? "God rays animation is in the stack" : "God rays animation is available"
    }
    return backgroundEffectEnabled(effectId) ? "Effect is visible" : "Effect is hidden"
  }

  function backgroundEffectsHint() {
    if (!backgroundEffectsEnabled()) return "Wallpaper-layer animations are hidden"
    var count = backgroundEffectStackCount()
    if (count === 0) return "No animation selected"
    if (count === 1) return backgroundEffectName(activeBackgroundEffect()) + " is visible"
    return count + " animations stacked"
  }

  function backgroundAnimationOpacity() {
    var value = Number(root.backgroundEffects && root.backgroundEffects.opacity !== undefined ? root.backgroundEffects.opacity : 1)
    if (isNaN(value)) value = 1
    return Math.max(0, Math.min(1, value))
  }

  function backgroundAnimationOpacityName() {
    return Math.round(backgroundAnimationOpacity() * 100) + "%"
  }

  function backgroundAnimationOpacityHint() {
    return "Overall animation opacity " + backgroundAnimationOpacityName()
  }

  function backgroundEffectStackWarning() {
    var count = backgroundEffectStackCount()
    return count > 3 ? count + " animations are active; heavy stacks may affect shell performance" : ""
  }

  function backgroundEffectsForegroundOverlayEnabled() {
    return root.backgroundEffects && root.backgroundEffects.foregroundOverlay === true
  }

  function backgroundVignetteEnabled() {
    return root.backgroundVignette && root.backgroundVignette.enabled === true
  }

  function backgroundVignetteHint() {
    return backgroundVignetteEnabled() ? "Wallpaper edge darkening is visible" : "Wallpaper edge darkening is hidden"
  }

  function backgroundVignetteIntensity() {
    var value = Number(root.backgroundVignette && root.backgroundVignette.intensity !== undefined ? root.backgroundVignette.intensity : 0.85)
    if (isNaN(value)) value = 0.85
    return Math.max(0, Math.min(1, value))
  }

  function backgroundVignetteIntensityName() {
    return Math.round(backgroundVignetteIntensity() * 100) + "%"
  }

  function backgroundVignetteIntensityHint() {
    return "Edge darkening opacity " + backgroundVignetteIntensityName()
  }

  function ambienceHostPluginId() {
    return "lacuna.ambience-host"
  }

  function backgroundEffectPluginId(effectId) {
    if (effectId === "trackingLines") return "lacuna.vhs-overlay"
    if (effectId === "crt") return "lacuna.crt-overlay"
    if (effectId === "filmGrain") return "lacuna.film-grain-overlay"
    if (effectId === "dustMotes") return "lacuna.dust-motes-overlay"
    if (effectId === "auroraDrift") return "lacuna.aurora-drift"
    if (effectId === "rainfall") return "lacuna.rainfall-overlay"
    if (effectId === "cinematicLight") return "lacuna.cinematic-light-overlay"
    if (effectId === "godRays") return "lacuna.god-rays-overlay"
    return ""
  }

  function backgroundEffectLayerSettings(effectId) {
    var defaults = {
      foregroundOverlay: false
    }
    var pluginId = backgroundEffectPluginId(effectId)
    if (pluginId === "") return defaults

    var plugins = Array.isArray(root.shellPlugins) ? root.shellPlugins : []
    for (var i = 0; i < plugins.length; i++) {
      var entry = plugins[i]
      if (!entry || String(entry.id || "") !== pluginId) continue
      var merged = {}
      for (var key in defaults) merged[key] = defaults[key]
      for (var entryKey in entry) {
        if (entryKey !== "id") merged[entryKey] = entry[entryKey]
      }
      return merged
    }

    return defaults
  }

  function backgroundEffectRuntimeSettings(effectId) {
    var effects = root.backgroundEffects && root.backgroundEffects.effects ? root.backgroundEffects.effects : ({})
    var settings = effects[String(effectId || "")]
    return settings && typeof settings === "object" ? settings : ({})
  }

  function filmGrainSettings() {
    var settings = backgroundEffectRuntimeSettings("filmGrain")
    return {
      intensity: Math.max(0, Math.min(1, numberSetting(settings.intensity, 0.28))),
      speed: Math.max(0.2, Math.min(5, numberSetting(settings.speed, 1))),
      grainCount: Math.max(32, Math.min(520, Math.round(numberSetting(settings.grainCount, 180)))),
      grainSize: Math.max(0.6, Math.min(3.5, numberSetting(settings.grainSize, 1.35))),
      accentBlend: Math.max(0, Math.min(1, numberSetting(settings.accentBlend, 0.18)))
    }
  }

  function filmGrainIntensity() { return filmGrainSettings().intensity }
  function filmGrainSpeed() { return filmGrainSettings().speed }
  function filmGrainGrainCount() { return filmGrainSettings().grainCount }
  function filmGrainGrainSize() { return filmGrainSettings().grainSize }
  function filmGrainAccentBlend() { return filmGrainSettings().accentBlend }
  function filmGrainIntensityName() { return Math.round(filmGrainIntensity() * 100) + "%" }
  function filmGrainSpeedName() { return Math.round(filmGrainSpeed() * 100) + "%" }
  function filmGrainGrainCountName() { return String(filmGrainGrainCount()) }
  function filmGrainGrainSizeName() { return Math.round(filmGrainGrainSize() * 100) + "%" }
  function filmGrainAccentBlendName() { return Math.round(filmGrainAccentBlend() * 100) + "%" }
  function filmGrainIntensityHint() { return "Film grain layer opacity " + filmGrainIntensityName() }
  function filmGrainSpeedHint() { return "Refresh speed " + filmGrainSpeedName() }
  function filmGrainGrainCountHint() { return "Visible grain particles " + filmGrainGrainCountName() }
  function filmGrainGrainSizeHint() { return "Grain dot size " + filmGrainGrainSizeName() }
  function filmGrainAccentBlendHint() { return "Theme accent tint " + filmGrainAccentBlendName() }

  function dustMotesSettings() {
    var settings = backgroundEffectRuntimeSettings("dustMotes")
    return {
      intensity: Math.max(0, Math.min(1, numberSetting(settings.intensity, 0.5))),
      speed: Math.max(0.15, Math.min(4, numberSetting(settings.speed, 0.7))),
      moteCount: Math.max(12, Math.min(180, Math.round(numberSetting(settings.moteCount, 72)))),
      moteSize: Math.max(1, Math.min(8, numberSetting(settings.moteSize, 2.6))),
      accentBlend: Math.max(0, Math.min(1, numberSetting(settings.accentBlend, 0.42))),
      mouseReactive: settings.mouseReactive !== false,
      mouseInfluence: Math.max(0, Math.min(1, numberSetting(settings.mouseInfluence, 0.28)))
    }
  }

  function dustMotesIntensity() { return dustMotesSettings().intensity }
  function dustMotesSpeed() { return dustMotesSettings().speed }
  function dustMotesMoteCount() { return dustMotesSettings().moteCount }
  function dustMotesMoteSize() { return dustMotesSettings().moteSize }
  function dustMotesAccentBlend() { return dustMotesSettings().accentBlend }
  function dustMotesMouseReactive() { return dustMotesSettings().mouseReactive }
  function dustMotesMouseInfluence() { return dustMotesSettings().mouseInfluence }
  function dustMotesIntensityName() { return Math.round(dustMotesIntensity() * 100) + "%" }
  function dustMotesSpeedName() { return Math.round(dustMotesSpeed() * 100) + "%" }
  function dustMotesMoteCountName() { return String(dustMotesMoteCount()) }
  function dustMotesMoteSizeName() { return Math.round(dustMotesMoteSize() * 100) + "%" }
  function dustMotesAccentBlendName() { return Math.round(dustMotesAccentBlend() * 100) + "%" }
  function dustMotesMouseInfluenceName() { return Math.round(dustMotesMouseInfluence() * 100) + "%" }
  function dustMotesIntensityHint() { return "Dust mote layer opacity " + dustMotesIntensityName() }
  function dustMotesSpeedHint() { return "Drift speed " + dustMotesSpeedName() }
  function dustMotesMoteCountHint() { return "Visible dust motes " + dustMotesMoteCountName() }
  function dustMotesMoteSizeHint() { return "Mote dot size " + dustMotesMoteSizeName() }
  function dustMotesAccentBlendHint() { return "Theme accent tint " + dustMotesAccentBlendName() }
  function dustMotesMouseReactiveHint() { return dustMotesMouseReactive() ? "Cursor movement pushes nearby motes" : "Cursor movement does not affect motes" }
  function dustMotesMouseInfluenceHint() { return "Cursor push strength " + dustMotesMouseInfluenceName() }

  function backgroundEffectForegroundCapable(effectId) {
    return backgroundEffectPluginId(effectId) !== ""
  }

  function backgroundEffectForegroundEnabled(effectId) {
    effectId
    return backgroundEffectsForegroundOverlayEnabled()
  }

  function backgroundEffectForegroundHint(effectId) {
    var name = backgroundEffectName(effectId)
    return backgroundEffectForegroundEnabled(effectId) ? name + " draws above shell UI" : name + " stays behind shell UI"
  }

  function cinematicLightSettings() {
    var defaults = {
      intensity: 1,
      stylePreset: "lightLeak",
      slowDrift: true,
      occasionalSweeps: false,
      activeShimmer: false
    }
    var plugins = Array.isArray(root.shellPlugins) ? root.shellPlugins : []
    for (var i = 0; i < plugins.length; i++) {
      var entry = plugins[i]
      if (!entry || String(entry.id || "") !== "lacuna.cinematic-light-overlay") continue
      var merged = {}
      for (var key in defaults) merged[key] = defaults[key]
      for (var entryKey in entry) {
        if (entryKey !== "id") merged[entryKey] = entry[entryKey]
      }
      if (!cinematicLightEntryHasMotionToggles(entry) && entry.motionMode !== undefined) {
        var legacyMode = cinematicLightNormalizeMotionMode(entry.motionMode)
        merged.slowDrift = legacyMode === "slowDrift"
        merged.occasionalSweeps = legacyMode === "occasionalSweeps"
        merged.activeShimmer = legacyMode === "activeShimmer"
      }
      return merged
    }
    return defaults
  }

  function cinematicLightStyleOptions() {
    return [
      { value: "lightLeak", label: "Light Leak" },
      { value: "cinematicFlare", label: "Cinematic Flare" },
      { value: "anamorphicGlow", label: "Anamorphic Glow" }
    ]
  }

  function cinematicLightIntensityOptions() {
    return [
      { value: "0.78", label: "Soft" },
      { value: "0.9", label: "Balanced" },
      { value: "1", label: "Bright" }
    ]
  }

  function cinematicLightIntensity() {
    var value = Number(cinematicLightSettings().intensity)
    if (isNaN(value)) return "1"
    if (value <= 0.84) return "0.78"
    if (value <= 0.95) return "0.9"
    return "1"
  }

  function cinematicLightIntensityHint() {
    var value = Number(cinematicLightSettings().intensity)
    if (isNaN(value)) value = 1
    value = Math.max(0, Math.min(1, value))
    return "Light overlay opacity " + Math.round(value * 100) + "%"
  }

  function cinematicLightStylePreset() {
    var value = String(cinematicLightSettings().stylePreset || "")
    if (value === "cinematicFlare" || value === "anamorphicGlow") return value
    return "lightLeak"
  }

  function cinematicLightEntryHasMotionToggles(entry) {
    return entry
      && (entry.slowDrift !== undefined || entry.occasionalSweeps !== undefined || entry.activeShimmer !== undefined)
  }

  function cinematicLightNormalizeMotionMode(value) {
    var mode = String(value || "")
    if (mode === "occasionalSweeps" || mode === "activeShimmer") return mode
    return "slowDrift"
  }

  function cinematicLightBool(value, fallbackValue) {
    if (value === true || value === false) return value
    var normalized = String(value || "").toLowerCase()
    if (normalized === "true" || normalized === "1" || normalized === "yes" || normalized === "on") return true
    if (normalized === "false" || normalized === "0" || normalized === "no" || normalized === "off") return false
    return fallbackValue
  }

  function cinematicLightMotionModes() {
    var settings = cinematicLightSettings()
    var modes = {
      slowDrift: cinematicLightBool(settings.slowDrift, true),
      occasionalSweeps: cinematicLightBool(settings.occasionalSweeps, false),
      activeShimmer: cinematicLightBool(settings.activeShimmer, false)
    }

    if (!modes.slowDrift && !modes.occasionalSweeps && !modes.activeShimmer) modes.slowDrift = true
    return modes
  }

  function cinematicLightSlowDriftEnabled() {
    return cinematicLightMotionModes().slowDrift
  }

  function cinematicLightOccasionalSweepsEnabled() {
    return cinematicLightMotionModes().occasionalSweeps
  }

  function cinematicLightActiveShimmerEnabled() {
    return cinematicLightMotionModes().activeShimmer
  }

  function cinematicLightStyleHint() {
    var value = cinematicLightStylePreset()
    if (value === "cinematicFlare") return "Balanced movie lens flare with core, ghosts, and warm bloom"
    if (value === "anamorphicGlow") return "Thin long horizontal streaks with stronger anamorphic contrast"
    return "Soft edge bleeds and warm film leak glow"
  }

  function cinematicLightMotionHint() {
    var modes = cinematicLightMotionModes()
    var selected = []
    if (modes.slowDrift) selected.push("slow drift")
    if (modes.occasionalSweeps) selected.push("occasional sweeps")
    if (modes.activeShimmer) selected.push("active shimmer")
    return selected.length > 0 ? selected.join(" / ") : "slow drift"
  }

  function shellPluginEnabled(id) {
    if (root.pluginRegistry && typeof root.pluginRegistry.isEnabled === "function") {
      return root.pluginRegistry.isEnabled(id)
    }

    if (shellBarWidgetExistsAnywhere(id)) return true

    var plugins = Array.isArray(root.shellPlugins) ? root.shellPlugins : []
    for (var i = 0; i < plugins.length; i++) {
      if (plugins[i] && String(plugins[i].id || "") === String(id || "")) return true
    }
    return false
  }

  function installedShellPluginRows() {
    if (!root.pluginRegistry || !root.pluginRegistry.installedPlugins) return []
    var plugins = root.pluginRegistry.installedPlugins
    var rows = []
    for (var id in plugins) {
      var manifest = plugins[id]
      if (!manifest || manifest.__isFirstParty) continue
      if (id === "lacuna.menu") continue
      rows.push({
        id: id,
        name: manifest.name || id,
        description: manifest.description || id,
        enabled: shellPluginEnabled(id)
      })
    }
    rows.sort(function(a, b) { return a.name.localeCompare(b.name) })
    return rows
  }

  readonly property var builtinWidgetMeta: ({
    "omarchy.menu": { name: "Omarchy menu", description: "Launches the Omarchy menu", category: "Compositor" },
    "omarchy.workspaces": { name: "Workspaces", description: "Workspace number indicators", category: "Compositor" },
    "omarchy.clock": { name: "Clock", description: "Date and time text", category: "Time" },
    "omarchy.system-update": { name: "Updates", description: "Indicates available system updates", category: "System" },
    "omarchy.spacer": { name: "Spacer", description: "Flexible bar spacing", category: "Layout", allowMultiple: true },
    "voxtype": { name: "Voxtype", description: "Voxtype dictation state", category: "Status" },
    "screenRecording": { name: "Screen recording", description: "Active recording indicator", category: "Status" },
    "notifications": { name: "DND", description: "Do-not-disturb indicator", category: "Status" },
    "omarchy.tray": { name: "System tray", description: "Status notifier items", category: "Status" }
  })

  function canonicalWidgetId(id) {
    switch (String(id || "")) {
    case "omarchy": return "omarchy.menu"
    case "workspaces": return "omarchy.workspaces"
    case "calendar":
    case "clock": return "omarchy.clock"
    case "spacer": return "omarchy.spacer"
    case "tray": return "omarchy.tray"
    case "update": return "omarchy.system-update"
    case "bluetoothPanel": return "omarchy.bluetooth"
    case "networkPanel": return "omarchy.network"
    case "audioPanel": return "omarchy.audio"
    case "battery": return "omarchy.power"
    case "controlCenter": return "omarchy.indicators"
    case "idle": return "idleInhibitor"
    case "weatherFlyout": return "weather"
    default: return String(id || "")
    }
  }

  function shellBarWidgetMetadata(id) {
    var key = String(id || "")
    var canonicalKey = canonicalWidgetId(key)
    if (root.barWidgetRegistry && root.barWidgetRegistry.has(canonicalKey)) return root.barWidgetRegistry.metadataFor(canonicalKey) || {}
    if (builtinWidgetMeta[canonicalKey]) return builtinWidgetMeta[canonicalKey]

    var manifest = root.pluginRegistry && root.pluginRegistry.installedPlugins ? root.pluginRegistry.installedPlugins[key] : null
    if (manifest) {
      var meta = manifest.barWidget || {}
      return {
        displayName: meta.displayName || manifest.name || key,
        name: meta.displayName || manifest.name || key,
        description: meta.description || manifest.description || "",
        category: meta.category || "Plugin",
        allowMultiple: meta.allowMultiple === true,
        source: "plugin"
      }
    }

    return {}
  }

  function shellBarWidgetName(id) {
    var rev = root.catalogRevision
    var meta = shellBarWidgetMetadata(id)
    return meta.displayName || meta.name || String(id || "")
  }

  function shellBarWidgetDescription(id) {
    var rev = root.catalogRevision
    var meta = shellBarWidgetMetadata(id)
    return meta.description || ""
  }

  function shellBarWidgetAllowsMultiple(id) {
    var meta = shellBarWidgetMetadata(id)
    if (meta.allowMultiple === true) return true
    return canonicalWidgetId(id) === "omarchy.spacer"
  }

  function shellBarWidgetIcon(id) {
    var key = canonicalWidgetId(id)
    if (key === "omarchy.clock") return "clock"
    if (key === "weather" || key === "omarchy.weather") return "world"
    if (key === "omarchy.system-update") return "refresh"
    if (key === "lacuna.tray") return "apps"
    if (key === "omarchy.tray") return "apps"
    if (key === "omarchy.bluetooth") return "bluetooth"
    if (key === "omarchy.network") return "wifi"
    if (key === "omarchy.audio" || key === "omarchy.microphone") return "volume"
    if (key === "omarchy.monitor") return "photo"
    if (key === "omarchy.power") return "power"
    if (key === "screenRecording") return "video"
    if (key === "idleInhibitor") return "moon"
    if (key === "omarchy.menu") return "lacuna"
    if (key === "omarchy.workspaces") return "apps"
    return "settings"
  }

  function shellBarCatalogIds() {
    var rev = root.catalogRevision
    var ids = {}
    if (root.barWidgetRegistry) {
      var registered = root.barWidgetRegistry.availableIds()
      for (var i = 0; i < registered.length; i++) ids[registered[i]] = true
    }
    if (root.pluginRegistry && root.pluginRegistry.installedPlugins) {
      var plugins = root.pluginRegistry.installedPlugins
      for (var pid in plugins) {
        var manifest = plugins[pid]
        if (manifest && Array.isArray(manifest.kinds) && manifest.kinds.indexOf("bar-widget") !== -1) ids[pid] = true
      }
    }
    for (var key in builtinWidgetMeta) ids[key] = true
    return Object.keys(ids)
  }

  function shellBarWidgetExistsAnywhere(id) {
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var list = shellBarLayoutSection(sections[s])
      for (var i = 0; i < list.length; i++) {
        if (list[i] && String(list[i].id || "") === String(id || "")) return true
      }
    }
    return false
  }

  function availableShellBarWidgets(section) {
    var ids = shellBarCatalogIds().sort(function(a, b) {
      return shellBarWidgetName(a).localeCompare(shellBarWidgetName(b))
    })
    var result = []
    for (var i = 0; i < ids.length; i++) {
      var id = ids[i]
      if (!shellBarWidgetAllowsMultiple(id) && shellBarWidgetExistsAnywhere(id)) continue
      result.push({
        id: id,
        name: shellBarWidgetName(id),
        description: shellBarWidgetDescription(id)
      })
    }
    return result
  }

  function anchorHorizontal() {
    if (root.desktopClockAnchor.indexOf("left") !== -1) return "left"
    if (root.desktopClockAnchor.indexOf("right") !== -1) return "right"
    return "center"
  }

  function anchorVertical() {
    if (root.desktopClockAnchor.indexOf("top") !== -1) return "top"
    if (root.desktopClockAnchor.indexOf("bottom") !== -1) return "bottom"
    return "center"
  }

  function clockPositionHint() {
    return root.desktopClockAnchor + "  x " + root.desktopClockOffsetX + "  y " + root.desktopClockOffsetY
  }

  function clockFormatHint() {
    return root.desktopClockUse12Hour ? "12-hour time" : "24-hour time"
  }

  function clockScaleHint() {
    return Math.round(root.desktopClockScale * 100) + "%"
  }

  function controlsLayoutName() {
    return root.controlsLayout === "list" ? "List" : "Grid"
  }

  function shellSettingsSurfaceName() {
    return root.shellSettingsSurface === "window" ? "Window" : "Flyout"
  }

  function shellSettingsSurfaceHint() {
    return root.shellSettingsSurface === "window" ? "Open Omarchy shell settings as a separate floating window" : "Attach Omarchy shell settings to the Lacuna sidebar"
  }

  function jellyfinProviderSettings() {
    var providers = root.mediaProviders && typeof root.mediaProviders === "object" ? root.mediaProviders : ({})
    var jellyfin = providers.jellyfin && typeof providers.jellyfin === "object" ? providers.jellyfin : ({})
    return {
      enabled: jellyfin.enabled === true,
      serverUrl: String(jellyfin.serverUrl || ""),
      apiKey: String(jellyfin.apiKey || ""),
      userId: String(jellyfin.userId || ""),
      preferredAudioLanguage: String(jellyfin.preferredAudioLanguage || "English")
    }
  }

  readonly property bool jellyfinProviderEnabled: jellyfinProviderSettings().enabled
  readonly property string jellyfinServerUrl: jellyfinProviderSettings().serverUrl
  readonly property string jellyfinApiKey: jellyfinProviderSettings().apiKey
  readonly property string jellyfinAudioLanguage: jellyfinProviderSettings().preferredAudioLanguage
  readonly property bool jellyfinApiKeyConfigured: jellyfinApiKey !== ""

  function jellyfinProviderHint() {
    if (!jellyfinProviderEnabled) return "Jellyfin search is disabled"
    if (jellyfinServerUrl === "" || jellyfinApiKey === "") return "Jellyfin needs a server URL and API key"
    return "Jellyfin results are merged into Media Player search"
  }

  function jellyfinAudioLanguageHint() {
    if (jellyfinAudioLanguage === "Default") return "Use Jellyfin’s default audio track"
    return "Prefer " + jellyfinAudioLanguage + " audio when the item exposes it"
  }

  function layoutOptions() {
    return [
      { value: "grid", icon: "layout-grid" },
      { value: "list", icon: "list" }
    ]
  }

  function quickLaunchHeader() {
    var header = entries.header("Quick Launch", "nav", "quick-launch")
    header.optionValue = root.quickLaunchLayout === "grid" ? "grid" : "list"
    header.optionActionPrefix = "set-quick-launch-layout-"
    header.options = layoutOptions()
    header.headerAction = "open-custom-quick-launch-picker"
    header.headerActionIcon = "plus"
    header.headerActionTooltip = "Add Quick Launch App"
    return header
  }

  function dailyLaunchHeader() {
    var header = entries.header("Daily Launch", "nav", "launch")
    header.optionValue = root.dailyLaunchLayout === "grid" ? "grid" : "list"
    header.optionActionPrefix = "set-daily-launch-layout-"
    header.options = layoutOptions()
    return header
  }

  function controlsHeader() {
    var header = entries.header("Controls", "session", "controls")
    header.optionValue = root.controlsLayout === "list" ? "list" : "grid"
    header.optionActionPrefix = "set-controls-layout-"
    header.options = layoutOptions()
    return header
  }

  function shortcutsHeader() {
    var header = entries.header("Shortcuts", "nav", "shortcuts")
    header.optionValue = root.shortcutsLayout === "grid" ? "grid" : "list"
    header.optionActionPrefix = "set-shortcuts-layout-"
    header.options = layoutOptions()
    return header
  }

  function dailyLaunchEntries() {
    return preferredAppItems("normal").concat([
      entries.command({ icon: "terminal", label: "Terminal", hint: "Open a terminal", command: openTerminalCommand(), tone: "nav", priority: "normal", group: "launch" }),
      entries.command({ icon: "world", label: "Browser", hint: "Launch browser", command: "omarchy launch browser", tone: "nav", priority: "normal", group: "launch" })
    ])
  }

  function dailyLaunchItems() {
    var rows = [dailyLaunchHeader()]
    var launchers = dailyLaunchEntries()
    if (root.dailyLaunchLayout === "grid") {
      rows.push(entries.grid("lacuna", launchers))
      return rows
    }
    return rows.concat(launchers)
  }

  function quickLaunchItems() {
    var rows = [quickLaunchHeader()]
    var launchers = customQuickLaunchItems()

    if (root.quickLaunchLayout === "grid") {
      rows.push(entries.grid("nav", launchers))
      return rows
    }

    return rows.concat(launchers)
  }

  function controlEntries() {
    return [
      entries.command({ icon: "wifi", label: "Wi-Fi", hint: "Show network status", command: "omarchy notification send \"$(omarchy network status --verbose 2>/dev/null || omarchy network status)\"", tone: "session", priority: "normal", group: "controls" }),
      entries.command({ icon: "bluetooth", label: "Bluetooth", hint: "Show Bluetooth status", command: "omarchy notification send -g 󰂯 \"Bluetooth\" \"$(bluetoothctl show 2>/dev/null; bluetoothctl devices Connected 2>/dev/null)\"", tone: "session", priority: "normal", group: "controls" }),
      entries.command({ icon: "volume", label: "Audio", hint: "Switch audio output", command: "omarchy audio output switch", tone: "session", priority: "normal", group: "controls" }),
      entries.command({ icon: "camera", label: "Screenshot", hint: "Capture screen or region", command: "omarchy capture screenshot", tone: "session", priority: "normal", group: "controls" }),
      entries.action({ icon: "video", label: "Record", hint: "Choose screen recording mode", action: "open-screenrecord-menu", tone: "session", priority: "normal", group: "controls" }),
      entries.command({ icon: "idle", label: "Idle", hint: "Toggle idle behavior", command: "omarchy toggle idle", tone: "session", priority: "normal", group: "controls" })
    ]
  }

  function appSettingsLinks() {
    return [
      entries.action({ icon: "palette", label: "Appearance Settings", hint: designStyleHint(), action: "open-settings-section-appearance", tone: "lacuna", group: "customize" }),
      entries.action({ icon: root.compact ? "density-compact" : "density-normal", label: "Layout Settings", hint: barSizeModeHint(), action: "open-settings-section-layout", tone: "lacuna", group: "customize" }),
      entries.action({ icon: "clock", label: "Clock Settings", hint: clockPositionHint(), action: "open-settings-section-desktop-clock", tone: "lacuna", group: "customize" }),
      entries.action({ icon: "settings", label: "Runtime Tools", hint: "Logs, reloads, and source shortcuts", action: "open-settings-section-runtime", tone: "shell", group: "customize" })
    ]
  }

  function appsViewItems() {
    var rows = [entries.header("Categories", "lacuna", "apps")]
    var cats = categories()
    for (var c = 0; c < cats.length; c++) {
      var meta = cats[c]
      if (appModel.appCount(meta.id) > 0 || meta.id === "games") rows.push(appModel.categoryItem(meta))
    }
    rows.push(entries.header("Fallback", "shell", "apps"))
    rows.push(entries.nav({ icon: "apps", label: "All Apps", view: "apps-all", tone: "nav", group: "apps" }))
    rows.push(entries.action({ icon: "refresh", label: "Reload app catalog", action: "reload-apps", tone: "shell", priority: "normal", group: "apps" }))
    rows.push(entries.command({ icon: "search", label: "Open Walker", command: "walker -p 'Launch...'", tone: "shell", priority: "normal", group: "apps" }))
    return rows
  }

  function controlsItems() {
    var rows = [
      controlsHeader()
    ]

    var controls = controlEntries()
    if (root.controlsLayout === "list") return rows.concat(controls)

    rows.push(entries.grid("session", controls))
    return rows
  }

  function shortcutEntries() {
    return [
      entries.nav({ icon: "apps", label: "Apps", hint: "Browse categorized launchers", view: "apps", tone: "nav", group: "apps" }),
      entries.nav({ icon: "palette", label: "Customize", hint: "Theme, background, and Lacuna settings", view: "customize", tone: "shell", group: "customize" }),
      entries.nav({ icon: "power", label: "System", hint: "Lock, logout, restart, shutdown", view: "system", tone: "session", group: "session" })
    ]
  }

  function shortcutItems() {
    var rows = [shortcutsHeader()]
    var shortcuts = shortcutEntries()
    if (root.shortcutsLayout === "grid") {
      rows.push(entries.grid("nav", shortcuts))
      return rows
    }
    return rows.concat(shortcuts)
  }

  function customizeItems() {
    return [
      entries.header("Customize", "shell", "customize"),
      entries.command({ icon: "photo", label: "Wallpaper Catalog", hint: "Open wallpaper picker", command: "jobowalls-gui", tone: "shell", group: "customize" }),
      entries.command({ icon: "palette", label: "Theme", hint: "Switch Omarchy theme", command: switchThemeCommand(), tone: "shell", group: "customize" }),
      entries.command({ icon: "background", label: "Background", hint: "Switch theme background", command: switchBackgroundCommand(), tone: "shell", group: "customize" }),
      entries.header("Lacuna Settings", "lacuna", "customize")
    ].concat(appSettingsLinks())
  }

  function systemItems() {
    return [
      entries.header("Session", "session", "session"),
      entries.command({ icon: "moon", label: "Screensaver", hint: "Start screensaver now", command: "omarchy launch screensaver force", tone: "session", priority: "normal", group: "session" }),
      entries.command({ icon: "lock", label: "Lock", hint: "Lock session", command: "omarchy system lock", tone: "session", group: "session" }),
      entries.command({ icon: "logout", label: "Logout", hint: "End session", command: "omarchy system logout", tone: "session", priority: "normal", group: "session" }),
      entries.header("Power", "danger", "power"),
      entries.action({ icon: "refresh", label: "Restart", hint: root.instantRestart ? "Reboot machine immediately" : "Confirm before rebooting machine", action: "confirm-system-restart", tone: "danger", priority: "normal", danger: true, group: "power" }),
      entries.command({ icon: "power", label: "Shutdown", hint: "Power off machine", command: "omarchy system shutdown", tone: "danger", danger: true, group: "power" })
    ]
  }

  function lacunaSettingsShortcutItems() {
    return [
      entries.header("Lacuna Settings", "lacuna", "lacuna")
    ].concat(appSettingsLinks()).concat([
      entries.header("Source", "shell", "source"),
      entries.command({ icon: "refresh", label: "Restart shell", hint: "Reload Omarchy shell", command: restartLacunaCommand(), tone: "shell", group: "source" }),
      entries.command({ icon: "edit", label: "Open plugin source", hint: "Edit the Lacuna plugin repository", command: editPluginCommand(), tone: "shell", group: "source" })
    ])
  }

  function mainItems() {
    var rows = quickLaunchItems().concat(dailyLaunchItems()).concat(shortcutItems()).concat(controlsItems())

    return rows
  }

  function railItems() {
    return [
      entries.nav({ icon: "apps", label: "Apps", hint: "Browse categorized launchers", view: "apps", tone: "nav", group: "apps" }),
      entries.nav({ icon: "controls", label: "Controls", hint: "Wi-Fi, audio, capture, and idle controls", view: "controls", tone: "session", group: "controls" }),
      entries.nav({ icon: "palette", label: "Customize", hint: "Theme, background, and Lacuna settings", view: "customize", tone: "shell", group: "customize" }),
      entries.nav({ icon: "power", label: "System", hint: "Lock, logout, restart, shutdown", view: "system", tone: "session", group: "session" })
    ].concat(customQuickLaunchItems()).concat([
      entries.command({ icon: "terminal", label: "Terminal", hint: "Open a terminal", command: openTerminalCommand(), tone: "nav", priority: "normal", group: "launch" }),
      entries.command({ icon: "world", label: "Browser", hint: "Launch browser", command: "omarchy launch browser", tone: "nav", priority: "normal", group: "launch" })
    ])
  }

  function sidebarDisplayMode() {
    return root.sidebarCollapsed ? "rail" : "full"
  }

  function sidebarDisplayName() {
    return root.sidebarCollapsed ? "Icon Rail" : "Full"
  }

  function sidebarDisplayHint() {
    return root.sidebarCollapsed ? "Only show the icon rail" : "Show the full sidebar surface"
  }

  function sidebarDefaultModeName() {
    if (root.sidebarDefaultMode === "rail") return "Rail"
    if (root.sidebarDefaultMode === "full") return "Full"
    return "Off"
  }

  function sidebarDefaultModeHint() {
    if (root.sidebarDefaultMode === "rail") return "Return to the icon rail after actions and shell restart"
    if (root.sidebarDefaultMode === "full") return "Return to the full sidebar after actions and shell restart"
    return "Close the sidebar after actions and shell restart"
  }

  function sidebarAutoHideName() {
    return root.sidebarAutoHideEnabled ? "On" : "Off"
  }

  function sidebarAutoHideHint() {
    if (!root.sidebarAutoHideEnabled) return "Keep the configured sidebar presentation persistent"
    return "Reveal from a " + root.sidebarAutoHideHotZoneWidth + " px left-edge zone after "
      + root.sidebarAutoHideRevealDelayMs + " ms; hide after " + root.sidebarAutoHideHideDelayMs + " ms"
  }

  function sidebarMonitorPolicyName() {
    if (root.sidebarMonitorPolicy === "pinned") return "Pinned"
    if (root.sidebarMonitorPolicy === "all") return "All"
    return "Auto"
  }

  function sidebarMonitorPolicyHint() {
    if (root.sidebarMonitorPolicy === "pinned") {
      var count = Array.isArray(root.sidebarMonitorNames) ? root.sidebarMonitorNames.length : 0
      return count > 0 ? "Keep the sidebar on " + count + " selected output" + (count === 1 ? "" : "s") : "Choose one or more outputs below"
    }
    if (root.sidebarMonitorPolicy === "all") return "Show the sidebar and frame on every live output"
    return "Follow the focused output, as Lacuna does today"
  }

  function itemsFor(view) {
    if (view === "apps") return appsViewItems()
    if (view === "apps-all") return appItems("all")
    if (view.indexOf("apps-") === 0) return appItems(view.substring(5))
    if (view === "controls") return controlsItems()
    if (view === "customize") return customizeItems()
    if (view === "system") return systemItems()
    if (view === "lacuna" || view === "lacuna-shell" || view === "lacuna-preferences" || view === "lacuna-clock" || view === "lacuna-preferred-apps") return lacunaSettingsShortcutItems()
    return mainItems()
  }

  MenuEntryFactory {
    id: entries
  }

  MenuCommandCatalog {
    id: commands
    lacunaPath: root.lacunaPath
  }

  MenuAppModel {
    id: appModel
    appCatalog: root.appCatalog
    customQuickLaunchApps: root.customQuickLaunchApps
    customQuickLaunchNames: root.customQuickLaunchNames
    preferredApps: root.preferredApps
    entries: entries
    commands: commands
  }
}
