---
title: Paper 2 — Leftover prediction and calibration (future)
date: 2026-10-20
status: NOT started as primary; waits on Paper 1 finalize + scale + lit/math
---

# Paper 2 (separate) — leftover prediction / calibration

**Not Part of Paper 1 wins.** New symbols only.

## Estimand

\[
y_{ij}=\mathbf{1}\{\mathrm{relchange}(C^{(1)}_{ij},C^{(2)}_{ij})>0.25,\ \max(C^{(1)},C^{(2)})\ge 10\}.
\]

## Symbols

| Symbol | Role |
|---|---|
| \(L\) | ranking score (may start from \(-\log(1+C_0)\); may add features) |
| \(P_L\) or \(G_L\) | calibrated \(P(y=1\mid L,\ldots)\) on **held-out subjects** |
| \(R\) | optional reliability class (robust / fragile / uncertain) |

**Forbidden:** \(\hat{U}\), plant isotonic applied to leftover, invent-cap retune to force soft win.

## Must include (lit + math)

1. TRT / weak-edge ICC literature (Buchanan, Schumacher, …) as motivation.  
2. Held-out isotonic/Platt + ECE/Brier (calibration survey standards).  
3. Baselines: count, length, FA, bootstrap CV / edge classes.  
4. Train/test by **subject**, not by edge within subject only.

## Gate

Start serious P2 compute after Paper 1 text is stable and preferably after **scale descriptive** supplies \(n\gg 2\).
