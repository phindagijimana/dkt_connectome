# Metrics and QC

On `--execute`, DLSurfer appends:

```text
$SD/$SID/scripts/dlsurfer_metrics.tsv
```

Columns: `step`, `engine`, `device`, `seconds`, `exit`.

Compare to SLURM queue time from job `.out` files. Visual QC: open `$SD` in FreeView (upstream FS GUI — not reimplemented here).

Phase-3 TopoFit machine score example:

```bash
python scripts/score_topofit_tbi_lit.py \
  --with-lit work/phase3_topofit/with_lit/sub-EG \
  --no-lit work/phase3_topofit/no_lit/sub-EG \
  --ref-white-dir /path/to/recon-surf/sub-EG \
  --out work/phase3_topofit/topofit_tbi_lit_score.json
```
