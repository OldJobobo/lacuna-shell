import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  readonly property string colorsPath: Quickshell.env("XDG_CONFIG_HOME") ? Quickshell.env("XDG_CONFIG_HOME") + "/omarchy/current/theme/colors.toml" : Quickshell.env("HOME") + "/.config/omarchy/current/theme/colors.toml"
  readonly property string themeNamePath: Quickshell.env("XDG_CONFIG_HOME") ? Quickshell.env("XDG_CONFIG_HOME") + "/omarchy/current/theme.name" : Quickshell.env("HOME") + "/.config/omarchy/current/theme.name"
  property var palette: ({})
  property string themeName: ""
  property string themeTitle: formatTitle(themeName)
  property color foreground: color("foreground")
  property color background: color("background")
  property color panel: withAlpha(background, 0.84)
  property color voidColor: withAlpha(background, 0.18)
  property color border: withAlpha(foreground, 0.18)
  property color muted: withAlpha(foreground, 0.48)
  property color soft: withAlpha(foreground, 0.78)

  function withAlpha(value, alpha) {
    return Qt.rgba(value.r, value.g, value.b, alpha)
  }

  function color(name) {
    return rawColor(name)
  }

  function rawColor(name) {
    return palette[name] || fallback(name)
  }

  function fallback(name) {
    var fallbacks = {
      foreground: "#d8dee9",
      background: "#101315",
      color4: "#81a1c1",
      color5: "#b48ead",
      color6: "#88c0d0",
      color7: "#e5e9f0",
      color9: "#bf616a",
      color10: "#a3be8c",
      color11: "#ebcb8b",
      color12: "#81a1c1",
      color13: "#b48ead",
      color14: "#8fbcbb",
      color15: "#eceff4"
    }

    return fallbacks[name] || "#d8dee9"
  }

  function load(raw) {
    var next = {}
    var lines = String(raw || "").split(/\n/)

    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?([^"'\s]+)["']?/)
      if (match) next[match[1]] = match[2].trim()
    }

    palette = next
  }

  function loadThemeName(raw) {
    themeName = String(raw || "").trim()
  }

  function formatTitle(value) {
    return String(value || "")
      .replace(/[-_]/g, " ")
      .toLowerCase()
      .replace(/\b\w/g, function(letter) { return letter.toUpperCase() })
  }

  FileView {
    id: themeFile

    path: root.colorsPath
    watchChanges: true
    printErrors: false
    onLoaded: root.load(text())
    onFileChanged: {
      reload()
    }
    onLoadFailed: themeRetry.restart()
  }

  FileView {
    id: themeNameFile

    path: root.themeNamePath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadThemeName(text())
    onFileChanged: reload()
    onLoadFailed: themeRetry.restart()
  }

  Timer {
    id: themeRetry

    interval: 500
    repeat: false
    onTriggered: {
      themeFile.reload()
      themeNameFile.reload()
    }
  }
}
