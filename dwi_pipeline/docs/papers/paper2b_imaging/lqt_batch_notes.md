# Paper 2B — LQT batch (placeholder)

**Status:** not run. RQ1 (patient-specific vs normative SDC) **requires** this step.

## Expected output layout

After batch LQT on the same lesion masks as Paper 2B cohort:

```text
$LQT_DIR/
  sub-TBI011011/
    lqt_disconnection_matrix.csv   # 78×78, DKT-78 order (match DWI disconnectome)
```

Point `run_paper2b_analysis.sh` at the directory:

```bash
export LQT_DIR=/path/to/lqt_outputs
bash dwi_pipeline/analysis/paper2b/run_paper2b_analysis.sh
```

## SLURM (pilot 7)

```bash
cd /path/to/TrackTBI-Sub
sbatch dwi_pipeline/analysis/paper2b/submit_lqt_batch.slurm
# After LQT install:
sbatch --export=ALL,LQT_ROOT=/path/to/lesion-quantification-toolkit \
  dwi_pipeline/analysis/paper2b/submit_lqt_batch.slurm
```

MNI lesion warps use fMRIPrep `from-T1w_to-MNI152NLin6Asym` + disconnectome `lesion_binary_t1w.nii.gz` (`prepare_lesion_mni_for_lqt.sh`).

## References

- Tool: Griffis 2021 LQT — [../LQT.md](../LQT.md)
- MNI lesion normalization: extend existing pipeline registration docs

## BCB (optional RQ4)

Voxel-level BCB maps → parcel aggregation to DKT-78; not wired in scripts yet.
