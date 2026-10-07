# Paper 2B — analysis scripts (imaging-only)

**Docs:** [`../../docs/papers/paper2b_imaging/index.md`](../../docs/papers/paper2b_imaging/index.md)

## Outputs

All cohort summaries go to:

```text
$OUT_ROOT/analysis/paper2b/
```

(or `--output-dir` override)

## Quick start (Gugger pilot, 7 subjects)

```bash
export EXPERIMENT_ROOT=/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment
export DWI_CONNECTOMES=$EXPERIMENT_ROOT/validation_v030/arms/neurolit-lesion/connectomes
export OUT_ROOT=$EXPERIMENT_ROOT/fmri_derivatives_inpaint
export LQT_DIR=$EXPERIMENT_ROOT/lqt_batch/outputs   # after LQT batch

bash dwi_pipeline/analysis/paper2b/run_paper2b_analysis.sh
```

## LQT batch (RQ1 blocker)

| Step | Command |
|------|---------|
| SLURM (7 pilot subjects) | `sbatch dwi_pipeline/analysis/paper2b/submit_lqt_batch.slurm` |
| One subject (staging) | `bash dwi_pipeline/analysis/paper2b/run_lqt_one_subject.sh TBI011011` |
| MNI lesion only | `bash dwi_pipeline/analysis/paper2b/prepare_lesion_mni_for_lqt.sh TBI011011` |
| Docx export | `bash dwi_pipeline/analysis/paper2b/export_paper2b_docx.sh` |

Without `LQT_ROOT`, the batch writes MNI lesions under `$EXPERIMENT_ROOT/lqt_batch/staging/` and `RUN_LQT.pending` under outputs. After installing [Griffis LQT](https://github.com/JDGriffis/lesion-quantification-toolkit), configure `lqt_run_subject.m` and resubmit with `LQT_ROOT` set.

## Scripts

| Script | RQ | Description |
|--------|-----|-------------|
| `compare_sdc_methods.py` | RQ1 | Patient `disconnection_matrix.csv` vs LQT matrix |
| `compare_sc_fc_association.py` | RQ3 | SC edge vector vs Arm B FC disconnection |
| `run_paper2b_analysis.sh` | — | Orchestrates 2B + fMRI pilot QC |
| `submit_lqt_batch.slurm` | RQ1 | Array SLURM for pilot cohort |
| `run_lqt_one_subject.sh` | RQ1 | MNI prep + optional MATLAB LQT |
| `export_lqt_disconnection_csv.py` | RQ1 | Normalize LQT CSV → `lqt_disconnection_matrix.csv` |

## LQT output layout (convention — create when LQT runs)

Place aligned DKT-78 CSVs at:

```text
$LQT_DIR/sub-<SUBJECT>/lqt_disconnection_matrix.csv
```

Same shape/order as DWI `disconnection_matrix.csv` (78×78). Update paths in
`compare_sdc_methods.py` if your LQT export differs.

## Dependencies

Python 3.9+ with `numpy` only (no scipy required for pilot metrics).
