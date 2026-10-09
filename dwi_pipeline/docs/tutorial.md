# Tutorial — first run with public IDEAS II sample

End-to-end walkthrough using the public [IDEAS II](datasets/ideas.md) sample (two subjects from [OpenNeuro ds007401](https://openneuro.org/datasets/ds007401)). For theory, see [Methods](methods/index.md). For flag decisions, see [Decision tables](decision_tables.md).

---

## What you will do

1. Download the public IDEAS II BIDS sample (or point the pipeline at your own BIDS)
2. Run Steps 1–5 for one subject (`sub-1`)
3. Inspect QC HTML and the DKT connectome
4. Optionally run disconnectome integrity checks

**Time:** several hours on HPC (QSIPrep + recon dominate). Use `--dry-run` first to validate the plan.

---

## 1. Layout

**Option A — IDEAS II sample (recommended, public data):**

```bash
bash dwi_pipeline/scripts/download_ideas_sample.sh
```

Two subjects (`sub-1`, `sub-6`) from [OpenNeuro ds007401](https://openneuro.org/datasets/ds007401). See [IDEAS sample data](datasets/ideas.md). After `cd dwi_pipeline` in the next section, set `BIDS_DIR="$(pwd)/sample_data/ideas/bids"`.

**Option B — your own BIDS + local RESULTS_ROOT:**

You provide BIDS. A typical `RESULTS_ROOT` layout:

```text
sub-<SUBJECT>_<recon>[_inpaint]/
```

Example: `sub-1_fastsurfer` = FastSurfer, no inpaint. You may keep local test data under any folder name (for example `dwi_test_TBI`); that folder is not shipped with the repository.

---

## 2. Prerequisites

```bash
git clone https://github.com/phindagijimana/dkt_connectome.git
cd dkt_connectome/dwi_pipeline
```

**FreeSurfer license (required before real runs):** register at [FreeSurfer](https://surfer.nmr.mgh.harvard.edu/registration.html), download `license.txt`, then:

```bash
export FS_LICENSE=/path/to/your/license.txt
./dkt check
# or: ./run doctor
```

The project does not provide a shared license — each user obtains their own. Details: [Installation → FreeSurfer license](installation.md#freesurfer-license-you-must-obtain-this).

Apptainer images: [Installation → Auto-install](installation.md#auto-install-recommended).

---

## 3. Dry-run (validate plan)

IDEAS DWI shells are 0, 300, 700, and **2500** s/mm² — pass `--dwi-select config/dwi_select_ideas_b2500.json` (not the default b=1000 filter). Use `--syn` (no fieldmaps in this sample).

```bash
export BIDS_DIR="$(pwd)/sample_data/ideas/bids"
export RESULTS_ROOT="$(pwd)/sample_data/ideas/results/sub-1_tutorial"
./run "${BIDS_DIR}" "${RESULTS_ROOT}" participant \
  --participant-label 1 --session-filter ses-1 --fastsurfer --syn \
  --dwi-select config/dwi_select_ideas_b2500.json --dry-run
```

Review Snakemake rule list: `qsiprep` → `inpaint` (if mask) → `recon` → `qsirecon` → `connectome` → `nodestrength`.

---

## 4. Full run

Same command without `--dry-run`, with `--n-cpus 8`:

```bash
export BIDS_DIR="$(pwd)/sample_data/ideas/bids"
export RESULTS_ROOT="$(pwd)/sample_data/ideas/results/sub-1_tutorial"
./run "${BIDS_DIR}" "${RESULTS_ROOT}" participant \
  --participant-label 1 --session-filter ses-1 --fastsurfer --syn \
  --dwi-select config/dwi_select_ideas_b2500.json --n-cpus 8
```

HPC equivalent:

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

## 6. Optional — disconnectome

Step 4.1 is off by default. With a lesion mask and validated settings:

```bash
./run "${BIDS_DIR}" "${RESULTS_ROOT}" participant \
  --participant-label 1 \
  --session-filter ses-1 \
  --disconnection
```

Integrity check:

```bash
python3 scripts/evaluate_disconnectome_integrity.py \
  --disconnectome-dir "${RESULTS_ROOT}/connectomes/sub-1/disconnectome"
```

Expected results for test subjects: [Validation](validation.md).

---

## 7. Cohort QC

After processing multiple subjects:

```bash
./run "${BIDS_DIR}" "${RESULTS_ROOT}" group
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
