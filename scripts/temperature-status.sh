#!/usr/bin/env bash
set -euo pipefail

critical_f=185
warm_f=150
meter_slots=10

read_temp_c() {
  local input

  for input in \
    /sys/class/hwmon/hwmon4/temp1_input \
    /sys/class/hwmon/hwmon4/temp2_input \
    /sys/class/thermal/thermal_zone0/temp
  do
    if [[ -r "$input" ]]; then
      awk '{ printf "%.1f\n", $1 / 1000 }' "$input"
      return 0
    fi
  done

  return 1
}

temp_c="$(read_temp_c)"
temp_f="$(awk -v c="$temp_c" 'BEGIN { printf "%.0f", (c * 9 / 5) + 32 }')"
filled_slots="$(awk -v temp="$temp_f" -v critical="$critical_f" -v slots="$meter_slots" '
  BEGIN {
    value = int((temp / critical) * slots + 0.5)
    if (value < 0) value = 0
    if (value > slots) value = slots
    print value
  }
')"
empty_slots=$((meter_slots - filled_slots))

if (( temp_f >= critical_f )); then
  icon="󱃂"
  status="Hot"
elif (( temp_f >= warm_f )); then
  icon="󰔏"
  status="Warm"
else
  icon="󰔏"
  status="Normal"
fi

text="${temp_f}°F ${icon}"

meter=""
for i in $(seq 1 "$meter_slots"); do
  if (( i <= filled_slots )); then
    if (( i <= 5 )); then
      meter+="<font color='#5f875f'>■</font>"
    elif (( i <= 8 )); then
      meter+="<font color='#ead94d'>■</font>"
    else
      meter+="<font color='#d42b5b'>■</font>"
    fi
  else
    meter+="<font color='#666666'>■</font>"
  fi
done

case "$status" in
  Hot) status_color="#d42b5b" ;;
  Warm) status_color="#ead94d" ;;
  *) status_color="#8cbfb8" ;;
esac

tooltip="<b>CPU Temperature</b><br/>Current: <font color='${status_color}'>${temp_f}°F</font><br/>Threshold: ${critical_f}°F<br/>Status: ${status}<br/>${meter}<br/><br/>Click to open btop"

jq -nc --arg text "$text" --arg tooltip "$tooltip" '{text:$text, tooltip:$tooltip}'
