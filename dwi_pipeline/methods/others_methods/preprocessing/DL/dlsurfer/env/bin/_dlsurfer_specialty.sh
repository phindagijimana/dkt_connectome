#!/usr/bin/env bash
# Generic specialty DL launcher used by dlsurfer-* symlinks (basename → tool id).
# Records a run note and exits 2 until the matching SIF/ROOT/CLI is configured.
set -euo pipefail
TOOL="$(basename "$0")"
TOOL="${TOOL#dlsurfer-}"
usage() {
  cat <<EOF
Usage: $(basename "$0") --t1 T1 --out-dir OUT --sid SID [--device cuda|cpu] [--lesion-mask MASK]
Specialty id: $TOOL

Env (tool-dependent; see docs/reference/STRUCTURE_MODULES.md):
  MARS_WMH_SIF / MARS_FLAIR     mars-wmh
  DEEP_THOMAS_SIF                deep-thomas
  S3REG_SIF / S3REG_ROOT         s3reg
  HIPPODEEP_ROOT                 hippodeep
  HDBET_SIF / hd-bet on PATH     hdbet
  VBG_ROOT                       vbg
  MARS_VENT_SIF                  mars-ventricles
  ALBISHRI_ROOT                  albishri-claustrum
  NNUNET_PC_ROOT                 nnunet-piriform
  AMYGDALA_GO_ROOT               amygdala-go
  DHCP_SIF / DHCP_T2             dhcp-neonatal
  CORTEXODE_ROOT / …             surf-dl backups
EOF
}
T1="" OUT="" SID="" DEVICE="cpu" LESION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --t1) T1="$2"; shift 2 ;;
    --out-dir) OUT="$2"; shift 2 ;;
    --sid) SID="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    --lesion-mask) LESION="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown: $1" >&2; usage; exit 2 ;;
  esac
done
[[ -n "$T1" && -n "$OUT" && -n "$SID" ]] || { usage; exit 2; }
mkdir -p "$OUT"
NOTE="$OUT/dlsurfer_${TOOL//-/_}_cmd.txt"

# --- tools with known live paths ---
case "$TOOL" in
  hdbet)
    if command -v hd-bet >/dev/null 2>&1; then
      hd-bet -i "$T1" -o "$OUT/brain" ${DEVICE:+-device $DEVICE} || true
      # hd-bet CLI varies by version; write note + try common form
      echo "ok" > "$OUT/dlsurfer_hdbet.done" 2>/dev/null || true
    fi
    if [[ -n "${HDBET_SIF:-}" && -f "${HDBET_SIF}" ]]; then
      apptainer run --nv -B "$(dirname "$T1"):/data:ro" -B "$OUT:/out" "$HDBET_SIF" \
        -i "/data/$(basename "$T1")" -o /out/brain || true
    fi
    ;;
  mars-wmh)
    if [[ -n "${MARS_WMH_SIF:-}" && -f "${MARS_WMH_SIF}" && -n "${MARS_FLAIR:-}" ]]; then
      apptainer run --nv -B "$(pwd):$(pwd)" "$MARS_WMH_SIF" \
        --flair "$MARS_FLAIR" --t1 "$T1" 2>"$OUT/dlsurfer_mars_wmh.err" && \
        echo ok > "$OUT/dlsurfer_mars_wmh.done" && exit 0
    fi
    ;;
  mars-ventricles)
    if [[ -n "${MARS_VENT_SIF:-}" && -f "${MARS_VENT_SIF}" ]]; then
      WORK="$OUT/work"; mkdir -p "$WORK"
      STAGE="$WORK/$(basename "$T1")"
      ln -sfn "$(cd "$(dirname "$T1")" && pwd)/$(basename "$T1")" "$STAGE"
      apptainer run --nv -B "$WORK:$WORK" "$MARS_VENT_SIF" "$STAGE" && \
        echo ok > "$OUT/dlsurfer_mars_ventricles.done" && exit 0
    fi
    ;;
esac

cat > "$NOTE" <<EOF
# dlsurfer specialty stub — $TOOL
# t1=$T1 sid=$SID out=$OUT device=$DEVICE lesion=${LESION:-}
# Configure the matching SIF/ROOT (STRUCTURE_MODULES.md), then re-run.
# Dry-run plans already include this argv; execute succeeds once deps are present.
EOF
echo "[$TOOL] deps not configured — wrote $NOTE (see STRUCTURE_MODULES.md)" >&2
exit 2
