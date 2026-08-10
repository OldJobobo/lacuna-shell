import QtQuick
import QtQuick.Shapes
import "../components"
import "../services"

Item {
  id: root

  signal activated(var entry)
  signal closeRequested()

  required property var registry
  required property var settingsService
  property bool compact: false
  property bool open: false
  property string currentSection: "apps"
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
  property int stateRevision: 0
  property var controlOverrides: ({})
  property int controlRevision: 0
  property var currentItems: []
  property string modelError: ""
  readonly property int panelRadius: Math.max(tokenNumber("radius", 0), compact ? 10 : 14)
  readonly property real curveKappa: lacunaGeometry.curveKappa

  LacunaGeometry { id: lacunaGeometry }

  onOpenChanged: if (open && settingsService) settingsService.refresh()
  onCurrentSectionChanged: {
    clearControlOverrides()
    refreshItems()
  }

  Component.onCompleted: refreshItems()

  function tokenNumber(name, fallback) {
    if (!designTokens || designTokens[name] === undefined || designTokens[name] === null) return fallback
    var value = Number(designTokens[name])
    return isFinite(value) ? value : fallback
  }

  function sections() {
    return [
      { id: "apps", icon: "preferred-apps", label: "Apps", hint: "Default terminal, browser, editor" },
      { id: "appearance", icon: "palette", label: "Appearance", hint: "Theme, wallpaper, font" },
      { id: "windows", icon: "sidebar-overlay", label: "Windows", hint: "Gaps, bar, monitor scale" },
      { id: "power", icon: "power", label: "Power", hint: "Profiles and nightlight" },
      { id: "idle", icon: "moon", label: "Idle", hint: "Lock, screensaver, suspend" },
      { id: "notifications", icon: "message", label: "Alerts", hint: "Notification behavior" },
      { id: "plugins", icon: "apps", label: "Plugins", hint: "Shell plugin activation" },
      { id: "runtime", icon: "refresh", label: "Runtime", hint: "Diagnostics and config files" }
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
    if (tone === "lacuna") return root.accent
    if (tone === "shell") return root.shellAccent
    if (tone === "session") return root.sessionAccent
    if (tone === "danger") return root.dangerAccent
    return root.navAccent
  }

  function section(label, note, tone) {
    return {
      kind: "section",
      label: label,
      note: note || "",
      tone: tone || "shell"
    }
  }

  function row(icon, label, hint, value, tone, action, control, checked, options, optionValue, actionPrefix) {
    return {
      kind: "row",
      icon: icon,
      label: label,
      hint: hint || "",
      value: value || "",
      tone: tone || "shell",
      action: action || "",
      control: control || "nav",
      checked: checked === true,
      options: options || [],
      optionValue: optionValue || "",
      optionActionPrefix: actionPrefix || "",
      view: "",
      command: "",
      setting: "",
      timeoutKind: "",
      pluginId: "",
      enabled: true
    }
  }

  function commandRow(icon, label, hint, command, tone) {
    var item = row(icon, label, hint, "Open", tone || "shell", "", "button")
    item.command = command || ""
    return item
  }

  function actionRow(icon, label, hint, action, tone, value) {
    return row(icon, label, hint, value || "Set", tone || "shell", action, "button")
  }

  function selectRow(icon, label, hint, currentValue, options, setting, tone, placeholder) {
    var item = row(icon, label, hint, "", tone || "shell", "", "select", false, options, currentValue || "", "")
    item.setting = setting || ""
    item.placeholder = placeholder || "Select"
    return item
  }

  function searchableSelectRow(icon, label, hint, currentValue, options, setting, tone, placeholder) {
    var item = selectRow(icon, label, hint, currentValue, options, setting, tone, placeholder)
    item.control = "search-select"
    return item
  }

  function toggleRow(icon, label, hint, setting, checked, tone) {
    var item = row(icon, label, hint, checked === null ? "Unknown" : checked ? "On" : "Off", tone || "shell", "", "toggle", checked === true)
    item.setting = setting || ""
    return item
  }

  function controlKey(entry) {
    if (!entry) return ""
    if (entry.control === "toggle") return "toggle:" + String(entry.setting || entry.pluginId || entry.action || entry.label || "")
    if (entry.control === "segments") return "value:" + String(entry.timeoutKind || entry.optionActionPrefix || entry.setting || entry.label || "")
    if (entry.control === "select" || entry.control === "search-select") return "value:" + String(entry.setting || entry.label || "")
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

  function timeoutRow(icon, label, hint, kind, currentValue, options) {
    var item = row(icon, label, hint, "", "shell", "", "segments", false, options, String(currentValue), "")
    item.timeoutKind = kind
    return item
  }

  function pluginItems() {
    var rows = [
      section("Installed Plugins", "Enable or disable shell plugins referenced from shell.json.", "shell")
    ]
    if (!root.registry || typeof root.registry.installedShellPluginRows !== "function") {
      rows.push(row("apps", "Plugin registry unavailable", "The host shell did not inject plugin registry helpers", "", "shell", "", "value"))
      return rows
    }
    var plugins = root.registry.installedShellPluginRows()
    if (plugins.length === 0) {
      rows.push(row("apps", "No third-party plugins", "Only first-party shell infrastructure is installed", "", "shell", "", "value"))
      return rows
    }

    for (var i = 0; i < plugins.length; i++) {
      var plugin = plugins[i]
      var item = toggleRow(plugin.enabled ? "check" : "apps", plugin.name, plugin.description, "shellPlugin", plugin.enabled, plugin.enabled ? "shell" : "nav")
      item.pluginId = plugin.id
      rows.push(item)
    }
    return rows
  }

  function registryCommand(name) {
    if (root.registry && typeof root.registry[name] === "function") return root.registry[name]()
    return ""
  }

  function itemsFor(sectionId) {
    var revision = root.stateRevision
    var service = root.settingsService
    if (sectionId === "apps") {
      return [
        section("Default Applications", "Used by Omarchy launchers and shell shortcuts.", "shell"),
        selectRow("terminal", "Terminal", "Sets xdg-terminal-exec and Omarchy terminal launches", service.currentTerminal, service.terminalOptions(), "default-terminal", "shell", "Terminal"),
        selectRow("world", "Browser", "Sets Omarchy browser launches and web link handlers", service.currentBrowser, service.browserOptions(), "default-browser", "shell", "Browser"),
        selectRow("edit", "Editor", "Sets Omarchy editor launches and config shortcuts", service.currentEditor, service.editorOptions(), "default-editor", "shell", "Editor")
      ]
    }

    if (sectionId === "appearance") {
      return [
        section("Theme and Wallpaper", "Visual assets shared by Omarchy shell and apps.", "shell"),
        commandRow("palette", "Theme", "Switch Omarchy theme", root.registry.switchThemeCommand(), "shell"),
        commandRow("background", "Background", "Switch active theme background", root.registry.switchBackgroundCommand(), "shell"),
        commandRow("photo", "Wallpaper Catalog", "Open wallpaper picker", "jobowalls-gui", "shell"),
        section("Font", "Installed font families from Omarchy's font registry.", "shell"),
        searchableSelectRow("edit", "Shell Font", "Search installed fonts and apply through Omarchy", service.currentFont, service.fontOptions(), "font", "shell", "Font")
      ]
    }

    if (sectionId === "windows") {
      return [
        section("Tiling", "Hyprland layout toggles for application windows.", "shell"),
        toggleRow("density-normal", "Window Gaps", "Use the active theme's tiled-window gap size", "windowGapsEnabled", service.hyprValue("windowGapsEnabled", null), "shell"),
        toggleRow("sidebar-overlay", "Single-Window Square", "Constrain one tiled window to a square aspect ratio", "singleWindowAspect", service.hyprValue("singleWindowAspect", null), "shell"),
        section("Shell Bar", "Visibility only. Bar layout remains in Omarchy's bar settings.", "shell"),
        toggleRow("sidebar-overlay", "Omarchy Bar", "Show or hide the host bar without killing shell", "barVisible", service.toggleValue("barVisible", true), "shell"),
        section("Focused Monitor Scale", "Set the scale for the currently focused Hyprland monitor.", "shell"),
        selectRow("photo", "Scale", service.focusedMonitorName === "" ? "Focused monitor" : service.focusedMonitorName, service.focusedMonitorScale, service.monitorScaleOptions(), "monitor-scale", "shell", "Scale")
      ]
    }

    if (sectionId === "power") {
      return [
        section("Power Profile", "CPU and platform performance mode.", "shell"),
        selectRow("power", "Profile", service.state.powerAvailable ? "Managed by power-profiles-daemon" : "powerprofilesctl is not available", service.currentPowerProfile, service.powerProfileOptions(), "power-profile", "shell", "Profile"),
        section("Display Comfort", "Screen temperature behavior.", "shell"),
        toggleRow("moon", "Nightlight", "Toggle warm screen temperature", "nightlight", service.toggleValue("nightlight", null), "shell")
      ]
    }

    if (sectionId === "idle") {
      return [
        section("Idle Timing", "Timeouts are written to shell.json.", "shell"),
        timeoutRow("moon", "Screensaver Timeout", "Current " + service.idleScreensaver + "s", "screensaver", service.idleScreensaver, [
          { value: "120", label: "2m" },
          { value: "300", label: "5m" },
          { value: "600", label: "10m" },
          { value: "900", label: "15m" }
        ]),
        timeoutRow("lock", "Lock Timeout", "Current " + service.idleLock + "s", "lock", service.idleLock, [
          { value: "300", label: "5m" },
          { value: "600", label: "10m" },
          { value: "900", label: "15m" },
          { value: "1800", label: "30m" }
        ]),
        section("Idle Actions", "Omarchy feature toggles for inactivity and session menu behavior.", "shell"),
        toggleRow("moon", "Idle Locking", "Allow the system to lock after inactivity", "idleEnabled", service.toggleValue("idleEnabled", null), "shell"),
        toggleRow("photo", "Screensaver", "Allow screensaver launch after inactivity", "screensaverEnabled", service.toggleValue("screensaverEnabled", true), "shell"),
        toggleRow("power", "Suspend Menu Item", "Show Suspend in the power menu", "suspendEnabled", service.toggleValue("suspendEnabled", true), "shell")
      ]
    }

    if (sectionId === "notifications") {
      return [
        section("Notifications", "Shell-backed notification behavior.", "shell"),
        toggleRow("message", "Do Not Disturb", "Silence normal notifications", "notificationSilencing", service.toggleValue("notificationSilencing", null), "shell")
      ]
    }

    if (sectionId === "plugins") return pluginItems()

    return [
      section("State", "Refresh the values shown by this panel.", "shell"),
      actionRow("refresh", "Refresh Settings State", root.settingsService.loading ? "Reading Omarchy state" : root.settingsService.errorText !== "" ? root.settingsService.errorText : "Defaults, fonts, toggles, and monitor status", "refresh-shell-settings-state", "shell", root.settingsService.loading ? "Busy" : "Refresh"),
      section("Shell", "Operational commands for the live Omarchy shell.", "shell"),
      commandRow("refresh", "Restart Shell", "Restart Omarchy shell", registryCommand("restartLacunaCommand"), "shell"),
      commandRow("file-search", "Open Log", "View the current shell log", registryCommand("openLogCommand"), "shell"),
      commandRow("edit", "Open shell.json", "Edit Omarchy shell user config", registryCommand("editShellConfigCommand"), "shell"),
      section("Diagnostics", "Useful shell and idle diagnostics.", "shell"),
      commandRow("settings", "Omarchy Debug", "Open debug output in a terminal", registryCommand("debugCommand"), "shell"),
      commandRow("moon", "Idle Debug", "Open idle diagnostics in a terminal", registryCommand("debugIdleCommand"), "shell")
    ]
  }

  function refreshItems() {
    try {
      modelError = ""
      currentItems = itemsFor(currentSection)
    } catch (e) {
      modelError = String(e)
      currentItems = [
        section("Unavailable", "Unable to build this settings section.", "danger"),
        row("settings", "Section Error", modelError, "", "danger", "", "value")
      ]
    }
  }

  function handleEntry(entry, desiredChecked) {
    if (!entry || entry.kind !== "row") return
    if (entry.action === "refresh-shell-settings-state") {
      root.settingsService.refresh()
      return
    }
    if (entry.control === "toggle") {
      var want = desiredChecked === true
      if (entry.setting === "shellPlugin") {
        root.settingsService.setShellPluginEnabled(entry.pluginId, want)
        return
      }
      root.settingsService.setToggle(entry.setting, want)
      return
    }
    root.activated(entry)
  }

  function handleSelected(entry, value) {
    if (!entry) return
    if (entry.setting === "default-terminal") root.settingsService.setDefault("terminal", value)
    else if (entry.setting === "default-browser") root.settingsService.setDefault("browser", value)
    else if (entry.setting === "default-editor") root.settingsService.setDefault("editor", value)
    else if (entry.setting === "font") root.settingsService.setFont(value)
    else if (entry.setting === "monitor-scale") root.settingsService.setMonitorScale(value)
    else if (entry.setting === "power-profile") root.settingsService.setPowerProfile(value)
  }

  function handleOptionSelected(entry, value) {
    if (!entry) return
    if (entry.timeoutKind !== "") {
      root.settingsService.setIdleTimeout(entry.timeoutKind, value)
      return
    }

    root.activated({
      kind: "item",
      action: entry.optionActionPrefix + value,
      view: "",
      command: ""
    })
  }

  function activateControl(entry, value) {
    if (!entry || entry.kind !== "row") return
    if (entry.control === "toggle") {
      var desired = !currentControlChecked(entry)
      setControlOverride(entry, desired)
      handleEntry(entry, desired)
      return
    }
    if (entry.control === "segments") {
      setControlOverride(entry, value)
      handleOptionSelected(entry, value)
      return
    }
    if (entry.control === "select" || entry.control === "search-select") {
      setControlOverride(entry, value)
      handleSelected(entry, value)
      return
    }
    handleEntry(entry)
  }

  Connections {
    target: root.settingsService
    function onStateChanged() { root.stateRevision++; root.clearControlOverrides(); root.refreshItems() }
    function onShellConfigChanged() { root.stateRevision++; root.clearControlOverrides(); root.refreshItems() }
    function onLoadingChanged() { root.stateRevision++; root.refreshItems() }
  }

  width: 430
  height: 560
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
      showLabels: true
      foreground: root.foreground
      background: root.background
      muted: root.muted
      accent: root.shellAccent
      designTokens: root.designTokens
      onSectionSelected: function(sectionId) {
        if (sectionId !== "") root.currentSection = sectionId
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
        accent: root.shellAccent
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
          width: parent.width
          spacing: root.compact ? 5 : 6

          Repeater {
            model: root.currentItems

            Loader {
              property var entry: modelData

              width: parent.width
              sourceComponent: entry.kind === "section"
                ? sectionDelegate
                : entry.control === "select"
                  ? selectDelegate
                  : entry.control === "search-select"
                    ? searchSelectDelegate
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
          id: searchSelectDelegate

          SettingsSearchableSelectRow {
            width: parent.width
            icon: parent.entry.icon
            label: parent.entry.label
            hint: parent.entry.hint
            currentValue: root.currentControlValue(parent.entry)
            placeholder: parent.entry.placeholder || "Search"
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
      }
    }
  }

  DesignTokens {
    id: fallbackDesignTokens
    designStyle: "lacuna"
    compact: root.compact
    foreground: root.foreground
    background: root.background
    accent: root.shellAccent
  }

  LacunaTokens { id: typeTokens }

}
