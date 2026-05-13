import Quickshell.Io
import QtQuick

Row {
  id: root

  required property var commandRunner
  property color foreground: "#d8dee9"
  property color background: "#101315"
  property color diskAccent: "#bf616a"
  property color memoryAccent: "#a3be8c"
  property color cpuAccent: "#8fbcbb"
  property bool compact: false
  property var tooltipHost: null

  spacing: 4
  property string cpuText: ""
  property string memText: ""
  property string diskText: ""

  LacunaButton {
    text: root.diskText
    minButtonWidth: 48
    compact: root.compact
    foreground: root.foreground
    background: root.background
    accent: root.diskAccent
    tooltip: "Disk usage\n" + root.diskText
    tooltipHost: root.tooltipHost
    onTriggered: root.commandRunner.run("omarchy launch or focus tui btop")
  }

  LacunaButton {
    text: root.memText
    minButtonWidth: 48
    compact: root.compact
    foreground: root.foreground
    background: root.background
    accent: root.memoryAccent
    tooltip: "Memory usage\n" + root.memText
    tooltipHost: root.tooltipHost
    onTriggered: root.commandRunner.run("omarchy launch or focus tui btop")
  }

  LacunaButton {
    text: root.cpuText
    minButtonWidth: 48
    compact: root.compact
    foreground: root.foreground
    background: root.background
    accent: root.cpuAccent
    tooltip: "CPU usage\n" + root.cpuText
    tooltipHost: root.tooltipHost
    onTriggered: root.commandRunner.run("omarchy launch or focus tui btop")
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!statsProc.running) {
        statsProc.output = ""
        statsProc.running = true
      }
    }
  }

  Process {
    id: statsProc
    property string output: ""
    command: ["bash", "-lc", "cpu=$(awk 'NR==1 {print int(100-($5*100/($2+$3+$4+$5+$6+$7+$8)))}' /proc/stat); mem=$(free | awk '/Mem:/ {print int($3/$2*100)}'); disk=$(df / | awk 'NR==2 {print $5}'); printf '{\"cpu\":\"%s%% 󰍛\",\"mem\":\"%s%% \",\"disk\":\"%s 󰋊\"}\\n' \"$cpu\" \"$mem\" \"$disk\""]

    stdout: SplitParser {
      onRead: function(data) {
        statsProc.output += data
      }
    }

    onExited: {
      try {
        var payload = JSON.parse(statsProc.output || "{}")
        root.cpuText = payload.cpu || ""
        root.memText = payload.mem || ""
        root.diskText = payload.disk || ""
      } catch (e) {}
    }
  }
}
