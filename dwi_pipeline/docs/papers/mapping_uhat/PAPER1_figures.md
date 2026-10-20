# Paper 1 — figure plan

Status: **concept locked**. Render from existing arrays when drafting submission PDF; scale panels marked *pending*.

## Figure 1 — Method schematic (Claim A)

Panel A: streamline endpoints → radial_4 → count matrix.  
Panel B: planted translations → \(U\).  
Panel C: jitter → \(F\), \(E_{\mathrm{soft}}\), \(P_{10}\).  
Panel D: isotonic \(U\to P_{\mathrm{cal}}\) for **planted 1 mm only** (label clearly).

## Figure 2 — Plant validation

A: ROC curves \(U\) vs planted movers (dev + confirm; or representative).  
B: Reliability diagram for \(P_{\mathrm{cal}}\) on plant event (ECE callout).  
C *(optional)*: multi-mm AUROC bars (0.25 / 0.5 / 1.0) from N1.

## Figure 3 — Retest boundary (Claim B) — the honesty figure

A: AUROC bars \(U\), \(U_{\mathrm{cal}}\), \(F\), \(L\) on leftover \(y\) (Kirby + Boekel).  
B: Leftover move rate vs reseed floor (Kirby).  
C: Mover taxonomy stacked bar (both-present / cross / reseed-overlap).  
D: Reliability diagram of plant \(P_{\mathrm{cal}}\) on leftover \(y\) (shows fail).

## Figure 4 — Reporting products

A: Enrichment of crossings in uncertain \(P_{10}\) band.  
B: Decision utility curve (frac edges kept vs moved-frac among kept) — N14.  
C: Example edge table (top-30 + uncertain CSV from Dir 7).

## Figure 5 — Claim split simulation (N16)

Two ROCs or bar pairs: count-churn world (\(L\) wins) vs plant world (\(U\) wins).

## Figure S* — supplement

- Soft invent strata (C0 histogram of invents).  
- Strong-edge AUROC vs floor (Dir 6 / N11).  
- Subject scorecards (N12).  
- **Pending scale:** forest plot of move rate / \(L\) AUROC across cohort.

## Render checklist

| Fig | Data ready now? | Blocked on scale? |
|---|---|---|
| 1 | Yes (schematic) | No |
| 2 | Yes (plant locks) | No |
| 3 | Yes (pilots) | Optional cohort panel |
| 4 | Yes (pilots) | Optional cohort panel |
| 5 | Yes (N16) | No |
| S-scale | No | **Yes** — insert after `scale descriptive` |
