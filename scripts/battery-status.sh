#!/usr/bin/env bash
set -euo pipefail

battery_dir="$(find /sys/class/power_supply -maxdepth 1 -type l -name 'BAT*' 2>/dev/null | head -1)"

if [[ -z "${battery_dir:-}" ]]; then
  jq -nc --arg text "" --arg tooltip "<b>Power</b><br/>Source: AC<br/>State: connected" '{text:$text, tooltip:$tooltip, class:"normal"}'
  exit 0
fi

capacity="$(cat "$battery_dir/capacity" 2>/dev/null || printf '')"
status="$(cat "$battery_dir/status" 2>/dev/null || printf 'Unknown')"

[[ "$capacity" =~ ^[0-9]+$ ]] || capacity=0

icons=(󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹)
charging_icons=(󰢜 󰂆 󰂇 󰂈 󰢝 󰂉 󰢞 󰂊 󰂋 󰂅)
index=$(( capacity / 10 ))
(( index > 9 )) && index=9

if [[ "$status" == "Charging" ]]; then
  text="${charging_icons[$index]}"
elif [[ "$status" == "Full" ]]; then
  text="󰂅"
else
  text="${icons[$index]}"
fi

class="normal"
if (( capacity <= 10 )); then
  class="over"
  color="#d42b5b"
elif (( capacity <= 20 )); then
  class="low"
  color="#e97b3c"
else
  color="#8cbfb8"
fi

tooltip="<b>Battery</b><br/>Charge: <font color='${color}'>${capacity}%</font><br/>State: ${status}<br/>Device: $(basename "$battery_dir")"

jq -nc --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" '{text:$text, tooltip:$tooltip, class:$class}'
