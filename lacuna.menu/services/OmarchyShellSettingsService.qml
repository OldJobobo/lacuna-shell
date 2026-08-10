import Quickshell.Io
import Quickshell
import QtQuick
import qs.Commons

Item {
  id: root

  signal pluginStateChanged()

  property string lacunaPath: manifest && manifest.__sourceDir ? manifest.__sourceDir : localPath(Qt.resolvedUrl("."))
  property var commandRunner: localCommandRunner
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var shellConfig: ({})
  property bool loading: false
  property bool refreshPending: false
  property string pendingRefreshDomains: ""
  property string scheduledRefreshDomains: ""
  property string activeRefreshDomains: ""
  property bool actionRefreshPending: false
  property string actionRefreshDomains: ""
  property bool styleRefreshPending: false
  property bool loadTimedOut: false
  property string errorText: ""
  property bool stale: false
  property int loadFailureStreak: 0
  property int fullRefreshCount: 0
  property int scopedRefreshCount: 0
  property double refreshStartedAt: 0
  property double lastRefreshDurationMs: 0
  readonly property int loadTimeoutMs: 30000
  readonly property int terminationGraceMs: 1500
  readonly property int maxAutoRetries: 2
  property var state: defaultState()
  readonly property string homeDir: Quickshell.env("HOME") || ""
  readonly property int roundedWindowRadius: 12

  readonly property string currentTerminal: stringAt(state, ["defaults", "terminal"])
  readonly property string currentBrowser: stringAt(state, ["defaults", "browser"])
  readonly property string currentEditor: stringAt(state, ["defaults", "editor"])
  readonly property string currentFont: stringAt(state, ["font"])
  readonly property string currentPowerProfile: stringAt(state, ["powerProfile"])
  readonly property string windowRoundingMode: stringAt(state, ["hypr", "windowRoundingMode"]) || "theme"
  readonly property string focusedMonitorName: stringAt(state, ["monitor", "name"])
  readonly property string focusedMonitorScale: stringAt(state, ["monitor", "scale"])
  readonly property int idleScreensaver: positiveInt(shellConfig && shellConfig.idle ? shellConfig.idle.screensaver : undefined, 150)
  readonly property int idleLock: positiveInt(shellConfig && shellConfig.idle ? shellConfig.idle.lock : undefined, 300)

  function localPath(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = value.slice(7)
    return decodeURIComponent(value)
  }

  function defaultState() {
    return {
      defaults: { terminal: "", browser: "", editor: "" },
      available: { terminal: {}, browser: {}, editor: {} },
      font: "",
      fonts: [],
      monitor: { name: "", scale: "" },
      powerProfile: "",
      powerAvailable: false,
      hypr: {
        windowGapsEnabled: null,
        windowRoundingMode: "theme",
        windowRoundingOverride: false,
        windowRoundingOverrideRadius: -1,
        roundedWindows: null,
        singleWindowAspect: null,
        gapsIn: -1,
        gapsOut: -1,
        borderSize: -1,
        rounding: -1
      },
      toggles: {
        barVisible: true,
        screensaverEnabled: true,
        suspendEnabled: true,
        idleEnabled: null,
        notificationSilencing: null,
        nightlight: null
      }
    }
  }

  function stringAt(source, path) {
    var value = source
    for (var i = 0; i < path.length; i++) {
      if (!value || value[path[i]] === undefined || value[path[i]] === null) return ""
      value = value[path[i]]
    }
    return String(value)
  }

  function boolAt(source, path, fallback) {
    var value = source
    for (var i = 0; i < path.length; i++) {
      if (!value || value[path[i]] === undefined || value[path[i]] === null) return fallback
      value = value[path[i]]
    }
    return value === true ? true : value === false ? false : fallback
  }

  function positiveInt(value, fallback) {
    var parsed = Math.round(Number(value))
    return isFinite(parsed) && parsed > 0 ? parsed : fallback
  }

  function quote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function option(value, label, description, enabled) {
    return {
      value: value,
      label: label,
      description: description || "",
      enabled: enabled !== false
    }
  }

  function availability(kind, value) {
    var available = state && state.available && state.available[kind] ? state.available[kind] : ({})
    if (available[value] === undefined) return true
    return available[value] === true
  }

  function terminalOptions() {
    return [
      option("foot", "Foot", "Omarchy's default terminal path", availability("terminal", "foot")),
      option("ghostty", "Ghostty", "GPU-rendered terminal", availability("terminal", "ghostty")),
      option("alacritty", "Alacritty", "Fast OpenGL terminal", availability("terminal", "alacritty")),
      option("kitty", "Kitty", "Feature-rich terminal", availability("terminal", "kitty"))
    ]
  }

  function browserOptions() {
    return [
      option("brave", "Brave", "Brave browser", availability("browser", "brave")),
      option("firefox", "Firefox", "Mozilla Firefox", availability("browser", "firefox")),
      option("chromium", "Chromium", "Chromium browser", availability("browser", "chromium")),
      option("zen", "Zen", "Zen Browser", availability("browser", "zen")),
      option("chrome", "Chrome", "Google Chrome", availability("browser", "chrome")),
      option("edge", "Edge", "Microsoft Edge", availability("browser", "edge"))
    ]
  }

  function editorOptions() {
    return [
      option("nvim", "Neovim", "Terminal editor", availability("editor", "nvim")),
      option("code", "VS Code", "Visual Studio Code", availability("editor", "code")),
      option("cursor", "Cursor", "Cursor editor", availability("editor", "cursor")),
      option("zed", "Zed", "Zed editor", availability("editor", "zed")),
      option("helix", "Helix", "Helix editor", availability("editor", "helix")),
      option("vim", "Vim", "Terminal editor", availability("editor", "vim")),
      option("emacs", "Emacs", "GNU Emacs", availability("editor", "emacs"))
    ]
  }

  function fontOptions() {
    var rows = []
    var fonts = state && Array.isArray(state.fonts) ? state.fonts : []
    for (var i = 0; i < fonts.length; i++) {
      rows.push(option(String(fonts[i]), String(fonts[i]), "Installed font", true))
    }
    if (rows.length === 0 && currentFont !== "") rows.push(option(currentFont, currentFont, "Current font", true))
    return rows
  }

  function powerProfileOptions() {
    return [
      option("performance", "Performance", "Prefer speed", state.powerAvailable === true),
      option("balanced", "Balanced", "Default power profile", state.powerAvailable === true),
      option("power-saver", "Power Saver", "Prefer lower power use", state.powerAvailable === true)
    ]
  }

  function monitorScaleOptions() {
    return [
      option("1", "1", "100%", true),
      option("1.25", "1.25", "125%", true),
      option("1.6", "1.6", "160%", true),
      option("2", "2", "200%", true),
      option("3", "3", "300%", true),
      option("4", "4", "400%", true)
    ]
  }

  function windowRoundingOptions() {
    return [
      option("square", "Square", "Force application windows to use square corners", true),
      option("rounded", "Rounded", "Force application windows to use rounded corners", true),
      option("theme", "Theme", "Follow the active theme's window corner setting", true)
    ]
  }

  function toggleValue(name, fallback) {
    return boolAt(state, ["toggles", name], fallback)
  }

  function hyprValue(name, fallback) {
    return boolAt(state, ["hypr", name], fallback)
  }

  function hyprNumber(name, fallback) {
    var value = state && state.hypr ? state.hypr[name] : undefined
    var parsed = Number(value)
    return isFinite(parsed) ? parsed : fallback
  }

  function copyState() {
    return JSON.parse(JSON.stringify(state || defaultState()))
  }

  function setOptimisticToggle(name, value) {
    var next = copyState()
    if (!next.toggles || typeof next.toggles !== "object") next.toggles = {}
    next.toggles[name] = value === true
    state = next
  }

  function setOptimisticHypr(name, value, patch) {
    var next = copyState()
    if (!next.hypr || typeof next.hypr !== "object") next.hypr = {}
    next.hypr[name] = value === true
    if (patch && typeof patch === "object") {
      for (var key in patch) next.hypr[key] = patch[key]
    }
    state = next
  }

  function normalizeDomains(domains) {
    if (domains === undefined || domains === null || domains === "") return ""
    var source = Array.isArray(domains) ? domains : String(domains).split(",")
    var unique = []
    for (var i = 0; i < source.length; i++) {
      var value = String(source[i] || "").trim()
      if (value !== "" && unique.indexOf(value) < 0) unique.push(value)
    }
    unique.sort()
    return unique.join(",")
  }

  function mergeDomains(current, incoming) {
    var left = normalizeDomains(current)
    var right = normalizeDomains(incoming)
    if (left === "" || right === "") return ""
    return normalizeDomains(left.split(",").concat(right.split(",")))
  }

  function refresh(domains) {
    if (lacunaPath === "") return
    var scope = normalizeDomains(domains)
    if (loading) {
      if (!refreshPending) pendingRefreshDomains = scope
      else pendingRefreshDomains = mergeDomains(pendingRefreshDomains, scope)
      refreshPending = true
      return
    }
    loading = true
    activeRefreshDomains = scope
    refreshStartedAt = Date.now()
    if (scope === "") fullRefreshCount += 1
    else scopedRefreshCount += 1
    loadTimedOut = false
    errorText = ""
    loadProc.output = ""
    loadProc.command = ["python3", lacunaPath + "/scripts/omarchy-shell-settings-state.py"]
    if (scope !== "") loadProc.command = loadProc.command.concat(["--domains", scope])
    loadProc.running = true
    loadWatchdog.restart()
  }

  function scheduleRefresh(domains) {
    var scope = normalizeDomains(domains)
    if (refreshTimer.running) scheduledRefreshDomains = mergeDomains(scheduledRefreshDomains, scope)
    else scheduledRefreshDomains = scope
    refreshTimer.restart()
  }

  // Resolve a single load cycle exactly once. Whichever of the process exit or
  // the watchdog timeout fires first wins; the other call no-ops because the
  // loading flag is already cleared. This keeps a hung subprocess from wedging
  // the service (loading stuck true, every refresh() blocked) and avoids
  // double-counting a failure when the watchdog terminates the process.
  function resolveLoad(success, message) {
    if (!loading) return
    loading = false
    loadTimedOut = false
    loadWatchdog.stop()
    terminationGrace.stop()
    if (success) {
      lastRefreshDurationMs = refreshStartedAt > 0 ? Date.now() - refreshStartedAt : 0
      stale = false
      loadFailureStreak = 0
      errorText = ""
      if (refreshPending) {
        var nextDomains = pendingRefreshDomains
        refreshPending = false
        pendingRefreshDomains = ""
        scheduleRefresh(nextDomains)
      }
      return
    }
    if (refreshPending) activeRefreshDomains = mergeDomains(activeRefreshDomains, pendingRefreshDomains)
    refreshPending = false
    pendingRefreshDomains = ""
    if (message) errorText = message
    else if (errorText === "") errorText = "Unable to read Omarchy settings state"
    stale = true
    loadFailureStreak += 1
    if (loadFailureStreak <= maxAutoRetries) {
      retryTimer.interval = Math.min(30000, 2000 * loadFailureStreak)
      retryTimer.restart()
    }
  }

  function handleLoadTimeout() {
    if (!loading || loadTimedOut) return
    loadTimedOut = true
    if (loadProc.running) loadProc.running = false
    terminationGrace.restart()
  }

  function run(command, domains) {
    if (commandRunner && typeof commandRunner.run === "function") commandRunner.run(command)
    if (domains === false) return
    var scope = normalizeDomains(domains)
    if (!actionRefreshPending) actionRefreshDomains = scope
    else actionRefreshDomains = mergeDomains(actionRefreshDomains, scope)
    actionRefreshPending = true
  }

  Connections {
    target: root.commandRunner
    ignoreUnknownSignals: true
    function onQueueDrained() {
      if (root.actionRefreshPending) {
        var domains = root.actionRefreshDomains
        root.actionRefreshPending = false
        root.actionRefreshDomains = ""
        root.scheduleRefresh(domains)
      }
      if (root.styleRefreshPending) {
        root.styleRefreshPending = false
        Style.scheduleRefresh()
      }
    }
  }

  function setDefault(kind, value) {
    var target = String(kind || "")
    if (target !== "terminal" && target !== "browser" && target !== "editor") return
    run("omarchy default " + target + " " + quote(value), ["defaults"])
  }

  function setFont(value) {
    run("omarchy font set " + quote(value), ["font"])
  }

  function setPowerProfile(value) {
    run("powerprofilesctl set " + quote(value), ["powerProfile", "powerAvailable"])
  }

  function setMonitorScale(value) {
    run("omarchy hyprland monitor scaling " + quote(value), ["monitor"])
  }

  function refreshIndicatorsCommand() {
    return "omarchy-shell -q omarchy.indicators refresh >/dev/null 2>&1"
  }

  function setNightlight(enabled) {
    var temp = enabled === true ? "4000" : "6500"
    run("if ! pgrep -x hyprsunset >/dev/null; then setsid uwsm-app -- hyprsunset >/dev/null 2>&1 & sleep 1; fi"
      + "; hyprctl hyprsunset temperature " + temp + " >/dev/null 2>&1"
      + "; " + refreshIndicatorsCommand(), ["toggles"])
  }

  function omarchyPathPrefix() {
    return "OMARCHY_PATH=${OMARCHY_PATH:-$HOME/.local/share/omarchy}"
  }

  function setHyprFlag(flag, enabled) {
    run(omarchyPathPrefix() + " omarchy hyprland toggle " + quote(flag) + " " + (enabled ? "on" : "off"), ["hypr"])
  }

  function setWindowGapsEnabled(enabled) {
    var want = enabled === true
    var dir = homeDir + "/.local/state/omarchy/toggles/hypr"
    var stockFile = dir + "/window-no-gaps.lua"
    var oldLacunaFile = dir + "/zz-lacuna-window-no-gaps.lua"
    var lacunaFile = dir + "/zz-lacuna-window-gaps.lua"
    setOptimisticHypr("windowGapsEnabled", want, {})
    if (want) {
      run("mkdir -p " + quote(dir)
        + "; rm -f " + quote(stockFile) + " " + quote(oldLacunaFile) + " " + quote(lacunaFile)
        + "; hyprctl reload >/dev/null", ["hypr"])
      return
    }

    var body = "-- Lacuna: Disable Hyprland window gaps without changing theme borders or corner rounding.\n"
      + "hl.config({\n"
      + "  general = {\n"
      + "    gaps_out = 0,\n"
      + "    gaps_in = 0,\n"
      + "  },\n"
      + "})\n"
    run("mkdir -p " + quote(dir)
      + "; rm -f " + quote(stockFile) + " " + quote(oldLacunaFile)
      + "; printf %s " + quote(body) + " > " + quote(lacunaFile)
      + "; hyprctl reload >/dev/null"
      + "; hyprctl eval " + quote("hl.config({ general = { gaps_out = 0, gaps_in = 0 } })") + " >/dev/null", ["hypr"])
  }

  function setSingleWindowAspect(enabled) {
    var want = enabled === true
    var dir = homeDir + "/.local/state/omarchy/toggles/hypr"
    var stockFile = dir + "/single-window-aspect-ratio.lua"
    var lacunaFile = dir + "/zz-lacuna-single-window-aspect.lua"
    var x = want ? 1 : 0
    var y = want ? 1 : 0
    setOptimisticHypr("singleWindowAspect", want, {})
    var body = "-- Lacuna: Own single-window aspect behavior explicitly.\n"
      + "hl.config({\n"
      + "  layout = {\n"
      + "    single_window_aspect_ratio = { " + x + ", " + y + " },\n"
      + "  },\n"
      + "})\n"
    var liveConfig = "hl.config({ layout = { single_window_aspect_ratio = { " + x + ", " + y + " } } })"
    run("mkdir -p " + quote(dir)
      + "; rm -f " + quote(stockFile)
      + "; printf %s " + quote(body) + " > " + quote(lacunaFile)
      + "; hyprctl reload >/dev/null"
      + "; hyprctl eval " + quote(liveConfig) + " >/dev/null", ["hypr"])
  }

  function setWindowRoundingMode(value) {
    var mode = String(value || "").toLowerCase()
    if (mode !== "square" && mode !== "rounded" && mode !== "theme") return

    var file = homeDir + "/.local/state/omarchy/toggles/hypr/zz-lacuna-window-rounded.lua"
    var dir = homeDir + "/.local/state/omarchy/toggles/hypr"
    var stockNoGapsFile = dir + "/window-no-gaps.lua"
    var lacunaGapsFile = dir + "/zz-lacuna-window-gaps.lua"
    var next = copyState()
    if (!next.hypr || typeof next.hypr !== "object") next.hypr = {}
    next.hypr.windowRoundingMode = mode

    if (mode === "theme") {
      next.hypr.windowRoundingOverride = false
      next.hypr.windowRoundingOverrideRadius = -1
      state = next
      styleRefreshPending = true
      var gapsOnlyBody = "-- Lacuna: Preserve disabled gaps without overriding theme borders or corner rounding.\n"
        + "hl.config({\n"
        + "  general = {\n"
        + "    gaps_out = 0,\n"
        + "    gaps_in = 0,\n"
        + "  },\n"
        + "})\n"
      run("mkdir -p " + quote(dir)
        + "; if [ -f " + quote(stockNoGapsFile) + " ]; then printf %s " + quote(gapsOnlyBody) + " > " + quote(lacunaGapsFile) + "; fi"
        + "; rm -f " + quote(file) + " " + quote(stockNoGapsFile)
        + "; hyprctl reload >/dev/null", ["hypr"])
      return
    }

    setWindowRoundingRadius(mode === "rounded" ? root.roundedWindowRadius : 0)
  }

  function setWindowRoundingRadius(value) {
    var parsed = Math.round(Number(value))
    if (!isFinite(parsed)) return
    var radius = Math.max(0, Math.min(32, parsed))
    var file = homeDir + "/.local/state/omarchy/toggles/hypr/zz-lacuna-window-rounded.lua"
    var dir = homeDir + "/.local/state/omarchy/toggles/hypr"
    var next = copyState()
    if (!next.hypr || typeof next.hypr !== "object") next.hypr = {}
    next.hypr.windowRoundingMode = radius > 0 ? "rounded" : "square"
    next.hypr.windowRoundingOverride = true
    next.hypr.windowRoundingOverrideRadius = radius
    next.hypr.roundedWindows = radius > 0
    next.hypr.rounding = radius
    state = next
    styleRefreshPending = true
    var body = "-- Lacuna: Override the active theme's Hyprland window corner rounding.\n"
      + "hl.config({\n"
      + "  decoration = {\n"
      + "    rounding = " + radius + ",\n"
      + "  },\n"
      + "})\n"
    var liveConfig = "hl.config({ decoration = { rounding = " + radius + " } })"
    run("mkdir -p " + quote(dir)
      + "; printf %s " + quote(body) + " > " + quote(file)
      + "; hyprctl reload >/dev/null"
      + "; hyprctl eval " + quote(liveConfig) + " >/dev/null", ["hypr"])
  }

  function setRoundedWindows(enabled) {
    setWindowRoundingMode(enabled === true ? "rounded" : "square")
  }

  function setToggle(name, desired) {
    var key = String(name || "")
    var want = desired === true
    if (key === "barVisible") {
      setOptimisticToggle("barVisible", want)
      run("omarchy toggle bar " + (want ? "on" : "off"), ["toggles"])
      return
    }
    if (key === "windowGapsEnabled") {
      setWindowGapsEnabled(want)
      return
    }
    if (key === "roundedWindows") {
      setRoundedWindows(want)
      return
    }
    if (key === "singleWindowAspect") {
      setSingleWindowAspect(want)
      return
    }

    var current = toggleValue(key, null)
    if (current !== null && current === want) return

    if (key === "screensaverEnabled") {
      setOptimisticToggle("screensaverEnabled", want)
      run("omarchy toggle screensaver", ["toggles"])
    } else if (key === "suspendEnabled") {
      setOptimisticToggle("suspendEnabled", want)
      run("omarchy toggle suspend", ["toggles"])
    } else if (key === "idleEnabled") {
      setOptimisticToggle("idleEnabled", want)
      run("omarchy toggle idle " + (want ? "allow-idle" : "stay-awake"), ["toggles"])
    } else if (key === "notificationSilencing") {
      setOptimisticToggle("notificationSilencing", want)
      run("current=$(omarchy-shell notifications isDnd 2>/dev/null || true)"
        + "; if [ \"$current\" != " + quote(want ? "on" : "off") + " ]; then omarchy-shell notifications toggleDnd >/dev/null; fi"
        + "; " + refreshIndicatorsCommand(), false)
    } else if (key === "nightlight") {
      setOptimisticToggle("nightlight", want)
      setNightlight(want)
    }
  }

  function mutateShellConfig(mutator) {
    if (shell && typeof shell.mutateShellConfig === "function") {
      shell.mutateShellConfig(mutator)
      return true
    }
    run("notify-send 'Lacuna' 'Omarchy shell settings require the live shell config mutator'", false)
    return false
  }

  function setIdleTimeout(kind, seconds) {
    var key = String(kind || "")
    var value = positiveInt(seconds, key === "lock" ? 300 : 150)
    if (key !== "screensaver" && key !== "lock") return

    mutateShellConfig(function(config) {
      if (!config.idle || typeof config.idle !== "object") config.idle = {}
      config.idle[key] = value
    })
  }

  function setShellPluginEnabled(id, enabled) {
    if (pluginRegistry && typeof pluginRegistry.setEnabled === "function") {
      pluginRegistry.setEnabled(id, enabled === true)
      pluginStateChanged()
      return
    }

    run("notify-send 'Lacuna' 'Plugin toggles require the Omarchy shell plugin registry'", false)
  }

  function mergeCollectedState(nextState) {
    var merged = copyState()
    var currentDnd = root.toggleValue("notificationSilencing", null)
    if (nextState.toggles && (nextState.toggles.notificationSilencing === null || nextState.toggles.notificationSilencing === undefined))
      nextState.toggles.notificationSilencing = currentDnd
    for (var key in nextState) merged[key] = nextState[key]
    state = merged
  }

  Component.onCompleted: refresh()

  Timer {
    id: refreshTimer
    interval: 1200
    repeat: false
    onTriggered: {
      var domains = root.scheduledRefreshDomains
      root.scheduledRefreshDomains = ""
      root.refresh(domains)
    }
  }

  Timer {
    id: reconciliationTimer
    interval: 60000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Timer {
    id: loadWatchdog
    interval: root.loadTimeoutMs
    repeat: false
    onTriggered: root.handleLoadTimeout()
  }

  Timer {
    id: retryTimer
    interval: 2000
    repeat: false
    onTriggered: root.refresh(root.activeRefreshDomains)
  }

  Timer {
    id: terminationGrace
    interval: root.terminationGraceMs
    repeat: false
    onTriggered: root.resolveLoad(false, "Timed out reading Omarchy settings state")
  }

  Process {
    id: loadProc
    property string output: ""

    stdout: SplitParser {
      onRead: function(data) {
        loadProc.output += data
      }
    }

    stderr: SplitParser {
      onRead: function(data) {
        root.errorText = String(data || "").trim()
      }
    }

    onExited: function(exitCode) {
      if (root.loadTimedOut) {
        root.resolveLoad(false, "Timed out reading Omarchy settings state")
        return
      }
      if (exitCode !== 0) {
        root.resolveLoad(false, "")
        return
      }
      try {
        var nextState = JSON.parse(loadProc.output || "{}")
        root.mergeCollectedState(nextState)
        root.resolveLoad(true, "")
      } catch (error) {
        root.resolveLoad(false, "Unable to parse Omarchy settings state")
      }
    }
  }

  CommandRunner {
    id: localCommandRunner
  }
}
