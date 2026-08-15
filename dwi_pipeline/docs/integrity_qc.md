# Integrity QC

Post-hoc checks for connectome and disconnectome outputs. These scripts verify
**internal consistency** (matching weighting, valid D matrices) — not biological
validity of tractography or lesion masks.

See also: [disconnectome.md](disconnectome.md), [`Inpainting/disconnection.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/disconnection.md).

---

## Disconnectome (Step 4.5)

**Script:** `dwi_pipeline/scripts/evaluate_disconnectome_integrity.py`

### What it checks

| Check | PASS criteria |
|-------|-----------------|
| Options A / B / C vs primary | Loads Step 4 `dkt_connectome.csv` and each spared matrix; reports totals, correlation, mean D |
| `spared > primary` on edges | **FAIL/WARN** if many edges exceed primary under **count** weighting (indicates P/B weighting mismatch) |
| `disconnection_matrix.csv` | Matches `disconnection_matrix_{A,B,C}.csv` for `--disconnection-spared` (default **C**) |
| `lesion_roi_metrics.csv` | File exists |

### Option A warnings

Option A (parc excision) can **reassign** streamline endpoints to different nodes,
so some edges may show `spared > primary` even with correct count weighting.
The script **WARN**s when >5% of active edges exceed primary on Option A only.
Options B and C should **PASS** with zero `spared > primary` edges under count weighting.

### Usage

```bash
python3 dwi_pipeline/scripts/evaluate_disconnectome_integrity.py \
  --disconnectome-dir dwi_pipeline/dwi_test_TBI/sub-TBI011011_fastsurfer_inpaint/connectomes/sub-TBI011011/disconnectome
```

Exit codes: **0** = all checks passed or warned; **1** = FAIL (or `--fail-on-warning`);
**2** = missing provenance.

Treat **WARN on Option A** as expected; **FAIL on B or C** means re-run with
`--connectome-weighting count` or fix Step 4 weighting.

### Validated TBI runs (Aug 2026, count weighting, erode 0)

| Subject | Option B | Option C | Mean D (C) | Edges D > 0 |
|---------|----------|----------|------------|-------------|
| TBI011011 | PASS | PASS | 0.045616 | 2124 / 5794 |
| TBI011204 | PASS | PASS | 0.036309 | 2420 / 5954 |

TBI011011 Option A: **WARN** (444 edges spared > primary — parc reassignment).

---

## Connectome (Step 4)

Manual checks until a dedicated script is added:

1. **Weighting** — `connectome.weighting` in `workflow/config/config.yaml` matches
   disconnectome `--connectome-weighting` (default **count**).
2. **Matrix shape** — 78×78 for DKT; no all-zero rows/columns unless expected.
3. **Provenance** — `connectomes/sub-<ID>/parcellation.json` and registration affine
   present when inpainting ran.

---

## When to run

| Stage | When |
|-------|------|
| After Step 4.5 manual run | Always, before reporting D matrices |
| After changing `connectome.weighting` | Re-run Step 4 **and** 4.5 with matching flag |
| Cohort batch | Loop over `connectomes/sub-*/disconnectome/` |
