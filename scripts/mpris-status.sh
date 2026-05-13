#!/usr/bin/env bash
set -euo pipefail

hide() {
  printf '%s\n' '{"text":"","tooltip":"","class":"hidden"}'
  exit 0
}

command -v playerctl >/dev/null 2>&1 || hide

status="$(playerctl status 2>/dev/null || true)"
[[ -n "$status" ]] || hide
[[ "$status" != "Stopped" ]] || hide

artist="$(playerctl metadata artist 2>/dev/null || true)"
title="$(playerctl metadata title 2>/dev/null || true)"
player="$(playerctl metadata --format '{{playerName}}' 2>/dev/null || true)"

case "$status" in
  Playing) icon=""; class="playing"; status_color="#8cbfb8" ;;
  Paused) icon=""; class="paused"; status_color="#ab9191" ;;
  *) hide ;;
esac

if [[ -n "$artist" && -n "$title" ]]; then
  label="$artist - $title"
elif [[ -n "$title" ]]; then
  label="$title"
else
  label="$status"
fi

tooltip="<b>${player:-Media}</b><br/>State: <font color='${status_color}'>${status}</font><br/>Track: ${label}<br/><br/>Left click: play/pause<br/>Right click: next"
jq -nc --arg text "$icon $label" --arg tooltip "$tooltip" --arg class "$class" \
  '{text:$text, tooltip:$tooltip, class:$class}'
