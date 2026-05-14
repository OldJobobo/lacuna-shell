import Quickshell
import QtQuick

Item {
  id: root

  property string lacunaPath: Quickshell.env("LACUNA_PATH") || Quickshell.env("PWD")
  property bool sidebarExclusive: true
  property bool sidebarCollapsed: false

  function item(kind, icon, label, hint, view, command, tone, priority, layout, danger, group, action) {
    return {
      kind: kind,
      icon: icon,
      label: label,
      hint: hint,
      view: view,
      command: command,
      action: action || "",
      tone: tone || (kind === "header" ? "section" : "nav"),
      priority: priority || "normal",
      layout: layout || (kind === "header" ? "section" : "row"),
      danger: danger || tone === "danger",
      group: group || ""
    }
  }

  function titleFor(view) {
    if (view === "lacuna") return "Lacuna"
    if (view === "lacuna-shell") return "Shell Settings"
    if (view === "lacuna-preferences") return "Preferences"
    if (view === "system") return "System"
    return "Utility Sidebar"
  }

  function itemsFor(view) {
    if (view === "lacuna") {
      return [
        item("header", "", "Control", "", "", "", "lacuna", "normal", "section", false, "lacuna"),
        item("item", "󰒓", "Shell settings", "Runtime actions and diagnostics", "lacuna-shell", "", "lacuna", "primary", "featured", false, "lacuna"),
        item("item", "", "Preferences", "Density, modules, and surface behavior", "lacuna-preferences", "", "lacuna", "primary", "featured", false, "lacuna"),
        item("header", "", "Source", "", "", "", "shell"),
        item("item", "󰑐", "Restart Lacuna", "Reload this Quickshell surface", "", "quickshell kill -p " + root.lacunaPath + "/shell.qml; setsid " + root.lacunaPath + "/run.sh >/tmp/lacuna-quickshell.log 2>&1 &", "shell"),
        item("item", "", "Open source", "Edit the local Lacuna project", "", "xdg-terminal-exec --app-id=org.omarchy.terminal bash -lc 'cd " + root.lacunaPath + " && ${EDITOR:-nvim} .'", "shell")
      ]
    }

    if (view === "lacuna-shell") {
      return [
        item("header", "", "Runtime", "", "", "", "shell", "normal", "section", false, "shell"),
        item("item", "󰑐", "Restart shell", "Restart Lacuna Quickshell", "", "quickshell kill -p " + root.lacunaPath + "/shell.qml; setsid " + root.lacunaPath + "/run.sh >/tmp/lacuna-quickshell.log 2>&1 &", "shell", "primary", "featured", false, "shell"),
        item("item", "󰌾", "Open log", "View the current Lacuna log", "", "xdg-terminal-exec --app-id=org.omarchy.terminal less /tmp/lacuna-quickshell.log", "shell"),
        item("item", "", "Edit shell", "Open shell.qml", "", "omarchy-launch-editor " + root.lacunaPath + "/shell.qml", "lacuna")
      ]
    }

    if (view === "lacuna-preferences") {
      return [
        item("header", "", "Preferences", "", "", "", "lacuna", "normal", "section", false, "lacuna"),
        item("item", "󰙵", "Bar density", "Compact and spacing controls", "", "", "lacuna", "primary", "featured", false, "lacuna"),
        item("item", "󰔡", "Tooltip style", "Surface, shadow, and edge behavior", "", "", "lacuna"),
        item("item", "󰀻", "Module visibility", "Per-module display controls", "", "", "lacuna")
      ]
    }

    if (view === "system") {
      return [
        item("header", "", "Session", "", "", "", "session", "normal", "section", false, "session"),
        item("item", "󱄄", "Screensaver", "Start screensaver now", "", "omarchy-launch-screensaver force", "session"),
        item("item", "", "Lock", "Lock session", "", "omarchy-system-lock", "session", "primary", "featured", false, "session"),
        item("item", "󰍃", "Logout", "End session", "", "omarchy-system-logout", "session"),
        item("header", "", "Power", "", "", "", "danger", "normal", "section", true, "power"),
        item("item", "󰜉", "Restart", "Reboot machine", "", "omarchy-system-reboot", "danger", "normal", "row", true, "power"),
        item("item", "󰐥", "Shutdown", "Power off machine", "", "omarchy-system-shutdown", "danger", "primary", "featured", true, "power")
      ]
    }

    return [
      item("header", "", "Lacuna", "", "", "", "lacuna", "normal", "section", false, "lacuna"),
      item("item", "󱥸", "Control surface", "Shell settings and preferences", "lacuna", "", "lacuna", "primary", "featured", false, "lacuna"),
      item("item", root.sidebarCollapsed ? "󰍽" : "󰍾", root.sidebarCollapsed ? "Expand sidebar" : "Collapse to icon rail", root.sidebarCollapsed ? "Show the full utility sidebar" : "Shrink into a side icon bar", "", "", "lacuna", "primary", "row", false, "lacuna", "toggle-sidebar-rail"),
      item("item", root.sidebarExclusive ? "󰹑" : "󰹐", root.sidebarExclusive ? "Use overlay mode" : "Reserve screen space", root.sidebarExclusive ? "Let the sidebar float over windows" : "Make windows leave room for the sidebar", "", "", "lacuna", "primary", "row", false, "lacuna", "toggle-sidebar-mode"),
      item("header", "", "Launch", "", "", "", "nav"),
      item("item", "󰀻", "Apps", "Open Walker app launcher", "", "walker -p 'Launch…'", "nav", "primary", "row"),
      item("item", "", "Terminal", "Open a terminal", "", "xdg-terminal-exec", "nav"),
      item("item", "󰈹", "Browser", "Launch browser", "", "omarchy launch browser", "nav"),
      item("header", "", "Desktop", "", "", "", "shell"),
      item("item", "󰸉", "Wallpaper", "Open wallpaper picker", "", "jobowalls-gui", "shell", "primary", "row"),
      item("item", "󰔎", "Theme", "Switch Omarchy theme", "", "omarchy theme switcher", "shell"),
      item("item", "󰖔", "Background", "Switch theme background", "", "omarchy theme bg-switcher", "shell"),
      item("header", "", "System Tools", "", "", "", "session"),
      item("item", "󰖩", "Wi-Fi", "Open Wi-Fi controls", "", "hyprctl dispatch 'hl.dsp.exec_cmd([[omarchy launch wifi]])'", "session"),
      item("item", "󰂯", "Bluetooth", "Open Bluetooth controls", "", "hyprctl dispatch 'hl.dsp.exec_cmd([[omarchy launch bluetooth]])'", "session"),
      item("item", "󰕾", "Audio", "Open audio mixer", "", "hyprctl dispatch 'hl.dsp.exec_cmd([[omarchy launch audio]])'", "session"),
      item("item", "󰄄", "Record screen", "Toggle screen recording", "", "omarchy capture screenrecording", "session"),
      item("item", "󰒲", "Idle", "Toggle idle behavior", "", "omarchy toggle idle", "session"),
      item("header", "", "Maintenance", "", "", "", "shell"),
      item("item", "", "Update", "Run Omarchy update", "", "omarchy launch floating terminal with presentation 'omarchy update'", "shell"),
      item("item", "󰑐", "Restart Lacuna", "Reload this Quickshell surface", "", "quickshell kill -p " + root.lacunaPath + "/shell.qml; setsid " + root.lacunaPath + "/run.sh >/tmp/lacuna-quickshell.log 2>&1 &", "shell"),
      item("header", "", "Session", "", "", "", "session"),
      item("item", "", "System", "Lock, logout, restart, shutdown", "system", "", "session", "primary", "row", false, "session")
    ]
  }
}
