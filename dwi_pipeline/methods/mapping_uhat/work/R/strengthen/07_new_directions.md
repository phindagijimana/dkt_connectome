# New directions — strengthen methods & claims beyond the six salvage points

Status: **proposal catalog** (2026-10-20). Not queued. No frozen-cut retunes.  
Hang under Claim spine A/B/C. Prefer one direction at a time when you say go.

These are **additional** ways to harden the paper: better questions, new scores, new validations — not ways to erase GOLD FAIL.

---

## Theme I — Sharpen Claim A (plant fragility)

### N1. Multi-magnitude plant curves
**Question:** Does \(U\) rank plants at 0.25 / 0.5 / 1 / 2 mm with a smooth AUROC curve, or only at the locked 1 mm test?
**Why strengthen:** Shows \(U\) is a general sensitivity surface, not a one-cut trick.
**Deliverable:** AUROC vs plant mm plot on 1–2 packs; no leftover involvement.

### N2. Spatial structure of high-\(U\) edges
**Question:** Are high-\(U\) edges enriched at thin cortex, deep GM, or long association tracts?
**Why:** Mechanistic story for plant fragility (anatomy, not just matrix scores).
**Deliverable:** Atlas overlays + enrichment vs length/FA if available.

### N3. Parcellation stress test
**Question:** Do \(U\)/\(F\) plant AUROCs hold under Schaefer-100 / Lausanne vs DKT-78?
**Why:** Methods generality; reduces “DKT-only” critique.
**Deliverable:** Same tck, new nodes, plant exam only.

### N4. Endpoint vs tract mid-point perturbation
**Question:** Is leftover/plant sensitivity dominated by **endpoints** (current) or would mid-streamline jitter change rankings?
**Why:** Defends the endpoint modeling choice.
**Deliverable:** Ablation score \(F_{\mathrm{mid}}\) vs \(F\); plant and leftover AUROCs.

---

## Theme II — Own Claim B (retest boundary) scientifically

### N5. Phenomenon taxonomy of leftover movers
**Question:** What fraction of leftover movers are (a) threshold cross, (b) both-present large ΔC, (c) appear/disappear, (d) also reseed-movers?
**Why:** Turns “AUROC failed” into a **decomposition paper result** (extends Dir 3).
**Deliverable:** Stacked bar per subject; cohort summary when scaled.

### N6. Time-scale contrast (same-day vs longer interval)
**Question:** Does leftover move rate and \(L\) AUROC change from same-day (Kirby/Boekel) to HCP retest interval?
**Why:** Separates acquisition noise from biology/time.
**Deliverable:** Stratum table; still descriptive (no hat{U}).

### N7. Site / protocol strata
**Question:** Are D1–D5 stable across Kirby vs Boekel vs HCP preprocessing paths?
**Why:** External validity without claiming leftover calibration.
**Deliverable:** Forest plots of move rate, uncertain frac, \(L\) AUROC.

### N8. Negative-control battery (pre-registered)
**Question:** Which scores *should* fail leftover ranking (random, degree, FA) vs which should succeed (\(L\), maybe length)?
**Why:** Shows \(L\) isn’t “anything correlates with weak edges.”
**Deliverable:** AUROC table of controls; pre-specify before scale.

---

## Theme III — Grow Claim C (\(L\) and successors)

### N9. Calibrated leftover probability (new symbol, e.g. \(P_L\))
**Question:** Can an isotonic / Platt map fit on **leftover** (not plant) yield ECE-band pass for \(L\)?
**Why:** Gives a real probability for visit change — **must stay named \(P_L\)**, never \(\hat{U}\).
**Risk:** Needs held-out subjects; only after scale descriptive has n≫2.
**Deliverable:** Train/test split protocol lock first.

### N10. Hybrid plant×count score
**Question:** Does \(L + \alpha U\) or rank-fusion beat \(L\) alone on leftover without hurting plant AUROC?
**Why:** Uses both phenomena; still a **new named** score.
**Deliverable:** Sweep α on pilots only for hypothesis; confirm on held-out.

### N11. Conditional \(L\) on strong edges
**Question:** On min(C0,C1)≥50 or ≥100, what residual can be predicted (length, FA, U, geometry)?
**Why:** Paper currently says leftover is weak-edge; strong-edge residual is the hard scientific prize.
**Deliverable:** Nested models; expect small effects — report honestly.

### N12. Graph-level summaries
**Question:** Do subject-level stats (mean \(L\), uncertain fraction, reseed gap) predict session QC or outlier status better than mean FA?
**Why:** Product for scanners/QC dashboards, not only edge tables.
**Deliverable:** Subject scorecard + association with known QC flags if any.

---

## Theme IV — Soft / reporting product

### N13. Continuous invent risk instead of binary invent
**Question:** Can \(P_{10}\) itself be the invent risk score, with a ROC against “became ≥10 on run-2”?
**Why:** Keeps invent lock binary for soft-win, but adds a **useful** continuous product.
**Deliverable:** AUROC of \(1-P_{10}\) or uncert score vs run-2 appearance (related to Dir 2).

### N14. Decision curve / reporting utility
**Question:** If users hide threshold-uncertain edges, how much leftover moved-frac drops vs how many edges they sacrifice?
**Why:** Translates Dir 2 into a **clinical/reporting utility** curve.
**Deliverable:** Tradeoff plot per pilot → scale descriptive.

### N15. Bundle-aware uncertainty
**Question:** Aggregate \(U\)/\(F\)/\(L\) to major bundles (AF, CST, CC) — do bundle scores replicate across visits better than edges?
**Why:** Many readers think in bundles; may recover reliability Claim B lost at edge level.
**Deliverable:** Bundle ICC table; optional figure.

---

## Theme V — Causal / generative strengthening

### N16. Controlled leftover simulation
**Question:** If we plant only low-count noise vs only 1 mm endpoint shift on a fixed ses-1 tck, which synthetic leftover does \(U\) vs \(L\) recover?
**Why:** Causal ground truth separating the two phenomena (supports claim split).
**Deliverable:** Simulation study section; high impact, moderate compute.

### N17. Registration / packing ablation
**Question:** How much leftover move rate is explained by ses-2 node misalignment vs tracking (partially addressed by reseed)?
**Why:** Another floor under Dir 3; may need rigid re-apply of ses-1 nodes to ses-2 tck.
**Deliverable:** “nodes-fixed leftover” vs full leftover.

### N18. Multi-shell vs single-shell
**Question:** Does HCP multi-shell reduce leftover move rate or improve \(L\) AUROC vs Kirby/Boekel single-shell?
**Why:** Protocol recommendation; strengthens methods impact for acquisition choices.

---

## Theme VI — Paper / impact packaging

### N19. Pre-registered analysis plan (osf/zenodo)
**Question:** Can we lock metrics + non-claims publicly before scale descriptive?
**Why:** Maximizes trust after a FAIL; reviewers love pre-reg of negative boundaries.

### N20. Software-first contribution
**Question:** Is the citable unit `edgeuq` (shift/jitter/instability/rescan) with frozen protocol docs?
**Why:** Impact via reuse even if retest transfer is negative — methods journal fit.

### N21. Minimal clinical vignette (lesion / TBI)
**Question:** On one TBI case, do high-\(U\) edges overlap lesion-adjacent disconnectome more than chance?
**Why:** Illustrative impact figure — **not** a retest claim; keep n=1 clearly marked.

---

## Suggested priority order (when you pick next work)

| Priority | IDs | Reason |
|---|---|---|
| First wave (cheap, high clarity) | N5, N8, N13, N14, N16 | Deepens Claim B/C without mass scale |
| With **scale descriptive** | N6, N7, N12, N15, N18 | Needs cohort n |
| After held-out n | N9, N10, N11 | Calibration / fusion |
| Impact packaging | N19, N20, N21 | Parallel to science |

## Hard constraints for all new directions

- No invent-cap / floor / relchange retune to rescue soft/G/\(U\) leftover AUROC.
- New predictive scores get **new symbols**.
- Negative results are publishable under Claim B.
- Mass queue only under Strengthen §5 gate phrase.
