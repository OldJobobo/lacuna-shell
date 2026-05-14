#!/usr/bin/env bash
set -euo pipefail

iface="$(iw dev 2>/dev/null | awk '/Interface/ {print $2; exit}' || true)"

if [[ -z "${iface:-}" ]]; then
  printf '%s\n' '{"text":"","tooltip":"","class":"hidden"}'
  exit 0
fi

ssid="$(iw dev "$iface" link 2>/dev/null | awk -F': ' '/SSID:/ {print $2; exit}')"

if [[ -n "${ssid:-}" ]]; then
  jq -nc --arg text "󰤨" --arg tooltip "<b>Wi-Fi</b><br/>State: <font color='#8cbfb8'>connected</font><br/>SSID: ${ssid}<br/>Interface: ${iface}<br/><br/>Click to open impala" '{text:$text, tooltip:$tooltip, class:"online"}'
else
  jq -nc --arg text "󰤮" --arg tooltip "<b>Wi-Fi</b><br/>State: <font color='#d42b5b'>disconnected</font><br/>Interface: ${iface}<br/><br/>Click to open impala" '{text:$text, tooltip:$tooltip, class:"offline"}'
fi
