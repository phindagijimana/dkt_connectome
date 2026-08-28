#!/usr/bin/env bash
# Step 3.5a: Daniel Deep Atropos segmentation → base_5tt_native.mif on BIDS T1w grid.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run_deep_atropos_5tt.sh [OPTIONS]

Required:
  --t1w PATH               BIDS T1w reference (native grid)
  --segmentation PATH      Deep Atropos integer segmentation (NIfTI)
  --outdir DIR             Output directory

Optional:
  -h, --help
EOF
}

fail() { echo "ERROR [deep-atropos-5tt]: $*" >&2; exit 1; }
log() { echo "[deep-atropos-5tt] $*" >&2; }

T1W="" SEG="" OUTDIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --t1w) T1W="$2"; shift 2 ;;
    --segmentation) SEG="$2"; shift 2 ;;
    --outdir) OUTDIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

[[ -n "${T1W}" && -n "${SEG}" && -n "${OUTDIR}" ]] || { usage; exit 1; }
[[ -f "${T1W}" ]] || fail "missing T1w: ${T1W}"
[[ -f "${SEG}" ]] || fail "missing segmentation: ${SEG}"

mkdir -p "${OUTDIR}"

log "map Deep Atropos labels → MRtrix 5TT channels"
python3 /opt/deep_atropos/convert_deep_atropos_to_5tt.py \
  --t1w "${T1W}" \
  --segmentation "${SEG}" \
  --output "${OUTDIR}/base_5tt_native.nii.gz" \
  --json "${OUTDIR}/deep_atropos_convert.json"

log "convert to MRtrix .mif + 5ttcheck"
mrconvert -force "${OUTDIR}/base_5tt_native.nii.gz" "${OUTDIR}/base_5tt_native.mif"
5ttcheck "${OUTDIR}/base_5tt_native.mif"

python3 - "${OUTDIR}" <<'PY'
import json, sys
from pathlib import Path

outdir = Path(sys.argv[1])
payload = {
    "five_tt_source": "deep-atropos-native",
    "spatial_reference": "bids_t1w_native",
    "base_5tt_native_mif": str(outdir / "base_5tt_native.mif"),
    "base_5tt_native_nii": str(outdir / "base_5tt_native.nii.gz"),
}
payload["convert"] = json.loads((outdir / "deep_atropos_convert.json").read_text())
(outdir / "deep_atropos_5tt.json").write_text(json.dumps(payload, indent=2) + "\n")
PY

echo "Deep Atropos 5TT OK:"
echo "  base_5tt_native.mif: ${OUTDIR}/base_5tt_native.mif"
echo "  provenance: ${OUTDIR}/deep_atropos_5tt.json"
