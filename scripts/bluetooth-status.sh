#!/usr/bin/env bash
set -euo pipefail

if ! rfkill list bluetooth >/dev/null 2>&1; then
  printf '%s\n' '{"text":"","tooltip":"","class":"hidden"}'
  exit 0
fi

if rfkill list bluetooth | grep -q 'Soft blocked: yes'; then
  jq -nc --arg text "󰂲" --arg tooltip "<b>Bluetooth</b><br/>State: <font color='#d42b5b'>off</font><br/><br/>Click to open bluetui" '{text:$text, tooltip:$tooltip, class:"off"}'
else
  jq -nc --arg text "" --arg tooltip "<b>Bluetooth</b><br/>State: <font color='#8cbfb8'>on</font><br/><br/>Click to open bluetui" '{text:$text, tooltip:$tooltip, class:"on"}'
fi
