---
title: Build order after A8 (no proxy-U-hat name)
date: 19 October 2026
---

# Phase by phase — do not skip a gate

proxy-\(\hat U\) stays closed. New questions only. Do not start a later phase’s science until the earlier phase’s gate is written.

| Phase | Build | Gate before the next phase | Status |
|---|---|---|---|
| **0** | This order. No A8 rescue. No leftover ECE. | Written. | **Done.** |
| **1** | Ship \(U\) + calibrated \(U\) (1 mm \(P\)). `dkt_connectome_Ucal.csv`. Persist the isotonic map. | Files exist; C still a win; filename is `Ucal`, not `Uhat`. | **Done.** C ECE 0.009 vs 0.121. Six `Ucal` maps. |
| **2** | Package A5 + V1 leftover **mm** (limitation, not a \(P\)). | Table + V1 maps; no assignment; no ECE. | **Done.** `work/leftover_mm/`. |
| **3** | G runner. Frozen calibrated \(U\) vs leftover \(y\). | Runner **exits blocked** while `LIST.json` is empty or `GOLD locked` is absent. No ECE on empty data. | **Done.** `g_exam.py` exit 2. |
| **4** | V2 lock + probe for \(p(\phi\mid\mathrm{images})\). | Lock written **before** any VoxelMorph/Simpson number. Probe may only report whether a model exists. Not \(\hat U\). | **Done.** Venv on home; voxelmorph 0.3.4 importable. Status `model_importable_not_run`. No posterior. |
| **5** | G compute (later). | User writes `GOLD locked` **and** `LIST.json` has ≥2 leftover paths. | **Data in progress.** Kirby KKI849 + Boekel pp01 freezes running; `retest_pack.py` queued on run-1 (189592/189593). Exam gated. |
| **5b** | P1 baselines + cut sensitivity (Paper 1). | Lock before numbers. Descriptive; no retune. | Lock written; Slurm 189590. |
| **5c** | C2 per-endpoint soft `radial_4` (Paper 3). | Lock before numbers; dev exam on planted \(y\); leftover exam gated with G. | Dev running 189577/189578. |
| **6** | G2 (only if G fails). | New lock. New leftover model. Win rule that does not need A8’s B9. | Not this build. |

Forbidden in every phase: rename `proxyUhat`; retune \(e>0.25\) / count≥10; Gugger walk; TBI021030 as leftover; Extra A as leftover; planted mm as leftover \(y\).
