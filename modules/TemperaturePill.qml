import QtQuick

LacunaButton {
  id: root

  required property var monitor
  property color moduleAccent: "#88c0d0"
  property int maxTextLength: 32
  readonly property int criticalF: 185
  readonly property int warmF: 150
  readonly property int meterSlots: 10
  readonly property string status: monitor.temperatureF >= criticalF ? "Hot" : monitor.temperatureF >= warmF ? "Warm" : "Normal"
  readonly property string statusColor: status === "Hot" ? "#d42b5b" : status === "Warm" ? "#ead94d" : "#8cbfb8"

  minButtonWidth: 32
  accent: moduleAccent
  text: monitor.temperatureAvailable ? clipped(monitor.temperatureF + "°F " + (status === "Hot" ? "󱃂" : "󰔏")) : ""
  tooltip: monitor.temperatureAvailable
    ? "<b>CPU Temperature</b><br/>Current: <font color='" + statusColor + "'>" + monitor.temperatureF + "°F</font><br/>Threshold: " + criticalF + "°F<br/>Status: " + status + "<br/>" + meter() + "<br/><br/>Click to open btop"
    : ""
  visible: text.length > 0

  function clipped(value) {
    if (!value) return ""
    if (value.length <= maxTextLength) return value
    return value.slice(0, Math.max(1, maxTextLength - 1)) + "…"
  }

  function meter() {
    var filled = Math.max(0, Math.min(meterSlots, Math.round(monitor.temperatureF / criticalF * meterSlots)))
    var output = ""

    for (var i = 1; i <= meterSlots; i++) {
      if (i > filled) output += "<font color='#666666'>■</font>"
      else if (i <= 5) output += "<font color='#5f875f'>■</font>"
      else if (i <= 8) output += "<font color='#ead94d'>■</font>"
      else output += "<font color='#d42b5b'>■</font>"
    }

    return output
  }
}
