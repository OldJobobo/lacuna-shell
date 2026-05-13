#!/usr/bin/env bash

set -euo pipefail

# Display format. Available placeholders:
#   {session_left}   percent remaining in the current 5h block
#   {session_pct}    percent used in the current 5h block
#   {session_reset}  local reset time for the current 5h block
#   {session_count}  number of live Claude Code sessions
SEP=" "
FMT_SESSION="{session_left}% 󰅕 {session_reset}"

theme_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
theme_colors="${OMARCHY_THEME_COLORS_TOML:-${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/current/theme/colors.toml}"
icon_template="$theme_dir/../assets/claude-ai.svg"
icon_output="$theme_dir/../assets/claude-ai-themed.svg"

SESSION_LIMIT="${CLAUDE_CODE_SESSION_LIMIT:-978515}"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CACHE_TTL="${CLAUDE_CODE_STATUS_CACHE_TTL:-30}"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/lacuna"
cache_file="$cache_dir/claude-code-status.json"
lock_file="$cache_dir/claude-code-status.lock"

hide() {
  printf '%s\n' '{"text":"","tooltip":"","class":"hidden"}'
  exit 0
}

command -v python3 >/dev/null 2>&1 || hide
command -v claude >/dev/null 2>&1 || hide
[[ "$SESSION_LIMIT" =~ ^[0-9]+$ ]] || hide
(( SESSION_LIMIT > 0 )) || hide
[[ -d "$CLAUDE_HOME" ]] || hide
mkdir -p "$cache_dir" 2>/dev/null || true

if [[ -f "$theme_colors" && -f "$icon_template" ]]; then
  claude_color="color9"
  accent="$(awk -F= -v color_name="$claude_color" '
    {
      key = $1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      if (key == color_name) {
        value = $2
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        gsub(/^["'\''"]|["'\''"]$/, "", value)
        print value
        exit
      }
    }
  ' "$theme_colors")"

  if [[ -n "${accent:-}" ]]; then
    tmp_icon="$(mktemp)"
    if sed -e "0,/fill=\"#d97757\"/s//fill=\"$accent\"/" "$icon_template" >"$tmp_icon"; then
      if [[ ! -f "$icon_output" ]] || ! cmp -s "$tmp_icon" "$icon_output"; then
        mv "$tmp_icon" "$icon_output" 2>/dev/null || rm -f "$tmp_icon"
      else
        rm -f "$tmp_icon"
      fi
    else
      rm -f "$tmp_icon"
    fi
  fi
fi

emit_from_ccusage() {
  local ccusage_bin="$1"
  local tmp_blocks

  tmp_blocks="$(mktemp)"
  if command -v timeout >/dev/null 2>&1; then
    timeout 5 "$ccusage_bin" blocks --json --offline --active >"$tmp_blocks" 2>/dev/null || {
      rm -f "$tmp_blocks"
      return 1
    }
  else
    "$ccusage_bin" blocks --json --offline --active >"$tmp_blocks" 2>/dev/null || {
      rm -f "$tmp_blocks"
      return 1
    }
  fi

  python3 - "$tmp_blocks" "$SESSION_LIMIT" "$SEP" "$FMT_SESSION" <<'PYEOF'
import datetime as dt
import json
import sys

blocks_file = sys.argv[1]
session_limit = int(sys.argv[2])
sep = sys.argv[3]
fmt_session = sys.argv[4]

def fail():
    raise SystemExit(1)

def parse_time(value):
    if not value:
        return None
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except Exception:
        return None

def local_time(value):
    if not value:
        return ""
    return value.astimezone().strftime("%-I:%M %p")

try:
    with open(blocks_file, encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    fail()

blocks = [
    block for block in data.get("blocks", [])
    if block.get("isActive") and not block.get("isGap")
]
if not blocks:
    fail()

active_block = max(blocks, key=lambda block: block.get("startTime", ""))
token_counts = active_block.get("tokenCounts") or {}
session_tokens = (
    int(token_counts.get("inputTokens") or 0)
    + int(token_counts.get("outputTokens") or 0)
    + int(token_counts.get("cacheCreationInputTokens") or 0)
)
if session_tokens <= 0:
    fail()

session_pct = min(100, round(session_tokens / session_limit * 100))
session_left = max(0, 100 - session_pct)
start_time = parse_time(active_block.get("startTime"))
end_time = parse_time(active_block.get("endTime"))
actual_end = parse_time(active_block.get("actualEndTime"))
entries = active_block.get("entries") or 0
models = ", ".join(active_block.get("models") or [])

values = {
    "session_left": str(session_left),
    "session_pct": str(session_pct),
    "session_reset": local_time(end_time),
    "session_count": "1",
}

text_parts = []
if fmt_session:
    text = fmt_session
    for key, value in values.items():
        text = text.replace("{" + key + "}", value)
    text = " ".join(text.split())
    if text:
        text_parts.append(text)

if not text_parts:
    fail()

usage_color = "#d42b5b" if session_left == 0 else "#e97b3c" if session_left < 20 else "#8cbfb8"
tooltip_lines = [
    "<b>Claude Code</b>",
    "Source: ccusage",
    f"5h block: <font color='{usage_color}'>{session_pct}% used</font> - resets {local_time(end_time)}",
    f"Tokens: {session_tokens:,} / {session_limit:,} counted",
]
if start_time:
    tooltip_lines.append(f"Started: {local_time(start_time)}")
if actual_end:
    tooltip_lines.append(f"Latest usage: {local_time(actual_end)}")
if entries:
    tooltip_lines.append(f"Entries: {entries}")
if models:
    tooltip_lines.append(f"Models: {models}")

css_class = ""
if session_left < 20:
    css_class = "low"
if session_left == 0:
    css_class = "over"

print(json.dumps({
    "text": sep.join(text_parts),
    "tooltip": "<br/>".join(tooltip_lines),
    "class": css_class,
}, separators=(",", ":")))
PYEOF
  local status=$?
  rm -f "$tmp_blocks"
  return "$status"
}

emit_cache_if_fresh() {
  local now mtime

  [[ "$CACHE_TTL" =~ ^[0-9]+$ ]] || return 1
  (( CACHE_TTL > 0 )) || return 1
  [[ -s "$cache_file" ]] || return 1

  now="$(date +%s)"
  mtime="$(stat -c %Y "$cache_file" 2>/dev/null || printf '0')"
  (( now - mtime < CACHE_TTL )) || return 1

  cat "$cache_file"
  exit 0
}

write_cache_and_emit() {
  local output="$1"
  local tmp_cache

  if tmp_cache="$(mktemp "$cache_dir/claude-code-status.XXXXXX" 2>/dev/null)"; then
    printf '%s\n' "$output" >"$tmp_cache"
    mv "$tmp_cache" "$cache_file" 2>/dev/null || rm -f "$tmp_cache"
  fi

  printf '%s\n' "$output"
  exit 0
}

emit_uncached_status() {
  if command -v ccusage >/dev/null 2>&1; then
    emit_from_ccusage "$(command -v ccusage)" && return 0
  fi

  python3 - "$CLAUDE_HOME" "$SESSION_LIMIT" "$SEP" "$FMT_SESSION" <<'PYEOF'
import datetime as dt
import glob
import json
import os
import sys

claude_home = sys.argv[1]
session_limit = int(sys.argv[2])
sep = sys.argv[3]
fmt_session = sys.argv[4]

def emit_hidden():
    print('{"text":"","tooltip":"","class":"hidden"}')
    raise SystemExit

def parse_time(value):
    if not value:
        return None
    try:
        if isinstance(value, (int, float)):
            if value > 10_000_000_000:
                value = value / 1000
            return dt.datetime.fromtimestamp(value, tz=dt.timezone.utc)
        if isinstance(value, str):
            return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except Exception:
        return None
    return None

def local_time(value):
    if not value:
        return ""
    return value.astimezone().strftime("%-I:%M %p")

session_dir = os.path.join(claude_home, "sessions")
project_dir = os.path.join(claude_home, "projects")
if not os.path.isdir(project_dir):
    emit_hidden()

live_sessions = []
if os.path.isdir(session_dir):
    for path in glob.glob(os.path.join(session_dir, "*.json")):
        try:
            with open(path, encoding="utf-8") as f:
                session = json.load(f)
        except Exception:
            continue

        pid = str(session.get("pid") or "")
        if not pid or not os.path.isdir(os.path.join("/proc", pid)):
            continue

        started = parse_time(session.get("startedAt"))
        if not started:
            continue

        live_sessions.append({
            "started": started,
            "cwd": session.get("cwd") or "",
            "status": session.get("status") or "",
            "version": session.get("version") or "",
        })

session_count = len(live_sessions)
now = dt.datetime.now(dt.timezone.utc)
window_start = now - dt.timedelta(hours=5)
window_end = now
reset_time = None

current_live_sessions = []
for session in live_sessions:
    session_end = session["started"] + dt.timedelta(hours=5)
    if session["started"] <= now < session_end:
        current_live_sessions.append(session)

if current_live_sessions:
    window_start = min(session["started"] for session in current_live_sessions)
    window_end = window_start + dt.timedelta(hours=5)
    reset_time = window_end

usage_events = []
jsonl_paths = glob.glob(os.path.join(project_dir, "**", "*.jsonl"), recursive=True)

for path in jsonl_paths:
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                try:
                    event = json.loads(line)
                except Exception:
                    continue

                if event.get("type") != "assistant":
                    continue

                timestamp = parse_time(event.get("timestamp"))
                if not timestamp:
                    continue

                message = event.get("message") or {}
                usage = message.get("usage") or {}
                if not usage:
                    continue

                counted = (
                    int(usage.get("input_tokens") or 0)
                    + int(usage.get("output_tokens") or 0)
                    + int(usage.get("cache_creation_input_tokens") or 0)
                )
                if counted <= 0:
                    continue

                usage_events.append((timestamp, counted))
    except Exception:
        continue

if not usage_events:
    emit_hidden()

latest_any_event = max(timestamp for timestamp, _counted in usage_events)
if not current_live_sessions:
    window_start = now - dt.timedelta(hours=5)
    window_end = now
    reset_time = latest_any_event + dt.timedelta(hours=5)

session_tokens = 0
latest_event = None
for timestamp, counted in usage_events:
    if timestamp < window_start or timestamp >= window_end:
        continue
    session_tokens += counted
    if latest_event is None or timestamp > latest_event:
        latest_event = timestamp

if session_tokens <= 0:
    emit_hidden()

if reset_time is None:
    reset_time = window_end

session_pct = min(100, round(session_tokens / session_limit * 100))
session_left = max(0, 100 - session_pct)

values = {
    "session_left": str(session_left),
    "session_pct": str(session_pct),
    "session_reset": local_time(reset_time),
    "session_count": str(session_count),
}

text_parts = []
if fmt_session:
    text = fmt_session
    for key, value in values.items():
        text = text.replace("{" + key + "}", value)
    text = " ".join(text.split())
    if text:
        text_parts.append(text)

if not text_parts:
    emit_hidden()

usage_color = "#d42b5b" if session_left == 0 else "#e97b3c" if session_left < 20 else "#8cbfb8"
tooltip_lines = [
    "<b>Claude Code</b>",
    f"Sessions: {session_count}",
    f"5h usage: <font color='{usage_color}'>{session_pct}% used</font> - resets {local_time(reset_time)}",
    f"Tokens: {session_tokens:,} / {session_limit:,} counted",
    f"Window start: {local_time(window_start)}",
]
if latest_event:
    tooltip_lines.append(f"Latest usage: {local_time(latest_event)}")

css_class = ""
if session_left < 20:
    css_class = "low"
if session_left == 0:
    css_class = "over"

print(json.dumps({
    "text": sep.join(text_parts),
    "tooltip": "<br/>".join(tooltip_lines),
    "class": css_class,
}, separators=(",", ":")))
PYEOF
}

emit_cached_status() {
  local output

  emit_cache_if_fresh || true

  if command -v flock >/dev/null 2>&1; then
    exec 9>"$lock_file"
    if flock -n 9; then
      emit_cache_if_fresh || true
      if output="$(emit_uncached_status)"; then
        write_cache_and_emit "$output"
      fi
      hide
    fi

    if [[ -s "$cache_file" ]]; then
      cat "$cache_file"
      exit 0
    fi

    flock 9
    if [[ -s "$cache_file" ]]; then
      cat "$cache_file"
      exit 0
    fi

    hide
  fi

  if output="$(emit_uncached_status)"; then
    write_cache_and_emit "$output"
  fi

  hide
}

emit_cached_status
