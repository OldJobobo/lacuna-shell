import Quickshell.Services.Mpris
import QtQuick

LacunaButton {
  id: root

  property int maxTextLength: 32
  property color moduleAccent: "#88c0d0"
  property bool sweepOnPlaying: false
  property var player: selectPlayer()

  minButtonWidth: 32
  accent: moduleAccent
  text: displayText
  tooltip: rawTooltip
  active: false
  sweepActive: sweepOnPlaying && cssClass === "playing"
  sweepColor: background
  visible: cssClass !== "hidden" && displayText.length > 0

  readonly property string cssClass: player && player.playbackState === MprisPlaybackState.Playing ? "playing" : player && player.playbackState === MprisPlaybackState.Paused ? "paused" : "hidden"
  readonly property string displayText: {
    if (!player || cssClass === "hidden") return ""

    var nextText = clipped(playerLabel(player))
    if (!nextText) return ""

    return (cssClass === "playing" ? " " : " ") + nextText
  }
  readonly property string rawTooltip: {
    if (!player || cssClass === "hidden") return ""

    var state = cssClass === "playing" ? "Playing" : "Paused"
    var stateColor = cssClass === "playing" ? "#8cbfb8" : "#ab9191"
    var identity = player.identity || player.desktopEntry || "Media"
    var label = playerLabel(player) || state

    return "<b>" + htmlEscape(identity) + "</b><br/>State: <font color='" + stateColor + "'>" + state + "</font><br/>Track: " + htmlEscape(label) + "<br/><br/>Left click: play/pause<br/>Right click: next"
  }

  function players() {
    return Mpris.players ? Mpris.players.values : []
  }

  function selectPlayer() {
    var available = players()
    var fallback = null

    for (var i = 0; i < available.length; i++) {
      var candidate = available[i]
      if (!candidate) continue

      if (candidate.playbackState === MprisPlaybackState.Playing) return candidate
      if (!fallback && candidate.playbackState === MprisPlaybackState.Paused) fallback = candidate
    }

    return fallback
  }

  function playerLabel(candidate) {
    if (!candidate) return ""

    var artist = candidate.trackArtist || candidate.trackArtists || ""
    var title = candidate.trackTitle || ""

    if (artist && title) return artist + " - " + title
    if (title) return title
    return candidate.playbackState === MprisPlaybackState.Playing ? "Playing" : "Paused"
  }

  function clipped(value) {
    if (!value) return ""
    if (value.length <= maxTextLength) return value
    return value.slice(0, Math.max(1, maxTextLength - 1)) + "…"
  }

  function htmlEscape(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
  }

  onTriggered: {
    if (!player) return

    if (player.canTogglePlaying) player.togglePlaying()
    else if (player.playbackState === MprisPlaybackState.Playing && player.canPause) player.pause()
    else if (player.canPlay) player.play()
  }

  onSecondaryTriggered: {
    if (player && player.canGoNext) player.next()
  }
}
