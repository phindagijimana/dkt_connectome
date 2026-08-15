# Validation

Benchmark subjects, integrity QC expectations, and cohort context for the DKT Connectome.

---

## Study context

The pipeline is **study-agnostic** — it runs on any BIDS DWI dataset with optional lesion masks. Primary validation cohorts:

| Cohort | Role |
|--------|------|
| **TRACK-TBI** (~14 centers) | Multi-site TBI diffusion MRI |
| **URMC clinical MRI** (incl. CIDUR) | Local acquisition variants, lesion masks |

Cite cohort data use separately from pipeline software — see [Citation](citation.md).

Clinical TBI connectivity background: Hayes et al. 2016 ([10.1017/S1355617715000740](https://doi.org/10.1017/S1355617715000740)).

---

## Bundled test subjects

Under [`dwi_test_TBI/`](https://github.com/phindagijimana/dkt_connectome/tree/main/dwi_pipeline/dwi_test_TBI):

| Subject | RESULTS_ROOT example | Notes |
|---------|---------------------|-------|
| **TBI011011** | `sub-TBI011011_fastsurfer_inpaint` | FastSurfer + inpaint; validated disconnectome |
| **TBI011204** | `sub-TBI011204_fastsurfer_inpaint` | Same pipeline settings |

Walkthrough: [Tutorial](tutorial.md).

---

## Disconnectome integrity (Step 4.5)

Script: `scripts/evaluate_disconnectome_integrity.py`

### Validated runs (Aug 2026, count weighting, erode 0)

| Subject | Option B | Option C | Mean D (C) | Edges D > 0 |
|---------|----------|----------|------------|-------------|
| TBI011011 | PASS | PASS | 0.045616 | 2124 / 5794 |
| TBI011204 | PASS | PASS | 0.036309 | 2420 / 5954 |

**TBI011011 Option A:** WARN expected (444 edges `spared > primary` — parcellation excision reassignment).

### PASS criteria (summary)

| Check | PASS |
|-------|------|
| Options B & C under **count** weighting | Zero `spared > primary` edges |
| `disconnection_matrix.csv` | Matches spared option C (default) |
| D values | In [0, 1]; symmetric |

Full spec: [Integrity QC](integrity_qc.md) · [Methods § Step 4.5](methods/step4_5_disconnectome.md).

---

## Connectome checks (Step 4)

| Check | Expected |
|-------|----------|
| Matrix shape | 78×78 (DKT default) |
| `parcellation.json` | `n_nodes: 78`, correct segmentation file |
| Empty nodes | 0 for standard DKT; warn if >0 post-resection |
| Weighting | `count` unless explicitly using SIFT2 |

---

## Inpainting QC (Step 1.5)

From `inpainting_qc.json` / `check_inpainting.py`:

| Metric | Default gate |
|--------|--------------|
| Outside-lesion correlation | ≥ 0.995 |
| Correlation drop vs resampling control | ≤ 0.01 |

Details: [Methods § Step 1.5](methods/step1_5_inpaint.md).

---

## Regression testing

CI runs on GitHub Actions:

- Snakemake lint + dry-run
- MkDocs strict build
- Schema validation tests

Maintainers: re-run integrity scripts after changing connectome or disconnectome logic.

---

## Reporting in publications

1. Cite upstream tools per [References by step](references.md)
2. State pipeline version (`./run --version` → `app.json`)
3. Document flags: recon tool, SDC mode, weighting, disconnectome opt-in
4. Report integrity QC pass/fail for disconnectome cohorts

---

## See also

- [Visual QC guide](visual_qc.md)
- [Integrity QC](integrity_qc.md)
- [Tutorial](tutorial.md)
