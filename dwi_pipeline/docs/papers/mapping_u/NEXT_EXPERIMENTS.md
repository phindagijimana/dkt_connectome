---
title: What is still open after A8 (no proxy-U-hat name)
date: 19 October 2026
---

# How we move on without naming proxy-\(\hat U\)

A8 used the only naming exam for the ANTs edge-frequency file. It failed. We keep the **measurements**. We stop the **name**. New work is new questions.

| # | Question | Product if it wins | Status |
|---|---|---|---|
| C | Is locked \(U\) a probability for planted 1 mm? | Calibrated \(U\) (1 mm only) | **Won.** Ship with the \(U\) paper. |
| A5 | Is leftover after usual alignment > 0.05 mm? | Session leftover mm (~0.7 mm) | **Won as mm.** Limitation of the 1 mm paper, not a \(P\). |
| A8 / L2 | Is the ANTs edge frequency a leftover / 1 mm probability? | would have been proxy-\(\hat U\) | **Failed.** Name closed. |
| **V1** | Where is leftover, in millimetres, on voxels? | Warp \(\phi\) maps (Hub ensemble SD) | **Won.** Confirmation voxel-median leftover 0.64–0.80 mm; voxel SD ~0.2 mm. Not \(\hat U\). |
| **V2** | What is \(p(\phi\mid\text{images})\)? | Simpson / VoxelMorph warp posterior | Package importable in `work/V2/venv`. Status `model_importable_not_run`. No posterior yet. Not \(\hat U\). |
| **G** | Does frozen calibrated \(U\) stay calibrated when \(y\) is a real leftover move? | \(\hat U\) if and only if the written exam wins | Rules locked. **Blocked** on ≥2 leftover paths in `sites_v1/LIST.json`. Kirby + Boekel pairs processing; run-1 packs queued (Paper 2). |
| **P1** | Do cheap baselines rank 1 mm movers as well as \(U\)? Are results stable across cuts? | Baseline + sensitivity tables for Paper 1 | Locked `work/P1/LOCK.json`. Slurm 189590. |
| **C2** | Does per-endpoint soft `radial_4` under measured leftover \(\sigma\) rank movers, and match leftover \(y\) better than hard? | Paper 3 | Locked `work/C2/LOCK.json`. Dev run 189577; leftover exam gated on Paper 2 data. |

Paper documents: Paper 1 `manuscript.md`; Paper 2 `PAPER2_LEFTOVER_UQ.md`; Paper 3 `PAPER3_C2_SOFT_ASSIGN.md`.

**Decision (20 Oct 2026):** write one combined paper (U as the method, C2 as extension and threshold diagnostic, the retest exam as validation). Plan, contribution, limits and the packaged software: `COMBINED_PAPER.md`.

## Registration noise models we can still run

1. **V1 (now)** — voxel-wise leftover from the A5 SyN ensemble we already paid for. Hub / Kybic. Maps, not probabilities.
2. **V2 (later)** — VoxelMorph / Simpson on T1 vs dwiref. Uncertainty on \(\phi\). Needs a model lock.
3. **G (when leftover files exist)** — do **not** build a new noise model first. Test **frozen calibrated \(U\)** on leftover \(y\). That is the remaining honest path **toward** \(\hat U\).
4. **G2 (only if G fails and V1/V2 exist)** — a **new** leftover model (e.g. \(\phi\) pushed through assignment), new lock, new win rule that does not require A8’s empty B9.

Do **not** run: another A8 on the same six sessions; more planted millimetres called leftover; Extra A as leftover; TBI021030 as leftover.

## Approach toward \(\hat U\) (not a rename)

The closed name was “this ANTs frequency is proxy-\(\hat U\).”

The open path is: **independent leftover** → \(y\) = did the edge move between those two real connectomes → test **frozen calibrated \(U\)** (G). Win → \(\hat U\). Fail → keep the 1 mm probability.

Copying other-site subjects into the home inbox **opens G**. It does not grant the name.
