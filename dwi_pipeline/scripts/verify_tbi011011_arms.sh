#!/usr/bin/env bash
# Verify TBI011011 (or custom) factorial arm completeness: connectome, disconnectome, QC.
#
# Usage:
#   bash dwi_pipeline/scripts/verify_tbi011011_arms.sh
#   EXP=/path/to/sub-TBI011011_fastsurfer_experiment SUBJECT=TBI011011 bash dwi_pipeline/scripts/verify_tbi011011_arms.sh
#
# Exit 0 only if every listed arm has connectome + disconnectome + QC overall_status=PASS.

set -euo pipefail

EXP="${EXP:-/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/sub-TBI011011_fastsurfer_experiment}"
SUBJECT="${SUBJECT:-TBI011011}"
SUBJECT="${SUBJECT#sub-}"
SID="sub-${SUBJECT}"

ARMS=(
  orig-std
  orig-lesion
  neurolit-std
  neurolit-lesion
  vbt-std
  vbt-lesion
  deep-atropos-pilot
)

fail=0
printf "%-20s %-12s %-14s %-8s\n" "ARM" "CONNECTOME" "DISCONNECTOME" "QC"
printf "%-20s %-12s %-14s %-8s\n" "---" "----------" "------------" "--"

for arm in "${ARMS[@]}"; do
  base="${EXP}/arms/${arm}"
  conn="${base}/connectomes/${SID}/dkt_connectome.csv"
  disc="${base}/connectomes/${SID}/disconnectome/disconnection_matrix.csv"
  qc="${base}/qc/${SID}/subject_qc.json"

  if [[ -f "${conn}" ]]; then
    conn_st=yes
  else
    conn_st=NO
    ((fail++)) || true
  fi

  if [[ -f "${disc}" ]]; then
    disc_st=yes
  else
    disc_st=NO
    ((fail++)) || true
  fi

  if [[ -f "${qc}" ]]; then
    qc_st="$(python3 -c "import json; print(json.load(open('${qc}'))['overall_status'])")"
    [[ "${qc_st}" == PASS ]] || ((fail++)) || true
  else
    qc_st=MISSING
    ((fail++)) || true
  fi

  printf "%-20s %-12s %-14s %-8s\n" "${arm}" "${conn_st}" "${disc_st}" "${qc_st}"
done

echo ""
if ((fail == 0)); then
  echo "OK: all ${#ARMS[@]} arms have connectome, disconnectome, and QC PASS."
  exit 0
fi
echo "INCOMPLETE: ${fail} check(s) failed."
exit 1
