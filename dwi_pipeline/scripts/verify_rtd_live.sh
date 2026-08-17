#!/usr/bin/env bash
# Verify the live Read the Docs site matches current DKT Connectome docs (branding + science pages).
# Usage: bash dwi_pipeline/scripts/verify_rtd_live.sh [HOME_URL]
set -euo pipefail

HOME_URL="${1:-https://dkt-connectome.readthedocs.io/en/latest/}"
BASE="${HOME_URL%/}"
if [[ "${BASE}" == */latest ]]; then
  SCIENCE_URL="${BASE}/science_overview/"
else
  SCIENCE_URL="${BASE}/science_overview/"
fi

HOME_HTML="$(curl -fsSL --max-time 30 "${HOME_URL}")"

fail() {
  echo "RTD live check FAILED: $*" >&2
  exit 1
}

echo "${HOME_HTML}" | grep -q '<title>DKT Connectome</title>' \
  || fail "title is not 'DKT Connectome' (got: $(echo "${HOME_HTML}" | grep -o '<title>[^<]*</title>' | head -1))"

echo "${HOME_HTML}" | grep -qi 'TrackTBI Connectome' \
  && fail "page still contains 'TrackTBI Connectome'"

echo "${HOME_HTML}" | grep -qE 'DKT Connectome' \
  || fail "page does not contain 'DKT Connectome' branding"

# Science overview landing (added v0.2.0 docs — commit 31e673f+)
if echo "${HOME_HTML}" | grep -q 'Start here'; then
  echo "RTD home: start-here section present"
else
  fail "home page missing 'Start here' — RTD build is stale; rebuild latest (see maintainer_tasks.md §14 on GitHub)"
fi

SCIENCE_CODE="$(curl -sS -o /tmp/rtd_science.html -w '%{http_code}' --max-time 30 "${SCIENCE_URL}")"
if [[ "${SCIENCE_CODE}" != "200" ]]; then
  fail "science_overview returned HTTP ${SCIENCE_CODE} at ${SCIENCE_URL} — rebuild Read the Docs"
fi

grep -q 'How it works' /tmp/rtd_science.html \
  || fail "science_overview page missing expected heading"

grep -q 'Scientific goal' /tmp/rtd_science.html \
  || fail "science_overview page missing 'Scientific goal' section"

echo "RTD live check OK:"
echo "  home:    ${HOME_URL}"
echo "  science: ${SCIENCE_URL}"
