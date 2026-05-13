#!/usr/bin/env bash
set -euo pipefail

day_num="$(date +%-d)"
case "$day_num" in
  1|21|31) suffix="st" ;;
  2|22) suffix="nd" ;;
  3|23) suffix="rd" ;;
  *) suffix="th" ;;
esac

if [[ "${1:-}" == "--short" ]]; then
  bar_text="$(date +"%-I:%M")"
else
  bar_text="$(printf '%s %s%s %s' "$(date +%a)" "$day_num" "$suffix" "$(date +"%I:%M %p")")"
fi

month_header="$(date +"%B %Y")"
calendar_lines="$(cal)"
weekday_line="$(sed -n '2p' <<<"$calendar_lines")"
date_lines="$(sed -n '3,$p' <<<"$calendar_lines")"
marked_dates="$(sed -E "s/(^|[[:space:]])(${day_num})([[:space:]]|$)/\1@@TODAY@@\3/g" <<<"$date_lines")"
weekday_line="$(sed 's/ /\&nbsp;/g' <<<"$weekday_line")"
highlighted_dates="$(sed 's/ /\&nbsp;/g' <<<"$marked_dates")"
highlighted_dates="${highlighted_dates//@@TODAY@@/<font color='#c0daf6'><b>${day_num}</b></font>}"
highlighted_dates="${highlighted_dates//$'\n'/<br/>}"

tooltip="<b><font color='#c9a554'>${month_header}</font></b><br/><br/><font color='#ab9191'>${weekday_line}</font><br/>${highlighted_dates}"

jq -nc --arg text "$bar_text" --arg tooltip "$tooltip" '{text:$text, tooltip:$tooltip}'
