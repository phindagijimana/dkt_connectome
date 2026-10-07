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
```

Default job: **MNI lesion staging only** (ANTs via host or `qsirecon.sif`).

**Recommended comparator (no MATLAB):** R [jdwor/LQT](https://github.com/jdwor/LQT) (Griffis 2021 equivalent):

```bash
# once: R -e "remotes::install_github('jdwor/LQT')"
export LQT_PARCEL_NII=/path/to/dkt78_mni_parcellation.nii.gz
export LQT_BACKEND=r
sbatch --export=ALL,LQT_BACKEND,LQT_PARCEL_NII \
  dwi_pipeline/analysis/paper2b/submit_lqt_batch.slurm
```

MATLAB Griffis toolkit: `LQT_BACKEND=matlab` + `LQT_ROOT=...`.

MNI lesion warps use fMRIPrep `from-T1w_to-MNI152NLin6Asym` + disconnectome `lesion_binary_t1w.nii.gz` (`prepare_lesion_mni_for_lqt.sh` + `ensure_pipeline_ants.sh`).

## References

- Tool: Griffis 2021 LQT — [../LQT.md](../LQT.md)
- MNI lesion normalization: extend existing pipeline registration docs

## BCB (optional RQ4)

Voxel-level BCB maps → parcel aggregation to DKT-78; not wired in scripts yet.
