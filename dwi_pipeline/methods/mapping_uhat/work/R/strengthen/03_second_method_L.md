# Strengthen §3 — Promote \(L\) as a second named method

Status: **implemented in code** (`edgeuq instability`) + claim language locked here.

## Naming

| Symbol | Name in prose | Code |
|---|---|---|
| \(U\) | shift sensitivity | `edgeuq shift` |
| \(F\) | jitter leakage | `edgeuq jitter` |
| \(L\) | leftover / count instability | `edgeuq instability` |

**Forbidden names for \(L\):** \(\hat{U}\), proxy-\(\hat{U}\), “calibrated leftover U”, “updated U”.

## Definition (ses-1 only)

\[
L_{ij} = -\log(1 + C^{(1)}_{ij})
\]

Higher \(L\) = weaker ses-1 count = more leftover-unstable on pilots.

Optional companions (usually no gain): \(1-P_{10}\), hybrid \(L+(1-P_{10})\).

## Evidence on GOLD pilots (frozen cuts)

| Pair | AUROC \(L\) | AUROC \(U\) | AUROC \(F\) | n |
|---|---:|---:|---:|---:|
| Kirby KKI849 | 0.699 | 0.578 | 0.598 | 2264 |
| Boekel pp01 | 0.704 | 0.605 | 0.592 | 2628 |

Artifacts: `directions/05_leftover_score.*`, pack `L.csv`/`L.npy`, `directions/instability/*/instability.json`.

## How this strengthens the paper

1. **Answers Claim B’s “then what?”** without retuning plant methods.
2. **Two-method product:** plant fragility (\(U\)/\(F\)) vs visit instability (\(L\)).
3. **Falsifiable:** \(L\) is deliberately count-aware; if strong-edge leftover ranking is required, \(L\)’s AUROC should drop (Dir 6 already shows it still beats \(U\)/\(F\) inside strong strata, but weaker).

## Paper methods paragraph (draft)

> In addition to plant- and jitter-based scores, we define a ses-1 leftover-instability score \(L=-\log(1+C_0)\). This is a separate method aimed at scan–rescan edge change, not a recalibration of \(U\). On two public retest pilots, \(L\) ranked leftover movers at AUROC ≈ 0.70 versus ≈ 0.58–0.60 for \(U\)/\(F\).

## Limits (state openly)

- \(L\) uses count magnitude; it will look good when leftover = weak-edge churn (pilots).
- Not a calibrated probability (no invent/ECE win claimed for \(L\)).
- Needs descriptive scaling (ICCs / AUROC distribution across subjects) before strong population claims — Strengthen §5; await **scale descriptive**.

## Decision

Ship \(L\) as Claim C. Keep \(U\)/\(F\) frozen. Never merge namespaces.
