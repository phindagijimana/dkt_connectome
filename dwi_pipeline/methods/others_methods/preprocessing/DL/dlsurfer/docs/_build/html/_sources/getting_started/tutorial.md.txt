# Tutorial — first run

First run? Use this page, not the full CLI reference (same advice as DKT Connectome’s Tutorial).

## 1. Install tools

```bash
git clone https://github.com/phindagijimana/dlsurfer.git
cd dlsurfer
pip install -e .
source env/cluster_containers.sh   # points at lab SIFs + FS_LICENSE
dlsurfer doctor                    # expect [READY]
```

Details: [Installation](../installation/index.md).

## 2. Dry-run a plan (no compute)

```bash
dlsurfer smoke
# or:
dlsurfer run --profile core-lesion \
  --t1 /path/T1.nii.gz \
  --lesion-mask /path/lesion.nii.gz \
  --sd /tmp/dlsurfer_tut --sid sub-01 \
  --fs-license $FS_LICENSE
```

You should see lit-inpainting → FastSurfer `--seg_only` → `--surf_only` → lit-post, with citations on each step.

## 3. Execute on a GPU node (optional)

```bash
dlsurfer run --profile core-lesion \
  --t1 /path/T1.nii.gz --lesion-mask /path/lesion.nii.gz \
  --sd ./subjects --sid sub-01 \
  --fs-license $FS_LICENSE --device cuda --execute
```

Or submit `hpc/sbatch_eg_gpu_core_lesion.sh` after editing paths.

## 4. Check outputs

```text
subjects/sub-01/mri/aparc.DKTatlas+aseg.deep.mgz
subjects/sub-01/surf/lh.white
subjects/sub-01/scripts/dlsurfer_metrics.tsv
```

Layout: [Outputs](../outputs/layout.md). QC notes: [Quality control](../usage/qc.md).

## Public / lab evidence

EG (Gugger PTE) standalone FastSurfer 2.6 + LIT already completed on-cluster — [EG smoke](../lab/EG_SMOKE_EVIDENCE.md). TopoFit ±LIT machine score: [TBI ± LIT report](../lab/TBI_LIT_SURFACES_REPORT.md).
