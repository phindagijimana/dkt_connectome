# Paper 2 — math and held-out protocol

## 1. Data

For each subject \(s=1,\ldots,S\) (retest pair):

- \(C^{s,(1)}, C^{s,(2)}\in\mathbb{R}^{N\times N}\) — ses-1 / ses-2 count matrices (DKT \(N=78\)).  
- Optional ses-1 auxiliaries: \(P^{s}_{10}\), length, FA, bootstrap CV, …

Upper-triangle index set \(\mathcal{E}=\{(i,j):i<j\}\).

## 2. Labels

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

## 3. Ranking score (ses-1 only)

**v0 (locked primary):**

\[
L^{s}_{ij}=-\log\!\big(1+C^{s,(1)}_{ij}\big).
\]

**Optional feature expansions** (new symbol \(L^{+}\) if used as primary later):

\[
L^{+}=g\big(C^{(1)},\,1-P_{10},\,\mathrm{length},\,\mathrm{FA},\,\mathrm{CV}_{\mathrm{boot}},\ldots\big)
\]

with \(g\) fit only on train subjects. **Do not** insert plant \(U\) into \(L\) under the name \(U\).

## 4. Calibration map

On training subjects \(\mathcal{S}_{\mathrm{tr}}\), pool eligible edges and fit a monotone map

\[
P_L=\phi(L),\qquad \phi\text{ isotonic or Platt},
\]

minimizing squared error / Brier on \(\{y^{s}_{ij}:s\in\mathcal{S}_{\mathrm{tr}}\}\).

**Evaluate** on \(\mathcal{S}_{\mathrm{te}}=\mathcal{S}\setminus\mathcal{S}_{\mathrm{tr}}\):

- AUROC\((L,y)\), AUROC\((P_L,y)\) (ranking usually unchanged under strict monotone \(\phi\))  
- ECE\((P_L,y)\), Brier\((P_L,y)\)  
- Reliability diagram; occupied-bin \(|\bar y-\bar P|\le 0.15\) with \(n\ge20\) (same band language as historical G, **new target**)

## 5. Cross-validation

- **Preferred:** k-fold or LOSO by **subject**.  
- **Forbidden:** edges from a test subject in the isotonic fit.  
- **Pilot n=2:** LOSO is a **protocol demo** only; ECE failures expected (base-rate mismatch across sites).

## 6. Baselines (pre-register)

| Score | Direction |
|---|---|
| random | chance |
| \(-\log(1+C^{(1)})\) | = \(L\) v0 |
| \(1-P_{10}\) | threshold uncertainty |
| \(-\mathrm{FA}\), length | microstructure / geometry |
| \(U\), \(F\) | Paper 1 baselines only |
| optional \(\mathrm{CV}_{\mathrm{boot}}\) | resampling reliability |

## 7. Optional reliability class \(R\)

Using ses-1 \(P_{10}\) (and/or bootstrap):

- `sure_pos`: \(P_{10}\ge 0.9\)  
- `uncertain`: \(0.1<P_{10}<0.9\)  
- `sure_neg`: \(P_{10}\le 0.1\)  

Report enrichment of \(y=1\) and crossings in `uncertain` (Paper 1 Dir 2). \(R\) is a **product**, not a soft invent win.

## 8. Generative sketch (theory / N16)

- **Count world:** \(C^{(2)}\sim\mathrm{Poisson}(C^{(1)})\) (or NegBin) → expect \(L\gg U\).  
- **Plant world:** apply 1 mm endpoint operator → expect \(U\gg L\).  

Supports two-paper split; not a substitute for held-out \(P_L\).

## 9. Success statement (for abstract if win)

> Using only ses-1 counts, \(L\) ranked leftover movers; a subject-held-out map \(P_L=\phi(L)\) was calibrated to leftover \(y\) (ECE …). This probability is **not** plant-calibrated \(U\) and is not named \(\hat{U}\).
