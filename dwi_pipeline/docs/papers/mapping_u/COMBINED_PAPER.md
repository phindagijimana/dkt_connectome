---
title: One paper from U, C2 and the retest exam — plan, contribution, limits
date: 20 October 2026
---

# One paper, not three

Local TrackTBI-Sub. Do not push to public `dkt_connectome`.

## How the three relate

All three address one problem: a streamline-count edge is fragile because endpoint-to-node assignment near region boundaries flips under small spatial error. They ask different questions.

| Piece | Question | Error model | Product |
|---|---|---|---|
| **U** (`manuscript.md`) | Which edges are fragile? | every endpoint moved together by a planted shift (±0.25/±0.5 fit, ±1 mm test) | per-edge score from one scan; calibrated U for the planted 1 mm event |
| **C2** (`PAPER3_C2_SOFT_ASSIGN.md`) | Same, under realistic error? | independent Gaussian jitter per endpoint, σ from measured leftover | leakage F; soft connectome E[C]; P(count ≥ 10) |
| **Retest exam** (`PAPER2_LEFTOVER_UQ.md`) | Do run-1 scores predict real scan–rescan change? | none (real data) | validation of U, calibrated U and F |

Two methods and one test of both.

Overlap: F ranks like U on planted 1 mm. Dev results: Spearman(F, U) 0.71–0.76, AUROC F 0.89–0.93 vs U 0.91–0.95. C2's distinct contribution is threshold uncertainty, not ranking. Its soft connectome invents edges (2–12 per session ≥ 10), so it is reported as a diagnostic, never as a corrected connectome.

## Decision

Write **one combined paper**:

- U as the method;
- C2 as the realistic-noise extension and threshold diagnostic;
- the retest exam as the main validation.

The three separate documents stay as working records. Draft: `COMBINED_MANUSCRIPT.md` (planted-shift results final; retest and tracking-control sections marked ⟨pending⟩).

## Tier

| State | Assessment |
|---|---|
| After current jobs (2 retest pairs: Kirby KKI849, Boekel pp01) | Not strong-tier. Planted-shift results are solid (U AUROC ~0.91–0.93 vs low-count ~0.77–0.78; sensitivity grid AUROC ≥ 0.85), but 2 pairs cannot support a claim about real change. |
| With the additions below | Plausible for *NeuroImage* / *Medical Image Analysis* / *Imaging Neuroscience*. |

## What would make it strong (in priority order)

1. **Scale the retest** to all Kirby21 (21) and Boekel (34) subjects, about 50 pairs. Queue only after the 2 current pairs pass end to end.
2. **Tracking-only control**: reseed run-1 tractography so tracking randomness is separated from endpoint placement. *Locked (`RETEST_LOCK.json` `tracking_only_control`) and queued for KKI849, Slurm 189610: same tckgen, new seed, ses-1 nodes fixed.*

Scaling (item 1) waits until both current pairs pass end to end (decision 20 Oct 2026). All 21 Kirby21 and 34 Boekel subjects are already local in BIDS.
3. **Beat the low-count baseline on real change**, not only on planted shifts. This is the main scientific risk.
4. **One downstream payoff**, e.g. masking or down-weighting fragile edges improves test–retest reliability of graph measures.
5. **Generality**: a second atlas and SIFT2 weighting.

Risk: if real change is dominated by tracking noise, or low count ties U on real data, the paper is an honest mixed or negative result at mid-tier.

## Contribution if it succeeds

Error bars on connectome edges from a single scan.

1. **U**: a per-edge reliability score from the subject's own tractogram and parcellation, with no rescan. Today edge reliability comes only from group test–retest studies, as one average per edge that does not transfer to a new subject, pipeline or lesioned brain.
2. **Calibrated U**: if retest calibration holds, a per-edge probability of a > 25% change on rescan.
3. **C2**: which edges exist only because of where the count-of-10 cut falls, i.e. which edges can appear or vanish between scans for non-biological reasons.
4. **Retest exam**: a reusable protocol and container for validating any edge-uncertainty measure on real scan–rescan data.

## How that helps

- **Group studies**: down-weight or drop fragile edges before statistics. Fewer noisy edges means fewer false findings and a smaller multiple-comparison burden (e.g. NBS).
- **Individual patients and follow-up (TRACK-TBI)**: a connection lost between 2WK and 6MO on a high-U edge means little; on a low-U edge it deserves attention. Lesions and atrophy move boundaries, where fragility concentrates.
- **Quality control**: shows which sessions and regions depend on registration accuracy.
- **Pipeline comparison**: atlases and processing choices compared on fragility without new rescans.
- **Reporting**: edges carry uncertainty like any other measurement.

## What it does not do

- Covers one error source only: endpoint placement relative to region boundaries.
- Says nothing about whether a streamline is anatomically real; false-positive tracts can be perfectly reliable.
- Reliability is not validity.
- Does not correct tracking stochasticity; the reseed control only measures how large it is.

## Software

Packaged as `edgeuq` (`edgeuq u`, `edgeuq c2`, `edgeuq retest`, `edgeuq demo`), one container, a docs page per method.

- Private repo: <https://github.com/phindagijimana/edgeuq>. Make it public with a Zenodo DOI at preprint (`docs/release.md` there).
- No TRACK-TBI data, IDs or paths. The frozen isotonic map was fit on public IDEAS and BTC demo sessions only.
- Tests pass on Python 3.9 and 3.12 (GitHub Actions).
- Docker image built, smoke-tested on synthetic data, published privately at `ghcr.io/phindagijimana/edgeuq:main`.
- Parity against frozen outputs on public dev session `ideas-sub-1-ses-1` **passed** (Slurm 189604, `work/package_parity.json`): endpoints identical, C0 exact, U within 4.9e-9 (CSV rounding), C2 F within 1.5e-8 (float32), E[C] exact.
- Local Apptainer `.sif` build deferred until running jobs finish. `/tmp` is noexec here, so set `APPTAINER_TMPDIR`, `PROOT_TMP_DIR` and `TMPDIR` to a home directory.
