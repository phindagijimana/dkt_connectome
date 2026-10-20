# Strengthen §2 — Sell descriptive retest findings as contributions

Status: **adopted**. These are Results section bullets under Claim B, not consolations.

After leftover ranking/calibration fail, the paper still has **positive descriptive retest science**. Write them as findings, not as “despite the fail…”

## Contribution D1 — Threshold-uncertain edges are rare but crossing-rich

- Flag: \(0.1 < P(C\ge 10) < 0.9\) from jitter samples.
- Pilots: ~1.6–2.7% of eligible edges uncertain; **~9–14× enriched** for hard threshold crossings vs base rate.
- **User value:** a small, actionable QC flag set (Dir 2 + Dir 7 CSVs).

Paper sentence:
> A few percent of reported edges sit near the count floor under endpoint jitter; those edges account for a disproportionate share of threshold crossings between visits.

## Contribution D2 — Tracking RNG is a minority of leftover moves

- Kirby reseed (fixed nodes, new `MRTRIX_RNG_SEED`): move rate ≈ **9.5%**.
- Leftover move rates: Kirby ≈ **54%**, Boekel ≈ **36%**.
- Excess above tracking ≈ **82%** of Kirby leftover move rate (Dir 3).
- Most movers are **both-present count changes**, not 10-count flicker (~5–7% crossings among eligible).

Paper sentence:
> Same-day retest change far exceeds a tracking-only reseed floor, so visit-to-visit instability is not explained by streamline RNG alone.

## Contribution D3 — Soft expectation as threshold blur, not a free lunch

- Soft moved-frac slightly **below** hard on both pilots (stability nudge).
- Invent fail is almost entirely **C0 ∈ [5,10)** pushed over 10 in Esoft (Dir 4 / postmortem).
- **User value:** report invent strata; do not claim invent win (Strengthen §4).

## Contribution D4 — Edge report schema

Per reported edge (count ≥ 10): `count`, `Esoft`, `F`, `U`, `P10`, `threshold_uncertain` (Dir 7).

Paper sentence:
> Connectome tables should carry uncertainty columns, not point counts alone.

## Contribution D5 — Move rate falls with edge strength; plant scores still weak

- Raising min-count floor lowers leftover y-rate; \(U\)/\(F\) AUROC stays ~0.57–0.61 (Dir 6).
- Reinforces: leftover is a **weak-edge phenomenon**; plant fragility ≠ leftover ranking.

## How to place these in the manuscript

| Section | Use |
|---|---|
| Results — Retest | D1–D3 numbers + negative AUROC/G |
| Results — Reporting | D4 schema + example tables |
| Discussion | D2/D5 explain *why* Claim B fails (different phenomenon) |
| Supplement | Full Dir 2–7 JSON/CSV |

## What this does *not* claim

- Does not turn retest into a leftover-AUROC win for \(U\)/\(F\).
- Does not replace Claim A plant validation.
- Does not authorize mass scale except for replicating D1–D5 descriptively (Strengthen §5).
