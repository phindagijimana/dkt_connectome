#!/usr/bin/env bash
# Verify the live Read the Docs site matches current DKT Connectome docs (branding + science pages).
# Usage: bash dwi_pipeline/scripts/verify_rtd_live.sh [HOME_URL]
set -euo pipefail

HOME_URL="${1:-https://dkt-connectome.readthedocs.io/en/latest/}"
BASE="${HOME_URL%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPECTED_VERSION="$(python3 -c "import json; print(json.load(open('${SCRIPT_DIR}/../app.json'))['PipelineVersion'])")"

HOME_HTML="$(curl -fsSL --max-time 30 "${HOME_URL}")"

fail() {
  echo "RTD live check FAILED: $*" >&2
  exit 1
}

echo "${HOME_HTML}" | grep -q 'DKT Connectome' \
  || fail "page missing 'DKT Connectome' branding (title: $(echo "${HOME_HTML}" | grep -o '<title>[^<]*</title>' | head -1))"

echo "${HOME_HTML}" | grep -qi 'TrackTBI Connectome' \
  && fail "page still contains 'TrackTBI Connectome'"

TITLE="$(echo "${HOME_HTML}" | grep -o '<title>[^<]*</title>' | head -1)"
echo "${TITLE}" | grep -q "${EXPECTED_VERSION}" \
  || fail "title missing expected version ${EXPECTED_VERSION} (got: ${TITLE}) — rebuild Read the Docs"

if echo "${HOME_HTML}" | grep -q 'Start here'; then
  echo "RTD home: start-here section present"
else
  fail "home page missing 'Start here' — RTD build is stale; rebuild latest"
fi

# Science overview (Sphinx RTD uses .html; trailing-slash URLs may redirect)
SCIENCE_URL="${BASE}/science_overview.html"
SCIENCE_CODE="$(curl -sS -o /tmp/rtd_science.html -w '%{http_code}' --max-time 30 "${SCIENCE_URL}")"
if [[ "${SCIENCE_CODE}" != "200" ]]; then
  SCIENCE_URL="${BASE}/science_overview/"
  SCIENCE_CODE="$(curl -sS -o /tmp/rtd_science.html -w '%{http_code}' --max-time 30 "${SCIENCE_URL}")"
fi
if [[ "${SCIENCE_CODE}" != "200" ]]; then
  fail "science_overview returned HTTP ${SCIENCE_CODE} at ${SCIENCE_URL} — rebuild Read the Docs"
fi

grep -q 'How it works' /tmp/rtd_science.html \
  || fail "science_overview page missing expected heading"

grep -q 'Scientific goal' /tmp/rtd_science.html \
  || fail "science_overview page missing 'Scientific goal' section"

echo "RTD live check OK:"
echo "  version: ${EXPECTED_VERSION}"
echo "  home:    ${HOME_URL}"
echo "  science: ${SCIENCE_URL}"
