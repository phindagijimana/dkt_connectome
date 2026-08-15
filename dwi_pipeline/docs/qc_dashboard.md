# QC dashboard

Unified HTML QC for Steps 1–5, plus cohort indexes.

## Per-subject dashboard

After a full pipeline run (or `./run` participant):

```text
RESULTS_ROOT/qc/sub-<ID>/subject_qc.html
RESULTS_ROOT/qc/sub-<ID>/subject_qc.json
```

Includes:

| Step | Source artifacts |
|------|------------------|
| 1 QSIPrep | Subject HTML report + key reportlets |
| 1.5 Inpaint | `inpainting_qc.json`, preview PNGs |
| 2 Recon | FreeSurfer/FastSurfer presence |
| 3 QSIRecon | Session HTML report |
| 4 Connectome | `parcellation.json` (empty nodes) |
| 4.5 Disconnectome | Integrity summary + link to detail report |
| 5 Node strength | PDF link + figure gallery |

Snakemake builds this automatically when `qc.subject_html: true` (default).

```bash
bash workflow/run_subject.sh all TBI011011
# or standalone:
python3 scripts/render_subject_qc.py --results-root OUT --subject TBI011011
```

## Cohort index

```bash
./run BIDS OUT group
# -> OUT/cohort_qc.html (all steps)
# -> OUT/disconnectome_cohort_qc.html (Step 4.5 only)
```

Manual:

```bash
python3 scripts/render_cohort_qc.py --results-root OUT --write-subject-reports
```

## Configuration

```yaml
qc:
  enabled: true
  subject_html: true
```

Disable with `qc.subject_html: false` in `config.local.yaml` or omit from Snakemake `all` target.

## Related

- [disconnectome.md](disconnectome.md) — Step 4.5 detail QC
- [integrity_qc.md](integrity_qc.md) — integrity check definitions
- [outputs.md](outputs.md) — full derivatives layout
