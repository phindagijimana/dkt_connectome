# Strengthen §5 — Scale only for descriptive replication

Status: **policy locked**. Mass processing **held** until the user says **`scale descriptive`**.

## Why scale at all (reframed)

Not to push leftover AUROC of \(U\)/\(F\) over a win line.  
To ask: **do D1–D5 and Claim C (\(L\)) patterns hold across subjects/sites?**

Cohorts ready (public): Kirby21 (21), Boekel (34), HCP TR (44) — see Dir 8 plan.

## Allowed scaled metrics (descriptive)

1. Leftover move rate (relchange > 0.25, count ≥ 10)
2. Move rate by min-count floor (10/20/30/50/100)
3. Threshold-uncertain fraction + crossing enrichment
4. Reseed move rate (tracking floor) on a subset
5. Soft invent strata (near vs far) — report only
6. Distribution of ses-1 \(L\) AUROC vs leftover \(y\) (Claim C replication)
7. Optional: ICC / concordance of strong edges across visits

## Forbidden scaled goals

- Optimize invent ≤ 0.001 or ECE band until “win”
- Refit isotonic on the scaled leftover set and call it \(\hat{U}\)
- Retune relchange / floor / radial after seeing scaled AUROCs
- Hide pilot FAIL and only report scaled successes

## Gate phrase

| Phrase | Action |
|---|---|
| *(none / pre-scale done)* | Hold mass queue |
| **`scale descriptive`** | Start Dir 8 cohort processing under this policy |
| anything implying “fix leftover AUROC” | Refuse; point here |

## Decision

Scaling strengthens **external validity of descriptive claims**, not Claim B as a positive leftover ranker for \(U\)/\(F\).
