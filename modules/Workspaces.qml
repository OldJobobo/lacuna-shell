import Quickshell.Io
import QtQuick

Row {
  id: root

  required property var commandRunner
  property color foreground: "#d8dee9"
  property color background: "#101315"
  property color accent: "#88c0d0"
  property bool compact: false
  property var tooltipHost: null

  spacing: 4
  property int activeWorkspace: 1

  function switchToWorkspace(workspace) {
    root.activeWorkspace = workspace
    if (switchProc.running) return

    switchProc.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + workspace + " })"]
    switchProc.running = true
  }

  Repeater {
    model: 7

    LacunaButton {
      required property int index

      text: String(index + 1)
      minButtonWidth: root.compact ? 24 : 32
      compact: root.compact
      foreground: root.foreground
      background: root.background
      accent: root.accent
      accentText: false
      labelHoverPulse: true
      labelHoverScale: root.compact ? 1.28 : 1.35
      active: root.activeWorkspace === index + 1
      onTriggered: root.switchToWorkspace(index + 1)
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!activeProc.running) {
        activeProc.output = ""
        activeProc.running = true
      }
    }
  }

  Process {
    id: activeProc
    property string output: ""
    command: ["bash", "-lc", "hyprctl monitors -j 2>/dev/null"]

    stdout: SplitParser {
      onRead: function(data) {
        activeProc.output += data
      }
    }

    onExited: {
      try {
        var monitors = JSON.parse(activeProc.output || "[]")
        for (var i = 0; i < monitors.length; i++) {
          if (monitors[i].focused && monitors[i].activeWorkspace) {
            root.activeWorkspace = Number(monitors[i].activeWorkspace.id || 1)
            return
          }
        }
      } catch (e) {}
    }
  }

  Process {
    id: switchProc
  }
}
