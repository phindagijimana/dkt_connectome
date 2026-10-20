# Strengthen §6 — What not to do (anti-retune lock)

Status: **locked**. Violation = credibility damage worse than GOLD FAIL.

## Frozen (do not change to rescue retest)

| Item | Value | Home |
|---|---|---|
| Radial assignment | 4 mm | protocol / edgeuq |
| Relchange cut | 0.25 | leftover / U |
| Count floor | 10 | all exams |
| Invent cap | 0.001 | C2 soft win |
| ECE band / min bin n | ±0.15 / 20 | G |
| Plant shifts | FIT/TEST mm sets | shift |
| Jitter seed / S | SEED0 / 32 | jitter |

## Explicitly forbidden “rescues”

1. **Raise invent cap** (e.g. 0.01) so soft “wins.”
2. **Drop near-threshold invents** then claim invent pass.
3. **Refit isotonic on leftover \(y\)** and rename as \(\hat{U}\) / G win.
4. **Retune relchange or floor** until \(U\)/\(F\) AUROC looks good.
5. **Cherry-pick subjects** after seeing AUROCs.
6. **Quietly omit** invent/G FAIL from the paper while keeping plant wins.
7. **Call \(L\) a recalibrated \(U\).**

## Allowed adaptations (not retunes)

- New **named** methods with new symbols (\(L\), future scores) — Strengthen §3 + new directions.
- New **evaluations** (stratified floors, enrichment, ICC) under frozen cuts.
- New **datasets** for descriptive replication — Strengthen §5.
- Soft **reporting** strata without changing the invent binary rule — Strengthen §4.

## Reviewer-proof sentence

> We pre-specified plant and soft/G rules; after retest FAIL we did not retune those rules. Transfer failure is reported as a boundary result, and leftover ranking is addressed with a separate count-instability score \(L\).

## Decision

Honesty > cosmetic wins. This lock is part of the methods contribution.
