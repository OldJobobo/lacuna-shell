#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

while IFS= read -r config; do
  python3 -m json.tool "$config" >/dev/null
done < <(find config -maxdepth 1 -name '*.json' -print | sort)

while IFS= read -r manifest; do
  python3 -m json.tool "$manifest" >/dev/null
done < <(find . -maxdepth 2 -path './lacuna.*/manifest.json' -print | sort)

if command -v qmllint >/dev/null 2>&1; then
  mapfile -t qml_files < <(find . -path './lacuna.*/*.qml' -print | sort)
  qmllint "${qml_files[@]}"
else
  echo "warning: qmllint not found; skipping QML lint" >&2
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck install.sh \
    scripts/check.sh \
    scripts/check-aur-package \
    lacuna.theme-preloader/scripts/*.sh \
    lacuna.claude-usage/scripts/claude-code-status.sh \
    lacuna.codex-usage/scripts/*.sh
else
  echo "warning: shellcheck not found; skipping shell script lint" >&2
fi

scripts/sync-vendored --check
scripts/release-check
scripts/check-aur-package

if python3 -c 'import pytest' >/dev/null 2>&1; then
  python3 -m pytest
else
  python3 -m unittest discover -s tests
fi
