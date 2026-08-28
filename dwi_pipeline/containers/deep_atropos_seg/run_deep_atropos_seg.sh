#!/usr/bin/env bash
# Run ANTsPyNet Deep Atropos on native T1w → integer segmentation (labels 0–6).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run_deep_atropos_seg.sh [OPTIONS]

Required:
  --t1w PATH          Native BIDS T1w NIfTI
  --outdir DIR        Output directory

Optional:
  --no-preprocessing  T1w is already preprocessed
  --use-spatial-priors N   0 or 1 (default 1)
  --cache-dir DIR     ANTsXNet model cache (default /opt/antsxnet_cache)
  -h, --help
EOF
}

fail() { echo "ERROR [deep-atropos-seg]: $*" >&2; exit 1; }
log() { echo "[deep-atropos-seg] $*" >&2; }

T1W="" OUTDIR=""
NO_PREPROCESS=0 SPATIAL_PRIORS=1 CACHE_DIR="/opt/antsxnet_cache"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --t1w) T1W="$2"; shift 2 ;;
    --outdir) OUTDIR="$2"; shift 2 ;;
    --no-preprocessing) NO_PREPROCESS=1; shift ;;
    --use-spatial-priors) SPATIAL_PRIORS="$2"; shift 2 ;;
    --cache-dir) CACHE_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

[[ -n "${T1W}" && -n "${OUTDIR}" ]] || { usage; exit 1; }
[[ -f "${T1W}" ]] || fail "missing T1w: ${T1W}"
mkdir -p "${OUTDIR}" "${CACHE_DIR}"

_args=(
  --t1w "${T1W}"
  --output "${OUTDIR}/desc-deepatropos_seg.nii.gz"
  --json "${OUTDIR}/deep_atropos_seg.json"
  --use-spatial-priors "${SPATIAL_PRIORS}"
  --cache-dir "${CACHE_DIR}"
)
[[ "${NO_PREPROCESS}" -eq 1 ]] && _args+=(--no-preprocessing)

log "ANTsPyNet deep_atropos on ${T1W}"
python3 /opt/deep_atropos_seg/run_deep_atropos_seg.py "${_args[@]}"

echo "Deep Atropos segmentation OK:"
echo "  seg: ${OUTDIR}/desc-deepatropos_seg.nii.gz"
echo "  json: ${OUTDIR}/deep_atropos_seg.json"
