#!/usr/bin/env bash
# Verify the live Read the Docs site shows current DKT Connectome branding.
# Usage: bash dwi_pipeline/scripts/verify_rtd_live.sh [URL]
set -euo pipefail

URL="${1:-https://dkt-connectome.readthedocs.io/en/latest/}"
HTML="$(curl -fsSL --max-time 30 "${URL}")"

fail() {
  echo "RTD live check FAILED: $*" >&2
  exit 1
}

echo "${HTML}" | grep -q '<title>DKT Connectome</title>' \
  || fail "title is not 'DKT Connectome' (got: $(echo "${HTML}" | grep -o '<title>[^<]*</title>' | head -1))"

echo "${HTML}" | grep -qi 'TrackTBI Connectome' \
  && fail "page still contains 'TrackTBI Connectome'"

echo "${HTML}" | grep -qE 'DKT Connectome' \
  || fail "page does not contain 'DKT Connectome' branding"

echo "RTD live check OK: ${URL}"
