---
title: Pre-fit φ maps, single-subject use, site/protocol dependence, harmonization
date: 2026-10-21
status: LAB_NOTE
companions: [PAPER2_LOCK.md, EDGEUQ_TRUST_BANDS_HOOK.md, EVALUATION_AS_SCIENCE.md]
---

# Pre-fit maps and site dependence (Paper 2 / `edgeuq`)

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

---

## Do we have pre-fit maps today?

| Map | Status | Location |
|-----|--------|----------|
| Plant \(\phi_{\mathrm{plant}}\) | **Yes — shipped** | `edgeuq` package data `isotonic_1mm.json` (`edgeuq.metrics.load_isotonic`) |
| Leftover \(\phi_L\) | **Interim Kirby map shipped** (n=4 excl. KKI239) | `edgeuq/data/isotonic_leftover_kirby21_ifod2_radial4.json` — stratum `kirby21_ifod2_radial4`; refresh after scale |

`edgeuq calibrate-leftover` **fits** \(\phi\) for a subject list; it does not yet install `isotonic_leftover_*.json` into the package.

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

- [PAPER2_LOCK.md](PAPER2_LOCK.md)  
- [EDGEUQ_TRUST_BANDS_HOOK.md](EDGEUQ_TRUST_BANDS_HOOK.md)  
- [EVALUATION_AS_SCIENCE.md](EVALUATION_AS_SCIENCE.md)  
- `edgeuq` `docs/leftover_cal.md`, `docs/shift.md`  
