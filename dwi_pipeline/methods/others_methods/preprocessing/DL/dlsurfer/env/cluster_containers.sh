# Source before dlsurfer doctor / run on this cluster (Apptainer SIFs).
#   source env/cluster_containers.sh
set -a

_DLS_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_DLS_ROOT="$(cd "${_DLS_ENV}/.." && pwd)"

# --- SIFs (lab Documents/others/containers) ---
DLSURFER_CONTAINERS="${DLSURFER_CONTAINERS:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers}"
DLSURFER_SIF_FASTSURFER="${DLSURFER_SIF_FASTSURFER:-${DLSURFER_CONTAINERS}/fastsurfer_cu126_v2.6.0.sif}"
DLSURFER_SIF_FREESURFER="${DLSURFER_SIF_FREESURFER:-${DLSURFER_CONTAINERS}/freesurfer_7.4.1.sif}"
DLSURFER_SIF_LIT="${DLSURFER_SIF_LIT:-${DLSURFER_CONTAINERS}/lit_0.6.0.sif}"

# --- License ---
FS_LICENSE="${FS_LICENSE:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/.freesurfer/license.txt}"

# --- Homes for doctor / plan expansion ---
FASTSURFER_HOME="${_DLS_ENV}/fastsurfer_home"
FREESURFER_HOME="${_DLS_ENV}/freesurfer_home"

# Wrappers on PATH (lit-*, recon-all, mri_*)
PATH="${_DLS_ENV}/bin:${PATH}"

# Broad bind for NFS data + license
DLSURFER_APPTAINER_BINDS="${DLSURFER_APPTAINER_BINDS:--B /mnt/nfs -B ${FS_LICENSE}:${FS_LICENSE}:ro}"

# --- Schaefer annots (Yeo/CBIG 400 parcels / 17 networks on fsaverage) ---
_SCH_LABEL="${_DLS_ROOT}/resources/schaefer2018/fsaverage/label"
SCHAEFER_ANNOT_LH="${SCHAEFER_ANNOT_LH:-${_SCH_LABEL}/lh.Schaefer2018_400Parcels_17Networks_order.annot}"
SCHAEFER_ANNOT_RH="${SCHAEFER_ANNOT_RH:-${_SCH_LABEL}/rh.Schaefer2018_400Parcels_17Networks_order.annot}"

# --- V2C-Flow (literature-best Ready full CSR) ---
V2C_ROOT="${V2C_ROOT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/Vox2Cortex}"

# --- SynthSeg-PC (experimental vs JLF; production PC stays JLF until gate) ---
SYNTHSEG_PC_ROOT="${SYNTHSEG_PC_ROOT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/piriform/synthseg_pc}"
if [[ -f "${SYNTHSEG_PC_ROOT}/paths.sh" ]]; then
  # shellcheck disable=SC1091
  source "${SYNTHSEG_PC_ROOT}/paths.sh"
fi
SYNTHSEG_PC_MODEL="${SYNTHSEG_PC_MODEL:-${SYNTHSEG_PC_ROOT}/models/fold0/dice_016.h5}"
SYNTHSEG_PC_LABELS="${SYNTHSEG_PC_LABELS:-${SYNTHSEG_PC_ROOT}/config/segmentation_labels.npy}"
# Hammers fold-0 FoV val set (aliases → prepare_labels.py val_*)
SSP_IMG_DIR="${SSP_IMG_DIR:-${SYNTHSEG_PC_ROOT}/data/hammers_val_img}"
SSP_GT_DIR="${SSP_GT_DIR:-${SYNTHSEG_PC_ROOT}/data/hammers_val_gt}"

set +a

export DLSURFER_ROOT="$_DLS_ROOT"
export DLSURFER_CONTAINERS DLSURFER_SIF_FASTSURFER DLSURFER_SIF_FREESURFER DLSURFER_SIF_LIT
export FS_LICENSE FASTSURFER_HOME FREESURFER_HOME PATH DLSURFER_APPTAINER_BINDS
export SCHAEFER_ANNOT_LH SCHAEFER_ANNOT_RH V2C_ROOT
export SYNTHSEG_PC_ROOT SYNTHSEG_PC_MODEL SYNTHSEG_PC_LABELS SSP_IMG_DIR SSP_GT_DIR
export SYNTHSEG_ROOT="${SYNTHSEG_ROOT:-}"

echo "[dlsurfer env] containers ready"
echo "  FASTSURFER_HOME=$FASTSURFER_HOME"
echo "  FREESURFER_HOME=$FREESURFER_HOME"
echo "  FS_LICENSE=$FS_LICENSE"
echo "  SIF_FASTSURFER=$DLSURFER_SIF_FASTSURFER"
echo "  SIF_LIT=$DLSURFER_SIF_LIT"
echo "  SIF_FREESURFER=$DLSURFER_SIF_FREESURFER"
echo "  SCHAEFER_ANNOT_LH=$SCHAEFER_ANNOT_LH"
echo "  V2C_ROOT=$V2C_ROOT"
echo "  SYNTHSEG_PC_MODEL=$SYNTHSEG_PC_MODEL"

# --- Phase-3 gate tools ---
SUGAR_ROOT="${SUGAR_ROOT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/SUGAR}"
SUGAR_SIF="${SUGAR_SIF:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/containers/sugar_latest.sif}"
SUGAR_MODEL_PATH="${SUGAR_MODEL_PATH:-${SUGAR_ROOT}/pretrained}"
CORTEXMORPH_ROOT="${CORTEXMORPH_ROOT:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/CortexMorph}"
export SUGAR_ROOT SUGAR_SIF SUGAR_MODEL_PATH CORTEXMORPH_ROOT

# --- Specialty DL gap-fills (Ready → live when SIF/tool present) ---
HIPPUNFOLD_SIF="${HIPPUNFOLD_SIF:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/HippUnfold/khanlab_hippunfold_latest.sif}"
HIPPUNFOLD_CACHE_DIR="${HIPPUNFOLD_CACHE_DIR:-${HOME}/hippunfold_cache}"
HIPPUNFOLD_RUN="${HIPPUNFOLD_RUN:-/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/HippUnfold/run_hippunfold.sh}"
MARS_SIF="${MARS_SIF:-${DLSURFER_CONTAINERS}/mars_brainstem_nnunet.sif}"
IBEAT_SIF="${IBEAT_SIF:-${DLSURFER_CONTAINERS}/ibeat_v2_release205.sif}"
IBEAT_AGE_MONTHS="${IBEAT_AGE_MONTHS:-}"  # required for infant-ibeat execute
# Prefer dedicated V2C-Long checkout (not Vox2Cortex); fall back only if missing.
_V2C_LONG_DEFAULT="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/V2C-Long"
if [[ -z "${V2C_LONG_ROOT:-}" ]]; then
  if [[ -f "${_V2C_LONG_DEFAULT}/vox2organ/main.py" ]]; then
    V2C_LONG_ROOT="${_V2C_LONG_DEFAULT}"
  else
    V2C_LONG_ROOT="${V2C_ROOT}"
  fi
fi
unset _V2C_LONG_DEFAULT
export HIPPUNFOLD_SIF HIPPUNFOLD_CACHE_DIR HIPPUNFOLD_RUN
export MARS_SIF IBEAT_SIF IBEAT_AGE_MONTHS V2C_LONG_ROOT
# Only export SIF paths if the file exists (doctor treats unset vs missing differently via file check)
[[ -f "$HIPPUNFOLD_SIF" ]] || unset HIPPUNFOLD_SIF
[[ -f "$MARS_SIF" ]] || unset MARS_SIF
[[ -f "$IBEAT_SIF" ]] || unset IBEAT_SIF
echo "  HIPPUNFOLD_SIF=${HIPPUNFOLD_SIF:-unset}"
echo "  MARS_SIF=${MARS_SIF:-unset (pull: docker://ghcr.io/miac-research/brainstem-nnunet:latest)}"
echo "  IBEAT_SIF=${IBEAT_SIF:-unset (pull: docker://ibeatgroup/ibeat_v2:release205)}"

# Optional expanded specialty (unset until files exist)
MARS_WMH_SIF="${MARS_WMH_SIF:-${DLSURFER_CONTAINERS}/mars_wmh_nnunet.sif}"
MARS_VENT_SIF="${MARS_VENT_SIF:-${DLSURFER_CONTAINERS}/mars_ventricles.sif}"
[[ -f "${MARS_WMH_SIF}" ]] && export MARS_WMH_SIF || unset MARS_WMH_SIF
[[ -f "${MARS_VENT_SIF}" ]] && export MARS_VENT_SIF || unset MARS_VENT_SIF
# Pass-through if user already set: DEEP_THOMAS_SIF HDBET_SIF S3REG_SIF HIPPODEEP_ROOT VBG_ROOT DHCP_SIF MARS_FLAIR
export MARS_FLAIR="${MARS_FLAIR:-}" DEEP_THOMAS_SIF="${DEEP_THOMAS_SIF:-}" HDBET_SIF="${HDBET_SIF:-}" \
  S3REG_SIF="${S3REG_SIF:-}" HIPPODEEP_ROOT="${HIPPODEEP_ROOT:-}" VBG_ROOT="${VBG_ROOT:-}" \
  DHCP_SIF="${DHCP_SIF:-}" DHCP_T2="${DHCP_T2:-}" NNUNET_PC_ROOT="${NNUNET_PC_ROOT:-}" \
  ALBISHRI_ROOT="${ALBISHRI_ROOT:-}" AMYGDALA_GO_ROOT="${AMYGDALA_GO_ROOT:-}" 2>/dev/null || true
