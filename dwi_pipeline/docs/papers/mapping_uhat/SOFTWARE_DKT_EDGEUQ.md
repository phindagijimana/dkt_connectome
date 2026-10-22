---
title: Software output — DKT-Connectome + optional edgeuq trust bands
date: 2026-10-21
status: PLANNED
venue_target: JOSS / NeuroImage Software / brief methods-software note
---

# SOFTWARE_DKT_EDGEUQ

## One-sentence pitch

**DKT-Connectome** builds reproducible Desikan–Killiany–Tourville streamline-count matrices from QSIPrep/QSIRecon-style derivatives; an **optional** post-step attaches edge trust bands from **edgeuq** (Paper 1 plant/jitter scores; Paper 2 leftover instability when a second session exists).

## What this paper claims (software only)

1. End-to-end, pinned-container path from BIDS/derivatives → DKT count (+ SIFT2/length/FA companions as already supported).
2. Provenance: radial assignment, parcellation JSON, empty-node policy, container digests.
3. Optional `edgeuq` hooks emit \(U\), \(F\), \(E_{\mathrm{soft}}\), \(L\) (and \(P_L\) only when calibrated maps / TRT pairs are provided) **without** renaming them \(\hat{U}\).
4. Validation **by citation**: numerical AUROC/ECE live in Paper 1/2 — this note shows commands and example outputs.

## What this paper does **not** claim

- New plant or leftover science.
- That trust bands replace clinical ground truth.
- HCP redistribution.

## Deliverables checklist

- [ ] Config flag `edgeuq_trust_bands: false` (default)
- [ ] Rule or wrapper: after `*_connectome_count.csv` + nodes/tck, call `edgeuq shift|jitter|instability`
- [ ] Docs page: symbol table + “plant ≠ leftover”
- [ ] CITATION.cff + Zenodo on `dkt-connectome` release that includes the hook
- [ ] Minimal example on public Kirby/Boekel derivative subset

## Relationship to methods papers

```text
Paper 1  →  validates U/F (+ boundary)
Paper 2  →  validates L / P_L
Software →  ships the pipeline users run; cites both
```
