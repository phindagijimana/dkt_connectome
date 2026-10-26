# Phase 4 — harden & publish notes

## Metrics

On `--execute`, DLSurfer appends:

`$SD/$SID/scripts/dlsurfer_metrics.tsv`

Columns: `step`, `engine`, `device`, `seconds`, `exit`.

Compare against legacy split jobs: wall-time, queue time (from SLURM), failure rate.

## Citation workflow

```bash
dlsurfer cite --profile core-lesion
```

Always cite **engines**, not DLSurfer as a morphometry method. See [`CLAIMS.md`](../reference/CLAIMS.md).

## Release checklist

- [ ] Pin FastSurfer / neuroLIT / FS versions in `engines.yaml` pins  
- [ ] `dlsurfer doctor` green on target cluster  
- [ ] EG + ≥1 TBI subject smoke (`core`, `core-lesion`)  
- [ ] Contract check passes preferred files  
- [ ] Experimental profiles remain flagged until TBI±LIT report exists  
- [ ] README claim boundary unchanged  

## Optional infrastructure paper

Measure: TtS, failure modes (PATH/OOM/LIT), not Dice vs FreeSurfer anatomy.
