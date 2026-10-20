# Direction 3 — Leftover noise decomposition

Question: **How much of scan–rescan change is tracking RNG vs threshold vs count change?**

## Kirby KKI849

| Source | Move rate | Cross frac of elig | Both-present movers / all movers |
|---|---:|---:|---:|
| Tracking-only (reseed) | 0.095 | 0.035 | 147/208 |
| Leftover ses-1 vs ses-2 | 0.538 | 0.072 | 1068/1219 |

- Excess above tracking: **0.443** (82% of leftover move rate)
- Among leftover-eligible edges: leftover-only moves 0.482, both leftover+reseed 0.056, reseed-only 0.030
- Crossings are only **12%** of leftover movers; the rest are count changes with both sides ≥10

## Boekel pp01 (leftover only; no reseed yet)

- Move rate 0.359; cross frac 0.053; both-present movers 814/943

## Claim

On Kirby, tracking-only explains ~9.5% move rate vs ~54% leftover; ~82% of leftover move rate is excess above tracking. Most leftover movers are both-present count changes, not threshold crossings.

## Next (optional)

Run the same reseed control on Boekel pp01 for a second tracking floor.
