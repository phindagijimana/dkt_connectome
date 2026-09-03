#!/usr/bin/env bash
# Simulate a new user's first-time experience (v0.3.0 workflow).
set -euo pipefail

TEST_ROOT="$(mktemp -d "${HOME}/.cache/dkt-random-user-test.XXXXXX")"
CACHE="${TEST_ROOT}/containers"
OUT="${TEST_ROOT}/results"
BIDS="${TEST_ROOT}/bids"
LOG="${TEST_ROOT}/test.log"
APPTAINER_TMP="${TEST_ROOT}/apptainer_tmp"
PASS=0
FAIL=0
SKIP=0

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "${LOG}"; }
pass() { PASS=$((PASS + 1)); log "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); log "FAIL: $*"; }
skip() { SKIP=$((SKIP + 1)); log "SKIP: $*"; }
step() { log ""; log "========== $* =========="; }

cleanup() {
  log "Test root: ${TEST_ROOT} (kept for inspection)"
  log "Summary: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
}
trap cleanup EXIT

step "1. Fresh clone (random user starts here)"
git clone --depth 1 https://github.com/phindagijimana/dkt_connectome.git "${TEST_ROOT}/repo" >>"${LOG}" 2>&1
cd "${TEST_ROOT}/repo/dwi_pipeline"
chmod +x dkt run install.sh scripts/*.sh 2>/dev/null || true
DKT=(bash ./dkt)
RUN=(bash ./run)
pass "git clone + cd dwi_pipeline"

step "2. Version and CLI help"
V="$("${DKT[@]}" version)"
[[ "${V}" == "0.3.0" ]] && pass "dkt version = ${V}" || fail "dkt version = ${V} (expected 0.3.0)"
"${DKT[@]}" --help | grep -q install && pass "dkt --help shows install" || fail "dkt --help missing install"
"${RUN[@]}" --help | grep -q "participant-label" && pass "./run --help OK" || fail "./run --help"

step "3. Pre-install check (expect missing containers)"
export FS_LICENSE="${TEST_ROOT}/license.txt"
echo "stub-freesurfer-license" > "${FS_LICENSE}"
export DKT_CONTAINER_CACHE="${CACHE}"
export APPTAINER_TMPDIR="${APPTAINER_TMP}"
export TMPDIR="${APPTAINER_TMP}"
mkdir -p "${CACHE}" "${OUT}" "${BIDS}" "${APPTAINER_TMP}"

if "${DKT[@]}" check 2>>"${LOG}"; then
  skip "dkt check passed before install (unexpected — cache may exist)"
else
  pass "dkt check fails before install (expected — no containers yet)"
fi

step "4. Install pinned step containers (./dkt install)"
log "Pulling all pinned .sif images into fresh cache: ${CACHE}"
log "This mirrors a real first-time install (may take several minutes)..."

if "${DKT[@]}" install --cache "${CACHE}" --quiet 2>>"${LOG}"; then
  pass "dkt install completed"
else
  fail "dkt install failed — see ${LOG}"
fi

if [[ -f workflow/config/config.local.yaml ]]; then
  pass "config.local.yaml written"
else
  fail "config.local.yaml missing after install"
fi

SIF_COUNT="$(find "${CACHE}" -name '*.sif' -size +0 2>/dev/null | wc -l)"
log "Cached .sif files: ${SIF_COUNT}"
[[ "${SIF_COUNT}" -ge 8 ]] && pass "${SIF_COUNT} step containers cached" || fail "only ${SIF_COUNT} containers cached (expected ≥8)"

step "5. Strict verify (./dkt check --strict)"
if "${DKT[@]}" check --strict --cache "${CACHE}" 2>>"${LOG}"; then
  pass "dkt check --strict"
else
  fail "dkt check --strict — see ${LOG}"
fi

step "6. Snakemake dry-run on bundled minimal BIDS fixture"
python3 tests/fixtures/generate_bids_fixture.py >>"${LOG}" 2>&1 || true
FIXTURE="tests/fixtures/bids_minimal"
export BIDS_DIR="${FIXTURE}"
export RESULTS_ROOT="${OUT}"

if "${DKT[@]}" run "${FIXTURE}" "${OUT}" participant \
  --participant-label EXAMPLE \
  --session-filter baseline \
  --dry-run \
  --no-sdc 2>>"${LOG}"; then
  pass "dkt run --dry-run on bids_minimal"
else
  fail "dkt run --dry-run failed"
fi

step "7. Docker orchestrator path (podman; no docker CLI on this node)"
if command -v podman >/dev/null 2>&1; then
  export CONTAINERS_STORAGE_DRIVER="${CONTAINERS_STORAGE_DRIVER:-vfs}"
  export CONTAINERS_CONF="${TEST_ROOT}/containers.conf"
  mkdir -p "${TEST_ROOT}/podman-storage"
  cat > "${CONTAINERS_CONF}" <<EOF
[storage]
driver = "vfs"
runroot = "${TEST_ROOT}/podman-run"
graphroot = "${TEST_ROOT}/podman-storage"
EOF

  if podman pull "docker.io/phindagijimana321/dkt-connectome:0.3.0" >>"${LOG}" 2>&1; then
    pass "podman pull dkt-connectome:0.3.0"
    if podman run --rm \
      -e BIDS_APP_CI=1 \
      -e "FS_LICENSE=${FS_LICENSE}" \
      "docker.io/phindagijimana321/dkt-connectome:0.3.0" \
      dkt version 2>>"${LOG}" | grep -q 0.3.0; then
      pass "podman run dkt version = 0.3.0"
    else
      fail "podman run dkt version"
    fi
    if podman run --rm \
      -e BIDS_APP_CI=1 \
      -e "FS_LICENSE=${FS_LICENSE}" \
      "docker.io/phindagijimana321/dkt-connectome:0.3.0" \
      dkt check 2>>"${LOG}"; then
      pass "podman run dkt check (CI mode)"
    else
      fail "podman run dkt check"
    fi
  else
    skip "podman pull failed (storage/network) — Apptainer path still validated above"
  fi
else
  skip "podman not available"
fi

step "8. Docker Hub tag spot-check (skopeo)"
AUTH="${HOME}/.config/containers/auth.json"
for spec in \
  "phindagijimana321/dkt-connectome:0.3.0" \
  "phindagijimana321/dkt_connectome:0.3.0" \
  "phindagijimana321/dkt-vbt:0.3.0"; do
  if skopeo list-tags --authfile "${AUTH}" "docker://${spec%%:*}" 2>/dev/null | grep -q "${spec##*:}"; then
    pass "Docker Hub tag exists: ${spec}"
  else
    fail "Docker Hub tag missing: ${spec}"
  fi
done

[[ "${FAIL}" -eq 0 ]] && exit 0 || exit 1
