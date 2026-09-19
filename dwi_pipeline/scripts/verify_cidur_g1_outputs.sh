#!/usr/bin/env bash
# Verify CIDUR Group 1 rigid-reg connectome + nodestrength outputs per subject.
#
# Usage:
#   bash dwi_pipeline/scripts/verify_cidur_g1_outputs.sh
#   RESULTS_ROOT=/path SUBJECT_LIST_FILE=/path/to/list.txt bash dwi_pipeline/scripts/verify_cidur_g1_outputs.sh
#   REQUIRE_QC=1 bash dwi_pipeline/scripts/verify_cidur_g1_outputs.sh   # also require subject_qc.json
#
# Exit 0 only if every listed subject passes all required checks.

set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_ROOT="${RESULTS_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results}"
SUBJECT_LIST_FILE="${SUBJECT_LIST_FILE:-${DWI_ROOT}/subject_list_cidur_g1_rigid_reg_rerun.txt}"
TRACTOGRAPHY_MODEL="${TRACTOGRAPHY_MODEL:-both}"
REQUIRE_QC="${REQUIRE_QC:-0}"

[[ -s "${SUBJECT_LIST_FILE}" ]] || {
  echo "Missing subject list: ${SUBJECT_LIST_FILE}" >&2
  exit 1
}

check_file() {
  local path="$1"
  [[ -f "${path}" && -s "${path}" ]]
}

check_subject() {
  local subject="$1"
  local sid="sub-${subject}"
  local conn="${RESULTS_ROOT}/connectomes/${sid}"
  local missing=()

  local -a ifod2=(
    "${conn}/dkt_connectome.csv"
    "${conn}/dkt_connectome_count.csv"
    "${conn}/dkt_connectome_sift2.csv"
    "${conn}/dkt_connectome_meanlength.csv"
    "${conn}/dkt_connectome_meanfa.csv"
    "${conn}/dkt_connectome_meanmd.csv"
    "${conn}/dkt_desc-FA_dwi.nii.gz"
    "${conn}/dkt_desc-MD_dwi.nii.gz"
    "${conn}/dkt_nodes.mif"
    "${conn}/parcellation.json"
    "${conn}/fs_to_preproc_T1w_0GenericAffine.mat"
  )
  local -a sdstream=(
    "${conn}/dkt_model-SDSTREAM_connectome_count.csv"
    "${conn}/dkt_model-SDSTREAM_connectome_sift2.csv"
    "${conn}/dkt_model-SDSTREAM_connectome_meanlength.csv"
    "${conn}/dkt_model-SDSTREAM_connectome_meanfa.csv"
    "${conn}/dkt_model-SDSTREAM_connectome_meanmd.csv"
    "${conn}/dkt_model-SDSTREAM_connectome.json"
  )
  local -a nodestrength=(
    "${RESULTS_ROOT}/node_strength/strength/per_subject/${sid}_strength.csv"
    "${RESULTS_ROOT}/node_strength/reports/${sid}/report.pdf"
  )

  local f
  for f in "${ifod2[@]}"; do
    check_file "${f}" || missing+=("$(basename "${f}")")
  done

  if [[ "${TRACTOGRAPHY_MODEL}" =~ ^(both|sd_stream|sdstream)$ ]]; then
    for f in "${sdstream[@]}"; do
      check_file "${f}" || missing+=("$(basename "${f}")")
    done
  fi

  for f in "${nodestrength[@]}"; do
    check_file "${f}" || missing+=("$(basename "${f}")")
  done

  if [[ "${REQUIRE_QC}" == "1" ]]; then
    check_file "${RESULTS_ROOT}/qc/${sid}/subject_qc.json" \
      || missing+=("subject_qc.json")
  fi

  if ((${#missing[@]} == 0)); then
    echo "OK"
    return 0
  fi
  echo "MISSING: ${missing[*]}"
  return 1
}

fail=0
ok=0
printf "%-10s %-6s %s\n" "SUBJECT" "STATUS" "DETAIL"
printf "%-10s %-6s %s\n" "-------" "------" "------"

while IFS= read -r line || [[ -n "${line}" ]]; do
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "${line}" || "${line}" == \#* ]] && continue
  subject="${line#sub-}"

  if out="$(check_subject "${subject}")"; then
    printf "%-10s %-6s %s\n" "${subject}" "OK" ""
    ((ok++)) || true
  else
    printf "%-10s %-6s %s\n" "${subject}" "FAIL" "${out#OK}"
    ((fail++)) || true
  fi
done < "${SUBJECT_LIST_FILE}"

echo ""
echo "Summary: ${ok} OK, ${fail} FAIL (${ok}+${fail} checked)"
echo "  RESULTS_ROOT=${RESULTS_ROOT}"
echo "  TRACTOGRAPHY_MODEL=${TRACTOGRAPHY_MODEL} REQUIRE_QC=${REQUIRE_QC}"

if ((fail == 0)); then
  echo "All subjects have expected Step 4 (IFOD2+SDSTREAM+SIFT2) and Step 5 outputs."
  exit 0
fi
echo "Incomplete: ${fail} subject(s) missing required outputs."
exit 1
