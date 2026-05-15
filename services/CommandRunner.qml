import Quickshell.Io
import QtQuick

Item {
  id: root

  property var queue: []
  property string currentCommand: ""
  property string stdoutText: ""
  property string stderrText: ""

  function quote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function failureText() {
    var detail = stderrText.trim()
    if (detail === "") detail = stdoutText.trim()
    if (detail === "") detail = currentCommand

    return detail.length > 220 ? detail.substring(0, 217) + "..." : detail
  }

  function run(command) {
    if (!command) return

    queue = queue.concat([command])
    drain()
  }

  function shouldDetach(command) {
    return command.indexOf("foot ") !== 0 && command.indexOf("xdg-terminal-exec ") !== 0
  }

  function drain() {
    if (proc.running || queue.length === 0) return

    var command = queue[0]
    queue = queue.slice(1)
    currentCommand = command
    stdoutText = ""
    stderrText = ""

    console.log("lacuna command:", command)
    proc.command = shouldDetach(command) ? ["setsid", "-f", "bash", "-lc", command] : ["bash", "-lc", command]
    proc.running = true
  }

  Process {
    id: proc

    stdout: SplitParser {
      onRead: function(data) {
        root.stdoutText += data + "\n"
      }
    }

    stderr: SplitParser {
      onRead: function(data) {
        root.stderrText += data + "\n"
      }
    }

    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0) {
        console.warn("lacuna command failed:", exitCode, root.currentCommand, root.failureText())
        failProc.command = ["notify-send", "Lacuna command failed", root.failureText()]
        failProc.running = true
      }

      root.drain()
    }
  }

  Process {
    id: failProc
  }
}
