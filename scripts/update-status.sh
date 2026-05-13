#!/usr/bin/env bash
set -euo pipefail

hide() {
  printf '%s\n' '{"text":"","tooltip":"","class":"hidden"}'
  exit 0
}

output="$(omarchy update available 2>/dev/null || true)"
[[ "$output" == *"update available"* ]] || hide

tooltip="<b>System Update</b><br/><font color='#e97b3c'>${output}</font><br/><br/>Click to run Omarchy update"

jq -nc --arg text "" --arg tooltip "$tooltip" '{text:$text, tooltip:$tooltip, class:"active"}'
