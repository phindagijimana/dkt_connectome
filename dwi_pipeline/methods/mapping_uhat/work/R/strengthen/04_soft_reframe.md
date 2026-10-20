# Strengthen §4 — Reframe soft expectation

Status: **reporting rule locked**. Invent ≤ 0.001 win rule stays FAIL; do not relax.

## What soft is for (narrow)

Soft expectation \(E_{\mathrm{soft}}\) averages jittered count matrices. It is a **denoising / band** tool around the hard count, not a passport to replace hard connectomes under the invent lock.

## Locked exam facts (pilots)

| Pair | moved_frac hard | moved_frac soft | invent_n | invent_frac | invent from C0∈[5,10) |
|---|---:|---:|---:|---:|---:|
| Kirby | 0.538 | ~0.531–0.534 | 14 | 0.0062 | 12 |
| Boekel | 0.359 | ~0.352–0.353 | 7 | 0.0027 | 7 |

- Soft **slightly** reduces moved-frac (descriptive winlet).
- Soft **fails** invent ≤ 0.001 (binary FAIL under C2 lock).
- Invents are **near-threshold blur**, not random phantoms.

## Reporting schema (use this in paper/tables)

For each subject / cohort summary:

1. **Stability:** `moved_frac_soft` vs `moved_frac_hard` (Δ only; no “win”).
2. **Invent total:** `invent_frac` vs locked 0.001 → **fail/pass binary**.
3. **Invent strata:**
   - near-threshold: \(C_0 \in [5,10)\)
   - far: \(C_0 < 5\)
4. **Per-edge band:** hard count + Esoft (Dir 7), optionally with invent flag.

## Paper language (approved)

> Soft expectation modestly reduces scan–rescan moved fraction but invents a small set of near-threshold edges across the count≥10 floor. We therefore report soft as a uncertainty band with invent strata, not as a replacement connectome under a no-invention rule.

## Anti-language

- Do not say “soft wins” or “soft passes QC.”
- Do not raise invent cap to 0.01 to get a win.
- Do not drop near-threshold invents post hoc and claim the lock passed.

## Decision

Keep invent lock. Soft = band + strata. Strengthen §2 D3 is the Results home for this.
