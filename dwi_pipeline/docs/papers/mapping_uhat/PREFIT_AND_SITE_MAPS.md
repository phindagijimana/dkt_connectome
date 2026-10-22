---
title: Pre-fit φ maps, single-subject use, site/protocol dependence, harmonization
date: 2026-10-21
status: LAB_NOTE
companions: [PAPER2_LOCK.md, EDGEUQ_TRUST_BANDS_HOOK.md, EVALUATION_AS_SCIENCE.md, CLAIMS_LIMITS_AND_MATH.md]
---

# Pre-fit maps and site dependence (Paper 2 / `edgeuq`)

Readable product note. Theory/claims spine: [CLAIMS_LIMITS_AND_MATH.md](CLAIMS_LIMITS_AND_MATH.md). Formal math: [PAPER2_MATH.md](PAPER2_MATH.md).

---

## Plain-language first

**Pre-fit map** = a frozen lookup \(\phi\): “given this score, what probability do we report?” learned once on a calibration cohort, then applied to new people **without** needing their second visit.

| Question | Answer |
|----------|--------|
| Can I get \(P_L\) from one scan? | **Yes**, if a **same-stratum** leftover map is shipped. |
| Do I need TRT on the new person? | **No** for apply; **yes** for anyone used to *fit* \(\phi\). |
| Can I use a Kirby map on Boekel? | **Not by default** — CLI refuses unless `--force-cross-site`. |
| Is plant \(U_{\mathrm{cal}}\) a leftover map? | **No** — different event (Paper 1 G fail). |

---

## What “pre-fit” means

A **frozen map** \(\phi\): score \(\mapsto\) probability, learned once on a **calibration cohort**, then **applied** to a new case.

| Map | Input → output | Needs TRT on the new subject? |
|-----|----------------|-------------------------------|
| Plant (Paper 1) | \(U \mapsto P(\text{planted 1 mm move})\) | No — single session |
| Leftover (Paper 2) | \(L \mapsto P_L = P(y^{\mathrm{leftover}}=1)\) | No for *application*; yes for *fitting* the cohort |

**Single-subject rules**

- **Allowed:** compute \(L\) from ses-1 only; apply a **shipped** same-site \(\phi_L\) if one exists.  
- **Not allowed as validation:** fit \(\phi\) on that subject’s own edges then report ECE on the same edges.  
- **Weak:** n=2 LOSO is a protocol demo, not a product map.

**Why the “not allowed” rule?** Fitting and scoring on the same person’s edges makes ECE look good by construction. We claim generalization across people, so train/test must split by **subject**.

---

## Do we have pre-fit maps today?

| Map | Status | Location |
|-----|--------|----------|
| Plant \(\phi_{\mathrm{plant}}\) | **Yes — shipped** | `edgeuq` package data `isotonic_1mm.json` (`edgeuq.metrics.load_isotonic`) |
| Leftover \(\phi_L\) | **Interim Kirby map shipped** (n=4 excl. KKI239) | `edgeuq` `src/edgeuq/data/isotonic_leftover_kirby21_ifod2_radial4.json` — stratum `kirby21_ifod2_radial4`; in **v0.2.0**; refresh after scale |

`edgeuq calibrate-leftover` fits \(\phi\); `apply-leftover-map` applies a shipped stratum JSON (refuses mismatch unless `--force-cross-site`).

---

## Can we get leftover pre-fits?

**Yes**, after enough **same-site / same-protocol** TRT pairs:

1. Fit isotonic \(\phi\) on Kirby within-site LOSO (or pooled Kirby with subject holdout for a release map).  
2. Freeze `isotonic_leftover_kirby.json` (versioned; cite Paper 2).  
3. Repeat for Boekel (and HCP stratum if recon differs).  
4. CLI: `edgeuq apply-leftover-map --map isotonic_leftover_kirby.json --stratum kirby21_ifod2_radial4 --count-run1 …` → \(P_L\) on one scan.  
5. Default: **refuse** applying Kirby map to Boekel/HCP without `--force-cross-site`.

Interim within-Kirby n=4 (ECE ≈ 0.04 vs cross-site ≈ 0.18) frozen 2026-10-22. KKI239 excluded from primary map (skip-mtnorm outlier). Re-freeze after scale CIs.

---

## Site / protocol dependence

### Intuition

Calibration asks: “when \(\phi\) says 0.6, do about 60% of edges move?” If site A moves ~54% of eligible edges and site B ~36%, a map trained on A will systematically mis-state probabilities on B — even if ranking (\(L\)) still helps.

### What we observed
- Cross-site LOSO (Kirby ↔ Boekel): ECE ≈ 0.18 with **y-rate clash** (~0.54 vs ~0.36).  
- Within-Kirby interim: ECE ≈ 0.04 with matched y-rates (~0.52–0.60).

So calibration failure is not “\(P_L\) never works”; it is often **wrong site/protocol for \(\phi\)**.

### Does harmonization solve it?

| Approach | Helps | Does not guarantee |
|----------|-------|---------------------|
| Image / count harmonization (e.g. ComBat-style) | May reduce scanner-driven shifts in \(C\) or \(L\) | Same leftover base rates; same \(L\!\to\!y\) curve; recon differences (ss3t vs multi-shell) |
| **Site- or protocol-specific \(\phi\) (preferred)** | Directly addresses the ECE clash we measured | Needs enough pairs per stratum |
| Pooled \(\phi\) after harmonization | Research hypothesis to test | Must show cross-site ECE improves; do not claim without that test |

**Lab preference (locked product rule):**

1. **Primary:** per-site (or per-protocol) maps; no silent cross-site apply.  
2. **Optional research:** test whether harmonization reduces cross-site ECE.  
3. **Do not** treat harmonization as a substitute for site maps in the software default.

---

## Relation to Paper 1 plant map

Plant \(\phi\) is a pre-fit for a **different estimand**. Reusing it on leftover \(y\) was Paper 1 G fail — that is why leftover needs its **own** \(\phi_L\), never named \(\hat{U}\).

**Analogy.** A thermometer calibrated for water baths is not automatically correct for outdoor air. Same instrument family, wrong target event.

---

## Checklist before shipping a leftover pre-fit

- [ ] Stratum defined (e.g. `kirby21_ifod2_radial4`)  
- [ ] Subject-level holdout or multi-fold ECE reported  
- [ ] y-rate range documented  
- [ ] Version + DOI / Paper 2 citation in file metadata  
- [ ] CLI warns on stratum mismatch  
- [ ] Harmonization **not** required for the default path  

---

## Related docs

- [CLAIMS_LIMITS_AND_MATH.md](CLAIMS_LIMITS_AND_MATH.md)  
- [PAPER2_LOCK.md](PAPER2_LOCK.md)  
- [PAPER2_MATH.md](PAPER2_MATH.md)  
- [EDGEUQ_TRUST_BANDS_HOOK.md](EDGEUQ_TRUST_BANDS_HOOK.md)  
- [EVALUATION_AS_SCIENCE.md](EVALUATION_AS_SCIENCE.md)  
- `edgeuq` `docs/leftover_cal.md`, `docs/shift.md`  
