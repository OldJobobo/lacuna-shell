#!/usr/bin/env bash
set -euo pipefail

default_iface="$(ip route show default 2>/dev/null | awk '{print $5; exit}' || true)"

if [[ -z "$default_iface" ]]; then
  jq -nc --arg text "󰤮" --arg tooltip "<b>Network</b><br/>State: <font color='#d42b5b'>disconnected</font><br/><br/>Click to open Wi-Fi controls" '{text:$text, tooltip:$tooltip, class:"offline"}'
  exit 0
fi

if [[ "$default_iface" == wl* || "$default_iface" == *wifi* ]]; then
  ssid="$(iw dev "$default_iface" link 2>/dev/null | awk -F': ' '/SSID:/ {print $2; exit}')"
  text="󰤨"
  tooltip="<b>Network</b><br/>Type: Wi-Fi<br/>SSID: ${ssid:-unknown}<br/>Interface: ${default_iface}<br/><br/>Click to open Wi-Fi controls"
else
  text="󰀂"
  tooltip="<b>Network</b><br/>Type: Ethernet<br/>Interface: ${default_iface}<br/><br/>Click to open network controls"
fi

jq -nc --arg text "$text" --arg tooltip "$tooltip" '{text:$text, tooltip:$tooltip, class:"online"}'
