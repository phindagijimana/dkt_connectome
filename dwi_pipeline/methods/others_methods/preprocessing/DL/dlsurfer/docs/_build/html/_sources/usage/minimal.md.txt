# A minimal command

Dry-run (default — prints the plan, executes nothing):

```bash
dlsurfer run \
  --profile core \
  --t1 /data/sub-01_T1w.nii.gz \
  --sd /data/dlsurfer_subjects \
  --sid sub-01 \
  --fs-license $FS_LICENSE \
  --device auto
```

Execute:

```bash
dlsurfer run ... --execute
```

Lesion path:

```bash
dlsurfer run \
  --profile core-lesion \
  --t1 T1.nii.gz \
  --lesion-mask lesion.nii.gz \
  --sd ./subjects --sid sub-01 \
  --fs-license $FS_LICENSE \
  --device cuda \
  --execute
```

!!! tip "Preview first"
    Omit `--execute` (or use `dlsurfer smoke`) until the planned argv looks right — same spirit as QSIPrep’s plan preview.
