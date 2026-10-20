---
title: Voxel warp UQ — lock (phi, not U-hat)
date: 19 October 2026
status: V rules locked. V1 uses existing A5 SyN leftover. V2 VoxelMorph not started.
---

# Uncertainty on the warp \(\phi\), not \(\hat U\)

Registration UQ answers: after the usual T1–dwiref alignment, how many millimetres is the leftover warp, and where?

That is **not** \(P(\text{edge wrong}\mid\text{leftover})\). Simpson (2012) and Dalca / VoxelMorph (2019) work on \(\phi\). We have not run those models. We **have** a Hub / Kybic ensemble (A5): 50 small ANTs re-fits. That ensemble failed as an **edge probability** (A8, L2). It did **not** fail as millimetres. V1 is the spatial summary of those millimetres.

## V1 (this lock) — Hub voxel leftover maps

**Question (written before maps).** On labeled voxels, what is the voxel-wise median and SD of leftover displacement \(\|u_k(x)\|\) for A5 SyN members?

**Source.** `work/a5/<sid>/k*.json` with `transform==syn` and `k*_norms.npy`. Same six sessions as A5. Rigid members are a global leftover; they are not this warp map.

**Not a probability.** No \(P\), no \(y\), no ECE, no assignment.

**Sanity.** Session median of voxel-wise medians within 0.05 mm of `leftover.json` → `splits.transform.syn.M_s`. Same ensemble, spatial cut.

**Win.** Six sessions write `phi_median.npy` and `phi_sd.npy`; sanity holds. Claim: voxel leftover-mm maps.

**Fail.** Keep A5 session \(M_s\). Still not \(\hat U\).

**Forbidden.** Naming \(\hat U\) or proxy-\(\hat U\); pushing \(\phi\) through assignment under this lock; calling this Simpson or VoxelMorph.

Evidence: `methods/mapping_uhat/work/V/`.

## V2 — Simpson / VoxelMorph (own lock; probe only)

Lock: `methods/mapping_uhat/work/V2/LOCK.json`. Probe: `v2_probe.json`.

T1 + dwiref exist for the six inventory sessions. Home venv `work/V2/venv` has voxelmorph 0.3.4 + neurite 0.3.4 (torch reused). Status: `model_importable_not_run`. No \(p(\phi\mid\mathrm{images})\) was computed. This login node has no GPU. Still not gold.

## After V1, toward gold

Maps of leftover millimetres are a **registration noise description**. They become a leftover **model for edges** only if a later lock (not V, not A8) pushes \(\phi\) through assignment **and** tests that number on **independent** leftover \(y\) (experiment G).
