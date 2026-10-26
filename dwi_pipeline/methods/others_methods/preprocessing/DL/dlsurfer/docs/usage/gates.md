# Gates

```bash
dlsurfer gates
```

| Gate | Status (lab) | Unblocks |
|------|--------------|----------|
| `core_lesion_eg_smoke` | passed | ops marker |
| `tbi_lit_topofit` | passed | `surf-dl-topofit*` |
| `tbi_lit_surfaces` | open | V2C / SUGAR / DL-CTE |
| `synthseg_pc_vs_jlf` | open (skipped) | SynthSeg-PC piriform |

`--execute` is refused while a gate listing that profile is not `passed`, unless `--allow-experimental`.

Evidence notes: [lab/](../lab/LIVE_RUNS.md).
