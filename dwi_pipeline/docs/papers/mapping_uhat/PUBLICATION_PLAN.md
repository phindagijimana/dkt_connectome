---
title: Three-output publication plan (locked)
date: 2026-10-21
status: LOCKED
decision: user chat 2026-10-21 — “go ahead with What works better”
---

# PUBLICATION_PLAN

Do **not** merge Paper 1, Paper 2, and DKT-Connectome into one manuscript.
Ship three citable outputs; software cites the methods papers for validation.

| Output | Role | Venue target | Gate before submission |
|--------|------|--------------|------------------------|
| **Paper 1** | Science: plant fragility \(U\)/\(F\) + retest boundary | NeuroImage / Imaging Neuroscience methods | Claim spine A/B locked; scale panels optional ([PAPER1_AWAITING_SCALE.md](PAPER1_AWAITING_SCALE.md)) |
| **Paper 2** | Science: leftover \(L\) → \(P_L\) (never \(\hat{U}\)) | Same tier | Within-site + scaled LOSO; ECE pass **or** honest ranking-only framing ([PAPER2_LOCK.md](PAPER2_LOCK.md)) |
| **DKT-Connectome (+ edgeuq hooks)** | Product: DKT counts + optional trust bands | JOSS / NeuroImage: Software / brief software paper | Optional `edgeuq` post-step; cite P1/P2; no re-proving AUROC/ECE |

## Non-negotiables

1. Paper 1 lead claim is **plant fragility**, not leftover prediction.
2. Paper 2 never renames \(P_L\) as \(\hat{U}\); plant scores are out of scope except as negative controls.
3. Software paper demonstrates **usability + provenance**, not new science claims.
4. Authorship can lag; **version tags + license + Zenodo DOI** for `edgeuq` / `dkt-connectome` should not ([DISTRIBUTION.md](DISTRIBUTION.md)).

## Dependency order

```text
edgeuq releases (DOI) ──► Paper 1 finalize ──► Paper 2 after scale/within-site
         └──► dkt-connectome optional trust-band hook ──► software note (cites P1/P2)
```

## Pointers

- Paper 1: [PAPER1_LOCK.md](PAPER1_LOCK.md), [PAPER1_manuscript.md](PAPER1_manuscript.md)
- Paper 2: [PAPER2_LOCK.md](PAPER2_LOCK.md), [PAPER2_manuscript.md](PAPER2_manuscript.md)
- Software: [SOFTWARE_DKT_EDGEUQ.md](SOFTWARE_DKT_EDGEUQ.md)
- Distribution while authors pending: [DISTRIBUTION.md](DISTRIBUTION.md)
- Hook design: [../../../../dkt_scripts_wt is external] — see `docs/EDGEUQ_TRUST_BANDS.md` in the DKT repo when synced; local copy under mapping_uhat: [EDGEUQ_TRUST_BANDS_HOOK.md](EDGEUQ_TRUST_BANDS_HOOK.md)
