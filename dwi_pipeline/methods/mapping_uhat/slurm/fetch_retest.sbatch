#!/bin/bash
# Public same-day retest download. Not leftover y. Not gold.
#SBATCH --job-name=retest_fetch
#SBATCH --partition=interactive
#SBATCH --time=4:00:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data/_download_logs/fetch_retest_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data/_download_logs/fetch_retest_%j.err
set -u
ROOT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub/dwi_pipeline/sample_data
KDIR=${ROOT}/kirby21/raw
BDIR=${ROOT}/boekel_dwi_retest/raw
LOG=${ROOT}/_download_logs
mkdir -p "${KDIR}" "${BDIR}" "${LOG}"

get_one() {
  local url="$1" dest="$2" insecure="${3:-0}"
  mkdir -p "$(dirname "${dest}")"
  if [[ -s "${dest}" && $(stat -c%s "${dest}") -gt 1000000 ]]; then
    echo "[skip] $(basename "${dest}") already $(stat -c%s "${dest}")"
    return 0
  fi
  rm -f "${dest}"
  local extra=()
  if [[ "${insecure}" == "1" ]]; then
    extra+=(--no-check-certificate)
  fi
  echo "[get] ${url}"
  if wget -c --tries=8 --timeout=90 --waitretry=8 "${extra[@]}" -O "${dest}" "${url}"; then
    echo "[ok] $(basename "${dest}") $(stat -c%s "${dest}")"
    return 0
  fi
  echo "[fail] ${url}" >&2
  return 1
}

fail=0
get_one "https://www.nitrc.org/frs/download.php/3978/KirbyResourceProposal_Version_3_Demographics_Revised.pdf" \
  "${KDIR}/KirbyResourceProposal_Version_3_Demographics_Revised.pdf" || true
for i in $(seq -w 1 42); do
  get_one "https://multimodal.projects.nitrc.org/downloads/kki2009/KKI2009-${i}.tar.bz2" \
    "${KDIR}/KKI2009-${i}.tar.bz2" || fail=$((fail+1))
done

get_one "https://www.nitrc.org/frs/download.php/10333/Error_in_the_affine_matrix.pdf" \
  "${BDIR}/Error_in_the_affine_matrix.pdf" || true
for i in $(seq -w 1 34); do
  get_one "https://dwi_test-retest.projects.nitrc.org/pp${i}_v2.tar.gz" \
    "${BDIR}/pp${i}_v2.tar.gz" 1 || fail=$((fail+1))
done

python3 "${LOG}/inventory_retest.py"
echo "[done] fail=${fail} $(date -Is)"
exit 0
