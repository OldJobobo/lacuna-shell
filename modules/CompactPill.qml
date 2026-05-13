import QtQuick

LacunaButton {
  id: root

  required property var stateController
  property color moduleAccent: "#88c0d0"

  minButtonWidth: 32
  accent: moduleAccent
  text: stateController.compact ? "󰘔" : "󰘕"
  tooltip: stateController.compact
    ? "<b>Compact Mode</b><br/>State: <font color='#8cbfb8'>on</font><br/><br/>Click to expand Lacuna"
    : "<b>Compact Mode</b><br/>State: off<br/><br/>Click to compact Lacuna"
  active: stateController.compact

  onTriggered: stateController.toggle()
}
