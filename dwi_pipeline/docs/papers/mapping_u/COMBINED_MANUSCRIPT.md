---
title: Which connectome edges survive a rescan? Single-scan edge uncertainty for streamline-count connectomes
date: 20 October 2026
status: combined manuscript draft. Planted-shift results final; retest and tracking-control results pending (marked ⟨pending⟩).
supersedes_for_submission: manuscript.md (Paper 1), PAPER2_LEFTOVER_UQ.md, PAPER3_C2_SOFT_ASSIGN.md (kept as working records)
plan: COMBINED_PAPER.md
---

> Local TrackTBI-Sub. Do not push to public `dkt_connectome`. Before submission, replace confirmation-session study IDs with anonymised labels; this draft already uses Confirmation 1–3 (= TBI011011, TBI011021, TBI011204 in local records).
>
> **Naming rule.** Calibrated \(U\) is a probability for the planted 1 mm event. It may be described as calibrated for real rescan change only if the locked transport exam (G) passes. Do not name \(\hat U\) or proxy-\(\hat U\) in this draft.

| Pending item | Source | State |
|---|---|---|
| Retest scores on 2 pairs (Kirby21 KKI849, Boekel pp01) | `retest_pack.py`, Slurm 189618 / 189593 | Packs queued/running |
| Calibration of calibrated \(U\) on real change (G) | `g_exam.py`; needs `LIST.json` n≥2 and user "GOLD locked" | Gated |
| Tracking-only control (KKI849) | `slurm/reseed_control.sbatch`, Slurm 189619 | Queued |
| Scaling to ~55 pairs | decision: after both pairs pass | Not queued |
| Downstream payoff, second atlas, SIFT2 | — | Not started |

---

## Abstract

Streamline-count structural connectomes are built by assigning each streamline's two endpoints to cortical or subcortical nodes. Endpoints concentrate near tissue and parcel boundaries, so millimetre-scale residual registration or segmentation error can move streamlines between neighbouring nodes and change edge counts for reasons unrelated to anatomy. Group test–retest studies report average edge reliability, but no method estimates, from a single session, which edges of *that* connectome are fragile.

We present three linked tools. **U** re-assigns a session's own endpoints under twelve planted sub-millimetre translations and scores each edge by its worst relative count change; a frozen isotonic map converts U into a probability that the edge moves by more than 25% under a 1 mm shift. **C2** replaces the rigid shift with independent Gaussian jitter of every endpoint, sized from measured residual misregistration, and reports per-edge leakage, a soft connectome and the probability that each edge clears the count threshold. A **scan–rescan exam** asks whether scores computed from run 1 alone predict which edges change in an independently processed run 2.

On three public development and three held-out clinical sessions (iFOD2, 10 million streamlines, 78-node DKT), U ranked edges that move under held-out ±1 mm shifts with AUROC 0.91–0.95 (Spearman 0.86–0.90), against 0.77–0.78 for edge count alone and ≈0.5 for endpoint-geometry baselines, and was stable across threshold choices (AUROC ≥ 0.85 everywhere). Calibrated U reached held-out ECE 0.009 (raw U 0.121). C2 leakage, built without any planted shift, ranked the same movers with AUROC 0.89–0.93; its distinct output is threshold uncertainty: 0.8–1.6% of eligible edges per session sit on the count-10 threshold. On real scan–rescan pairs, ⟨pending: AUROC of U, calibrated U and F; low-count baseline; calibration; tracking-only control⟩.

Software reproducing all analyses from a tractogram and node image is provided as a container (`connectome-edge-uq`).

---

## 1. Introduction

Diffusion tractography connectomes count streamlines between parcels. The count depends on where each endpoint lands, and endpoints cluster at the grey–white boundary where parcel labels change over a few millimetres. Registration of T1-derived parcellations into diffusion space (Avants 2011; Cieslak 2021) leaves sub-millimetre to millimetre residual error even when pipeline QC passes. The MRtrix assignment documentation and Yeh et al. (2019, 2021) note that the endpoint-to-node assignment rule is consequential; perturbation studies show connectome measures shift under small spatial changes (Qi 2018; Buchanan 2014, 2015; Greene 2018, 2019).

What is missing is a per-edge, per-session answer: *in this connectome, which edges would change if the endpoints had landed slightly differently, and how likely is each to change on a rescan?* Edge reliability is otherwise available only from group test–retest data, as one average per edge that does not transfer to a new subject, pipeline or lesioned brain.

We contribute (i) U, a frozen ranking of edge fragility from a single session, with a calibration to a planted 1 mm event; (ii) C2, a per-endpoint stochastic assignment model that adds threshold uncertainty; (iii) a pre-specified scan–rescan exam, with a tracking-only control, that tests whether either predicts real change; and (iv) a container that reproduces all of it.

---

## 2. Methods

All rules below were written to lock files before the numbers they govern (Section 2.8).

### 2.1 Data and processing

| Role | Sessions |
|---|---|
| Development | IDEAS sub-1, IDEAS sub-6 (public demos); BTC glioma sub-PAT20 pre-op (OpenNeuro ds001226) |
| Confirmation | Three TRACK-TBI 2-week sessions, one site, lesion-aware ACT (Confirmation 1–3) |
| Scan–rescan | Kirby21 KKI849 (two same-day sessions); Boekel DWI test–retest pp01 (two sessions, four runs each) |

QSIPrep (Cieslak 2021) preprocessing; QSIRecon MRtrix3 single-shell SS3T CSD with hybrid surface–volume ACT; iFOD2, 10 million streamlines (backtrack, crop at GM–WM interface, dynamic seeding, length 30–250 mm). FreeSurfer/FastSurfer DKT parcellation (78 nodes) warped to DWI space. Boekel data required two repairs before eddy: total readout time from published bandwidth, and removal of the scanner-appended trace volume (b = 1000, zero gradient vector) from all 212 runs.

### 2.2 Endpoint assignment and count connectome

Each endpoint takes the label of its voxel; if unlabelled, the nearest labelled voxel within 4 mm (MRtrix radial search); otherwise it is unassigned. \(C^0_{ij}\) counts streamlines whose endpoints are assigned to \(i\) and \(j\), \(i \ne j\). Edge change between matrices \(A, B\): \(\mathrm{rel}(A,B) = |A-B| / \max(A,B)\). *Moved*: \(\mathrm{rel} > 0.25\) and \(\max(A,B) \ge 10\).

### 2.3 U: planted-shift fragility

All endpoints are translated by \(t\) along one scanner axis and re-assigned. Fit shifts: \(t \in \{\pm0.25, \pm0.5\}\) mm on x, y, z (12 maps). Test shifts: \(\pm1\) mm on x, y, z (6 maps).

\[
U_{ij} = \max_{s \in \text{fit}} \mathrm{rel}(C^0_{ij}, C^s_{ij}) \cdot \mathbb{1}[\max(C^0_{ij}, C^s_{ij}) \ge 10].
\]

The planted event uses the same algebra on the test maps: \(e_{ij}\) = max over test maps, \(y_{ij} = [e_{ij} > 0.25]\). Edges are scored if any of \(C^0\) and the 18 maps reaches 10. Development win rule: Spearman\((U,e) > 0.5\) and AUROC \(> 0.7\) on at least 2 of 3 development and 2 of 3 confirmation sessions. Sessions, not edges, are held out.

Review rule: ordinary QC (session PASS, no empty nodes) has no per-edge output; we compare it with a per-edge footnote \(U > 0.25\).

### 2.4 Calibrated U

Isotonic regression (Zadrozny & Elkan 2002) of \(y\) on \(U\), fit once on the 8112 eligible development edges (1 mm move rate 0.153), then frozen. Test: pooled confirmation edges. Win: ECE (Naeini 2015; 10 equal-width bins) below that of raw U, and the fit-frozen high bin evaluable (\(n \ge 20\)) with \(|\bar y - \bar p| \le 0.15\).

### 2.5 C2: per-endpoint soft assignment

Each endpoint is jittered independently, \(\delta \sim N(0, \sigma^2 I_3)\), and re-assigned with the same rule, \(S = 32\) times with fixed seeds. For streamline \(k\) hard-assigned to edge \(ij\), \(p_k\) is the fraction of samples on which it keeps the same node pair.

- Leakage: \(F_{ij} = 1 - \sum_{k \in ij} p_k / C^0_{ij}\).
- Soft connectome: \(E[C] = S^{-1} \sum_s C^s\).
- Threshold probability: \(P_{ij} = S^{-1} \sum_s [C^s_{ij} \ge 10]\); threshold-uncertain if \(0.1 < P_{ij} < 0.9\).

\(\sigma\) = measured median residual displacement / 1.5382 (the median of a 3-D isotropic Gaussian's magnitude is 1.5382σ). Residual displacement came from a 25-member SyN ensemble re-registering already-aligned T1 to the DWI reference, summarised at labelled voxels (session voxel-median 0.64–0.80 mm on confirmation; development σ 0.41–0.63 mm). Scan–rescan pairs use the pooled σ = 0.4981 mm, fixed before any retest number. Assumptions: isotropic, constant σ per session, independent ends; the coherent case is U's rigid shift.

Planted development exam: as for U, with \(F\) in place of \(U\). Soft-connectome rule (retest): \(E[C]\) must move less than \(C^0\) on every pair while inventing (\(E[C] \ge 10\) where \(C^0 < 10\)) at most 0.1% of scored edges.

### 2.6 Scan–rescan exam

U, calibrated U and C2 are computed on run 1 only. Run 1 and run 2 are processed independently by the same pipeline. Event: moved between \(C^{\text{run1}}\) and \(C^{\text{run2}}\) among edges with \(\max \ge 10\).

Primary: AUROC of U, calibrated U and F for real movers; baseline: low count (\(-C^{\text{run1}}\)). Secondary: threshold-crossing rate between runs; share of crossings on C2 threshold-uncertain edges; soft-connectome rule. Calibration (G): ECE of calibrated U on real movers and occupied-bin check (every bin with \(n \ge 20\) within ±0.15). The exam runs only with at least two pairs and after the transport rule is locked by the investigator.

### 2.7 Tracking-only control

Run 1's tractography is regenerated with the identical tckgen command and inputs, changing only the random seed (`MRTRIX_RNG_SEED = 20261020`), and assigned to run 1's node image with the same rule. Moved between run 1 and the reseed estimates how much of the run-1/run-2 change is tracking randomness rather than endpoint placement. Descriptive; no win rule.

### 2.8 Pre-specification

Lock files (JSON, version-controlled) fixed the shift sets, cuts, splits, isotonic map, C2 model and seeds, σ, the retest event, the soft-connectome rule and the tracking control before the corresponding numbers were computed. Amendments were dated and written before new numbers. The thresholds (relchange 0.25, count 10, radius 4 mm, win cut-offs) were never retuned; sensitivity to them is reported separately (Section 3.4).

### 2.9 Software

`connectome-edge-uq` (Python, NumPy, NiBabel; Docker/Apptainer) implements `edgeuq u`, `edgeuq c2` and `edgeuq retest` from a `.tck` and a node image. On a development session it reproduces the analysis code exactly: identical endpoints and \(C^0\), U within 5×10⁻⁹, F within 1.5×10⁻⁸, \(E[C]\) identical.

---

## 3. Results

### 3.1 U ranks planted movers (6/6 sessions)

| Session | Split | Eligible edges | 1 mm movers | Spearman\((U,e)\) | AUROC |
|---|---|---:|---:|---:|---:|
| IDEAS sub-1 | dev | 2742 | 389 | 0.861 | 0.906 |
| IDEAS sub-6 | dev | 2703 | 464 | 0.883 | 0.923 |
| BTC PAT20 | dev | 2667 | 389 | 0.867 | 0.912 |
| Confirmation 1 | confirm | 2604 | 439 | 0.886 | 0.923 |
| Confirmation 2 | confirm | 2791 | 426 | 0.887 | 0.935 |
| Confirmation 3 | confirm | 2841 | 474 | 0.899 | 0.945 |

Re-assignment without a shift reproduced the pipeline connectome (count Spearman 1.0). Ordinary QC accepted all six sessions and flagged no edges; \(U > 0.25\) flagged 78–138 edges per session at precision 0.98–0.99 against 1 mm movers (recall 0.20–0.29; conservative by design).

### 3.2 Calibrated U is a probability for the 1 mm event

Pooled held-out confirmation (\(n = 8236\), move rate 0.163): ECE 0.009 for calibrated U vs 0.121 for raw U. In the fit-frozen top bin [0.9, 1.0], mean predicted 0.978 vs observed 0.970 (\(n = 462\)).

### 3.3 U beats cheap baselines

Mean over three sessions (same edges, same event):

| Score | Dev Spearman | Dev AUROC | Confirm Spearman | Confirm AUROC |
|---|---:|---:|---:|---:|
| U | 0.870 | 0.914 | 0.891 | 0.934 |
| C2 leakage F | 0.768 | 0.898 | 0.782 | 0.923 |
| Low count \(-C^0\) | 0.566 | 0.783 | 0.540 | 0.769 |
| Near label boundary | 0.216 | 0.567 | 0.027 | 0.491 |
| Endpoints needing radial search | 0.160 | 0.561 | −0.028 | 0.550 |
| Short edge | 0.021 | 0.535 | 0.003 | 0.533 |

Edge count alone carries part of the signal; endpoint-geometry summaries are near chance.

### 3.4 Robustness to the cut-offs

Recomputing U, the event and the mask over relchange {0.15, 0.25, 0.35} × count floor {5, 10, 20}: AUROC 0.85–0.96 and Spearman 0.86–0.91 at every grid point (move rate 0.06–0.37). The ranking does not depend on the locked cuts.

### 3.5 C2 leakage ranks the same movers without a planted shift

| Session | σ (mm) | Spearman\((F,e)\) | AUROC F | AUROC U | Spearman\((F,U)\) |
|---|---:|---:|---:|---:|---:|
| IDEAS sub-1 | 0.63 | 0.759 | 0.904 | 0.906 | 0.706 |
| IDEAS sub-6 | 0.46 | 0.767 | 0.892 | 0.923 | 0.741 |
| BTC PAT20 | 0.59 | 0.777 | 0.897 | 0.912 | 0.757 |
| Confirmation 1 | 0.52 | 0.787 | 0.910 | 0.923 | 0.746 |
| Confirmation 2 | 0.48 | 0.773 | 0.927 | 0.935 | 0.731 |
| Confirmation 3 | 0.41 | 0.787 | 0.931 | 0.945 | 0.754 |

C2 passed its development rule on 3/3 + 3/3. U remained slightly better on every session; F and U are related (ρ 0.71–0.76) but not identical. Mean streamline stay probability was 0.95–0.96; 11–16% of endpoints had stay probability below 1.

### 3.6 Threshold uncertainty; the soft connectome is a diagnostic

Averaging over jitter moved 2–12 edges per session from below 10 to at least 10 (up to 0.45% of eligible edges, above the 0.1% rule) and moved 6–17 edges below 10. Thirty-three of 35 invented edges had hard count 6–9; two did not (hard 0 → soft 35.5; hard 2 → soft 14.8). Per session, 46–74 edges (0.8–1.6% of eligible) were threshold-uncertain, and 28 of the 35 invented edges were among them. We therefore report the hard connectome, flag threshold-uncertain edges, and use F as a fragility score; \(E[C]\) is not offered as a corrected connectome.

### 3.7 Scan–rescan ⟨pending⟩

| Pair | Scored edges | Move rate | AUROC U | AUROC cal. U | AUROC F | AUROC low count | Crossing rate | Crossings on flagged edges |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Kirby21 KKI849 | ⟨⟩ | ⟨⟩ | ⟨⟩ | ⟨⟩ | ⟨⟩ | ⟨⟩ | ⟨⟩ | ⟨⟩ |
| Boekel pp01 | ⟨⟩ | ⟨⟩ | ⟨⟩ | ⟨⟩ | ⟨⟩ | ⟨⟩ | ⟨⟩ | ⟨⟩ |

Calibration of calibrated U on real change (G): ⟨pending; gated⟩. Soft-connectome rule: ⟨pending⟩.

### 3.8 Tracking-only control ⟨pending⟩

Move rate run 1 vs reseed: ⟨⟩. Share of run-1/run-2 movers that also move under reseed: ⟨⟩. AUROC of U, calibrated U and F against reseed movers: ⟨⟩.

### 3.9 Context: how large is residual misregistration?

Re-registering already-aligned T1 to the DWI reference (25-member SyN ensemble) gave confirmation voxel-median residuals of 0.64–0.80 mm (voxel SD ≈ 0.2 mm; p95 of voxel medians 1.22–1.53 mm). A rigid endpoint shift of that size moved 1.9% of eligible edges, against 16% at 1 mm, so the 1 mm event lies in the residual band but is a stronger edge event. The ensemble's empirical edge-move frequency was not a calibrated probability (reported as a negative result in the supplement).

---

## 4. Discussion

Ordinary connectome QC is a session gate: it accepts or rejects a session. U adds a per-edge layer the gate cannot see. In every session QC accepted, U identified edges whose counts change under shifts well within residual misregistration, and ranked them far better than edge size or endpoint geometry. Calibrated U states that ranking as a probability for a defined 1 mm event.

C2 reaches almost the same ranking from a different error model, independent per-endpoint jitter of measured size, which supports the conclusion that the ranking reflects boundary geometry rather than an artefact of rigid shifts. Its distinct contribution is the threshold view: about 1% of eligible edges per session can appear or disappear at the common count-10 cut for reasons unrelated to anatomy. Its soft connectome invents edges at that cut and should not replace the hard connectome.

⟨pending: interpretation of the scan–rescan result. If U/F beat the low-count baseline on real change after the tracking control, the scores are validated per-edge reliability measures. If not, the planted and jitter models capture boundary fragility that real rescan change, dominated by ⟨tracking/other⟩ variation, does not reflect, and the paper reports that boundary.⟩

**Uses.** Down-weighting or masking fragile edges before group statistics reduces noise and the multiple-comparison burden; in longitudinal clinical work, a change on a low-U edge is more informative than one on a high-U edge, which matters after injury, where lesions and atrophy move boundaries; per-session fragility shows where registration accuracy matters; pipelines and atlases can be compared on fragility without new rescans.

---

## 5. Limitations

- One error source: endpoint placement relative to parcel boundaries. Not anatomical validity (a false-positive tract can be perfectly reliable) and not tractography randomness, which the reseed control measures but no method here corrects.
- The 1 mm event is planted. Calibrated U is a probability for that event unless the transport exam passes on real change.
- C2 assumes isotropic, spatially constant, independent jitter; real deformation is smooth and spatially varying.
- Development and confirmation: six sessions; confirmation from one clinical site. Scan–rescan: two pairs in this draft (⟨scaling pending⟩).
- One atlas (DKT-78), streamline counts only (SIFT2 not evaluated), one tracking algorithm (iFOD2).
- Isotonic calibration is fit on three public sessions and is not guaranteed to transfer to other reconstructions.

---

## 6. Data and code availability

Development and scan–rescan data are public (IDEAS; OpenNeuro ds001226; Kirby21; Boekel test–retest ⟨accessions to fill⟩). Clinical confirmation data are available from TRACK-TBI under its data-use agreement. Code and container: `connectome-edge-uq` (GitHub; Zenodo DOI ⟨at preprint⟩). Lock files and analysis code are archived with the release.

---

## References

Avants et al. 2011; Buchanan et al. 2014, 2015; Cieslak et al. 2021; Dalca et al. 2019; Greene et al. 2018, 2019; Hub & Kessler 2009; Kybic 2010; Naeini et al. 2015; Qi et al. 2018; Simpson et al. 2012; Tournier et al. 2019 (MRtrix3); Yeh et al. 2019, 2021; Zadrozny & Elkan 2002.
