#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
location_config="${script_dir}/weather-location.conf"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/lacuna"
cache_file="${cache_dir}/weather-location.cache"

# Defaults match the original omabar-v2 weather setup.
location_query="Duvall, WA"
lat="47.7423"
lon="-121.9857"
default_lat="${lat}"
default_lon="${lon}"
tz="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
forecast_url=""

if [[ -z "${tz}" ]]; then
  tz="America/Los_Angeles"
fi

if [[ -f "${location_config}" ]]; then
  # shellcheck disable=SC1090
  source "${location_config}"
fi

if [[ "${1:-}" == "--select" ]]; then
  exec "${script_dir}/weather-location-select.sh"
fi

should_geocode=0
if [[ -z "${lat}" || -z "${lon}" || "${lat}" == "auto" || "${lon}" == "auto" ]]; then
  should_geocode=1
  lat="${default_lat}"
  lon="${default_lon}"
fi

if [[ -n "${location_query:-}" && -f "${cache_file}" ]]; then
  # shellcheck disable=SC1090
  source "${cache_file}"
  if [[ "${cached_query:-}" == "${location_query}" && -n "${cached_lat:-}" && -n "${cached_lon:-}" ]]; then
    lat="${cached_lat}"
    lon="${cached_lon}"
    should_geocode=0
  fi
fi

if [[ "${should_geocode}" -eq 1 ]]; then
  geocode_query="${location_query:-}"
  if [[ -z "${geocode_query}" ]]; then
    geocode_query="Duvall, WA"
  fi

  geocode_url="https://geocoding-api.open-meteo.com/v1/search?count=1&format=json&name=$(printf '%s' "${geocode_query}" | jq -sRr @uri)"
  if geocode_json="$(curl --fail --silent --show-error --max-time 4 "${geocode_url}" 2>/dev/null)"; then
    resolved_lat="$(jq -r '.results[0].latitude // empty' <<<"${geocode_json}")"
    resolved_lon="$(jq -r '.results[0].longitude // empty' <<<"${geocode_json}")"
  else
    resolved_lat=""
    resolved_lon=""
  fi

  if [[ -n "${resolved_lat}" && -n "${resolved_lon}" ]]; then
    lat="${resolved_lat}"
    lon="${resolved_lon}"
    mkdir -p "${cache_dir}"
    cat > "${cache_file}" <<EOF
cached_query=$(printf '%q' "${geocode_query}")
cached_lat=$(printf '%q' "${lat}")
cached_lon=$(printf '%q' "${lon}")
EOF
  else
    printf 'Unable to resolve weather location: %s; using fallback coordinates\n' "${geocode_query}" >&2
    lat="${default_lat}"
    lon="${default_lon}"
  fi

  if [[ -z "${forecast_url}" ]]; then
    forecast_url="https://forecast.weather.gov/MapClick.php?lat=${lat}&lon=${lon}"
  fi
fi

if [[ -z "${forecast_url}" ]]; then
  forecast_url="https://forecast.weather.gov/MapClick.php?lat=${lat}&lon=${lon}"
fi

if [[ "${1:-}" == "--open" ]]; then
  exec xdg-open "${forecast_url}"
fi

url="https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&timezone=${tz}&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch&current=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max"

if ! json="$(curl --fail --silent --show-error --max-time 4 "$url" 2>/dev/null)"; then
  jq -nc \
    --arg text "--" \
    --arg tooltip "<b>Weather</b><br/><font color='#d42b5b'>Unavailable</font>" \
    --arg class "fallback" \
    '{text:$text, tooltip:$tooltip, class:$class}'
  exit 0
fi
alerts_url="https://api.weather.gov/alerts/active?point=${lat},${lon}"
alerts_json="$(
  curl --fail --silent --show-error --max-time 4 \
    -H 'Accept: application/geo+json' \
    -H 'User-Agent: omabar-v2-weather-alerts/1.0 (https://github.com/OldJobobo/jobo-bars)' \
    "${alerts_url}" 2>/dev/null || true
)"

weather_code="$(jq -r '.current.weather_code' <<<"$json")"
temp="$(jq -r '.current.temperature_2m | round' <<<"$json")"
high="$(jq -r '.daily.temperature_2m_max[0] | round' <<<"$json")"
low="$(jq -r '.daily.temperature_2m_min[0] | round' <<<"$json")"
rain="$(jq -r '.daily.precipitation_probability_max[0] // 0' <<<"$json")"
sunrise="$(jq -r '.daily.sunrise[0] | sub("^[^T]+T"; "") | .[0:5]' <<<"$json")"
sunset="$(jq -r '.daily.sunset[0] | sub("^[^T]+T"; "") | .[0:5]' <<<"$json")"

describe_weather() {
  case "$1" in
    0) printf '%s|%s\n' "󰖙" "Clear" ;;
    1) printf '%s|%s\n' "󰖔" "Mostly Clear" ;;
    2) printf '%s|%s\n' "󰖐" "Partly Cloudy" ;;
    3) printf '%s|%s\n' "󰖐" "Overcast" ;;
    45|48) printf '%s|%s\n' "󰖑" "Fog" ;;
    51|53|55|56|57) printf '%s|%s\n' "󰖖" "Drizzle" ;;
    61|63|65|66|67|80|81|82) printf '%s|%s\n' "󰖗" "Rain" ;;
    71|73|75|77|85|86) printf '%s|%s\n' "󰖘" "Snow" ;;
    95|96|99) printf '%s|%s\n' "󰖓" "Storm" ;;
    *) printf '%s|%s\n' "󰼰" "Weather" ;;
  esac
}

IFS='|' read -r icon label <<<"$(describe_weather "$weather_code")"

tooltip_lines=()
alert_count=0
alert_icon=""
weather_class="normal"

if [[ -n "${alerts_json}" ]]; then
  alert_count="$(jq -r '.features | length // 0' <<<"$alerts_json" 2>/dev/null || printf '0')"
fi

if [[ "${alert_count}" =~ ^[0-9]+$ ]] && (( alert_count > 0 )); then
  weather_class="alert"
  alert_icon=""
  tooltip_lines+=("<b><font color='#d42b5b'>Active Alerts</font></b>")
  while IFS=$'\t' read -r event severity urgency expires headline; do
    expires_text="${expires:-Unknown}"
    tooltip_lines+=("<b>${event}</b> (${severity}, ${urgency})")
    tooltip_lines+=("Expires ${expires_text}")
    if [[ -n "${headline}" && "${headline}" != "null" ]]; then
      tooltip_lines+=("${headline}")
    fi
    tooltip_lines+=("")
  done < <(
    jq -r '
      .features[]
      | .properties
      | [
          (.event // "Alert"),
          (.severity // "Unknown"),
          (.urgency // "Unknown"),
          (.expires // "Unknown"),
          (.headline // "")
        ]
      | @tsv
    ' <<<"$alerts_json"
  )
fi

tooltip_lines+=("<b>${label}</b> <font color='#c0daf6'>${temp}°F</font>")
tooltip_lines+=("Today: High ${high}°  Low ${low}°")
tooltip_lines+=("Rain ${rain}%")
tooltip_lines+=("Sunrise ${sunrise}  Sunset ${sunset}")
tooltip_lines+=("")
tooltip_lines+=("<b>7-Day Forecast</b>")

while IFS=$'\t' read -r date day_code day_high day_low; do
  IFS='|' read -r day_icon day_label <<<"$(describe_weather "$day_code")"
  day_name="$(date -d "$date" +%a)"
  tooltip_lines+=("${day_name}  ${day_icon}  <font color='#c0daf6'>${day_high}°/${day_low}°</font>  ${day_label}")
done < <(
  jq -r '
    .daily.time as $time
    | .daily.weather_code as $code
    | .daily.temperature_2m_max as $high
    | .daily.temperature_2m_min as $low
    | range(0; ($time | length))
    | [$time[.], $code[.], ($high[.] | round), ($low[.] | round)]
    | @tsv
  ' <<<"$json"
)

tooltip="$(printf '%s<br/>' "${tooltip_lines[@]}")"

text="${icon} ${temp}°F"
if [[ -n "${alert_icon}" ]]; then
  text="${alert_icon} ${text}"
fi

jq -nc --arg text "$text" --arg tooltip "$tooltip" --arg class "$weather_class" \
  '{text:$text, tooltip:$tooltip, class:$class}'
