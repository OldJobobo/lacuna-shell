#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
current_background_link="$config_home/omarchy/current/background"

format_title() {
  local filename="$1"
  local name="${filename##*/}"

  name="$(sed -E 's/^[0-9]+//; s/^-//; s/\.[^.]+$//; s/-/ /g' <<<"$name")"

  sed 's/.*/\L&/; s/\b\([a-z]\)/\U\1/g' <<<"$name"
}

if [[ -L "$current_background_link" ]]; then
  background_path="$(readlink -f "$current_background_link" 2>/dev/null || true)"
else
  background_path=""
fi

if [[ -n "$background_path" && -f "$background_path" ]]; then
  wallpaper_title="$(format_title "$(basename "$background_path")")"
  tooltip="<b>${wallpaper_title}</b><br/>Current wallpaper<br/><br/><font color='#ab9191'>${background_path}</font><br/><br/>Left click: picker<br/>Right click: next"
else
  wallpaper_title="No Wallpaper"
  tooltip="<b>No Wallpaper</b><br/>No active Omarchy background symlink was found."
fi

jq -nc --arg text " $wallpaper_title" --arg tooltip "$tooltip" '{text:$text, tooltip:$tooltip}'
