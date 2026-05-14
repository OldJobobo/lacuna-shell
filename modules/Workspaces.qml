import Quickshell.Hyprland
import QtQuick

Row {
  id: root

  property var commandRunner: null
  property color foreground: "#d8dee9"
  property color background: "#101315"
  property color accent: "#88c0d0"
  property color occupiedColor: foreground
  property color emptyColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.42)
  property color urgentColor: "#bf616a"
  property bool compact: false
  property var tooltipHost: null
  property int workspaceSerial: 0

  spacing: 4
  readonly property int activeWorkspace: Hyprland.focusedWorkspace ? Number(Hyprland.focusedWorkspace.id) : 1

  function workspaceFor(id) {
    workspaceSerial

    var workspaces = Hyprland.workspaces ? Hyprland.workspaces.values : []
    for (var i = 0; i < workspaces.length; i++) {
      if (Number(workspaces[i].id) === Number(id)) return workspaces[i]
    }

    return null
  }

  function workspaceWindowCount(workspace) {
    if (!workspace || !workspace.lastIpcObject) return 0
    return Number(workspace.lastIpcObject.windows || 0)
  }

  function workspaceOccupied(id) {
    var workspace = workspaceFor(id)
    return !!workspace && workspaceWindowCount(workspace) > 0
  }

  function workspaceUrgent(id) {
    var workspace = workspaceFor(id)
    return !!workspace && workspace.urgent
  }

  function workspaceColor(id) {
    if (workspaceUrgent(id)) return urgentColor
    if (activeWorkspace === id) return accent
    if (workspaceOccupied(id)) return occupiedColor
    return emptyColor
  }

  function workspaceTooltip(id) {
    var workspace = workspaceFor(id)
    var state = activeWorkspace === id ? "active" : workspaceOccupied(id) ? "occupied" : "empty"
    var windows = workspaceWindowCount(workspace)
    return "Workspace " + id + "\n" + state + (windows > 0 ? "\n" + windows + " window" + (windows === 1 ? "" : "s") : "")
  }

  function switchToWorkspace(workspace) {
    Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.focus({ workspace = " + workspace + " })" : "workspace " + workspace)
  }

  function refreshWorkspaceState() {
    Hyprland.refreshWorkspaces()
    workspaceSerial += 1
  }

  Component.onCompleted: refreshWorkspaceState()

  Timer {
    id: workspaceRefreshTimer
    interval: 80
    repeat: false
    onTriggered: root.refreshWorkspaceState()
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      var name = event.name
      if (name.indexOf("workspace") >= 0 || name === "focusedmon" || name.indexOf("window") >= 0 || name === "urgent") {
        workspaceRefreshTimer.restart()
      }
    }

    function onFocusedWorkspaceChanged() {
      root.workspaceSerial += 1
    }
  }

  Connections {
    target: Hyprland.workspaces

    function onValuesChanged() {
      root.workspaceSerial += 1
    }
  }

  Repeater {
    model: 7

    LacunaButton {
      required property int index
      readonly property int workspaceId: index + 1
      readonly property bool workspaceActive: root.activeWorkspace === workspaceId
      readonly property bool workspaceOccupied: root.workspaceOccupied(workspaceId)
      readonly property bool workspaceUrgent: root.workspaceUrgent(workspaceId)

      text: String(workspaceId)
      minButtonWidth: root.compact ? 24 : 32
      contentHorizontalPadding: 0
      compact: root.compact
      foreground: root.workspaceColor(workspaceId)
      background: root.background
      accent: root.workspaceColor(workspaceId)
      accentText: workspaceOccupied && !workspaceActive
      tooltip: root.workspaceTooltip(workspaceId)
      tooltipHost: root.tooltipHost
      labelHoverPulse: true
      labelHoverScale: root.compact ? 1.28 : 1.35
      active: workspaceActive
      onTriggered: root.switchToWorkspace(workspaceId)
    }
  }
}
