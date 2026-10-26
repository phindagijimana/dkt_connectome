# Preview the plan

Without `--execute`, `dlsurfer run` prints each step: why, citations, and argv.

```bash
dlsurfer run --profile core-lesion --t1 T1.nii.gz --lesion-mask L.nii.gz \
  --sd SD --sid S --fs-license $FS_LICENSE
```

Also:

```bash
dlsurfer smoke          # doctor + canned dry-run
dlsurfer cite --profile core-lesion
dlsurfer compare        # FS vs FastSurfer coverage matrix
dlsurfer gaps-remaining
```
