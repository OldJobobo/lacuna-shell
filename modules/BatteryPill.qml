import Quickshell.Services.UPower
import QtQuick

LacunaButton {
  id: root

  property var commandRunner: null
  property color moduleAccent: "#88c0d0"
  property color alertAccent: moduleAccent
  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: battery && battery.ready && battery.isPresent && battery.percentage > 0
  readonly property int percentage: hasBattery ? Math.round(battery.percentage) : 0
  readonly property string stateText: hasBattery ? UPowerDeviceState.toString(battery.state) : "connected"
  readonly property string cssClass: hasBattery && percentage <= 10 ? "over" : hasBattery && percentage <= 20 ? "low" : "normal"
  readonly property string statusColor: cssClass === "over" ? "#d42b5b" : cssClass === "low" ? "#e97b3c" : "#8cbfb8"

  minButtonWidth: 32
  accent: cssClass === "low" || cssClass === "over" ? alertAccent : moduleAccent
  text: hasBattery ? batteryIcon() : ""
  tooltip: hasBattery
    ? "<b>Battery</b><br/>Charge: <font color='" + statusColor + "'>" + percentage + "%</font><br/>State: " + stateText + "<br/>Device: " + (battery.model || battery.nativePath || "Battery")
    : "<b>Power</b><br/>Source: AC<br/>State: connected"

  onTriggered: {
    if (commandRunner) commandRunner.run("omarchy menu power")
  }

  function batteryIcon() {
    var index = Math.max(0, Math.min(9, Math.floor(percentage / 10)))
    var icons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    var chargingIcons = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]

    if (battery.state === UPowerDeviceState.Charging) return chargingIcons[index]
    if (battery.state === UPowerDeviceState.FullyCharged) return "󰂅"
    return icons[index]
  }
}
