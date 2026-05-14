import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  readonly property string lacunaPath: Quickshell.env("LACUNA_PATH") || Quickshell.env("PWD")
  property var apps: []
  property bool ready: false

  function reload() {
    if (loadProc.running) return
    loadProc.output = ""
    loadProc.command = [root.lacunaPath + "/scripts/desktop-app-catalog.py"]
    loadProc.running = true
  }

  function appsFor(category) {
    if (!category || category === "all") return apps

    var filtered = []
    for (var i = 0; i < apps.length; i++) {
      if (apps[i].category === category) filtered.push(apps[i])
    }
    return filtered
  }

  function countFor(category) {
    return appsFor(category).length
  }

  Component.onCompleted: reload()

  Process {
    id: loadProc
    property string output: ""

    stdout: SplitParser {
      onRead: function(data) {
        loadProc.output += data
      }
    }

    onExited: {
      try {
        root.apps = JSON.parse(loadProc.output || "[]")
      } catch (error) {
        console.warn("lacuna app catalog parse failed:", error)
        root.apps = []
      }
      root.ready = true
    }
  }
}
