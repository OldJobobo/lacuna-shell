#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
theme_name_file="$config_home/omarchy/current/theme.name"
colors_toml="$config_home/omarchy/current/theme/colors.toml"

theme_name="$(<"$theme_name_file")"
theme_title="$(sed 's/[-_]/ /g; s/.*/\L&/; s/\b\([a-z]\)/\U\1/g' <<<"$theme_name")"

declare -a colors=()
for i in $(seq 0 15); do
  value="$(sed -nE "s/^color${i}[[:space:]]*=[[:space:]]*\"([^\"]+)\"/\1/p" "$colors_toml" | head -n1)"
  colors+=("${value:-#777777}")
done

swatch_row_one=""
swatch_row_two=""
for i in $(seq 0 7); do
  swatch_row_one+="<font color='${colors[$i]}' size='+2'>■</font> "
done
for i in $(seq 8 15); do
  swatch_row_two+="<font color='${colors[$i]}' size='+2'>■</font> "
done

tooltip="$(printf "<b>%s</b><br/>Current Omarchy theme<br/><br/><b>Palette</b><br/>%s<br/>%s<br/><br/><font color='%s'>■</font> base00  <font color='%s'>■</font> base07  <font color='%s'>■</font> accent" \
  "$theme_title" \
  "$swatch_row_one" \
  "$swatch_row_two" \
  "${colors[0]}" \
  "${colors[7]}" \
  "${colors[11]}")"

jq -nc --arg text "󰸉 $theme_title" --arg tooltip "$tooltip" '{text:$text, tooltip:$tooltip}'
