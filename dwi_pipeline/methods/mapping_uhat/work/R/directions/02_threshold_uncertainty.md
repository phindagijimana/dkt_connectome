# Direction 2 — Threshold uncertainty (P(count≥10))

Question: **Which reported edges are unstable under the count≥10 rule?**

Uses jitter samples `Cs.npy` already in each pack. Frozen floor=10.

## kirby21/KKI849

- Eligible edges: 2264
- Uncertain fraction: 0.027
- Hard crossings: 162 (0.072)
- Share of crossings on uncertain edges: 0.259
- Enrichment vs base rate: 9.47×
- AUROC(uncertainty score → crossing): 0.701
- AUROC(1−P10 → leftover y): 0.553

Strata (y_rate / cross_rate):
- `P10>=0.9`: n=2117, y_rate=0.514, cross_rate=0.017
- `0.1<P10<0.9`: n=62, y_rate=0.758, cross_rate=0.677
- `P10<=0.1`: n=85, y_rate=0.976, cross_rate=1.000

## boekel_dwi_retest/pp01

- Eligible edges: 2628
- Uncertain fraction: 0.016
- Hard crossings: 139 (0.053)
- Share of crossings on uncertain edges: 0.223
- Enrichment vs base rate: 13.95×
- AUROC(uncertainty score → crossing): 0.674
- AUROC(1−P10 → leftover y): 0.538

Strata (y_rate / cross_rate):
- `P10>=0.9`: n=2544, y_rate=0.342, cross_rate=0.026
- `0.1<P10<0.9`: n=42, y_rate=0.714, cross_rate=0.738
- `P10<=0.1`: n=42, y_rate=1.000, cross_rate=1.000

## Claim

Threshold-uncertain edges (0.1<P(count>=10)<0.9) are enriched for hard run1↔run2 threshold crossings; this is a usable uncertainty product without claiming U ranks leftover y.

