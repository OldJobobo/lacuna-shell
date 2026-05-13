#!/usr/bin/env bash
set -euo pipefail

if pgrep -f '^gpu-screen-recorder' >/dev/null; then
  jq -nc --arg text "󰻂" --arg tooltip "<b>Screen Recording</b><br/>State: <font color='#d42b5b'>recording</font><br/><br/>Click to stop recording" '{text:$text, tooltip:$tooltip, class:"active"}'
else
  printf '%s\n' '{"text":"","tooltip":"","class":"hidden"}'
fi
