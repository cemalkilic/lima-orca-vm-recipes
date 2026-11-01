#!/usr/bin/env bash
# Embeds src/<recipe>/*.sh into recipes/<recipe>.json, the file Orca reads.
# Usage: scripts/build.sh [--check]   (--check fails if a recipe JSON is stale)
set -euo pipefail
cd "$(dirname "$0")/.."

check="${1:-}"
case "$check" in ""|--check) ;; *) echo "usage: $0 [--check]" >&2; exit 2 ;; esac
stale=0

build() { # id name description dir
  jq -n --arg id "$1" --arg name "$2" --arg description "$3" \
    --rawfile create "$4/create.sh" --rawfile suspend "$4/suspend.sh" \
    --rawfile resume "$4/resume.sh" --rawfile destroy "$4/destroy.sh" \
    '{schemaVersion: 1, $id, $name, $description,
      create: ($create | rtrimstr("\n")), suspend: ($suspend | rtrimstr("\n")),
      resume: ($resume | rtrimstr("\n")), destroy: ($destroy | rtrimstr("\n"))}'
}

emit() { # out id name description dir
  local out="$1"; shift
  if [ "$check" = --check ]; then
    if ! diff -q <(build "$@") "$out" >/dev/null 2>&1; then
      echo "stale: $out (run scripts/build.sh)" >&2; stale=1
    fi
  else
    build "$@" > "$out"; echo "wrote $out"
  fi
}

emit recipes/ubuntu-lts.json lima-ubuntu-lts "Lima Ubuntu LTS" \
  "Creates a two-CPU disposable Ubuntu LTS workspace with Lima." src/ubuntu-lts

exit "$stale"
