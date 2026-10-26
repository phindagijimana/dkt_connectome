# Output layout

After a successful `core` / `core-lesion` run:

```text
$SD/$SID/
  mri/
    orig.mgz
    aparc.DKTatlas+aseg.deep.mgz
    aseg.auto_noCCseg.mgz
    mask.mgz
    …
  surf/
    lh.white  rh.white
    lh.pial   rh.pial
    …
  stats/
  scripts/
    deep-seg.log
    recon-surf.log
    dlsurfer_metrics.tsv
  touch/ or scripts/recon-surf.done   # FastSurfer completion markers
```

TopoFit adds `surf/?h.white.topofit` (ico7 mesh; denser than recon-surf white).
