#!/usr/bin/env bash
set -euo pipefail

command -v powerprofilesctl >/dev/null 2>&1 || {
  printf '%s\n' '{"text":"","tooltip":"","class":"hidden"}'
  exit 0
}

profile="$(powerprofilesctl get 2>/dev/null || true)"

case "$profile" in
  performance)
    text="󰓅"
    label="Performance"
    color="#e97b3c"
    ;;
  balanced)
    text="󰾅"
    label="Balanced"
    color="#8cbfb8"
    ;;
  power-saver)
    text=""
    label="Power saver"
    color="#5f875f"
    ;;
  *)
    text="󰾅"
    label="${profile:-Unknown}"
    color="#ab9191"
    ;;
esac

tooltip="<b>Power Profile</b><br/>Mode: <font color='${color}'>${label}</font><br/><br/>Click to open power menu"

jq -nc --arg text "$text" --arg tooltip "$tooltip" '{text:$text, tooltip:$tooltip, class:"normal"}'
