import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  property var settingsService: null
  property bool exclusive: true
  property bool collapsed: false
  property string defaultMode: "off"
  property string monitorPolicy: "auto"
  property var monitorNames: []
  property bool autoHideEnabled: false
  property int autoHideHotZoneWidth: 3
  property int autoHideRevealDelayMs: 120
  property int autoHideHideDelayMs: 350
  property bool displayInitialized: false

  // Two distinct concepts that previously bled together:
  //   desiredDefaultMode - the persisted startup preference (off/rail/full).
  //   runtimeCollapsed    - the live rail/full toggle for the current session.
  // The aliases name the split so consumers can read intent directly.
  readonly property string desiredDefaultMode: defaultMode
  readonly property bool runtimeCollapsed: collapsed

  function load() {
    if (settingsService && settingsService.load) settingsService.load()
  }

  function toggle() {
    setExclusive(!exclusive)
  }

  function setExclusive(value) {
    exclusive = value === true
    save()
  }

  function toggleCollapsed() {
    collapsed = !collapsed
  }

  function expand() {
    collapsed = false
  }

  function setDisplay(mode) {
    var value = String(mode || "full").toLowerCase()
    collapsed = value === "rail"
  }

  function setDefaultMode(mode) {
    defaultMode = normalizeDefaultMode(mode)
    collapsed = defaultMode === "rail"
    save()
  }

  function setAutoHideEnabled(value) {
    var nextEnabled = value === true
    if (nextEnabled === autoHideEnabled) return
    autoHideEnabled = nextEnabled
    save()
  }

  function setAutoHideTiming(hotZoneWidth, revealDelayMs, hideDelayMs) {
    autoHideHotZoneWidth = boundedInt(hotZoneWidth, 3, 2, 8)
    autoHideRevealDelayMs = boundedInt(revealDelayMs, 120, 0, 1000)
    autoHideHideDelayMs = boundedInt(hideDelayMs, 350, 0, 3000)
    save()
  }

  function boundedInt(value, fallback, minimum, maximum) {
    var parsed = Math.round(Number(value))
    if (!isFinite(parsed)) return fallback
    return Math.max(minimum, Math.min(maximum, parsed))
  }

  function normalizeDefaultMode(mode) {
    var value = String(mode || "").toLowerCase()
    if (value === "off" || value === "rail" || value === "full") return value
    return "off"
  }

  function save() {
    if (!settingsService || !settingsService.save) return
    var next = settingsService.normalize ? settingsService.normalize(settingsService.data) : settingsService.data
    if (!next || typeof next !== "object") next = { version: 2 }
    if (!next.sidebar || typeof next.sidebar !== "object") next.sidebar = {}
    next.sidebar.defaultMode = defaultMode
    // This live rail/full state is also the presentation autohide reveals.
    next.sidebar.collapsed = collapsed
    next.sidebar.exclusive = exclusive
    // Deprecated trim booleans survive normalization untouched for rollback;
    // SidebarState no longer owns or advertises them as runtime controls.
    next.sidebar.monitorPolicy = next.sidebar.monitorPolicy ? String(next.sidebar.monitorPolicy) : monitorPolicy
    next.sidebar.monitorNames = Array.isArray(next.sidebar.monitorNames) ? next.sidebar.monitorNames : monitorNames
    if (!next.sidebar.autoHide || typeof next.sidebar.autoHide !== "object") next.sidebar.autoHide = {}
    next.sidebar.autoHide.enabled = autoHideEnabled
    next.sidebar.autoHide.hotZoneWidth = autoHideHotZoneWidth
    next.sidebar.autoHide.revealDelayMs = autoHideRevealDelayMs
    next.sidebar.autoHide.hideDelayMs = autoHideHideDelayMs
    settingsService.save(next, false, true)
  }

  function applySettings() {
    var sidebar = settingsService && settingsService.data ? settingsService.data.sidebar : null
    defaultMode = normalizeDefaultMode(sidebar && sidebar.defaultMode)
    if (!displayInitialized) {
      // Seed the session toggle from the startup preference on first load; from
      // then on it is session state that setDefaultMode/toggleCollapsed own.
      collapsed = defaultMode === "rail"
      displayInitialized = true
    }
    exclusive = !(sidebar && sidebar.exclusive === false)
    monitorPolicy = sidebar && sidebar.monitorPolicy ? String(sidebar.monitorPolicy) : "auto"
    monitorNames = sidebar && Array.isArray(sidebar.monitorNames) ? sidebar.monitorNames : []
    var autoHide = sidebar && sidebar.autoHide && typeof sidebar.autoHide === "object" ? sidebar.autoHide : ({})
    autoHideEnabled = autoHide.enabled === true
    autoHideHotZoneWidth = boundedInt(autoHide.hotZoneWidth, 3, 2, 8)
    autoHideRevealDelayMs = boundedInt(autoHide.revealDelayMs, 120, 0, 1000)
    autoHideHideDelayMs = boundedInt(autoHide.hideDelayMs, 350, 0, 3000)
  }

  Component.onCompleted: {
    if (!settingsService || settingsService.hasLoaded !== false) applySettings()
  }

  Connections {
    target: root.settingsService
    function onLoaded() {
      root.applySettings()
    }
  }
}
