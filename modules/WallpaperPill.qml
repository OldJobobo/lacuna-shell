import Quickshell
import Quickshell.Io
import QtQuick

LacunaButton {
  id: root

  property color moduleAccent: "#88c0d0"
  property int maxTextLength: 32
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
  readonly property string backgroundLink: configHome + "/omarchy/current/background"
  property string backgroundPath: ""
  property string wallpaperTitle: backgroundPath ? formatTitle(backgroundPath) : "No Wallpaper"

  minButtonWidth: 32
  accent: moduleAccent
  text: clipped(" " + wallpaperTitle)
  tooltip: backgroundPath
    ? "<b>" + wallpaperTitle + "</b><br/>Current wallpaper<br/><br/><font color='#ab9191'>" + backgroundPath + "</font><br/><br/>Left click: picker<br/>Right click: next"
    : "<b>No Wallpaper</b><br/>No active Omarchy background symlink was found."
  visible: text.length > 0

  function refresh() {
    if (!readlinkProc.running) {
      readlinkProc.output = ""
      readlinkProc.running = true
    }
  }

  function clipped(value) {
    if (!value) return ""
    if (value.length <= maxTextLength) return value
    return value.slice(0, Math.max(1, maxTextLength - 1)) + "…"
  }

  function formatTitle(path) {
    var filename = String(path || "").split("/").pop()
    var name = filename
      .replace(/^[0-9]+/, "")
      .replace(/^-/, "")
      .replace(/\.[^.]+$/, "")
      .replace(/-/g, " ")
      .toLowerCase()

    return name.replace(/\b\w/g, function(letter) { return letter.toUpperCase() })
  }

  Component.onCompleted: refresh()

  FileView {
    path: root.backgroundLink
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
    onLoadFailed: root.backgroundPath = ""
  }

  Process {
    id: readlinkProc
    property string output: ""
    command: ["readlink", "-f", root.backgroundLink]

    stdout: SplitParser {
      onRead: function(data) {
        readlinkProc.output += data
      }
    }

    onExited: root.backgroundPath = readlinkProc.output.trim()
  }
}
