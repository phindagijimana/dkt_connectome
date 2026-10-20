---
title: Gold hat{U} — rules locked, run blocked
date: 19 October 2026
status: G rules written 19 October 2026. Do not compute ECE until LIST.json has ≥2 paths and the user writes “GOLD locked”.
---

# Gold \(\hat U\) is a new experiment (rules locked)

C (calibrated \(U\) on planted 1 mm) does **not** unlock this. A8 / L2 closed the Wave 3 leftover-ensemble **name**. This file is the written exam for leftover \(y\). Changing these rules after leftover ECE would be inventing.

**Target:**

\[
\hat U_{ij}
=P(\text{edge }ij\text{ is wrong}\mid\text{measured leftover}).
\]

Wrong = locked moved: \(\mathrm{relchange}>0.25\) and \(\max(C)\ge10\). \(C_a,C_b\) come from an **independent leftover**, not a planted millimetre ladder and not the A5/A6 ANTs ensemble reused as leftover.

Machine copy: `methods/mapping_uhat/work/G/LOCK.json`.

## Lock-before-ECE (written once)

| Item | This exam |
|---|---|
| Leftover source + list | One of: other-site (site ≠ 01), same-day `run-2`, rater landmarks. Exact paths in `work/sites_v1/LIST.json` (empty now). How to drop files: `work/sites_v1/INBOX.md`. |
| Which \(P\) | Frozen calibrated \(U\) (experiment C). **No refit.** Not A8 frequency. |
| \(y\) | Edge moved between the two independent connectomes, same \(e>0.25\), count≥10. Not 1 mm plants. |
| Who is held out | The leftover list is test. The A5/A6 six-session frequency is not leftover. |
| How we decide | ECE, 10 bins, ±15 on bins that actually have ≥20 edges. **Do not require** \([0.8,0.9)\). Miss → keep calibrated \(U\). Do not call it \(\hat U\). |

Win sentence: ECE is computed on leftover \(y\) **and** every occupied bin (\(n\ge20\)) has \(|\bar y-\bar P|\le 0.15\). Then the 78×78 number may be named \(\hat U\).

Fail sentence: any miss, or the list still empty. Keep calibrated \(U\) as a 1 mm probability.

## What uploading to home folders does

Copying other-site / `run-2` subjects into

`dwi_pipeline/sample_data/tracktbi_othersite/bids/`

gives G **data**. It does **not** grant \(\hat U\). Process with the same freeze; QC-PASS; `empty_nodes=0`; write paths into `LIST.json`; then `GOLD locked`. Fail still keeps calibrated \(U\).

**TBI021030 is not leftover** (QC-FAIL / missing fmap). Confirmation 011011 / 011021 / 011204 are not other-site.

Do **not** use: stored `*_0GenericAffine.mat`; more planted mm as leftover; Extra A 6MO \(\Delta\); FAIL `.tck`; a Gugger walk.

## Compute (only after “GOLD locked” and \(n\ge 2\))

Same pipeline as confirmation, hardcoded list, cluster, `SUBJECT_LIST_USE_EXISTING=1`. No Gugger walk.

Until then: ship calibrated \(U\) with the \(U\) paper. `sites_v1` stays empty.
