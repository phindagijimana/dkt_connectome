# Tutorial — first run with public IDEAS II sample

End-to-end walkthrough using the public [IDEAS II](datasets/ideas.md) sample (two subjects from [OpenNeuro ds007401](https://openneuro.org/datasets/ds007401)). For theory, see [Methods](methods/index.md). For flag decisions, see [Decision tables](decision_tables.md).

---

## What you will do

1. Clone, install containers, and run `./dkt check --strict`
2. Download the public IDEAS II BIDS sample (or point the pipeline at your own BIDS)
3. Run Steps 1–5 for one subject (`sub-1`)
4. Inspect QC HTML and the DKT connectome
5. Optionally run the [BTC glioma](datasets/btc_glioma.md) lesion-aware demo (`--disconnection`)

**Time:** several hours on HPC (QSIPrep + recon dominate). Use `--dry-run` first to validate the plan. Preflight still requires cached step containers for `--dry-run`; export `BIDS_APP_CI=1` only to skip those checks for a plan-only / CI dry-run — do not set it for real runs.

---

## 1. Clone, install, and verify

```bash
git clone https://github.com/phindagijimana/dkt_connectome.git
cd dkt_connectome/dwi_pipeline
chmod +x dkt run install
export FS_LICENSE=/path/to/your/license.txt
export DKT_CONTAINER_CACHE=${DKT_CONTAINER_CACHE:-$HOME/.cache/dkt-connectome/containers}
export APPTAINER_TMPDIR=${APPTAINER_TMPDIR:-$HOME/.cache/dkt-connectome/apptainer_tmp}
mkdir -p "$DKT_CONTAINER_CACHE" "$APPTAINER_TMPDIR"
./dkt install
./dkt check --strict
```

**FreeSurfer license (required before real runs):** register at [FreeSurfer](https://surfer.nmr.mgh.harvard.edu/registration.html), download `license.txt`, then export `FS_LICENSE` as above. The project does not provide a shared license — each user obtains their own. Details: [Installation → FreeSurfer license](installation.md#freesurfer-license-you-must-obtain-this).

Apptainer images: [Installation → Auto-install](installation.md#auto-install-recommended).

---

## 2. Download the IDEAS sample

From `dwi_pipeline/` (the same directory as `./dkt`):

```bash
bash scripts/download_ideas_sample.sh
```

Two subjects (`sub-1`, `sub-6`) from [OpenNeuro ds007401](https://openneuro.org/datasets/ds007401). See [IDEAS sample data](datasets/ideas.md). After download, BIDS is at `$(pwd)/sample_data/ideas/bids`.

**Your own BIDS:** skip the download and pass your dataset path to `./dkt run` after this first subject.

A typical `RESULTS_ROOT` layout:

```text
sub-<SUBJECT>_<recon>[_inpaint]/
```

Example: `sub-1_fastsurfer` = FastSurfer, no inpaint. You may keep local test data under any folder name (for example `dwi_test_TBI`); that folder is not shipped with the repository.

---

## 3. Dry-run (validate plan)

IDEAS DWI shells are 0, 300, 700, and **2500** s/mm² — pass `--dwi-select config/dwi_select_ideas_b2500.json` (not the default b=1000 filter). Use `--syn` (no fieldmaps in this sample).

`./dkt run` is the same command as `./run`.

```bash
./dkt run "$(pwd)/sample_data/ideas/bids" "$(pwd)/sample_data/ideas/results/sub-1_tutorial" participant \
  --participant-label 1 --session-filter ses-1 --fastsurfer --syn \
  --dwi-select config/dwi_select_ideas_b2500.json --dry-run
```

Review Snakemake rule list: `qsiprep` → `inpaint` (if mask) → `recon` → `qsirecon` → `connectome` → `nodestrength`.

---

## 4. Full run

Same command without `--dry-run`, with `--n-cpus 8`:

```bash
./dkt run "$(pwd)/sample_data/ideas/bids" "$(pwd)/sample_data/ideas/results/sub-1_tutorial" participant \
  --participant-label 1 --session-filter ses-1 --fastsurfer --syn \
  --dwi-select config/dwi_select_ideas_b2500.json --n-cpus 8
```

HPC equivalent (after your first subject):

```bash
bash workflow/run_subject.sh all 1 --session-filter ses-1 --fastsurfer --syn \
  --dwi-select config/dwi_select_ideas_b2500.json
```

---

## 5. Check outputs

| Artifact | Path |
|----------|------|
| QSIPrep | `RESULTS_ROOT/qsiprep_single_run_output/sub-1/` |
| Inpaint (if mask) | `RESULTS_ROOT/inpainted/sub-1/` |
| Recon | `RESULTS_ROOT/freesurfer/sub-1/` |
| QSIRecon | `RESULTS_ROOT/qsirecon_single_run_output/sub-1/` |
| **Connectome** | `RESULTS_ROOT/connectomes/sub-1/dkt_connectome.csv` |
| Node strength | `RESULTS_ROOT/node_strength/reports/sub-1/report.pdf` |
| **QC dashboard** | `RESULTS_ROOT/qc/sub-1/subject_qc.html` |

```bash
# Open QC in browser
firefox "${RESULTS_ROOT}/qc/sub-1/subject_qc.html"
```

What each panel means: [Quality control](qc.md).

---

## 6. Optional — lesion-aware disconnectome

Step 4.1 is off by default. IDEAS II `sub-1` has **no** lesion mask. For the public lesion-aware demo, download [BTC glioma PAT20](datasets/btc_glioma.md) and pass `--disconnection`:

```bash
bash scripts/download_btc_glioma_sample.sh
./dkt run "$(pwd)/sample_data/btc_glioma/bids" "$(pwd)/sample_data/btc_glioma/results/sub-PAT20_tutorial" participant \
  --participant-label PAT20 --fastsurfer --syn --disconnection \
  --dwi-select config/dwi_select_btc_hardi.json --dry-run
```

Integrity check:

```bash
python3 scripts/evaluate_disconnectome_integrity.py \
  --disconnectome-dir "$(pwd)/sample_data/btc_glioma/results/sub-PAT20_tutorial/connectomes/sub-PAT20/disconnectome"
```

Expected results for test subjects: [Validation](validation.md).

---

## 7. Cohort QC

After processing multiple subjects:

```bash
./dkt run "$(pwd)/sample_data/ideas/bids" "$(pwd)/sample_data/ideas/results/sub-1_tutorial" group
# -> cohort_qc.html, derivatives/ export
```

---

## 8. Common variations

| Scenario | Add flags |
|----------|-----------|
| No fieldmaps (GE) | `--syn` |
| Skip inpainting | `--no-inpaint` |
| recon-all instead of FastSurfer | `--freesurfer` |
| Re-run connectome only | `--mode connectome` |

Full reference: [Usage](usage.md) · [Decision tables](decision_tables.md).

---

## See also

- [Usage](usage.md)
- [Validation](validation.md)
- [Troubleshooting](troubleshooting.md)
- [IDEAS sample data](datasets/ideas.md)
