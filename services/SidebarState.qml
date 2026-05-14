import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/lacuna"
  readonly property string stateFile: stateDir + "/sidebar.state"
  property bool exclusive: true
  property bool collapsed: false

  function load() {
    if (!loadProc.running) {
      loadProc.output = ""
      loadProc.running = true
    }
  }

  function toggle() {
    exclusive = !exclusive
    save()
  }

  function toggleCollapsed() {
    collapsed = !collapsed
    save()
  }

  function expand() {
    collapsed = false
    save()
  }

  function save() {
    saveProc.command = ["bash", "-lc", "mkdir -p " + quote(stateDir) + "; printf '%s\\n%s\\n' " + quote(exclusive ? "exclusive" : "overlay") + " " + quote(collapsed ? "rail" : "full") + " > " + quote(stateFile)]
    saveProc.running = true
  }

  function quote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  Component.onCompleted: load()

  Process {
    id: loadProc
    property string output: ""
    command: ["bash", "-lc", "cat " + root.quote(root.stateFile) + " 2>/dev/null || printf 'exclusive\\nfull\\n'"]

    stdout: SplitParser {
      onRead: function(data) {
        loadProc.output += data
      }
    }

    onExited: {
      var output = loadProc.output.trim()
      root.exclusive = output.indexOf("overlay") === -1
      root.collapsed = output.indexOf("rail") !== -1
    }
  }

  Process {
    id: saveProc
  }
}
