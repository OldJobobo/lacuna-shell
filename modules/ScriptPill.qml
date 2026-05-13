import Quickshell
import Quickshell.Io
import QtQuick

LacunaButton {
  id: root

  property string script: ""
  property string lacunaPath: Quickshell.env("LACUNA_PATH") || Quickshell.env("PWD")
  property string scriptPath: lacunaPath + "/" + script
  property int interval: 30000
  property int maxTextLength: 32
  property string icon: ""
  property string image: ""
  property color moduleAccent: "#88c0d0"
  property color alertAccent: moduleAccent
  property bool wide: false
  property bool sweepOnPlaying: false
  property string cssClass: ""
  property string rawTooltip: ""

  minButtonWidth: wide ? 120 : 32
  accent: cssClass === "alert" || cssClass === "low" || cssClass === "over" ? alertAccent : moduleAccent
  leadingImageSource: image ? lacunaPath + "/" + image : ""
  text: displayText
  tooltip: rawTooltip
  active: cssClass === "alert" || cssClass === "active" || cssClass === "recording" || cssClass === "transcribing"
  sweepActive: sweepOnPlaying && cssClass === "playing"
  sweepColor: background
  visible: cssClass !== "hidden" && displayText.length > 0

  property string displayText: ""

  function clipped(value) {
    if (!value) return ""
    if (value.length <= maxTextLength) return value
    return value.slice(0, Math.max(1, maxTextLength - 1)) + "…"
  }

  function refresh() {
    if (!script || proc.running) return
    proc.output = ""
    proc.command = ["bash", "-lc", scriptPath]
    proc.running = true
  }

  Timer {
    interval: root.interval
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: proc
    property string output: ""

    stdout: SplitParser {
      onRead: function(data) {
        proc.output += data
      }
    }

    onExited: {
      try {
        var payload = JSON.parse(proc.output || "{}")
        var nextText = root.clipped(payload.text || "")
        root.displayText = root.icon && nextText ? root.icon + " " + nextText : nextText
        root.rawTooltip = payload.tooltip || ""
        root.cssClass = payload.class || ""
      } catch (e) {
        root.displayText = ""
        root.rawTooltip = ""
        root.cssClass = "hidden"
      }
    }
  }
}
