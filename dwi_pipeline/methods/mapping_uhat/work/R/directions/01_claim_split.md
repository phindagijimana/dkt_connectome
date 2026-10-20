# Direction 1 — Split claims (plant UQ vs leftover negative control)

Status: **adopted as paper framing**. No new compute. No threshold changes.

## Claim A (keep — supported)

**Shift sensitivity (U) and jitter leakage (F) quantify connectome fragility under a known endpoint perturbation (~1 mm plant).**

Evidence:
- Planted-y exams: AUROC U ≈ 0.91–0.94, F ≈ 0.89–0.93 (IDEAS/BTC dev + TBI confirm).
- Calibrated U is a **probability for planted 1 mm**, not leftover change (C win).
- Software parity reproduces frozen U/F.

Scope language for the paper:
> “We measure which edges are sensitive to small endpoint displacement and assignment noise.”

## Claim B (keep — supported as negative / boundary result)

**On public scan–rescan pairs, leftover edge moves are not well ranked by U/F, and planted-1 mm calibration does not transfer to leftover y.**

Evidence:
- Retest exam (GOLD): AUROC U/F ≈ 0.58–0.60; G ECE ≈ 0.32; soft invent_frac fail.
- Reseed floor ≈ 9.5% vs leftover move rates 36–54% → most leftover change is not tracking RNG alone.
- Postmortem: leftover movers concentrate on low-count edges; U/F barely separate y=0 vs y=1.

Scope language:
> “Retest shows U/F are not detectors of natural visit-to-visit change; that requires a different score (Directions 2–5).”

## Explicit non-claims

- Not hat{U} / Û from leftover.
- Not “soft connectome wins” under invent≤0.001.
- Not “U/F calibrate real change rates.”

## Paper skeleton under this split

1. Methods: shift, jitter, soft expectation (definitions).
2. Planted validation (positive).
3. Retest external check (negative for leftover ranking/calibration; positive for honesty).
4. Follow-ons: threshold uncertainty, noise decomposition, optional leftover score (Dirs 2–5).

## Decision

Proceed with Directions 2–8 **under this split**. Do not reopen frozen Spearman/AUROC/FLAG/invent cuts to rescue Claim B as a positive leftover ranker.
