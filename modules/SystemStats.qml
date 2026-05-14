import QtQuick

Row {
  id: root

  required property var commandRunner
  required property var monitor
  property color foreground: "#d8dee9"
  property color background: "#101315"
  property color diskAccent: "#bf616a"
  property color memoryAccent: "#a3be8c"
  property color cpuAccent: "#8fbcbb"
  property bool compact: false
  property var tooltipHost: null

  spacing: 4
  readonly property string cpuText: monitor.cpuPercent + "% 󰍛"
  readonly property string memText: monitor.memoryPercent + "% "
  readonly property string diskText: monitor.diskText || "-- 󰋊"

  LacunaButton {
    text: root.diskText
    minButtonWidth: 48
    compact: root.compact
    foreground: root.foreground
    background: root.background
    accent: root.foreground
    accentText: false
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

}
