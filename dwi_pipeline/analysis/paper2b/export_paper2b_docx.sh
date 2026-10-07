#!/usr/bin/env bash
# Regenerate .docx siblings for paper2b_imaging markdown cluster.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
DOCS="${REPO}/dwi_pipeline/docs/papers/paper2b_imaging"
CONVERT="${REPO}/dwi_pipeline/scripts/md_to_docx.py"

if [[ ! -f "${CONVERT}" ]]; then
    echo "ERROR: missing ${CONVERT}" >&2
    exit 1
fi

shopt -s nullglob
for md in "${DOCS}"/*.md; do
    base="$(basename "${md}" .md)"
    python3 "${CONVERT}" "${md}" "${DOCS}/${base}.docx"
done

echo "Paper 2B docx export complete: ${DOCS}/"
