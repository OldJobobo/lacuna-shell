#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

before="$(git rev-parse --short HEAD)"
upstream="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"

echo "Updating Lacuna"
echo "Repository: $repo_dir"
echo "Current HEAD: $before"
echo

if [[ -z "$upstream" ]]; then
  echo "Cannot update: this branch has no upstream remote."
  echo "Set one with: git branch --set-upstream-to origin/$(git branch --show-current)"
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Cannot update: the Lacuna repo has local changes."
  echo
  git status --short
  echo
  echo "Commit, stash, or discard those changes before updating."
  exit 1
fi

git fetch --prune
git merge --ff-only "$upstream"

after="$(git rev-parse --short HEAD)"

echo
if [[ "$before" != "$after" ]]; then
  echo "Updated: $before -> $after"
  echo "Restarting Lacuna..."
  quickshell kill -p "$repo_dir/shell.qml" || true
  setsid "$repo_dir/run.sh" >/tmp/lacuna-quickshell.log 2>&1 &
else
  echo "Lacuna is already up to date."
fi

echo
echo "Done."
