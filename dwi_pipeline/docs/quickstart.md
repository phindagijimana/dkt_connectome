# Quick start

Minimal examples to run the pipeline on one participant. For installation prerequisites see [Installation](installation.md). For every flag see [Usage](usage.md) and [BIDS App](bids_app.md).

---

## 1. Prepare BIDS inputs

Your dataset should follow [BIDS](https://bids-specification.readthedocs.io/) with at least:

```text
sub-009/ses-1/
  anat/sub-009_ses-1_T1w.nii.gz
  dwi/sub-009_ses-1_dwi.nii.gz (+ .bval, .bvec, .json)
```

Optional but recommended:

- `fmap/` with `IntendedFor` pointing at the DWI series (TOPUP SDC)
- `anat/*_T1w_label-lesion_roi.nii.gz` for automatic Step 1.5 inpainting

If Siemens sidecars are missing PE timing fields, repair before QSIPrep — see [Preprocessing inputs](preprocessing.md).

---

## 2. Run with the BIDS App (`./run`)

```bash
cd dwi_pipeline

export FS_LICENSE=/path/to/license.txt   # required for QSIPrep / FreeSurfer

./run /path/to/BIDS /path/to/derivatives participant \
  --participant-label 009 \
  --session-filter ses-1 \
  --n-cpus 8
```

This runs Steps **1 → 5** for `sub-009`, limiting recon/connectome to `ses-1` when multiple sessions exist.

### FastSurfer instead of recon-all

```bash
./run /path/to/BIDS /path/to/derivatives participant \
  --participant-label 009 \
  --session-filter ses-1 \
  --fastsurfer \
  --n-cpus 8
```

### Plan without executing

```bash
./run /path/to/BIDS /path/to/derivatives participant \
  --participant-label 009 \
  --dry-run
```

---

## 3. Run with `subject.sh` (HPC)

Same science, explicit environment variables:

```bash
export BIDS_DIR=/path/to/BIDS
export RESULTS_ROOT=/path/to/derivatives
export FS_LICENSE=/path/to/license.txt

bash dwi_pipeline/subject.sh all 009 --session-filter ses-1
```

Slurm array over a subject list:

```bash
export BIDS_DIR=/path/to/BIDS
export RESULTS_ROOT=/path/to/derivatives
export SUBJECT_LIST_FILE=dwi_pipeline/subject_list_cidur_fmap.txt
bash dwi_pipeline/submit.sh
```

---

## 4. Check outputs

After a successful run, expect under `RESULTS_ROOT`:

| Path | Step |
|------|------|
| `qsiprep_single_run_output/sub-009/` | 1 |
| `inpainted/sub-009/ses-1/` | 1.5 (if lesion mask) |
| `freesurfer/sub-009/` | 2 |
| `qsirecon_single_run_output/sub-009/` | 3 |
| `connectomes/sub-009/dkt_connectome.csv` | 4 |
| `node_strength/reports/sub-009/` | 5 |

Full layout: [Outputs](outputs.md).

---

## 5. Optional: disconnectome (Step 4.5)

Step 4.5 is **off by default** (method still under validation). Pass **`--disconnection`** on a full run, or use standalone mode:

```bash
./run /path/to/BIDS /path/to/derivatives participant \
  --participant-label 009 --session-filter ses-1 --disconnection

bash dwi_pipeline/subject.sh disconnectome 009
# or
./run /path/to/derivatives /path/to/derivatives participant --participant-label 009 --mode disconnectome
```

See [Disconnectome](disconnectome.md) and [Inpainting/disconnection.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/disconnection.md).

---

## 6. QC

```bash
python3 dwi_pipeline/scripts/evaluate_disconnectome_integrity.py \
  --disconnectome-dir /path/to/derivatives/connectomes/sub-009/disconnectome
```

See [Integrity QC](integrity_qc.md).

---

## Test subjects in this repo

Local TBI examples under [`dwi_test_TBI/`](https://github.com/phindagijimana/dkt_connectome/tree/main/dwi_pipeline/dwi_test_TBI):

| Subject | Results tree |
|---------|--------------|
| TBI011011 | `dwi_test_TBI/sub-TBI011011_fastsurfer_inpaint/` |
| TBI011204 | `dwi_test_TBI/sub-TBI011204_fastsurfer_inpaint/` |

Both have validated Step 4.5 disconnectome outputs — see [Integrity QC](integrity_qc.md).

---

## What is happening?

While the pipeline runs, terminal output shows **which step and container** is active. Examples:

```text
[Step 1] QSIPrep — sub-009 ses-1
[Step 2] recon-all — sub-009
[Step 3] QSIRecon — mrtrix_singleshell_ss3t_ACT-hsvs
[Step 4] DKT connectome — sub-009
```

With Snakemake (`PIPELINE_ENGINE=snakemake`, the default), you will also see rule names such as `qsiprep`, `inpaint`, `recon`, `qsirecon`, `connectome`, and `disconnectome`. Each rule maps to one pipeline step — see [Snakemake workflow](snakemake_workflow.md) for the full DAG and `target_*` goals.

Logs are written under `RESULTS_ROOT/logs/`. If a step fails, check the step-specific log there before re-running with `--mode <step>` or a Snakemake `target_*` rule.

For what each step does scientifically, see [Pipeline steps](pipeline_steps.md) and [References by step](references.md).
