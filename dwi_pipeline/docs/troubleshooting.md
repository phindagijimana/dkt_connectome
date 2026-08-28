# Troubleshooting

Common failures and fixes. The pipeline **fails loudly** rather than silently skipping steps.

---

## Before you run

| Symptom | Cause | Fix |
|---------|-------|-----|
| `bids-validator` errors | BIDS layout issues | `bash scripts/run_bids_validator.sh BIDS_DIR`; fix sidecars |
| `FS_LICENSE` missing | No FreeSurfer license on your machine | Register at [FreeSurfer](https://surfer.nmr.mgh.harvard.edu/registration.html); `export FS_LICENSE=/path/to/your/license.txt` — [Installation](installation.md#freesurfer-license-you-must-obtain-this) |
| Container not found | Wrong `.sif` path | Set `CONTAINER_*` or `config.local.yaml` → [Configuration](configuration.md) |
| `snakemake not found` | Missing on PATH | `pip install snakemake` or `module load` |

---

## Step 1 — QSIPrep

| Error / symptom | Fix |
|-----------------|-----|
| `KeyError: 'TotalReadoutTime'` | Repair DWI JSON sidecars — [Preparing your data](preparing_data.md) |
| SDC failure, no fieldmap | Add `--syn`, `--fmap-retry`, or `--no-sdc` |
| Wrong DWI series processed | Check `--dwi-shell` / `--dwi-select`; use `--session-filter` |
| Multiple sessions ambiguous | Pass `--session-filter ses-X` |

---

## Step 1.1 — Inpaint

| Error / symptom | Fix |
|-----------------|-----|
| Step skipped silently | No lesion mask for session (expected) |
| `inpainting_qc.json` `ok: false` | Check `outside_lesion_correlation`; set `INPAINT_FAIL_ON_QC=1` to hard-fail |
| GPU OOM | Lower `INPAINT_BATCH_SIZE` (default 4); request larger GPU slice |
| Wrong grid / geometry | Ensure LIT ran with `--keepgeom` (pipeline default) |

---

## Step 2 — Recon

| Error / symptom | Fix |
|-----------------|-----|
| recon-all very slow | Use `--fastsurfer` (~1–2 h vs ~10 h) |
| Missing `aparc+aseg.mgz` | Check `logs/sub-*_recon.log`; verify license |
| FastSurfer cuda fails | Set `RECON_FASTSURFER_DEVICE=cpu` |

---

## Step 3 — QSIRecon

| Error / symptom | Fix |
|-----------------|-----|
| Missing FreeSurfer for ACT-hsvs | Run Step 2 first, or use ACT-fast spec |
| QSIPrep outputs missing | Run `qsiprep` mode first; check markers in `.snakemake_markers/` |

---

## Step 3.1 — Lesion-aware ACT

| Error / symptom | Fix |
|-----------------|-----|
| `no file found for sub-*` (wm-fod) | QSIRecon not finished; if `qsirecon_single_run_output` is a **symlink**, pipeline uses `find -L` — verify target has `*model-ss3t_param-fod_label-WM_dwimap.mif.gz` |
| Empty lesion in ACPC grid | Check QSIPrep `from-T1wNative_to-T1wACPC`; pipeline falls back to empirical BIDS→preproc affine |
| `lesion voxels were not fully assigned to 5TT pathology` | Lesion mask misaligned to 5TT ref; check `lesion_aware_act.json` `lesion_warp_method` |
| ANTsPyNet `math domain error` / Figshare download fail | Set `act.deep_atropos.antsxnet_cache` to persistent NFS; run `run_deep_atropos_seg.py --prefetch-only` from login node — [deep_atropos_seg README](../containers/deep_atropos_seg/README.md) |
| Preflight: `requires act.deep_atropos.antsxnet_cache` | Create shared cache dir and prefetch before submit (required for `auto`/`generate` seg modes) |
| `missing Deep Atropos segmentation` with `import` mode | Provide `--deep-atropos-seg` or cohort files under `derivatives/deep-atropos/` |
| `TripWireError: scipy` in 5TT conversion | Rebuild `dkt_deep_atropos.sif` (Dockerfile + Apptainer.def include scipy) |
| Script changes not in published SIF | Set `ACT_BIND_MOUNT_DEV=1` for dev only, or rebuild/publish containers |
| Slow `tckgen` | Default 10M streamlines; reduce with `--act-streamlines` for pilots |

Theory: [Step 3.1 methods](methods/step3_1_lesion_act.md) · Deep Atropos: [maintainer plan](maintainer/deep_atropos_5tt_plan.md).

---

## Step 4 — Connectome

| Error / symptom | Fix |
|-----------------|-----|
| Empty nodes in matrix | Check `parcellation.json`; review registration QC |
| Wrong matrix size | DKT = 78×78; DK = 84×84 — don't mix across cohort |
| `dkt_connectome.csv` missing | Ensure QSIRecon + recon completed |

---

## Step 4.1 — Disconnectome

| Error / symptom | Fix |
|-----------------|-----|
| Step skipped | No lesion mask or non-DKT parcellation |
| Option A **WARN** in QC | Expected with count weighting (parcellation excision artifact); B/C are primary |
| `spared > primary` on edges | Re-run Step 4 and 4.1 with **`--connectome-weighting count`** |
| Invalid mean D | Step 4 used counts but 4.1 used sift2 — align weighting |
| Integrity **FAIL** | Run `evaluate_disconnectome_integrity.py`; see [Disconnectome § Integrity QC](disconnectome.md#integrity-qc) |

---

## Step 5 — Node strength

| Error / symptom | Fix |
|-----------------|-----|
| Skipped | Connectome did not run (`--no-connectome`) |
| Missing `report.pdf` | Check `nodestrength` container path; `logs/sub-*_nodestrength.log` |

---

## HPC / Slurm

| Error / symptom | Fix |
|-----------------|-----|
| Array job fails immediately | Run `bash workflow/preflight.sh --mode all --quick` |
| Node prolog error | Set `EXCLUDE_NODES` (default excludes known bad node) |
| Resume after partial run | Re-submit same `RESULTS_ROOT` — Snakemake skips completed steps |
| Markers out of sync | `bash workflow/backfill_markers.sh` |

---

## QC and export

| Error / symptom | Fix |
|-----------------|-----|
| Missing `subject_qc.html` | Run `./run` participant or `render_subject_qc.py` |
| Empty `derivatives/` | Run `./run … group` or `export_bids_derivatives.py` |
| Broken symlinks in export | Re-run export; use `--copy` for portable archives |

---

## Getting help

1. Check `RESULTS_ROOT/logs/sub-<ID>_*.log`
2. Open `qc/sub-<ID>/subject_qc.html`
3. See [FAQ](faq.md) and [GitHub issues](https://github.com/phindagijimana/dkt_connectome/issues)
