---
title: Paper 2 lock — leftover prediction and calibration
date: 2026-10-20
status: DESIGN_LOCKED_PILOT_DEMO
venue_target: NeuroImage / MedIA (if held-out P_L closes)
depends_on: Paper 1 finalize; scale descriptive preferred for n≫2
publication_plan: PUBLICATION_PLAN.md (P2 separate from P1 and DKT software note)
---

# PAPER2_LOCK

> **Publication:** methods paper alone (NeuroImage-tier). DKT-Connectome ships \(L\)/\(P_L\) as an optional hook and cites this paper — it does not absorb these claims.

## Core question

Can we **predict** and **calibrate** scan–rescan (leftover) edge change with a dedicated model, without reusing plant scores as \(\hat{U}\)?

## Estimand (frozen cuts; shared with P1 event definition)

\[
y^{\mathrm{leftover}}_{ij}
=
\mathbf{1}\!\left\{
\frac{|C^{(1)}_{ij}-C^{(2)}_{ij}|}{\max(C^{(1)}_{ij},C^{(2)}_{ij},\varepsilon)} > \tau
\;\wedge\;
\max(C^{(1)}_{ij},C^{(2)}_{ij})\ge f
\right\}
\]

with \(\tau=0.25\), \(f=10\), \(\varepsilon=10^{-9}\).  
Eligibility for AUROC/ECE tables: \(\max(C^{(1)},C^{(2)})\ge f\) on the upper triangle.

**Not** the planted 1 mm event \(y^{\mathrm{plant}}\).

## Symbol table (mandatory)

| Symbol | Meaning | Must **not** equal |
|---|---|---|
| \(L\) | ses-1 ranking score for leftover instability | \(U\) (shift) |
| \(P_L\) or \(G_L\) | calibrated \(P(y^{\mathrm{leftover}}=1\mid L,\ldots)\) | plant \(U_{\mathrm{cal}}\) / \(\hat{U}\) |
| \(y^{\mathrm{leftover}}\) | move under frozen relchange/floor between visits | planted 1 mm \(y\) |
| \(R\) (optional) | reliability class from bootstrap / \(P_{10}\) | soft invent “win” under invent≤0.001 |

Primary ses-1 score (v0): \(L=-\log(1+C^{(1)})\). Features may be added later under new names (\(L^{+}\)), not by renaming \(U\).

## Win / fail (held-out by **subject**)

| Gate | Win | Fail → still publishable as |
|---|---|---|
| Ranking | mean test AUROC(\(L\)) materially > baselines (random, FA, …) and > \(U\)/\(F\) | descriptive limit of count scores |
| Calibration | ECE(\(P_L\)) on held-out subjects passes pre-registered band (default: improve vs uncalibrated + occupied bins within ±0.15, \(n_{\mathrm{bin}}\ge20\)) | “\(L\) ranks; \(P_L\) not yet calibrated at this n” |
| Naming | never call \(P_L\) \(\hat{U}\) | — |

**Train/test unit = subject (pair), not edges pooled from the test subject into training.**

## Forbidden

1. Fit isotonic/Platt on plant \(y\) and evaluate on leftover \(y\) as a P2 win (that was Paper 1 G fail).  
2. Name any leftover probability \(\hat{U}\) or “updated U.”  
3. Retune \(\tau\), \(f\), or invent cap to force soft/G wins.  
4. Claim P2 complete with n=2 pilots only (pilot LOO is **demo / protocol check** only).

## Relation to Paper 1

- P1: plant fragility + transfer **boundary**.  
- P2: leftover as **primary** estimand.  
- \(U\)/\(F\) may appear only as **baselines** labeled `U_shift` / `F_jitter`.

## Scale gate

Serious multi-fold \(P_L\) claims after **`scale descriptive`** (or equivalent n≫2 public pairs). Until then: design + code + pilot protocol demo.

## Pre-fit maps and site preference

Single-subject users need a **shipped** \(\phi_L\) (pre-fit), not a local TRT fit. Prefer **per-site / per-protocol** maps; do not treat harmonization as a substitute without an explicit ECE test. See [PREFIT_AND_SITE_MAPS.md](PREFIT_AND_SITE_MAPS.md). Software: `edgeuq apply-leftover-map` refuses stratum mismatch unless `--force-cross-site`. Reviewer checklist: [NEUROIMAGE_REVIEWER_RESPONSE.md](NEUROIMAGE_REVIEWER_RESPONSE.md).
