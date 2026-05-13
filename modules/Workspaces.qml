import Quickshell.Hyprland
import QtQuick

Row {
  id: root

  property var commandRunner: null
  property color foreground: "#d8dee9"
  property color background: "#101315"
  property color accent: "#88c0d0"
  property bool compact: false
  property var tooltipHost: null

  spacing: 4
  readonly property int activeWorkspace: Hyprland.focusedWorkspace ? Number(Hyprland.focusedWorkspace.id) : 1

  function switchToWorkspace(workspace) {
    Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.focus({ workspace = " + workspace + " })" : "workspace " + workspace)
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
}
