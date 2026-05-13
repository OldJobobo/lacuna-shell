import Quickshell.Services.Pipewire
import QtQuick

LacunaButton {
  id: root

  property var commandRunner: null
  property color moduleAccent: "#88c0d0"
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var audio: sink ? sink.audio : null
  readonly property int volumePercent: audio ? Math.round(audio.volume * 100) : 0
  readonly property bool muted: audio ? audio.muted : false
  readonly property string state: muted ? "Muted" : volumePercent < 35 ? "Low" : volumePercent < 70 ? "Normal" : "Loud"
  readonly property string stateColor: muted ? "#d42b5b" : volumePercent >= 70 ? "#e97b3c" : "#8cbfb8"
  readonly property string icon: muted ? "" : volumePercent < 35 ? "" : volumePercent < 70 ? "" : ""

  minButtonWidth: 32
  accent: moduleAccent
  text: audio ? icon + " " + volumePercent + "%" : ""
  tooltip: audio ? "<b>Audio</b><br/>Volume: <font color='" + stateColor + "'>" + volumePercent + "%</font><br/>State: " + state + "<br/><br/>Left click: Wiremix<br/>Right click: mute" : ""
  visible: audio !== null && text.length > 0

  onTriggered: {
    if (commandRunner) commandRunner.run("hyprctl dispatch 'hl.dsp.exec_cmd([[omarchy launch audio]])'")
  }

  onSecondaryTriggered: {
    if (audio) audio.muted = !audio.muted
  }

  onScrolled: function(delta) {
    if (!audio) return

    var next = audio.volume + (delta > 0 ? 0.05 : -0.05)
    audio.volume = Math.max(0, Math.min(1.5, next))
  }

  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }
}
