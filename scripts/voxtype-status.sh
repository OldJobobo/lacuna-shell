#!/usr/bin/env bash
set -euo pipefail

hide() {
  printf '%s\n' '{"text":"","tooltip":"","class":"hidden"}'
  exit 0
}

command -v voxtype >/dev/null 2>&1 || hide

line="$(timeout 1s voxtype status --extended --format json 2>/dev/null | head -n 1 || true)"
[[ -n "$line" ]] || hide

class="$(jq -r '.class // "idle"' <<<"$line" 2>/dev/null || printf 'idle')"
tooltip="$(jq -r '.tooltip // ""' <<<"$line" 2>/dev/null || true)"

case "$class" in
  recording) text="󰍬" ;;
  transcribing) text="󰔟" ;;
  *) hide ;;
esac

jq -nc --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" \
  '{text:$text, tooltip:$tooltip, class:$class}'
