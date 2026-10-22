---
title: NeuroImage-tier reviewer concerns — status and fixes
date: 2026-10-21
status: LAB_ACTION
companions: [PAPER1_LOCK.md, PAPER2_LOCK.md, PREFIT_AND_SITE_MAPS.md, PUBLICATION_PLAN.md]
---

# NeuroImage reviewer concerns — what we can solve

Hard-reviewer bar from the lab red-team (clear estimand, enough n, baselines, frozen cuts, software, abstracts that match numbers). Below: each concern → **status** → **what closes it**.

## Shared (both papers)

| Concern | Status | Fix |
|---------|--------|-----|
| Oversell / “UQ for real change” / \(\hat{U}\) | **Solved in locks + manuscripts** | Non-claims locked; abstracts forbid leftover as plant \(U\); symbols \(P_L\neq\hat{U}\) |
| Thin n (pilot n=2) | **Open — needs scale** | Gate: user phrase `scale descriptive`; do not submit full NI on n=2 alone |
| Two overlapping manuscripts | **Solved by plan** | [PUBLICATION_PLAN.md](PUBLICATION_PLAN.md): P1 plant+boundary; P2 leftover; DKT software cites both |
| Software others can run | **Mostly solved** | `edgeuq` shift/jitter/instability/calibrate-leftover; Zenodo tag still pending |
| Harmonization as cure for site shift | **Solved as product rule** | Prefer **site/protocol \(\phi\)**; harmonization optional research only ([PREFIT_AND_SITE_MAPS.md](PREFIT_AND_SITE_MAPS.md)) |

## Paper 1 (plant + boundary)

| Concern | Status | Fix |
|---------|--------|-----|
| Positive use case + honest TRT fail | **Solved in draft** | Claim A plant win + Claim B leftover fail in same abstract |
| Soft invent / G quietly dropped | **Solved in draft** | Reported as locked fails |
| Scale / multi-site / HCP stratum | **Open** | Descriptive panels after `scale descriptive` ([PAPER1_AWAITING_SCALE.md](PAPER1_AWAITING_SCALE.md)) |
| Plant≠leftover figure | **Open (cheap)** | Fig plan exists; render PDF/SVG pre-submission |
| Alternate-atlas smoke | **Open (optional)** | N3 if cheap — improves odds, not a gate |
| Clinical/TBI leap | **Solved by non-claim** | No clinical leap in P1; TRACK-TBI only for plant held-out |

## Paper 2 (\(L\) / \(P_L\))

| Concern | Status | Fix |
|---------|--------|-----|
| Cross-site ECE ≈ 0.18 = “maps don’t transfer” | **Solved as finding** | Frame as **site/protocol dependence**, not universal \(\phi\); ship per-site maps |
| Within-site ECE must improve if clash was the driver | **Interim evidence** | Within-Kirby LOSO n=4: mean ECE ≈ **0.043**, y-rates 0.52–0.60 vs cross-site 0.54 vs 0.36 (`work/R/paper2/within_site_kirby/P_L_loso_within_kirby_interim_n4.json`) |
| Refresh n=5 (add KKI239) | **Blocked on pack** | KKI239 ses-2 / pack pending (`uhat_mini_pack_KKI239`); then re-run `run_within_site_PL.py` |
| Calibration CIs / n≈10–20 | **Open — scale** | n=5 exploratory; serious ECE bands after more Kirby + Boekel within-site |
| Baselines (random, FA, length, \(U\)/\(F\)) | **Partial** | \(L\) vs \(U\)/\(F\) in pilots; FA/length when edge features available |
| If ECE never passes | **Contingency locked** | Retitle to ranking / instability prediction; still publishable |
| Single-subject pre-fit \(\phi_L\) | **Rule locked; map not frozen** | CLI `apply-leftover-map` refuses stratum mismatch; freeze Kirby JSON after n=5 + scale CIs |

## Decision rule (submission)

| Evidence | Paper 2 venue posture |
|----------|----------------------|
| Within-site ECE holds + scale | NeuroImage / MedIA **calibration** paper |
| Ranking holds; ECE only within-site | NeuroImage-tier **methods** with site maps as product; cross-site as hard negative |
| Ranking holds; ECE fails everywhere | Imaging Neuroscience / NI:Reports — **ranking only**, no probability product claim |

## What is *not* blocked on more compute

Already closed or closeable in text/code today:

1. Non-claims, symbol discipline, three-output split  
2. Site-map > harmonization product rule  
3. Within-site vs cross-site narrative (interim n=4)  
4. CLI refuse cross-site leftover map apply  
5. Manuscript abstract guardrails  

Still require jobs / user gate:

1. KKI239 pack → n=5 within-Kirby refresh  
2. `scale descriptive` → cohort tables + CIs  
3. Zenodo / alternate atlas / figure renders  

---

## Related

- Interim JSON: `dwi_pipeline/methods/mapping_uhat/work/R/paper2/within_site_kirby/P_L_loso_within_kirby_interim_n4.json`  
- [PREFIT_AND_SITE_MAPS.md](PREFIT_AND_SITE_MAPS.md)  
- [PAPER2_LOCK.md](PAPER2_LOCK.md)  
