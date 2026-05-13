#!/usr/bin/env bash
set -euo pipefail

state_file="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/lacuna/compact.state"
state="$(cat "$state_file" 2>/dev/null || printf normal)"
state="${state//[[:space:]]/}"

if [[ "$state" == "compact" ]]; then
  jq -nc --arg text "󰘔" --arg tooltip "<b>Compact Mode</b><br/>State: <font color='#8cbfb8'>on</font><br/><br/>Click to expand Lacuna" '{text:$text, tooltip:$tooltip, class:"active"}'
else
  jq -nc --arg text "󰘕" --arg tooltip "<b>Compact Mode</b><br/>State: off<br/><br/>Click to compact Lacuna" '{text:$text, tooltip:$tooltip, class:"normal"}'
fi
