#!/usr/bin/env bash
set -euo pipefail

LACUNA_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export LACUNA_PATH

exec quickshell -p "$LACUNA_PATH/shell.qml"
