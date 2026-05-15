import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/lacuna"
  readonly property string stateFile: stateDir + "/compact.state"
  property bool compact: false

  function load() {
    if (!loadProc.running) {
      loadProc.output = ""
      loadProc.running = true
    }
  }

  function toggle() {
    compact = !compact
    saveProc.command = ["bash", "-lc", "mkdir -p " + quote(stateDir) + "; echo " + quote(compact ? "compact" : "normal") + " > " + quote(stateFile)]
    saveProc.running = true
  }

  function quote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  Component.onCompleted: load()

  Process {
    id: loadProc
    property string output: ""
    command: ["bash", "-lc", "cat " + root.quote(root.stateFile) + " 2>/dev/null || echo normal"]

    stdout: SplitParser {
      onRead: function(data) {
        loadProc.output += data
      }
    }

    onExited: root.compact = loadProc.output.trim() === "compact"
  }

  Process {
    id: saveProc
  }
}
