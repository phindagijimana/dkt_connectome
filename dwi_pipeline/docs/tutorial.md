# Tutorial — first run with test data

End-to-end walkthrough using the bundled TBI example layout. For theory, see [Methods](methods/index.md). For flag decisions, see [Decision tables](decision_tables.md).

---

## What you will do

1. Point the pipeline at local test BIDS inputs
2. Run Steps 1–5 for one subject
3. Inspect QC HTML and the DKT connectome
4. Optionally run disconnectome integrity checks

**Time:** several hours on HPC (QSIPrep + recon dominate). Use `--dry-run` first to validate the plan.

---

## 1. Layout

**Option A — IDEAS II sample (recommended, public data):**

```bash
bash dwi_pipeline/scripts/download_ideas_sample.sh
export BIDS_DIR="$(pwd)/dwi_pipeline/sample_data/ideas/bids"
```

Two subjects (`sub-1`, `sub-6`) from [OpenNeuro ds007401](https://openneuro.org/datasets/ds007401). See [IDEAS sample data](datasets/ideas.md).

**Option B — local TBI test tree:**

```text
dwi_pipeline/dwi_test_TBI/
  bids/                              # BIDS inputs (gitignored — you provide)
    sub-EXAMPLE/
    sub-EXAMPLE2/
  sub-EXAMPLE_fastsurfer_inpaint/  # RESULTS_ROOT (example outputs)
  sub-EXAMPLE2_fastsurfer_inpaint/
```

Naming convention for `RESULTS_ROOT`:

```text
sub-<SUBJECT>_<recon>[_inpaint]/
```

Example: `sub-EXAMPLE_fastsurfer_inpaint` = FastSurfer + inpainting ran.

See [dwi_test_TBI README](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/dwi_test_TBI/README.md).

---

## 2. Prerequisites

```bash
git clone https://github.com/phindagijimana/dkt_connectome.git
cd dkt_connectome/dwi_pipeline
```

**FreeSurfer license (required before real runs):** register at [FreeSurfer](https://surfer.nmr.mgh.harvard.edu/registration.html), download `license.txt`, then:

```bash
export FS_LICENSE=/path/to/your/license.txt
./run doctor
```

The project does not provide a shared license — each user obtains their own. Details: [Installation → FreeSurfer license](installation.md#freesurfer-license-you-must-obtain-this).

Apptainer images: [Installation → Auto-install](installation.md#auto-install-recommended).

---

## 3. Dry-run (validate plan)

```bash
export BIDS_DIR="$(pwd)/dwi_test_TBI/bids"
export RESULTS_ROOT="$(pwd)/dwi_test_TBI/sub-EXAMPLE_fastsurfer_inpaint"

./run "${BIDS_DIR}" "${RESULTS_ROOT}" participant \
  --participant-label EXAMPLE \
  --session-filter ses-1 \
  --fastsurfer \
  --dry-run
```

Review Snakemake rule list: `qsiprep` → `inpaint` (if mask) → `recon` → `qsirecon` → `connectome` → `nodestrength`.

---

## 4. Full run

```bash
./run "${BIDS_DIR}" "${RESULTS_ROOT}" participant \
  --participant-label EXAMPLE \
  --session-filter ses-1 \
  --fastsurfer \
  --n-cpus 8
```

HPC equivalent:

```bash
bash workflow/run_subject.sh all EXAMPLE --session-filter ses-1 --fastsurfer
```

---

## 5. Check outputs

| Artifact | Path |
|----------|------|
| QSIPrep | `RESULTS_ROOT/qsiprep_single_run_output/sub-EXAMPLE/` |
| Inpaint (if mask) | `RESULTS_ROOT/inpainted/sub-EXAMPLE/` |
| Recon | `RESULTS_ROOT/freesurfer/sub-EXAMPLE/` |
| QSIRecon | `RESULTS_ROOT/qsirecon_single_run_output/sub-EXAMPLE/` |
| **Connectome** | `RESULTS_ROOT/connectomes/sub-EXAMPLE/dkt_connectome.csv` |
| Node strength | `RESULTS_ROOT/node_strength/reports/sub-EXAMPLE/report.pdf` |
| **QC dashboard** | `RESULTS_ROOT/qc/sub-EXAMPLE/subject_qc.html` |

```bash
# Open QC in browser
firefox "${RESULTS_ROOT}/qc/sub-EXAMPLE/subject_qc.html"
```

What each panel means: [Quality control](qc.md).

---

## 6. Optional — disconnectome

Step 4.5 is off by default. With a lesion mask and validated settings:

```bash
./run "${BIDS_DIR}" "${RESULTS_ROOT}" participant \
  --participant-label EXAMPLE \
  --session-filter ses-1 \
  --disconnection
```

Integrity check:

```bash
python3 scripts/evaluate_disconnectome_integrity.py \
  --disconnectome-dir "${RESULTS_ROOT}/connectomes/sub-EXAMPLE/disconnectome"
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
