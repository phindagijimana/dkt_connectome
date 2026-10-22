---
title: Software output — DKT-Connectome + optional edgeuq trust bands
date: 2026-10-22
status: DRAFT_NOTE
venue_target: JOSS / NeuroImage Software / brief methods-software note
edgeuq_version: 0.2.0
---

# SOFTWARE_DKT_EDGEUQ (draft note)

## One-sentence pitch

**DKT-Connectome** builds reproducible Desikan–Killiany–Tourville streamline-count matrices from QSIPrep/QSIRecon-style derivatives; an **optional** post-step attaches edge trust bands from **edgeuq** v0.2.0 (Paper 1 plant/jitter; Paper 2 leftover \(L\) / stratum \(P_L\)).

## What this paper claims (software only)

1. End-to-end, pinned-container path from BIDS/derivatives → DKT count (+ SIFT2/length/FA companions as already supported).
2. Provenance: radial assignment, parcellation JSON, empty-node policy, container digests.
3. Optional `edgeuq` hooks emit \(U\), \(F\), \(E_{\mathrm{soft}}\), \(L\) (and \(P_L\) only with a shipped same-stratum map or TRT pairs) **without** renaming them \(\hat{U}\).
4. Validation **by citation**: AUROC/ECE live in Paper 1/2 — this note shows commands and example outputs.

## What this paper does **not** claim

- New plant or leftover science.
- That trust bands replace clinical ground truth.
- Silent cross-site leftover probability (CLI refuses stratum mismatch).
- HCP redistribution.

## Example commands (public Kirby-style derivatives)

```bash
# Paper 1 — plant / jitter (ses-1 tck + nodes)
edgeuq shift  --tck streamlines.tck --nodes nodes.nii.gz --n-nodes 78 --out S
edgeuq jitter --tck streamlines.tck --nodes nodes.nii.gz --n-nodes 78 --out S --sigma 0.5

# Paper 2 — leftover instability (ses-1 counts only)
edgeuq instability --count-run1 S/C0.csv --out S

# Paper 2 — apply shipped Kirby stratum map (refuse if --stratum mismatches)
edgeuq apply-leftover-map \
  --map path/to/isotonic_leftover_kirby21_ifod2_radial4.json \
  --count-run1 S/C0.csv \
  --stratum kirby21_ifod2_radial4 \
  --out S_PL
```

Smoke: `edgeuq demo --out /tmp/edgeuq_demo` and `pytest` in the `edgeuq` repo (v0.2.0: stratum guards covered).

## Symbol table (must appear in software docs)

| Symbol | Meaning | Paper |
|--------|---------|-------|
| \(U\), \(U_{\mathrm{cal}}\) | Planted endpoint fragility / P(plant move) | 1 |
| \(F\), \(E_{\mathrm{soft}}\) | Jitter leakage / soft counts | 1 |
| \(L\) | Leftover instability \(-\log(1+C_0)\) | 1C / 2 |
| \(P_L\) | Calibrated leftover probability (stratum map) | 2 |
| \(\hat{U}\) | **Forbidden** name for leftover products | — |

## Deliverables checklist

- [ ] Config flag `edgeuq_trust_bands: false` (default)
- [ ] Rule or wrapper: after `*_connectome_count.csv` + nodes/tck, call `edgeuq shift|jitter|instability`
- [x] Docs page: symbol table + plant ≠ leftover (this note + Paper figures)
- [ ] CITATION / Zenodo DOI on `edgeuq` v0.2.0 (tag local; push + public release pending auth)
- [ ] Minimal example on public Kirby/Boekel derivative subset in DKT-Connectome CI

## Relationship to methods papers

```text
Paper 1  →  validates U/F (+ leftover boundary)
Paper 2  →  validates L / P_L (site maps)
Software →  ships the pipeline users run; cites both + edgeuq v0.2.0
```
