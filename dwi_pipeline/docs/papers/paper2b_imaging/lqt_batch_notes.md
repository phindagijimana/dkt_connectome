# Paper 2B — LQT batch (placeholder)

**Status:** R LQT installed (SLURM 173881); pilot batch **173882 failed** — parallel Figshare downloads corrupted zip extracts on NFS. Run serial template install, then re-batch. RQ1 pending `lqt_disconnection_matrix.csv` for all 7 subjects.

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
bash dwi_pipeline/analysis/paper2b/prepare_dkt78_mni_parcellation.sh TBI011011
# R via module OR Apptainer rocker (no module needed):
sbatch dwi_pipeline/analysis/paper2b/submit_lqt_install_r.slurm
sbatch dwi_pipeline/analysis/paper2b/submit_lqt_install_templates.slurm
# after install + templates OK:
export LQT_BACKEND=r
sbatch --export=ALL,LQT_BACKEND \
  dwi_pipeline/analysis/paper2b/submit_lqt_batch.slurm
```

**DSI Studio:** large `DSI_studio.zip` often fails to `unzip` directly on NFS; `install_lqt_templates.sh` falls back to `repair_lqt_dsi_studio.sh` (local `/tmp` extract).

If a prior array failed during template download, clean and retry templates only:

```bash
LQT_CLEAN_TEMPLATES=1 sbatch --export=ALL,LQT_CLEAN_TEMPLATES=1 \
  dwi_pipeline/analysis/paper2b/submit_lqt_install_templates.slurm
```

Atlas path (auto-detected if present): `$EXPERIMENT_ROOT/lqt_batch/atlas/dkt78_mni152nlin6asym_res-2.nii.gz`

MATLAB Griffis toolkit: `LQT_BACKEND=matlab` + `LQT_ROOT=...`.

MNI lesion warps use fMRIPrep `from-T1w_to-MNI152NLin6Asym` + disconnectome `lesion_binary_t1w.nii.gz` (`prepare_lesion_mni_for_lqt.sh` + `ensure_pipeline_ants.sh`).

## References

- Tool: Griffis 2021 LQT — [../LQT.md](../LQT.md)
- MNI lesion normalization: extend existing pipeline registration docs

## BCB (optional RQ4)

Voxel-level BCB maps → parcel aggregation to DKT-78; not wired in scripts yet.
