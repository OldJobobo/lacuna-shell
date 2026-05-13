#!/usr/bin/env bash
set -euo pipefail

if pgrep -x hypridle >/dev/null; then
  printf '%s\n' '{"text":"","tooltip":"","class":"hidden"}'
else
  jq -nc --arg text "󱫖" --arg tooltip "<b>Idle Lock</b><br/>State: <font color='#e97b3c'>disabled</font><br/><br/>Click to re-enable idle locking" '{text:$text, tooltip:$tooltip, class:"active"}'
fi
