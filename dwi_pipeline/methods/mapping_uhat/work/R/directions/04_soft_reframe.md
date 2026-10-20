# Direction 4 — Soft connectome reframed

Locked invent≤0.001 **unchanged** (still fail). Reframe is reporting only.

## kirby21/KKI849

- Hard moved-frac: 0.5384
- Soft moved-frac: 0.5336 (Δ=0.0048)
- Invent: 14 (0.0062) vs cap 0.001 → FAIL
- Near-threshold invents C0∈[5,10): 12
- Far invents C0<5: 2

## boekel_dwi_retest/pp01

- Hard moved-frac: 0.3588
- Soft moved-frac: 0.3530 (Δ=0.0058)
- Invent: 7 (0.0027) vs cap 0.001 → FAIL
- Near-threshold invents C0∈[5,10): 7
- Far invents C0<5: 0

## Claim

Soft expectation slightly reduces moved-frac on both pilots but fails invent<=0.001. Almost all invents are near-threshold (C0 in [5,10)). Report soft as denoising-with-threshold-blur, not as a win under the locked invent rule.

## Paper wording

> Soft radial assignment slightly lowers the fraction of edges that move between scans, 
> but pushes several near-threshold edges (counts 5–9) above the reporting floor of 10. 
> We therefore report soft expectation as a denoised complement with an explicit invent stratum, 
> not as a replacement connectome that passes the pre-specified invent≤0.001 rule.
