# TBI ± LIT — surface DL gate report

**Date:** 2026-10-23–25  
**TopoFit gate:** **passed** (`tbi_lit_topofit`) — machine + Chamfer soft QC  
**V2C gate:** **passed** (`tbi_lit_surfaces` — literature-best Ready full CSR)  
**SUGAR gate:** **passed** (`tbi_lit_sphere_sugar`) — lh-only pretrained, job **192095**  
**V2C-Long gate:** **passed** (`tbi_lit_v2c_long`) — TrackTBI 2TP ±LIT, job **192111**  
**DL-CTE:** thickness gate passed (`tbi_lit_thickness`)  
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
- Venv: `work/phase3_gates/envs/v2c` (torch 2.6+cu124, fabibo3 pytorch3d, PyG wheels)  
- Runner: `scripts/run_v2c_main.py` (torch.load `weights_only=False` for PT 2.6 checkpoints)  
- Job: `sbatch hpc/sbatch_phase3_v2c_tbi_lit.sh` (`ensure_pyg` pins nibabel 4.0.2, pymeshlab 2022.2, pandas 1.4.2)  
- Gate **passed** after job **192088** ±LIT inference **and** FS `surf/*.white|*.pial` install (2026-10-24)

### V2C-Flow — ±LIT machine run (2026-10-24)

| Job | State | Notes |
|-----|-------|-------|
| 192082 | FAILED | `ModuleNotFoundError: torch_geometric` |
| 192083–192087 | FAILED | PT2.6 checkpoint load, nibabel int64, pymeshlab API, pandas groupby |
| **192088** | **COMPLETED** | Both arms inference OK (~9m41s) |

**Inference (job 192088):** `work/phase3_v2c/{with_lit,no_lit}/sub-EG/scripts/dlsurfer_v2c.done` = `ok`, exit `0`.  
Meshes (binary PLY, epoch 102):

| Arm | Vox2Cortex dir | lh.white | rh.white | lh.pial | rh.pial |
|-----|----------------|----------|----------|---------|---------|
| with-LIT | `…/sub-EG/` | `lh_white_epoch_102.ply` | `rh_white_epoch_102.ply` | `lh_pial_epoch_102.ply` | `rh_pial_epoch_102.ply` |
| no-LIT | `…/sub-EG_nolit/` | same naming | same | same | same |

Base: `Documents/others/Vox2Cortex/experiments/V2C-Flow-S-ADNI/test_template_fsaverage-smooth-no-parc_dlsurfer_t1_n_5/`.

**FS contract (fixed):** `dlsurfer/adapters/surfaces_fs.py` reads binary PLY with **trimesh** and writes FreeSurfer geometry via **nibabel** (`nibabel_fs_geometry`), avoiding `mris_convert` SIGSEGV. Manual install (per-arm `--search-dir`):

- with-LIT → `work/phase3_v2c/with_lit/sub-EG/surf/{lh,rh}.{white,pial}` + `scripts/dlsurfer_surf_dl.done`
- no-LIT → `work/phase3_v2c/no_lit/sub-EG/surf/…` (search `sub-EG_nolit` PLY dir)

**machine_ok=true** for ±LIT inference + FS packaging. Chamfer vs `work/eg_gpu_core_lesion` recon-surf (~4.1–4.3 mm mean; H95 ~12–13 mm) — see `work/phase3_v2c/v2c_tbi_lit_score.json`. **Not** claimed equal to classical recon-surf morphometry.

## V2C-Long — TrackTBI longitudinal ±LIT (2026-10-26)

| Item | Value |
|------|--------|
| Job (final) | **192111** COMPLETED (~3m9s; prior debug **192096–192108**) |
| Cohort | **sub-TBI011021** `TrackTBI_Lesion` **ses-2WK** + **ses-6MO** native T1; **2WK** `*_label-lesion_roi.nii.gz` for LIT arm |
| V2C-Long root | `Documents/others/V2C-Long` (`vox2organ` + `public_experiments/{v2c-flow-s_base,v2c-long}`) |
| Runner | `hpc/sbatch_phase3_v2c_long_tbi_lit.sh` → `dlsurfer-v2c-long` (3-step flow → mean meshes → v2c-long) |
| Venv | `work/phase3_gates/envs/v2c` (torch 2.6+cu124, fabibo3 pytorch3d MeshesXD, PyG, torchio) |
| Score | `work/phase3_v2c_long/v2c_long_tbi_lit_score.json` (`machine_ok=true` both arms) |

**Arms:** with-LIT uses stable inpaint `work/phase3_v2c_long/staging/with_lit/inpainted_2wk.nii.gz` (from LIT on 2WK) + native 6MO; no-LIT uses native 2WK+6MO. SynthSeg aseg via `scripts/synthseg_t1_aseg.sh`; visits staged under `work/phase3_v2c_long/v2c_long_raw_{with_lit,no_lit}/`.

**Outputs:** `work/phase3_v2c_long/{with_lit,no_lit}/sub-TBI011021/scripts/dlsurfer_v2c_long.done` = `ok`; flow/mean/long exit `0`. PLY meshes under `V2C-Long/public_experiments/…/TEST_DATASET_LONG_n_5/` (listed in `dlsurfer_v2c_long_meshes.txt`). `dlsurfer-install-surfaces` FS surf copy may remain partial (`fs_install_exit=1`) — gate is on DL longitudinal inference, not morphometric equivalence to fs-long.

**Fixes landed for this gate:** LIT output path fallbacks + stable copy; PyG→pytorch3d bootstrap order; `torchio` pip extra; upstream `combine_labels` dict patch (`scripts/patch_v2c_long_supported_datasets.py`); `create_mean_meshes.py --csv-file $V2C_LONG_CSV`.

## SUGAR — ±LIT sphere.reg (2026-10-25)

| Item | Value |
|------|--------|
| Job (final) | **192095** COMPLETED (~14s no-LIT rerun; with-LIT on **192094**) |
| FSD / ICO templates | `SUGAR_FSD` → `Documents/others/data_mining/freesurfer` (real fsaverage3–6; **not** FastSurfer fsaverage symlinks) |
| Runner | `hpc/sbatch_phase3_sugar_tbi_lit.sh` → `scripts/run_sugar_predict.py` (PyG **2.2.0** + featreg shim) |
| Score | `work/phase3_sugar/sugar_tbi_lit_score.json` (`machine_ok=true`) |

**Arms:** with-LIT `work/eg_gpu_core_lesion`; no-LIT native FastSurfer `…/native_lesion_mask/fastsurfer_v2.6/subjects`.

**Outputs (lh):** `work/phase3_sugar/{with_lit,no_lit}/sub-EG/scripts/dlsurfer_sugar.done`, `surf/lh.sphere.reg` (from `lh.rigid.interp_fsaverage6.sphere.reg` via `dlsurfer-install-surfaces --backend sugar --mode sphere --allow-partial-sphere`).

**rh note:** public SUGAR pretrained is **lh-only** (`pretrained/lh_*`). Gate passes on lh sphere.reg for both arms; `rh.sphere.reg` under the install tree may be copied from existing recon-surf if discover finds it — use lh for DL atlas transfer unless rh weights are added later.

## Baseline recon-surf (EG)

Standalone LIT (`core-lesion`) validated on EG vs native LIT — see prior COMPARISON_EG.md. GPU confirmatory job **191960 COMPLETED** (`work/eg_gpu_core_lesion`, `recon-surf.done`).
