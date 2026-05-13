#!/usr/bin/env bash
set -euo pipefail

if command -v pamixer >/dev/null 2>&1; then
  muted="$(pamixer --get-mute 2>/dev/null || printf false)"
  volume="$(pamixer --get-volume 2>/dev/null || printf 0)"
else
  muted=false
  volume="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{printf "%.0f", $2 * 100}' || printf 0)"
fi

if [[ "$muted" == "true" ]]; then
  icon=""
  class="muted"
  state="Muted"
  state_color="#d42b5b"
elif (( volume < 35 )); then
  icon=""
  class="normal"
  state="Low"
  state_color="#8cbfb8"
elif (( volume < 70 )); then
  icon=""
  class="normal"
  state="Normal"
  state_color="#8cbfb8"
else
  icon=""
  class="normal"
  state="Loud"
  state_color="#e97b3c"
fi

tooltip="<b>Audio</b><br/>Volume: <font color='${state_color}'>${volume}%</font><br/>State: ${state}<br/><br/>Left click: Wiremix<br/>Right click: mute"

jq -nc --arg text "$icon $volume%" --arg tooltip "$tooltip" --arg class "$class" \
  '{text:$text, tooltip:$tooltip, class:$class}'
