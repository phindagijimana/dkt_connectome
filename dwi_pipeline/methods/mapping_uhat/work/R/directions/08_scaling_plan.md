# Direction 8 — Scale for descriptive reliability (not leftover-AUROC confirmation)

Status: **plan only**. Do not mass-queue until you approve after reading Dirs 1–7.
Frozen U/F thresholds unchanged. Goal is **population descriptive stats**, not “prove U ranks leftover.”

## Why scale now (reframed)

Pilots already showed:
- U/F fail as leftover rankers (AUROC ~0.6).
- Threshold-uncertain edges are rare but **highly enriched** for crossings (Dir 2).
- Tracking floor ~10% vs leftover 36–54% (Dir 3).
- Move rate falls with edge strength (Dir 6).

Scaling answers: **how stable are these descriptive patterns across subjects/sites?**

## Cohorts (public)

| Cohort | Pairs ready on disk | Notes |
|---|---:|---|
| Kirby21 | 21 | Same-day retest |
| Boekel | 34 | pp20–34 single-T1 stratum |
| HCP Test-Retest | 44 | Preprocessed; skips QSIPrep; multi-shell |

Pilot subjects already done: KKI849, pp01. HCP 103818 adapt done; FS/iFOD held/released separately.

## Metrics to compute per pair (descriptive)

1. Leftover move rate (relchange>0.25, count≥10)
2. Move rate by min-count floor (10/20/30/50/100)
3. Threshold-uncertain fraction + crossing enrichment
4. Reseed move rate (tracking floor) — at least Kirby+Boekel subset
5. Invent strata for soft expectation (near-threshold vs far) — report only
6. Optional: ses-1-only `−log1p(C0)` AUROC as the **leftover score** candidate (Dir 5), never as U

**Do not** optimize invent≤0.001 or isotonic on this scaled set to “get a win.”

## Processing order (compute)

1. **Boekel pp02–pp34** — BIDS already fixed; QSIPrep → FastSurfer → iFOD2 → pack (same as pp01)
2. **Kirby remaining 20** — same chain
3. **HCP** — adapt (`hcp_to_qsiprep.py`) → FastSurfer → multi-shell iFOD2 → pack; report partial-diffusion stratum separately
4. After packs: batch script for metrics 1–6 → one CSV/JSON per cohort

Interactive 12 h: prefer `general` for QSIPrep/iFOD2 if wall time >12 h (lesson from pilots).

## Disk

Home ~338 GB free after cleanup. Plan:
- Delete QSIPrep/QSIRecon `.work` after each subject’s tck+counts exist (~40 GB saved per few subjects)
- Keep bids + derivatives + pack outputs
- HCP raw stays; skip `grad_dev`

## Success criteria for this direction (not soft/G win)

- Cohort-level tables of move rates and uncertain-edge enrichment with CIs
- Replication that leftover is mostly both-present count change, excess above reseed
- Replication that `−log1p(C0)` > U/F for leftover ranking (if you promote Dir 5)

## Explicit non-goals

- Mass scale to rescue hat{U}
- Retune FLAG_U / invent / isotonic on scaled leftover
- Mix HCP preprocessed and Kirby/Boekel QSIPrep without labeling the processing difference

## Gate to start jobs

Reply **scale descriptive** (or similar) after reviewing Dirs 1–7. Until then, no array submissions beyond current HCP pilot.
