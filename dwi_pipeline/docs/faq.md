# FAQ

---

## General

### Is this a single Docker image like QSIPrep?

No. The BIDS App **orchestrates multiple Apptainer images** (QSIPrep, FreeSurfer, QSIRecon, connectome, LIT, nodestrength). This matches multi-site HPC deployments where images are cached on shared storage. See [Installation](installation.md).

### What is the recommended way to run on Slurm HPC?

```bash
export BIDS_DIR=/path/to/BIDS
export RESULTS_ROOT=/path/to/out
bash dwi_pipeline/submit.sh
```

Use `PIPELINE_ENGINE=snakemake` (default). See [Usage](usage.md) and [Cloud & group deployment](cloud_deployment.md).

### Do I need a lesion mask?

**No** for the standard connectome pipeline. Step 1.5 (inpaint) runs **only when** `*_T1w_label-lesion_roi.nii.gz` exists. Step 4.5 (disconnectome) is **opt-in** via `--disconnection` (off by default while under validation).

### Which connectome should I use — DKT or DK?

**DKT (78 nodes)** is the default and works with both FreeSurfer and FastSurfer. **DK (84 nodes)** requires `recon-all` or `--fast-fs`. Step 4.5 disconnectome requires **DKT**.

### What edge weighting should I use?

**`count`** (streamline counts) for Step 4 and 4.5. Using `sift2` in disconnectome without matching Step 4 produces invalid disconnection indices.

---

## BIDS App (`./run`)

### Can I process multiple subjects at once?

Yes:

```bash
./run BIDS OUT participant --participant-label 001 003 009
```

Subjects run sequentially; exit code is non-zero if any fail.

### What does `group` analysis level do?

Cohort **QC indexes** and **BIDS Derivatives export** — not group statistics:

- `cohort_qc.html`
- `disconnectome_cohort_qc.html`
- `derivatives/` symlink mirror

### Is BIDS validation required?

No. Pass `--bids-validation` or set `bids.validate: true` in config.

---

## Sessions and multi-site data

### My subject has multiple sessions — what do I pass?

Exactly one session per invocation:

```bash
./run BIDS OUT participant --participant-label 009 --session-filter ses-2WK
```

Run separate jobs per session.

### GE scanners without fieldmaps?

Use `--syn` (SyN SDC) or `--no-sdc` to match legacy no-SDC runs. See [Preparing your data](preparing_data.md).

---

## Outputs and sharing

### Where are derivatives written?

Internal layout under `RESULTS_ROOT/` (see [Outputs](outputs.md)). For sharing, run:

```bash
./run BIDS OUT group
# or
bash scripts/batch_postprocess.sh
```

This builds `RESULTS_ROOT/derivatives/` (BIDS Derivatives-style symlinks).

### How do I check disconnectome quality?

Per subject: `connectomes/sub-<ID>/disconnectome/disconnectome_qc.html`  
Unified: `qc/sub-<ID>/subject_qc.html`  
CLI: `python3 scripts/evaluate_disconnectome_integrity.py --disconnectome-dir ...`

---

## Documentation

### Where is the hosted documentation?

[Read the Docs](https://dkt-connectome.readthedocs.io/en/latest/) (built from this `docs/` folder). GitHub mirror: [docs/index.md](index.md).
