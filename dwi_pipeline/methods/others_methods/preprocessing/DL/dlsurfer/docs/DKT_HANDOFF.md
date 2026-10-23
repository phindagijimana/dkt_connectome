# Phase 2 — DKT / QSIRecon handoff

DLSurfer stops at a FreeSurfer-compatible subject tree. Connectomics stay in the existing DKT pipeline.

## Mapping

| DLSurfer | DKT today |
|----------|-----------|
| `core` | `--fastsurfer` without lesion |
| `core-lesion` | `--anat-mitigation neurolit` + ordinary FastSurfer (+ `--post-hoc-fs` ≈ `--post-lit`) |
| `core-lesion-native` | `--fastsurfer-lesion-mask` |
| `fs8` | `--freesurfer` with FS8 |

## Usage

```bash
dlsurfer run --profile core-lesion --t1 T1.nii.gz --lesion-mask les.nii.gz \
  --sd /path/subjects --sid sub-EG --fs-license $FS_LICENSE --execute

dlsurfer handoff-dkt --sd /path/subjects --sid sub-EG
```

Set `FS_SUBJECTS_DIR` / `fs_subjects_dir` to the same `--sd`.
