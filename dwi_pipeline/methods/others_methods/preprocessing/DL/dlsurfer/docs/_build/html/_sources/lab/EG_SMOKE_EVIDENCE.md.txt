# EG smoke evidence — `core_lesion_eg_smoke`

**Date:** 2026-10-23  
**Subject:** Gugger PTE **sub-EG**  
**Gate status:** **passed** (orchestration + prior completed science path)

## What we verified

| Check | Result |
|-------|--------|
| `source env/cluster_containers.sh` → `dlsurfer doctor` | **[READY]** core deps (Apptainer SIFs) |
| `dlsurfer run --profile core-lesion` dry-run | Plan: lit-inpainting → FastSurfer `--seg_only` → `--surf_only` → lit-post |
| Container SIFs | `fastsurfer_cu126_v2.6.0.sif`, `lit_0.6.0.sif`, `freesurfer_7.4.1.sif` |
| Inputs | T1 `…/Gugger_Lab/PTE/EG/Nii/DICOM_Ax_3D_T1_MP-RAGE_*.nii.gz` · Lesion `…/Lesion.nii.gz` |
| Prior EG **standalone** arm C (same profile science) | **Done** — `recon-surf.done`, surfaces, LIT posthoc (`COMPARISON_EG.md`) |

Reference tree (read-only symlink):

`work/evidence/sub-EG_standalone_fs26_ref`  
→ `…/gugger_eg_lit/fastsurfer_inpainting/standalone/fastsurfer_v2.6/subjects/sub-EG`

## Why not a second full `--execute` on the login node

- Login node has **no GPU** (`nvidia-smi` missing).  
- CPU LIT fill estimated **~50 h** (aborted).  
- Full FastSurfer+LIT for EG **already completed** on this cluster (jobs 191907 / 191927 / posthoc) — identical standalone path that `core-lesion` orchestrates.

GPU confirmatory re-run under DLSurfer (inpainted T1 → FastSurfer core):

| Item | Result |
|------|--------|
| Job | **191960 COMPLETED** (01:56:33 wall) |
| Tree | `work/eg_gpu_core_lesion/sub-EG` |
| Markers | `recon-surf.done`, `dlsurfer_eg_gpu_core_lesion.done`, contract OK |
| Compute | ~829 s CUDA seg + ~6162 s CPU surf (`dlsurfer_metrics.tsv`) |
| lit-post | WARN missing `inpainting/inpainting_mask.nii.gz` (non-fatal; fill reused) |

```bash
source env/cluster_containers.sh
sbatch hpc/sbatch_eg_gpu_core_lesion.sh   # already done: 191960
python scripts/compare_metrics_slurm.py \
  --metrics work/eg_gpu_core_lesion/sub-EG/scripts/dlsurfer_metrics.tsv \
  --jobid 191960
```

## Policy note

Wrapping FastSurfer/FS remains correct for SUBJECTS_DIR; see [`ENGINE_POLICY.md`](../reference/ENGINE_POLICY.md).
