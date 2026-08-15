# Usage

How to run the pipeline outside the minimal [Quick start](quickstart.md) examples.

---

## Entry points

| Method | When to use |
|--------|-------------|
| [`./run`](bids_app.md) | BIDS Apps interface, portable CLI |
| [`subject.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/subject.sh) | HPC scripts, full flag surface |
| [`run_subject.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/workflow/run_subject.sh) | Snakemake-backed (used internally by `./run`) |
| [`submit.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/submit.sh) | Slurm array over a subject list |

All paths assume `BIDS_DIR` and `RESULTS_ROOT` are set (or passed as `./run` positional args).

---

## Modes (`subject.sh` / `./run --mode`)

| Mode | Steps |
|------|-------|
| `all` | 1 → 1.5 (if mask) → 2 → 3 → 4 → 5 |
| `qsiprep` | Step 1 only |
| `inpaint` | Step 1.5 only |
| `recon` | Step 2 only |
| `qsirecon` | Step 3 only |
| `connectome` | Step 4 (+ Step 5 if enabled) |
| `disconnectome` | Step 4.5 only (needs DKT connectome + lesion mask) |
| `nodestrength` | Step 5 only (needs connectome) |

Legacy alias: `dk` → `connectome`.

---

## Session selection

Multi-session subjects require an explicit filter:

```bash
bash subject.sh all 009 --session-filter ses-1
# or
./run BIDS OUT participant --participant-label 009 --session-filter ses-1
```

Environment alternative: `RECON_SESSION=1`.

---

## Common flags

| Flag | Effect |
|------|--------|
| `--fastsurfer` | FastSurfer instead of recon-all |
| `--fast-fs` | FastSurfer + classic DK aparc (`--fsaparc`) |
| `--no-recon` | Skip Step 2 (needs ACT-fast spec or existing FS dir) |
| `--no-inpaint` / `--inpaint` | Force skip / enable Step 1.5 |
| `--no-connectome` | Skip Steps 4 and 5 |
| `--no-node-strength` | Skip Step 5 only |
| `--no-disconnectome` | Skip Step 4.5 |
| `--disconnectome-core-only` | Step 4.5 sensitivity: core label only |
| `--disconnectome-erode-voxels N` | Step 4.5 sensitivity: erode lesion |
| `--connectome-weighting count\|sift2` | Step 4 and 4.5 edge weights |
| `--syn` | SyN SDC when no fmap in filter |
| `--fmap-retry` | Ignore fieldmaps, use SyN |
| `--no-sdc` | Skip SDC |
| `--no-dwi-filter` | Process all DWI (not just b=1000) |
| `--dwi-shell N` | Filter to shell N |
| `--dry-run` | Snakemake plan only |
| `--export-bids-derivatives` | Write `derivatives/` after run |

Full reference: [Configuration](configuration.md) · [flag.md on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/flag.md).

---

## Snakemake workflow

Direct invocation (advanced):

```bash
cd dwi_pipeline/workflow
snakemake --configfile config/config.yaml \
  --config results_root=/path/to/out bids_dir=/path/to/BIDS \
  target_all -- sub-009
```

Slurm profiles: [`profiles/`](https://github.com/phindagijimana/dkt_connectome/tree/main/profiles) in the repository root.

---

## Step 4.5 disconnectome

Runs automatically after Step 4 when `lesion_mask_prepared.nii.gz` exists (Snakemake + `subject.sh` + `./run`).

```bash
bash dwi_pipeline/workflow/run_subject.sh disconnectome 009
bash dwi_pipeline/subject.sh disconnectome 009 --session-filter ses-1
```

Skip: `--no-disconnectome`. Sensitivities: `--disconnectome-erode-voxels 1`, `--disconnectome-core-only`.

Documentation: [Disconnectome](disconnectome.md).

---

## Slurm array

```bash
export BIDS_DIR=/path/to/BIDS
export RESULTS_ROOT=/path/to/results
export SUBJECT_LIST_FILE=dwi_pipeline/subjects.txt
bash dwi_pipeline/submit.sh
```

One array task = one subject via `array.sh` → Snakemake / `subject.sh`.

---

## Cohort post-processing

After array jobs finish (no reprocessing):

```bash
export RESULTS_ROOT=/path/to/cohort_output
export BIDS_DIR=/path/to/BIDS
bash dwi_pipeline/scripts/batch_postprocess.sh
```

Same as `./run BIDS OUT group`.

---

## Strict fail-fast policy

The pipeline avoids silent fallbacks. See [Troubleshooting](troubleshooting.md) for fixes.

---

## See also

- [Outputs](outputs.md) — what each step writes
- [Integrity QC](integrity_qc.md) — post-run checks
- [Lesion segmentation](lesion_segmentation.md) — mask requirements
- [FAQ](faq.md)
