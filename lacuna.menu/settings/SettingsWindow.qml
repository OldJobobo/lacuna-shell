import QtQuick
import QtQuick.Shapes
import "../components"
import "../services"

Item {
  id: root

  signal activated(var entry)
  signal closeRequested()

  required property var registry
  property bool compact: false
  property bool open: false
  property string currentSection: "overview"
  property string version: ""
  property string themeTitle: ""
  property color foreground: "#d8dee9"
  property color background: "#101315"
  property color accent: "#88c0d0"
  property color shellAccent: "#88c0d0"
  property color sessionAccent: "#ebcb8b"
  property color dangerAccent: "#bf616a"
  property color navAccent: "#d8dee9"
  property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.48)
  property string bodyFontFamily: "Hack Nerd Font Propo"
  property string itemFontFamily: itemFont.name !== "" ? itemFont.name : "Tektur"
  property var designTokens: fallbackDesignTokens
  property bool drawBackground: true
  property var controlOverrides: ({})
  property int controlRevision: 0
  readonly property int panelRadius: designTokens.panelRadius !== undefined ? designTokens.panelRadius : 14
  readonly property real curveKappa: lacunaGeometry.curveKappa

  LacunaGeometry { id: lacunaGeometry }

  onOpenChanged: if (!open) clearControlOverrides()
  onCurrentSectionChanged: clearControlOverrides()

  function sections() {
    return [
      { id: "overview", icon: "apps", label: "Overview", hint: "Current Lacuna state" },
      { id: "appearance", icon: "palette", label: "Appearance", hint: "Style, colors, theme shortcuts" },
      { id: "animations", icon: "background", label: "Animations", hint: "Background, foreground, and vignette effects" },
      { id: "bar", icon: "density-normal", label: "Bar", hint: "Workspace widget behavior" },
      { id: "layout", icon: "density-normal", label: "Layout", hint: "Sidebar and density behavior" },
      { id: "media-player", icon: "music", label: "Media Player", hint: "Provider search and playback sources" },
      { id: "preferred-apps", icon: "preferred-apps", label: "Preferred Apps", hint: "Role-based app launch targets" },
      { id: "desktop-clock", icon: "clock", label: "Desktop Clock", hint: "Desktop layer clock placement" },
      { id: "runtime", icon: "settings", label: "Lacuna Tools", hint: "Plugin maintenance and menu behavior" },
      { id: "about", icon: "lacuna", label: "About", hint: "Plugin metadata" }
    ]
  }

  function sectionMeta(section) {
    var all = sections()
    for (var i = 0; i < all.length; i++) {
      if (all[i].id === section) return all[i]
    }
    return all[0]
  }

  function toneAccent(tone) {
    if (tone === "danger") return root.dangerAccent
    return root.accent
  }

  function section(label, note, tone) {
    return {
      kind: "section",
      label: label,
      note: note || "",
      tone: tone || "lacuna"
    }
  }

  function row(icon, label, hint, value, tone, action, control, checked, options, optionValue, actionPrefix, sectionId, sliderValue, sliderMinimum, sliderMaximum, sliderStep) {
    return {
      kind: "row",
      icon: icon,
      label: label,
      hint: hint || "",
      value: value || "",
      tone: tone || "lacuna",
      action: action || "",
      control: control || "nav",
      checked: checked === true,
      options: options || [],
      optionValue: optionValue || "",
      optionActionPrefix: actionPrefix || "",
      settingsSection: sectionId || "",
      sliderValue: sliderValue === undefined ? 0 : Number(sliderValue),
      sliderMinimum: sliderMinimum === undefined ? 0 : Number(sliderMinimum),
      sliderMaximum: sliderMaximum === undefined ? 1 : Number(sliderMaximum),
      sliderStep: sliderStep === undefined ? 0.05 : Number(sliderStep),
      view: "",
      command: ""
    }
  }

  function selectRow(icon, label, hint, currentValue, options, actionPrefix, tone, placeholder) {
    var item = row(icon, label, hint, "", tone || "lacuna", "", "select", false, options, currentValue || "", actionPrefix || "")
    item.placeholder = placeholder || "Select"
    return item
  }

  function textRow(icon, label, hint, currentValue, actionPrefix, tone, placeholder, masked) {
    var item = row(icon, label, hint, "", tone || "lacuna", "", "text", false, [], currentValue || "", actionPrefix || "")
    item.placeholder = placeholder || ""
    item.masked = masked === true
    return item
  }

  function stackRow(effectId, enabled, index, count) {
    var item = row("background", root.registry.backgroundEffectName(effectId), root.registry.backgroundEffectHint(effectId), enabled ? "#" + String(index + 1) : "Off", "lacuna", "toggle-background-effect-" + effectId, "stack-effect", enabled)
    item.effectId = effectId
    item.moveUpAction = "move-background-effect-up-" + effectId
    item.moveDownAction = "move-background-effect-down-" + effectId
    item.canMoveUp = enabled && index > 0
    item.canMoveDown = enabled && index >= 0 && index < count - 1
    return item
  }

  function controlKey(entry) {
    if (!entry) return ""
    if (entry.control === "toggle" || entry.control === "stack-effect") return "toggle:" + String(entry.action || entry.label || "")
    if (entry.control === "segments" || entry.control === "select" || entry.control === "search-select")
      return "value:" + String(entry.optionActionPrefix || entry.action || entry.label || "")
    if (entry.control === "slider" || entry.control === "text") return "value:" + String(entry.optionActionPrefix || entry.action || entry.label || "")
    return ""
  }

  function hasControlOverride(key) {
    return key !== "" && controlOverrides && controlOverrides[key] !== undefined
  }

  function currentControlChecked(entry) {
    var revision = controlRevision
    var key = controlKey(entry)
    if (hasControlOverride(key)) return controlOverrides[key] === true
    return entry && entry.checked === true
  }

  function currentControlValue(entry) {
    var revision = controlRevision
    var key = controlKey(entry)
    if (hasControlOverride(key)) return String(controlOverrides[key])
    return entry && entry.optionValue !== undefined && entry.optionValue !== null ? String(entry.optionValue) : ""
  }

  function setControlOverride(entry, value) {
    var key = controlKey(entry)
    if (key === "") return
    var next = {}
    for (var existingKey in controlOverrides) next[existingKey] = controlOverrides[existingKey]
    next[key] = value
    controlOverrides = next
    controlRevision++
    controlResetTimer.restart()
  }

  function clearControlOverrides() {
    if (!controlOverrides) return
    var hadOverrides = false
    for (var key in controlOverrides) {
      hadOverrides = true
      break
    }
    if (!hadOverrides) return
    controlOverrides = ({})
    controlRevision++
  }

  function commandRow(icon, label, hint, command, tone) {
    var item = row(icon, label, hint, "Open", tone || "shell", "", "button")
    item.command = command || ""
    return item
  }

  function backgroundEffectRows() {
    var rows = [
      section("Global", "Wallpaper-layer animation and frame-overlay controls.", "lacuna"),
      row("photo", "Background Vignette", root.registry.backgroundVignetteHint(), root.registry.backgroundVignetteEnabled() ? "On" : "Off", "lacuna", "toggle-background-vignette", "toggle", root.registry.backgroundVignetteEnabled()),
      row("sliders", "Vignette Intensity", root.registry.backgroundVignetteIntensityHint(), root.registry.backgroundVignetteIntensityName(), "lacuna", "", "slider", false, [], String(root.registry.backgroundVignetteIntensity()), "set-background-vignette-intensity-", "", root.registry.backgroundVignetteIntensity(), 0, 1, 0.01),
      row("background", "Background Animations", root.registry.backgroundEffectsHint(), root.registry.backgroundEffectsEnabled() ? "On" : "Off", "lacuna", "toggle-background-effects", "toggle", root.registry.backgroundEffectsEnabled()),
      row("sliders", "Animation Opacity", root.registry.backgroundAnimationOpacityHint(), root.registry.backgroundAnimationOpacityName(), "lacuna", "", "slider", false, [], String(root.registry.backgroundAnimationOpacity()), "set-background-animation-opacity-", "", root.registry.backgroundAnimationOpacity(), 0, 1, 0.01),
      row("layers", "Foreground Overlay", root.registry.backgroundEffectForegroundHint(root.registry.activeBackgroundEffect()), root.registry.backgroundEffectForegroundEnabled(root.registry.activeBackgroundEffect()) ? "On" : "Off", "lacuna", "toggle-background-effect-foreground-" + root.registry.activeBackgroundEffect(), "toggle", root.registry.backgroundEffectForegroundEnabled(root.registry.activeBackgroundEffect()))
    ]

    var activeStack = root.registry.activeBackgroundEffects()
    var stackCount = activeStack.length
    rows.push(section("Active Animations", stackCount === 0 ? "No animations selected." : "Front to back; #1 is topmost. Click an active row to remove it.", "lacuna"))

    var options = root.registry.backgroundEffectOptions()
    for (var stackIndex = 0; stackIndex < activeStack.length; stackIndex++) {
      rows.push(stackRow(activeStack[stackIndex], true, stackIndex, stackCount))
    }

    if (stackCount < options.length) {
      rows.push(section("Add Animation", "Click an entry to add it to the stack.", "lacuna"))
    }

    for (var optionIndex = 0; optionIndex < options.length; optionIndex++) {
      var effectId = String(options[optionIndex].value || "")
      if (root.registry.backgroundEffectStackIndex(effectId) < 0) {
        rows.push(stackRow(effectId, false, -1, stackCount))
      }
    }

    var stackWarning = root.registry.backgroundEffectStackWarning()
    if (stackWarning !== "") {
      rows.push(section("Performance", stackWarning, "danger"))
    }

    if (root.registry.backgroundEffectEnabled("cinematicLight")) {
      rows.push(section("Effect Controls", "Controls for enabled animation layers.", "lacuna"))
      rows.push(selectRow("photo", "Light Style", root.registry.cinematicLightStyleHint(), root.registry.cinematicLightStylePreset(), root.registry.cinematicLightStyleOptions(), "set-cinematic-light-style-", "lacuna", "Style"))
      rows.push(selectRow("sliders", "Intensity", root.registry.cinematicLightIntensityHint(), root.registry.cinematicLightIntensity(), root.registry.cinematicLightIntensityOptions(), "set-cinematic-light-intensity-", "lacuna", "Intensity"))
      rows.push(section("Light Motion", root.registry.cinematicLightMotionHint(), "lacuna"))
      rows.push(row("motion", "Slow Drift", "Slow breathing and gentle left-right drift", root.registry.cinematicLightSlowDriftEnabled() ? "On" : "Off", "lacuna", "toggle-cinematic-light-motion-slowDrift", "toggle", root.registry.cinematicLightSlowDriftEnabled()))
      rows.push(row("motion", "Occasional Sweeps", "Rare bright horizontal passes", root.registry.cinematicLightOccasionalSweepsEnabled() ? "On" : "Off", "lacuna", "toggle-cinematic-light-motion-occasionalSweeps", "toggle", root.registry.cinematicLightOccasionalSweepsEnabled()))
      rows.push(row("motion", "Active Shimmer", "More frequent glints, pulse variation, and shimmer", root.registry.cinematicLightActiveShimmerEnabled() ? "On" : "Off", "lacuna", "toggle-cinematic-light-motion-activeShimmer", "toggle", root.registry.cinematicLightActiveShimmerEnabled()))
    }

    if (root.registry.backgroundEffectEnabled("filmGrain")) {
      rows.push(section("Film Grain", "Tune grain visibility and texture.", "lacuna"))
      rows.push(row("sliders", "Grain Opacity", root.registry.filmGrainIntensityHint(), root.registry.filmGrainIntensityName(), "lacuna", "", "slider", false, [], String(root.registry.filmGrainIntensity()), "set-film-grain-intensity-", "", root.registry.filmGrainIntensity(), 0, 1, 0.01))
      rows.push(row("sliders", "Grain Size", root.registry.filmGrainGrainSizeHint(), root.registry.filmGrainGrainSizeName(), "lacuna", "", "slider", false, [], String(root.registry.filmGrainGrainSize()), "set-film-grain-size-", "", root.registry.filmGrainGrainSize(), 0.6, 3.5, 0.05))
      rows.push(row("sliders", "Grain Count", root.registry.filmGrainGrainCountHint(), root.registry.filmGrainGrainCountName(), "lacuna", "", "slider", false, [], String(root.registry.filmGrainGrainCount()), "set-film-grain-count-", "", root.registry.filmGrainGrainCount(), 32, 520, 4))
      rows.push(row("sliders", "Grain Speed", root.registry.filmGrainSpeedHint(), root.registry.filmGrainSpeedName(), "lacuna", "", "slider", false, [], String(root.registry.filmGrainSpeed()), "set-film-grain-speed-", "", root.registry.filmGrainSpeed(), 0.2, 5, 0.05))
      rows.push(row("color-swatch", "Accent Tint", root.registry.filmGrainAccentBlendHint(), root.registry.filmGrainAccentBlendName(), "lacuna", "", "slider", false, [], String(root.registry.filmGrainAccentBlend()), "set-film-grain-accent-", "", root.registry.filmGrainAccentBlend(), 0, 1, 0.01))
    }

    if (root.registry.backgroundEffectEnabled("dustMotes")) {
      rows.push(section("Dust Motes", "Tune mote density, drift, tint, and cursor response.", "lacuna"))
      rows.push(row("sliders", "Mote Opacity", root.registry.dustMotesIntensityHint(), root.registry.dustMotesIntensityName(), "lacuna", "", "slider", false, [], String(root.registry.dustMotesIntensity()), "set-dust-motes-intensity-", "", root.registry.dustMotesIntensity(), 0, 1, 0.01))
      rows.push(row("sliders", "Mote Speed", root.registry.dustMotesSpeedHint(), root.registry.dustMotesSpeedName(), "lacuna", "", "slider", false, [], String(root.registry.dustMotesSpeed()), "set-dust-motes-speed-", "", root.registry.dustMotesSpeed(), 0.15, 4, 0.05))
      rows.push(row("sliders", "Mote Count", root.registry.dustMotesMoteCountHint(), root.registry.dustMotesMoteCountName(), "lacuna", "", "slider", false, [], String(root.registry.dustMotesMoteCount()), "set-dust-motes-count-", "", root.registry.dustMotesMoteCount(), 12, 180, 4))
      rows.push(row("sliders", "Mote Size", root.registry.dustMotesMoteSizeHint(), root.registry.dustMotesMoteSizeName(), "lacuna", "", "slider", false, [], String(root.registry.dustMotesMoteSize()), "set-dust-motes-size-", "", root.registry.dustMotesMoteSize(), 1, 8, 0.05))
      rows.push(row("color-swatch", "Accent Tint", root.registry.dustMotesAccentBlendHint(), root.registry.dustMotesAccentBlendName(), "lacuna", "", "slider", false, [], String(root.registry.dustMotesAccentBlend()), "set-dust-motes-accent-", "", root.registry.dustMotesAccentBlend(), 0, 1, 0.01))
      rows.push(row("motion", "Mouse Reactive", root.registry.dustMotesMouseReactiveHint(), root.registry.dustMotesMouseReactive() ? "On" : "Off", "lacuna", "toggle-dust-motes-mouse-reactive", "toggle", root.registry.dustMotesMouseReactive()))
      rows.push(row("sliders", "Mouse Influence", root.registry.dustMotesMouseInfluenceHint(), root.registry.dustMotesMouseInfluenceName(), "lacuna", "", "slider", false, [], String(root.registry.dustMotesMouseInfluence()), "set-dust-motes-mouse-influence-", "", root.registry.dustMotesMouseInfluence(), 0, 1, 0.01))
    }

    return rows
  }

  function activateEntryAction(entry, action) {
    var next = {}
    for (var key in entry) next[key] = entry[key]
    next.action = action
    next.control = "button"
    handleEntry(next)
  }

  function colorProfileName() {
    return root.registry.colorProfile === "colorful" ? "Colorful" : "Semantic"
  }

  function frameModeName() {
    return root.registry.frameMode === "fullframe" ? "On" : "Off"
  }

  function frameReserveModeName() {
    return root.registry.frameReserveModeName ? root.registry.frameReserveModeName() : "Auto"
  }

  function frameReserveModeHint() {
    return root.registry.frameReserveModeHint ? root.registry.frameReserveModeHint() : "Collapse extra frame reserve when the focused workspace is gapsless"
  }

  function sidebarModeName() {
    return root.registry.sidebarExclusive ? "Overlay" : "Docked"
  }

  function sidebarShapeName() {
    return root.registry.sidebarCollapsed ? "Icon Rail" : "Full"
  }

  function sidebarDefaultModeName() {
    return root.registry.sidebarDefaultModeName ? root.registry.sidebarDefaultModeName() : "Off"
  }

  function sidebarMonitorPolicyName() {
    return root.registry.sidebarMonitorPolicyName ? root.registry.sidebarMonitorPolicyName() : "Auto"
  }

  function sidebarMonitorPolicyHint() {
    return root.registry.sidebarMonitorPolicyHint ? root.registry.sidebarMonitorPolicyHint() : "Follow the focused output"
  }

  function densityName() {
    if (root.registry.barSizeMode === "theme") return "Theme"
    return root.registry.barSizeMode === "compact" ? "Compact" : "Full"
  }

  function barSizeModeName() {
    return root.registry.barSizeModeName ? root.registry.barSizeModeName() : "Full"
  }

  function barSizeModeHint() {
    return root.registry.barSizeModeHint ? root.registry.barSizeModeHint() : "Control topbar, sidebar, and rail size together"
  }

  function clockAnchorName() {
    return root.registry.desktopClockAnchor + "  x " + root.registry.desktopClockOffsetX + "  y " + root.registry.desktopClockOffsetY
  }

  function clockScaleName() {
    return Math.round(root.registry.desktopClockScale * 100) + "%"
  }

  function preferredSummary() {
    return root.registry.preferredAppHint("files") + " / " + root.registry.preferredAppHint("editor")
  }

  function mediaPlayerSummary() {
    return root.registry.jellyfinProviderEnabled ? "Jellyfin on" : "Jellyfin off"
  }

  function settingsPersistenceName() {
    var state = String(root.registry.settingsPersistenceState || "idle")
    if (state === "saving") return "Saving"
    if (state === "saved") return "Saved"
    if (state === "failed") return "Failed"
    if (state === "retrying") return "Retrying"
    return "Idle"
  }

  function settingsPersistenceHint() {
    if (root.registry.settingsPersistenceError !== "") return root.registry.settingsPersistenceError
    if (root.registry.settingsPersistenceState === "saved")
      return "Revision " + root.registry.settingsConfirmedRevision + " is durably stored"
    if (root.registry.settingsPersistenceState === "saving" || root.registry.settingsPersistenceState === "retrying")
      return "Writing revision " + root.registry.settingsRequestedRevision
    return "Lacuna runtime settings persistence"
  }

  function navRow(icon, label, hint, sectionId, tone, value) {
    return row(icon, label, hint, value || "", tone || "lacuna", "", "nav", false, [], "", "", sectionId)
  }

  function itemsFor(sectionId) {
    if (sectionId === "overview") {
      return [
        section("Status", "Fast links into each settings area.", "lacuna"),
        navRow("palette", "Appearance", root.registry.designStyleHint(), "appearance", "lacuna", root.registry.designStyleName()),
        navRow("background", "Animations", root.registry.backgroundEffectsHint(), "animations", "lacuna", root.registry.backgroundEffectStackCount() + " active"),
        navRow("density-normal", "Bar", "Workspace widget behavior", "bar", "lacuna", root.registry.workspacesActiveOnly() ? "Active only" : "All workspaces"),
        navRow(root.registry.compact ? "density-compact" : "density-normal", "Layout", sidebarModeName() + " / default " + sidebarDefaultModeName(), "layout", "lacuna", densityName()),
        navRow("music", "Media Player", "Provider search and playback sources", "media-player", "lacuna", mediaPlayerSummary()),
        navRow("preferred-apps", "Preferred Apps", preferredSummary(), "preferred-apps", "lacuna", "Edit"),
        navRow("clock", "Desktop Clock", clockAnchorName(), "desktop-clock", "lacuna", root.registry.desktopClockEnabled ? "On" : "Off"),
        navRow("settings", "Lacuna Tools", "Plugin source, app catalog, and menu safety", "runtime", "lacuna", "Tools"),
        navRow("lacuna", "About", root.version !== "" ? root.version : "Lacuna plugin", "about", "lacuna", "Info")
      ]
    }

    if (sectionId === "appearance") {
      return [
        section("Design", "Panel and sidebar visual treatment.", "lacuna"),
        row("palette", "Design Style", root.registry.designStyleHint(), "", "lacuna", "", "segments", false, [
          { value: "lacuna", label: "Lacuna" },
          { value: "omarchy", label: "Omarchy" },
          { value: "material", label: "Material" }
        ], root.registry.designStyle, "set-design-style-"),
        row("color-swatch", "Color Profile", root.registry.colorProfile === "colorful" ? "Use theme colors across Lacuna surfaces" : "Use semantic accents with restrained color", colorProfileName(), "lacuna", "toggle-color-profile", "toggle", root.registry.colorProfile === "colorful"),
        row("corners", "Shell Corners", root.registry.cornerModeHint(), "", "lacuna", "", "segments", false, [
          { value: "theme", label: "Theme" },
          { value: "square", label: "Square" },
          { value: "custom", label: "Custom" }
        ], root.registry.cornerMode, "set-corner-mode-"),
        row("sliders", "Custom Radius", root.registry.cornerRadiusHint(), root.registry.cornerRadius + " px", "lacuna", "", "slider", false, [], String(root.registry.cornerRadius), "set-corner-radius-", "", root.registry.cornerRadius, 0, 32, 1),
        section("Frame", "Fake fullscreen frame and unified shadow treatment.", "lacuna"),
        row("corners", "Frame", "Draw Lacuna-owned frame pieces around the screen perimeter", frameModeName(), "lacuna", "", "segments", false, [
          { value: "off", label: "Off" },
          { value: "fullframe", label: "On" }
        ], root.registry.frameMode, "set-frame-mode-"),
        row("photo", "Frame Shadow", root.registry.frameShadow ? "Apply one cohesive shadow pass to the frame layer" : "Keep frame pieces fill-only", root.registry.frameShadow ? "On" : "Off", "lacuna", "toggle-frame-shadow", "toggle", root.registry.frameShadow),
        row("corners", "Frame Border", root.registry.frameBorder ? "Draw a fine inner edge around the frame reveal" : "Keep the frame reveal without an inner edge", root.registry.frameBorder ? "On" : "Off", "lacuna", "toggle-frame-border", "toggle", root.registry.frameBorder),
        row("density-normal", "Frame Reserve", frameReserveModeHint(), frameReserveModeName(), "lacuna", "", "segments", false, [
          { value: "auto", label: "Auto" },
          { value: "comfort", label: "Comfort" },
          { value: "flush", label: "Flush" }
        ], root.registry.frameReserveMode, "set-frame-reserve-mode-")
      ]
    }

    if (sectionId === "animations") {
      return backgroundEffectRows()
    }

    if (sectionId === "bar") {
      return [
        section("Workspaces", "Choose how the Lacuna workspace widget uses available bar space.", "lacuna"),
        row("density-normal", "Active workspace only", "Show one button for the currently focused workspace", root.registry.workspacesActiveOnly() ? "On" : "Off", "lacuna", "toggle-workspaces-active-only", "toggle", root.registry.workspacesActiveOnly())
      ]
    }

    if (sectionId === "layout") {
      var layoutRows = [
        section("Sidebar", "Keep launcher behavior separate from Lacuna settings.", "lacuna"),
        row(root.registry.compact ? "density-compact" : "density-normal", "Lacuna Size", barSizeModeHint(), barSizeModeName(), "lacuna", "", "segments", false, [
          { value: "theme", label: "Theme" },
          { value: "compact", label: "Compact" },
          { value: "full", label: "Full" }
        ], root.registry.barSizeMode, "set-bar-size-mode-"),
        section("Portrait Outputs", "Selected widgets are redistributed automatically; edit the canonical layout in Omarchy Settings.", "lacuna"),
        row("monitor", "Portrait split bar", "Use an opposite-edge companion on portrait outputs", root.registry.portraitSplit ? "On" : "Off", "lacuna", "toggle-portrait-split", "toggle", root.registry.portraitSplit),
        row("sidebar-toggle", "Sidebar Default", root.registry.sidebarDefaultModeHint(), sidebarDefaultModeName(), "lacuna", "", "segments", false, [
          { value: "off", label: "Off" },
          { value: "full", label: "Full" },
          { value: "rail", label: "Rail" }
        ], root.registry.sidebarDefaultMode, "set-sidebar-default-"),
        row("sidebar-toggle", "Autohide Sidebar", root.registry.sidebarAutoHideHint(), root.registry.sidebarAutoHideName(), "lacuna", "toggle-sidebar-autohide", "toggle", root.registry.sidebarAutoHideEnabled),
        row("sidebar-overlay", "Window Mode", root.registry.sidebarAutoHideEnabled ? "Autohide temporarily overlays windows; this saved choice returns when disabled" : (root.registry.sidebarExclusive ? "Float over windows" : "Reserve screen space"), root.registry.sidebarAutoHideEnabled ? "Overlay" : sidebarModeName(), "lacuna", "toggle-sidebar-mode", "toggle", root.registry.sidebarExclusive),
        row("monitor", "Sidebar Monitors", sidebarMonitorPolicyHint(), sidebarMonitorPolicyName(), "lacuna", "", "segments", false, [
          { value: "auto", label: "Auto" },
          { value: "pinned", label: "Pinned" },
          { value: "all", label: "All" }
        ], root.registry.sidebarMonitorPolicy, "set-sidebar-monitor-policy-")
      ]

      if (root.registry.sidebarMonitorPolicy === "pinned") {
        layoutRows.push(section("Pinned Outputs", "Select one or more live outputs for the sidebar and frame.", "lacuna"))
        var monitorOptions = root.registry.sidebarMonitorOptions || []
        for (var monitorIndex = 0; monitorIndex < monitorOptions.length; monitorIndex++) {
          var monitor = monitorOptions[monitorIndex]
          var monitorName = String(monitor.name || monitor.label || "")
          if (monitorName === "") continue
          var monitorChecked = monitor.checked === true
          layoutRows.push(row("monitor", monitorName, monitorChecked ? "Pinned output" : "Available output", monitorChecked ? "On" : "Off", "lacuna", "toggle-sidebar-monitor-" + monitorName, "toggle", monitorChecked))
        }
      }

      layoutRows.push(
        section("Settings Link", "Choose how Lacuna opens the separate Omarchy shell settings surface.", "lacuna"),
        row("settings", "Omarchy Settings Link", root.registry.shellSettingsSurfaceHint(), root.registry.shellSettingsSurfaceName(), "lacuna", "", "segments", false, [
          { value: "flyout", label: "Flyout" },
          { value: "window", label: "Window" }
        ], root.registry.shellSettingsSurface, "set-shell-settings-surface-")
      )
      return layoutRows
    }

    if (sectionId === "media-player") {
      return [
        section("Providers", "Configure media sources used by search and playback.", "lacuna"),
        row("music", "Jellyfin", root.registry.jellyfinProviderHint(), root.registry.jellyfinProviderEnabled ? "On" : "Off", "lacuna", "toggle-jellyfin-provider", "toggle", root.registry.jellyfinProviderEnabled),
        textRow("world", "Server URL", "Base Jellyfin server address", root.registry.jellyfinServerUrl, "set-jellyfin-server-url-", "lacuna", "https://jellyfin.example", false),
        textRow("lock", "API Key", root.registry.jellyfinApiKeyConfigured ? "Saved API key is configured" : "Paste a Jellyfin API key", root.registry.jellyfinApiKey, "set-jellyfin-api-key-", "lacuna", "API key", true),
        selectRow("music", "Preferred Audio Language", root.registry.jellyfinAudioLanguageHint(), root.registry.jellyfinAudioLanguage, [
          { value: "English", label: "English" },
          { value: "Japanese", label: "Japanese" },
          { value: "Default", label: "Jellyfin default" }
        ], "set-jellyfin-audio-language-", "lacuna", "Language")
      ]
    }

    if (sectionId === "preferred-apps") {
      return [
        section("Launch Roles", "Rows open the shared app picker and preserve the reset-to-system option.", "lacuna"),
        row("folder", "Files", root.registry.preferredAppHint("files"), "Change", root.registry.roleMeta("files").tone, "choose-preferred-app-files", "button"),
        row("edit", "Editor", root.registry.preferredAppHint("editor"), "Change", root.registry.roleMeta("editor").tone, "choose-preferred-app-editor", "button"),
        row("mail", "Email", root.registry.preferredAppHint("email"), "Change", root.registry.roleMeta("email").tone, "choose-preferred-app-email", "button"),
        row("message", "Discord", root.registry.preferredAppHint("discord"), "Change", root.registry.roleMeta("discord").tone, "choose-preferred-app-discord", "button")
      ]
    }

    if (sectionId === "desktop-clock") {
      return [
        section("Activation", "Controls the separate desktop clock plugin entry.", "lacuna"),
        row("clock", "Desktop Clock", root.registry.desktopClockEnabled ? "Visible on the desktop layer" : "Hidden from the desktop layer", root.registry.desktopClockEnabled ? "On" : "Off", "lacuna", "toggle-desktop-clock", "toggle", root.registry.desktopClockEnabled),
        row("clock", "12-Hour Time", root.registry.desktopClockUse12Hour ? "Show 1:05 PM style time" : "Show 13:05 style time", root.registry.clockFormatHint(), "lacuna", "toggle-clock-12-hour", "toggle", root.registry.desktopClockUse12Hour),
        section("Position", "Anchor and nudge values are written inline to shell plugin state.", "lacuna"),
        row("clock", "Horizontal", "Anchor column", "", "lacuna", "", "segments", false, [
          { value: "left", label: "Left" },
          { value: "center", label: "Center" },
          { value: "right", label: "Right" }
        ], root.registry.anchorHorizontal(), "set-clock-anchor-x-"),
        row("clock", "Vertical", "Anchor row", "", "lacuna", "", "segments", false, [
          { value: "top", label: "Top" },
          { value: "center", label: "Center" },
          { value: "bottom", label: "Bottom" }
        ], root.registry.anchorVertical(), "set-clock-anchor-y-"),
        row("density-compact", "Scale Down", "Current scale " + clockScaleName(), "Smaller", "lacuna", "scale-clock-down", "button"),
        row("density-normal", "Scale Up", "Current scale " + clockScaleName(), "Larger", "lacuna", "scale-clock-up", "button"),
        row("arrow-left", "Move Left", "Nudge 24 px left", "Move", "lacuna", "nudge-clock-left", "button"),
        row("chevron-right", "Move Right", "Nudge 24 px right", "Move", "lacuna", "nudge-clock-right", "button"),
        row("arrow-up", "Move Up", "Nudge 24 px up", "Move", "lacuna", "nudge-clock-up", "button"),
        row("arrow-down", "Move Down", "Nudge 24 px down", "Move", "lacuna", "nudge-clock-down", "button"),
        row("refresh", "Reset Position", "Clear clock offsets, scale, and return to bottom-right", "Reset", "shell", "reset-clock-position", "button")
      ]
    }

    if (sectionId === "runtime") {
      return [
        section("Lacuna Maintenance", "Plugin-owned tools and cached app metadata.", "lacuna"),
        row("settings", "Settings Persistence", settingsPersistenceHint(), settingsPersistenceName(), root.registry.settingsPersistenceState === "failed" ? "danger" : "lacuna", root.registry.settingsPersistenceState === "failed" ? "retry-settings-save" : "", root.registry.settingsPersistenceState === "failed" ? "button" : "value"),
        row("refresh", "Reload App Catalog", "Rescan desktop launchers used by Lacuna launch rows", "Reload", "lacuna", "reload-apps", "button"),
        commandRow("edit", "Open Plugin Source", "Edit the Lacuna plugin repository", root.registry.editPluginCommand(), "lacuna"),
        section("Menu Safety", "Controls Lacuna's confirmation step before system restart actions.", "danger"),
        row("refresh", "Skip Restart Confirmation", root.registry.instantRestart ? "Lacuna restarts the system immediately" : "Lacuna asks before rebooting", root.registry.instantRestart ? "On" : "Off", "danger", "toggle-instant-restart", "toggle", root.registry.instantRestart)
      ]
    }

    return [
      section("Lacuna", "Low-noise plugin metadata.", "lacuna"),
      row("lacuna", "Version", "", root.version !== "" ? root.version : "Unavailable", "lacuna", "", "value"),
      row("palette", "Active Theme", "", root.themeTitle !== "" ? root.themeTitle : "Omarchy theme", "shell", "", "value"),
      row("settings", "Color Profile", "", colorProfileName(), "lacuna", "", "value"),
      section("Source", root.registry.lacunaPath, "nav"),
      commandRow("edit", "Open Source", "Edit this plugin repository", root.registry.editPluginCommand(), "lacuna")
    ]
  }

  function entryWithDesiredChecked(entry, desiredChecked) {
    var next = {}
    for (var key in entry) next[key] = entry[key]
    next.desiredChecked = desiredChecked === true
    return next
  }

  function handleEntry(entry, desiredChecked) {
    if (!entry || entry.kind !== "row") return
    if (entry.settingsSection !== "") {
      currentSection = entry.settingsSection
      return
    }
    root.activated(desiredChecked === undefined ? entry : entryWithDesiredChecked(entry, desiredChecked))
  }

  function handleOptionSelected(entry, value) {
    root.activated({
      kind: "item",
      action: entry.optionActionPrefix + value,
      view: "",
      command: ""
    })
  }

  function activateControl(entry, value) {
    if (!entry || entry.kind !== "row") return
    if (entry.control === "toggle" || entry.control === "stack-effect") {
      var desired = !currentControlChecked(entry)
      setControlOverride(entry, desired)
      handleEntry(entry, desired)
      return
    }
    if (entry.control === "segments" || entry.control === "select" || entry.control === "search-select" || entry.control === "slider" || entry.control === "text") {
      setControlOverride(entry, value)
      handleOptionSelected(entry, value)
      return
    }
    handleEntry(entry)
  }

  width: 560
  height: 660
  clip: true
  focus: open
  Keys.onEscapePressed: root.closeRequested()

  Timer {
    id: controlResetTimer
    interval: 1600
    repeat: false
    onTriggered: root.clearControlOverrides()
  }

  FontLoader {
    id: itemFont

    source: "../assets/fonts/Tektur-SemiBold.ttf"
  }

  Shape {
    visible: root.drawBackground
    anchors.fill: parent
    asynchronous: true
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: root.background
      strokeWidth: 0
      startX: 0
      startY: 0

      PathLine { x: root.width - root.panelRadius; y: 0 }
      PathCubic {
        x: root.width
        y: root.panelRadius
        control1X: root.width - root.panelRadius * (1 - root.curveKappa)
        control1Y: 0
        control2X: root.width
        control2Y: root.panelRadius * (1 - root.curveKappa)
      }
      PathLine { x: root.width; y: root.height - root.panelRadius }
      PathCubic {
        x: root.width - root.panelRadius
        y: root.height
        control1X: root.width
        control1Y: root.height - root.panelRadius * (1 - root.curveKappa)
        control2X: root.width - root.panelRadius * (1 - root.curveKappa)
        control2Y: root.height
      }
      PathLine { x: 0; y: root.height }
      PathLine { x: 0; y: 0 }
    }
  }

  Item {
    anchors.fill: parent
    anchors.margins: root.compact ? 10 : 12

    SettingsRail {
      id: sectionRail

      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      sections: root.sections()
      currentSection: root.currentSection
      compact: root.compact
      foreground: root.foreground
      background: root.background
      muted: root.muted
      accent: root.accent
      designTokens: root.designTokens
      onSectionSelected: function(section) {
        root.currentSection = section
      }
    }

    Column {
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.left: sectionRail.right
      anchors.right: parent.right
      anchors.leftMargin: root.compact ? 9 : 12
      spacing: root.compact ? 8 : 10

      SettingsHeader {
        width: parent.width
        title: root.sectionMeta(root.currentSection).label
        subtitle: root.sectionMeta(root.currentSection).hint
        compact: root.compact
        foreground: root.foreground
        muted: root.muted
        accent: root.accent
        titleFontFamily: root.itemFontFamily
        bodyFontFamily: root.bodyFontFamily
        designTokens: root.designTokens
        onCloseRequested: root.closeRequested()
      }

      LacunaRect {
        width: parent.width
        height: 1
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
      }

      LacunaScrollView {
        width: parent.width
        height: Math.max(0, parent.height - y)
        showEdgeMasks: true
        edgeMaskColor: root.background

        Column {
          id: itemList

          width: parent.width
          spacing: root.compact ? 5 : 6

          Repeater {
            model: root.itemsFor(root.currentSection)

            Loader {
              property var entry: modelData

              width: parent.width
              sourceComponent: entry.kind === "section"
                ? sectionDelegate
                : entry.control === "stack-effect"
                  ? stackDelegate
                : entry.control === "select"
                  ? selectDelegate
                : entry.control === "text"
                  ? textDelegate
                  : rowDelegate
            }
          }
        }

        Component {
          id: sectionDelegate

          SettingsSection {
            width: parent ? parent.width : 0
            title: parent.entry.label
            note: parent.entry.note
            compact: root.compact
            foreground: root.foreground
            muted: root.muted
            accent: root.toneAccent(parent.entry.tone)
            fontFamily: root.bodyFontFamily
          }
        }

        Component {
          id: rowDelegate

          SettingsRow {
            width: parent.width
            icon: parent.entry.icon
            label: parent.entry.label
            hint: parent.entry.hint
            value: parent.entry.value
            tone: parent.entry.tone
            control: parent.entry.control
            checked: root.currentControlChecked(parent.entry)
            options: parent.entry.options
            optionValue: root.currentControlValue(parent.entry)
            sliderValue: Number(root.currentControlValue(parent.entry))
            sliderMinimum: parent.entry.sliderMinimum
            sliderMaximum: parent.entry.sliderMaximum
            sliderStep: parent.entry.sliderStep
            compact: root.compact
            foreground: root.foreground
            background: root.background
            muted: root.muted
            accent: root.accent
            toneAccent: root.toneAccent(parent.entry.tone)
            titleFontFamily: root.itemFontFamily
            bodyFontFamily: root.bodyFontFamily
            designTokens: root.designTokens
            onTriggered: root.activateControl(parent.entry)
            onOptionSelected: function(value) { root.activateControl(parent.entry, value) }
            onSliderChanged: function(value) { root.activateControl(parent.entry, value) }
          }
        }

        Component {
          id: stackDelegate

          SettingsStackRow {
            width: parent.width
            icon: parent.entry.icon
            label: parent.entry.label
            hint: parent.entry.hint
            value: parent.entry.value
            checked: root.currentControlChecked(parent.entry)
            canMoveUp: parent.entry.canMoveUp
            canMoveDown: parent.entry.canMoveDown
            compact: root.compact
            foreground: root.foreground
            background: root.background
            muted: root.muted
            toneAccent: root.toneAccent(parent.entry.tone)
            titleFontFamily: root.itemFontFamily
            bodyFontFamily: root.bodyFontFamily
            designTokens: root.designTokens
            onToggled: root.activateControl(parent.entry)
            onMoveUp: root.activateEntryAction(parent.entry, parent.entry.moveUpAction)
            onMoveDown: root.activateEntryAction(parent.entry, parent.entry.moveDownAction)
          }
        }

        Component {
          id: selectDelegate

          SettingsSelectRow {
            width: parent.width
            icon: parent.entry.icon
            label: parent.entry.label
            hint: parent.entry.hint
            currentValue: root.currentControlValue(parent.entry)
            placeholder: parent.entry.placeholder || "Select"
            options: parent.entry.options
            compact: root.compact
            foreground: root.foreground
            background: root.background
            muted: root.muted
            toneAccent: root.toneAccent(parent.entry.tone)
            titleFontFamily: root.itemFontFamily
            bodyFontFamily: root.bodyFontFamily
            designTokens: root.designTokens
            onSelected: function(value) { root.activateControl(parent.entry, value) }
          }
        }

        Component {
          id: textDelegate

          SettingsTextRow {
            width: parent.width
            icon: parent.entry.icon
            label: parent.entry.label
            hint: parent.entry.hint
            textValue: root.currentControlValue(parent.entry)
            placeholder: parent.entry.placeholder || ""
            masked: parent.entry.masked === true
            compact: root.compact
            foreground: root.foreground
            background: root.background
            muted: root.muted
            toneAccent: root.toneAccent(parent.entry.tone)
            titleFontFamily: root.itemFontFamily
            bodyFontFamily: root.bodyFontFamily
            designTokens: root.designTokens
            onAccepted: function(value) { root.activateControl(parent.entry, value) }
          }
        }
      }
    }
  }

  DesignTokens {
    id: fallbackDesignTokens
    designStyle: "lacuna"
    compact: root.compact
    foreground: root.foreground
    background: root.background
    accent: root.accent
  }
}
