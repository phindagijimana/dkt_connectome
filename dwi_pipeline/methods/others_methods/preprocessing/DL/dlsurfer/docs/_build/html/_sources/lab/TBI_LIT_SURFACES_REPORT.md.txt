# TBI ± LIT — surface DL gate report

**Date:** 2026-10-23–24  
**TopoFit gate:** **passed** (`tbi_lit_topofit`) — machine + Chamfer soft QC  
**V2C gate:** **open** (`tbi_lit_surfaces` — literature-best Ready full CSR)  
**SUGAR / DL-CTE:** separate open gates (sphere / thickness-only)  
**Piriform:** production stays **JLF** until SynthSeg-PC eval (`synthseg_pc_vs_jlf`)

## Literature picks (one per stage)

| Stage | Chosen | Why |
|-------|--------|-----|
| Full CSR (Phase 3) | **V2C-Flow** | Best Ready joint WM+pial + template IDs (Bongratz MedIA 2024); over CortexODE/PialNN |
| sphere.reg alt | **SUGAR** | Multi-dataset / speed (Ren 2023) > S3Reg |
| Thickness w/o mesh | **DL-CTE family** | Fast biomarker path; never for connectome |
| Piriform production | **JLF** | Best deployed IDEAS method until PC clears Hammers bar |

## TopoFit — machine + Chamfer QC

Score: `work/phase3_topofit/topofit_tbi_lit_score.json`  
FreeView: `work/phase3_topofit/freeview_topofit_qc.sh`

| Metric | with-LIT lh/rh | no-LIT |
|--------|----------------|--------|
| `*.white.topofit` | yes / yes | yes / yes |
| mean Chamfer vs recon-surf white | ~2.2–2.7 mm | similar |
| hausdorff_95 | ~10–14 mm | elevated (unequal topology) |

`machine_ok=true`, `chamfer_soft_ok=true` (≤4 mm). Visual QC: run FreeView script (red=TopoFit+LIT, yellow=noLIT, green=recon-surf).

## V2C-Flow — install path

- Clone: `Documents/others/Vox2Cortex` (pretrained `V2C-Flow-S-ADNI`)  
- Wrapper: `env/bin/dlsurfer-v2c`  
- Job: `sbatch hpc/sbatch_phase3_v2c_tbi_lit.sh` after `conda env create -f requirements.yml` (+ pytorch3d) or their Docker wheel under `Vox2Cortex/docker/`  
- Gate stays **open** until ±LIT inference succeeds and meshes are scored

## Baseline recon-surf (EG)

Standalone LIT (`core-lesion`) validated on EG vs native LIT — see prior COMPARISON_EG.md. GPU confirmatory job **191960 COMPLETED** (`work/eg_gpu_core_lesion`, `recon-surf.done`).
