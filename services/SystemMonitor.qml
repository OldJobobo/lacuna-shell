import Quickshell.Io
import QtQuick

Item {
  id: root

  property int cpuPercent: 0
  property int memoryPercent: 0
  property string diskText: ""
  property int temperatureF: 0
  property bool temperatureAvailable: false

  property real previousCpuTotal: 0
  property real previousCpuIdle: 0
  property int tempPathIndex: 0
  readonly property list<string> temperaturePaths: [
    "/sys/class/hwmon/hwmon4/temp1_input",
    "/sys/class/hwmon/hwmon4/temp2_input",
    "/sys/class/thermal/thermal_zone0/temp"
  ]

  function refresh() {
    procStat.reload()
    memInfo.reload()
    tempInput.reload()

    if (!diskProc.running) {
      diskProc.output = ""
      diskProc.running = true
    }
  }

  function parseCpu(raw) {
    var fields = String(raw || "").split(/\n/)[0].trim().split(/\s+/)
    if (fields.length < 8 || fields[0] !== "cpu") return

    var user = Number(fields[1] || 0)
    var nice = Number(fields[2] || 0)
    var system = Number(fields[3] || 0)
    var idle = Number(fields[4] || 0)
    var iowait = Number(fields[5] || 0)
    var irq = Number(fields[6] || 0)
    var softirq = Number(fields[7] || 0)
    var steal = Number(fields[8] || 0)
    var total = user + nice + system + idle + iowait + irq + softirq + steal
    var idleAll = idle + iowait

    if (previousCpuTotal > 0) {
      var totalDelta = total - previousCpuTotal
      var idleDelta = idleAll - previousCpuIdle
      if (totalDelta > 0) {
        cpuPercent = Math.max(0, Math.min(100, Math.round((1 - idleDelta / totalDelta) * 100)))
      }
    }

    previousCpuTotal = total
    previousCpuIdle = idleAll
  }

  function parseMemory(raw) {
    var lines = String(raw || "").split(/\n/)
    var total = 0
    var available = 0

    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].trim().split(/\s+/)
      if (parts[0] === "MemTotal:") total = Number(parts[1] || 0)
      else if (parts[0] === "MemAvailable:") available = Number(parts[1] || 0)
    }

    if (total > 0) memoryPercent = Math.max(0, Math.min(100, Math.round((1 - available / total) * 100)))
  }

  function parseTemperature(raw) {
    var milliC = Number(String(raw || "").trim())
    if (!isFinite(milliC) || milliC <= 0) {
      temperatureAvailable = false
      return
    }

    temperatureF = Math.round((milliC / 1000 * 9 / 5) + 32)
    temperatureAvailable = true
  }

  Component.onCompleted: refresh()

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  FileView {
    id: procStat
    path: "/proc/stat"
    printErrors: false
    onLoaded: root.parseCpu(text())
  }

  FileView {
    id: memInfo
    path: "/proc/meminfo"
    printErrors: false
    onLoaded: root.parseMemory(text())
  }

  FileView {
    id: tempInput
    path: root.temperaturePaths[Math.min(root.tempPathIndex, root.temperaturePaths.length - 1)]
    printErrors: false
    onLoaded: root.parseTemperature(text())
    onLoadFailed: {
      if (root.tempPathIndex < root.temperaturePaths.length - 1) {
        root.tempPathIndex += 1
        reload()
      } else {
        root.temperatureAvailable = false
      }
    }
  }

  Process {
    id: diskProc
    property string output: ""
    command: ["df", "-P", "/"]

    stdout: SplitParser {
      onRead: function(data) {
        diskProc.output += data
      }
    }

    onExited: {
      var lines = diskProc.output.trim().split(/\n/)
      if (lines.length < 2) return

      var fields = lines[1].trim().split(/\s+/)
      if (fields.length >= 5) root.diskText = fields[4] + " 󰋊"
    }
  }
}
