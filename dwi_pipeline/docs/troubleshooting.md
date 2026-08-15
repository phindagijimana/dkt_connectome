# Troubleshooting

Common failures and fixes. The pipeline **fails loudly** rather than silently skipping steps.

---

## Before you run

| Symptom | Cause | Fix |
|---------|-------|-----|
| `bids-validator` errors | BIDS layout issues | `bash scripts/run_bids_validator.sh BIDS_DIR`; fix sidecars |
| `FS_LICENSE` missing | No FreeSurfer license | [FreeSurfer registration](https://surfer.nmr.mgh.harvard.edu/registration.html); export path |
| Container not found | Wrong `.sif` path | Set `CONTAINER_*` or `config.local.yaml` → [Configuration](configuration.md) |
| `snakemake not found` | Missing on PATH | `pip install snakemake` or `module load` |

---

## Step 1 — QSIPrep

| Error / symptom | Fix |
|-----------------|-----|
| `KeyError: 'TotalReadoutTime'` | Repair DWI JSON sidecars — [Preprocessing inputs](preprocessing.md) |
| SDC failure, no fieldmap | Add `--syn`, `--fmap-retry`, or `--no-sdc` |
| Wrong DWI series processed | Check `--dwi-shell` / `--dwi-select`; use `--session-filter` |
| Multiple sessions ambiguous | Pass `--session-filter ses-X` |

---

## Step 1.5 — Inpaint

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

## Step 4 — Connectome

| Error / symptom | Fix |
|-----------------|-----|
| Empty nodes in matrix | Check `parcellation.json`; review registration QC |
| Wrong matrix size | DKT = 78×78; DK = 84×84 — don't mix across cohort |
| `dkt_connectome.csv` missing | Ensure QSIRecon + recon completed |

---

## Step 4.5 — Disconnectome

| Error / symptom | Fix |
|-----------------|-----|
| Step skipped | No lesion mask or non-DKT parcellation |
| Option A **WARN** in QC | Expected with count weighting (parcellation excision artifact); B/C are primary |
| `spared > primary` on edges | Re-run Step 4 and 4.5 with **`--connectome-weighting count`** |
| Invalid mean D | Step 4 used counts but 4.5 used sift2 — align weighting |
| Integrity **FAIL** | Run `evaluate_disconnectome_integrity.py`; see [Integrity QC](integrity_qc.md) |

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
