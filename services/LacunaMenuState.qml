import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/lacuna"
  readonly property string stateFile: stateDir + "/menu.state"
  property bool open: false
  property var stack: ["main"]
  readonly property string currentView: stack.length > 0 ? stack[stack.length - 1] : "main"

  function load() {
    if (!loadProc.running) {
      loadProc.output = ""
      loadProc.running = true
    }
  }

  function save() {
    saveProc.command = ["bash", "-lc", saveCommand()]
    saveProc.running = true
  }

  function saveCommand() {
    var lines = [open ? "open" : "closed"].concat(stack)
    var args = []
    for (var i = 0; i < lines.length; i++) {
      args.push(quote(lines[i]))
    }

    return "mkdir -p " + quote(stateDir) + "; printf '%s\\n' " + args.join(" ") + " > " + quote(stateFile)
  }

  function quote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function show() {
    open = true
    save()
  }

  function close() {
    open = false
    stack = ["main"]
    save()
  }

  function toggle() {
    if (open) close()
    else show()
  }

  function push(view) {
    if (!view) return
    stack = stack.concat([view])
    save()
  }

  function back() {
    if (stack.length <= 1) {
      close()
      return
    }

    stack = stack.slice(0, stack.length - 1)
    save()
  }

  Component.onCompleted: load()

  Process {
    id: loadProc
    property string output: ""
    command: ["bash", "-lc", "cat " + root.quote(root.stateFile) + " 2>/dev/null || printf 'closed\\nmain\\n'"]

    stdout: SplitParser {
      onRead: function(data) {
        loadProc.output += data + "\n"
      }
    }

    onExited: {
      var lines = loadProc.output.trim().split(/\r?\n/)
      var restoredStack = lines.slice(1).filter(function(view) {
        return view !== ""
      })

      root.stack = restoredStack.length > 0 ? restoredStack : ["main"]
      root.open = lines.length > 0 && lines[0] === "open"
    }
  }

  Process {
    id: saveProc
  }
}
