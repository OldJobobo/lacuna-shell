import Quickshell.Io
import QtQuick

Item {
  id: root

  property var queue: []

  function quote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function run(command) {
    if (!command) return

    queue = queue.concat([command])
    drain()
  }

  function drain() {
    if (proc.running || queue.length === 0) return

    var command = queue[0]
    queue = queue.slice(1)

    console.log("lacuna command:", command)
    proc.command = ["setsid", "-f", "bash", "-lc", command + " || notify-send " + quote("Lacuna command failed") + " " + quote(command)]
    proc.running = true
  }

  Process {
    id: proc

    onExited: root.drain()
  }
}
