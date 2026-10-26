# SUBJECTS_DIR

Always pass a **DLSurfer-owned** `--sd` unless you intentionally reuse a finished FreeSurfer tree (e.g. TopoFit-only on an existing subject).

```text
$SD/
  $SID/
    mri/          # orig, aseg*, aparc.DKTatlas+aseg.deep, …
    surf/         # white, pial, … (+ optional *.white.topofit)
    stats/
    scripts/      # logs, dlsurfer_metrics.tsv
    label/
```

Do not point `--sd` at an active DKT-connectome work tree unless that is an explicit handoff choice. Isolation policy: [reference/ISOLATION.md](../reference/ISOLATION.md).
