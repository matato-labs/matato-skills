#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  printf 'Usage: npm run atlas -- [folder]\nRequires uv and jq. ATLAS_PROJECT defaults to ../atlas/atlas.\n'
  exit 0
fi

if (( $# > 1 )); then
  printf 'Usage: npm run atlas -- [folder]\n' >&2
  exit 1
fi

reportFile=$(mktemp)
trap 'rm -f "$reportFile"' EXIT

uv run --project "${ATLAS_PROJECT:-../atlas/atlas}" --no-dev \
  atlas report --f "${1:-.}" --skip-save --format json | tee "$reportFile"

if ! jq -e '.findings == []' "$reportFile" > /dev/null; then
  printf 'Atlas check failed: expected a valid report with zero findings.\n' >&2
  exit 1
fi
