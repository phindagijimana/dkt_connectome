# Disconnectome

Theory and biological rationale: [Step 4.5 — Disconnectome (methods)](methods/step4_5_disconnectome.md).

Full method specification: [`Inpainting/disconnection.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/disconnection.md).

---

## Defaults

- **A/B/C** all built by default; skip with `--skip-option-a` etc.
- **D default spared = C** (`--disconnection-spared C`)
- **Weighting default = count** (matches Step 4); optional `--connectome-weighting sift2`
- **Opt-in** via `--disconnection` on `./run` / `subject.sh all` (off by default; method under validation)
- Standalone: `--mode disconnectome` or `subject.sh disconnectome` (requires `lesion_mask_prepared.nii.gz` from Step 1.5)
- **SIFT1 is not used** in this pipeline

---

## Lesion definition (primary)

- **Binary union** of labels in `lesion_mask_prepared.json` (default: core `1` + oedema `2`)
- **Erosion: 0** (`--lesion-erode-voxels 0`) — definition-faithful primary
- **Sensitivities:** `--lesion-erode-voxels 1` (border robustness); `--core-only` (oedema exclusion)

---

## QC reports

**Per-subject HTML report** (auto-written by Snakemake / Step 4.5):

```text
connectomes/sub-<ID>/disconnectome/disconnectome_qc.html
connectomes/sub-<ID>/disconnectome/disconnectome_qc.json
```

**Cohort index** (BIDS App group level):

```bash
./run BIDS OUT group
# -> OUT/disconnectome_cohort_qc.html
```

Render manually:

```bash
python3 scripts/render_disconnectome_qc.py --disconnectome-dir ...
python3 scripts/render_disconnectome_cohort_qc.py --results-root OUT --write-subject-reports
```

---

## Integrity QC

Post-hoc checks verify **internal consistency** (matching weighting, valid D matrices) — not biological validity of tractography or lesion masks.

**Script:** `dwi_pipeline/scripts/evaluate_disconnectome_integrity.py`

### What it checks

| Check | PASS criteria |
|-------|-----------------|
| Options A / B / C vs primary | Loads Step 4 `dkt_connectome.csv` and each spared matrix; reports totals, correlation, mean D |
| `spared > primary` on edges | **FAIL/WARN** if many edges exceed primary under **count** weighting (weighting mismatch) |
| `disconnection_matrix.csv` | Matches `disconnection_matrix_{A,B,C}.csv` for `--disconnection-spared` (default **C**) |
| `lesion_roi_metrics.csv` | File exists |

Option A (parc excision) can reassign streamline endpoints — **WARN** when >5% of active edges exceed primary on Option A only. Options B and C should **PASS** with zero `spared > primary` edges under count weighting.

### Usage

```bash
python3 dwi_pipeline/scripts/evaluate_disconnectome_integrity.py \
  --disconnectome-dir dwi_pipeline/dwi_test_TBI/sub-TBI011011_fastsurfer_inpaint/connectomes/sub-TBI011011/disconnectome
```

Exit codes: **0** = passed or warned; **1** = FAIL; **2** = missing provenance.

### Validated TBI runs (count weighting, erode 0)

| Subject | Option B | Option C | Mean D (C) | Edges D > 0 |
|---------|----------|----------|------------|-------------|
| TBI011011 | PASS | PASS | 0.045616 | 2124 / 5794 |
| TBI011204 | PASS | PASS | 0.036309 | 2420 / 5954 |

TBI011011 Option A: **WARN** (444 edges spared > primary — parc reassignment).

### Connectome (Step 4) manual checks

1. **Weighting** — `connectome.weighting` matches disconnectome `--connectome-weighting` (default **count**).
2. **Matrix shape** — 78×78 for DKT; no unexpected all-zero rows/columns.
3. **Provenance** — `parcellation.json` present when inpainting ran.

Re-run Step 4 **and** 4.5 after changing weighting.
