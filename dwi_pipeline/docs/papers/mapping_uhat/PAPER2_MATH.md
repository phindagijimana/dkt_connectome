# Paper 2 — math and held-out protocol

Lab-readable walkthrough of the leftover estimand. For the short PI story and claim table, see [CLAIMS_LIMITS_AND_MATH.md](CLAIMS_LIMITS_AND_MATH.md). Manuscript tone stays in [PAPER2_manuscript.md](PAPER2_manuscript.md).

---

## 0. Plain-language overview

**Goal.** From a single scan’s counts, rank which edges are likely to change on a second visit, and (when a matching site map exists) attach a probability \(P_L\).

**Three ingredients.**

1. **Label \(y\)** — built only when *both* visits exist (training / evaluation).  
2. **Score \(L\)** — built from **ses-1 only** (usable on a new single session).  
3. **Map \(\phi\)** — learned on train **subjects’** \((L,y)\) pairs; applied as \(P_L=\phi(L)\).

**Hard rules.**

- Never fit \(\phi\) on the same subject you report ECE for.  
- Never call \(P_L\) plant \(\hat{U}\) or plant \(U_{\mathrm{cal}}\).  
- Prefer **one \(\phi\) per site/protocol stratum**; refuse silent cross-site apply.

---

## 1. Data

For each subject \(s=1,\ldots,S\) (retest pair):

- \(C^{s,(1)}, C^{s,(2)}\in\mathbb{R}^{N\times N}\) — ses-1 / ses-2 count matrices (DKT \(N=78\)).  
- Optional ses-1 auxiliaries: \(P^{s}_{10}\), length, FA, bootstrap CV, …

Upper-triangle index set \(\mathcal{E}=\{(i,j):i<j\}\).

**In words.** One person, two connectomes, same atlas and assignment rule. We only score undirected edges once (upper triangle).

---

## 2. Labels

**In words.** Edge \((i,j)\) is a leftover “mover” if relative count change exceeds \(\tau\) **and** at least one visit clears the count floor \(f\). Edges below the floor are excluded from AUROC/ECE so near-zero noise does not dominate.

\[
y^{s}_{ij}
=
\mathbf{1}\!\left\{
\mathrm{relchange}(C^{s,(1)}_{ij},C^{s,(2)}_{ij})>\tau
\;\wedge\;
\max(C^{s,(1)}_{ij},C^{s,(2)}_{ij})\ge f
\right\},
\quad (i,j)\in\mathcal{E}.
\]

Eligible edges for scoring: \(\mathcal{E}^{s}_{\mathrm{elig}}=\{(i,j)\in\mathcal{E}:\max(C^{s,(1)}_{ij},C^{s,(2)}_{ij})\ge f\}\).

Locked defaults: \(\tau=0.25\), \(f=10\), \(\mathrm{relchange}(a,b)=|a-b|/\max(a,b,\varepsilon)\).

---

## 3. Ranking score (ses-1 only)

**In words.** \(L\) is large when ses-1 count is small. That matches the TRT idea that weak edges churn more. You can compute \(L\) without ses-2; ses-2 is only needed to *define* \(y\) when fitting or evaluating.

**v0 (locked primary):**

\[
L^{s}_{ij}=-\log\!\big(1+C^{s,(1)}_{ij}\big).
\]

**Optional feature expansions** (new symbol \(L^{+}\) if used as primary later):

\[
L^{+}=g\big(C^{(1)},\,1-P_{10},\,\mathrm{length},\,\mathrm{FA},\,\mathrm{CV}_{\mathrm{boot}},\ldots\big)
\]

with \(g\) fit only on train subjects. **Do not** insert plant \(U\) into \(L\) under the name \(U\).

---

## 4. Calibration map

**In words.** Isotonic (or Platt) regression turns \(L\) into a probability that matches leftover move rates on the **training people**, staying monotone. Evaluation people are never in that fit.

On training subjects \(\mathcal{S}_{\mathrm{tr}}\), pool eligible edges and fit a monotone map

\[
P_L=\phi(L),\qquad \phi\text{ isotonic or Platt},
\]

minimizing squared error / Brier on \(\{y^{s}_{ij}:s\in\mathcal{S}_{\mathrm{tr}}\}\).

**Evaluate** on \(\mathcal{S}_{\mathrm{te}}=\mathcal{S}\setminus\mathcal{S}_{\mathrm{tr}}\):

- AUROC\((L,y)\), AUROC\((P_L,y)\) (ranking usually unchanged under strict monotone \(\phi\))  
- ECE\((P_L,y)\), Brier\((P_L,y)\)  
- Reliability diagram; occupied-bin \(|\bar y-\bar P|\le 0.15\) with \(n\ge20\) (same band language as historical G, **new target**)

**AUROC vs ECE.** AUROC asks “did we order edges correctly?” ECE asks “when we say 0.7, do ~70% actually move?” Ranking can succeed while cross-site calibration fails — that is our Kirby↔Boekel result.

---

## 5. Cross-validation

- **Preferred:** k-fold or LOSO by **subject**.  
- **Forbidden:** edges from a test subject in the isotonic fit.  
- **Pilot n=2:** LOSO is a **protocol demo** only; ECE failures expected (base-rate mismatch across sites).

**Why not edge-level CV?** Edges in one brain share anatomy, tracking, and QC. Subject is the unit of generalization we care about for a shipped map.

---

## 6. Baselines (pre-register)

| Score | Direction | Role |
|---|---|---|
| random | chance | Floor |
| \(-\log(1+C^{(1)})\) | = \(L\) v0 | Primary |
| \(1-P_{10}\) | threshold uncertainty | Competing ses-1 signal |
| \(-\mathrm{FA}\), length | microstructure / geometry | Competing |
| \(U\), \(F\) | Paper 1 baselines only | Show plant ≠ leftover |
| optional \(\mathrm{CV}_{\mathrm{boot}}\) | resampling reliability | Optional |

---

## 7. Optional reliability class \(R\)

Using ses-1 \(P_{10}\) (and/or bootstrap):

- `sure_pos`: \(P_{10}\ge 0.9\)  
- `uncertain`: \(0.1<P_{10}<0.9\)  
- `sure_neg`: \(P_{10}\le 0.1\)  

Report enrichment of \(y=1\) and crossings in `uncertain` (Paper 1 Dir 2). \(R\) is a **product**, not a soft invent win.

---

## 8. Generative sketch (theory / N16)

**In words.** Two different “noise models” predict two different winners — supporting the two-paper split.

- **Count world:** \(C^{(2)}\sim\mathrm{Poisson}(C^{(1)})\) (or NegBin) → expect \(L\gg U\).  
- **Plant world:** apply 1 mm endpoint operator → expect \(U\gg L\).  

Supports two-paper split; not a substitute for held-out \(P_L\).

---

## 9. Success statement (for abstract if win)

> Using only ses-1 counts, \(L\) ranked leftover movers; a subject-held-out map \(P_L=\phi(L)\) was calibrated to leftover \(y\) (ECE …). This probability is **not** plant-calibrated \(U\) and is not named \(\hat{U}\).
