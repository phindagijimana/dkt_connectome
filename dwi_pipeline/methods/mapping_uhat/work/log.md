# Wave agent log

| When | Item | Evidence | Claim |
|---|---|---|---|
| 2026-10-18 | A5 | `a5_summary.json` a5_fail=false. Six leftover.json K=50. Jobs 189120/189121/189122 COMPLETED. | Leftover mm measured. Not hat{U}. |
| 2026-10-18 | A6 | Labels-only code + Slurm. Tractogram frozen. radial_4 reused. Not 10M in Cursor. Array **189139** + continue **189140**. | Not hat{U}. Not A7. |
| 2026-10-19 | A6 | **189139**/**189140** failed all 6 (job). `assignments.csv` is space-separated; check used commas. Ends + L0 kept. Resubmit. | Not leftover science fail. Not \(\hat U\). |
| 2026-10-19 | A6 | Poll **189366**: all 6 R ~36 min. assign_check pair_agree=1.0. C npy 13–15/51 (identity + k). Continue **189372** waiting. | Not \(\hat U\). Not A7. |
| 2026-10-19 | A6 | Poll **189366**: all 6 R ~1:54. C npy 44–49/51; k on 044–049. Empty err. Continue waiting. | Not \(\hat U\). Not A7. |
| 2026-10-19 | A6 | **189366** COMPLETED all 6 (~2 h). Each session 10M ends, 50 \(C^{(k)}\) + identity. **189372** skip-if-done. | Labels-only matrices. Not \(\hat U\). Not A7. |
| 2026-10-19 | A7 | `work/a7/*/dkt_connectome_proxyUhat.csv`. Mean frequency 0.009–0.036; median 0; max 0.56–0.74. Cuts 0.25 / count≥10 frozen. | Frequency file only. Not proxy-\(\hat U\). Not A8. |
| 2026-10-19 | A8 | Exam A: n=8074 pooled TBI count≥10; y_rate=0.152; ECE_proxyUhat=0.126 > ECE_UasP=0.126; B9 n=0. Exam B not planted. `work/a8/a8_summary.json`. | Fail: keep U. Not proxy-\(\hat U\). Not \(\hat U\). Stop. |
| 2026-10-19 | A8 | Diagnosis only (`work/a8/diagnosis.json`). AUROC proxy 0.752 vs U 0.973; Spearman proxy–U 0.32; 84.6% proxy=0; max 0.74. Not a new exam. | keep U. Not a reopen. |
| 2026-10-19 | A8 | Challenge (`work/a8/challenge.json`). A6≡confirmation identity. Locked U mask max(all 18 plants)≥10 matches uq_summary; ECE 0.136 vs 0.121; n9=0. Fail robust. | keep U. Not a reopen. |
| 2026-10-19 | C | New lock `work/C/LOCK.json`. Isotonic U on demos; test TBI 1 mm. ECE 0.009 vs raw 0.121; B10 n=462, \|y−P\|=0.008. `c_summary.json`. | Win: 1 mm probability only. Not leftover. Not \(\hat U\). |
| 2026-10-19 | L | New lock `work/L/LOCK.json`. Plants array **189430** (3 TBI, leftover-sized label translation). Waiting. | Not proxy-\(\hat U\). Not \(\hat U\). |
| 2026-10-19 | L | **189430** COMPLETED ~2.5 min. \(t=0.56\)–\(0.90\) mm on 2 mm voxels; nearest shift 0. \(C=C^0\); y_rate=0. Not evaluable. | Null plant. Not leftover fail. Not \(\hat U\). |
| 2026-10-19 | L2 | New lock `work/L2/LOCK.json`. Same \((t,\hat e)\) as L; endpoints translated. Array **189433**. | Not named. |
| 2026-10-19 | L2 | Plant real (\(\Delta C\) 1538–3173). \(n=8108\), y_rate=0.019. ECE 0.018 < U 0.061; B6 \(n=73\), P=0.52 vs y=0.14. | Fail. keep U. Not proxy-\(\hat U\). |
| 2026-10-19 | G | Rules locked `work/G/LOCK.json`. `sites_v1/LIST.json` empty. Inbox written. | Run blocked. Not \(\hat U\). |
| 2026-10-19 | V1 | Lock then maps from A5 SyN `k*_norms.npy`. 6/6 sanity vs syn \(M_s\). TBI voxel-median leftover 0.64–0.80 mm. | Win: \(\phi\) mm maps. Not \(\hat U\). Not VoxelMorph. |
| 2026-10-19 | P1 | Persist `isotonic.json`. Ship six `dkt_connectome_Ucal.csv`. C still win ECE 0.009. | 1 mm \(P\) shipped. Not \(\hat U\). |
| 2026-10-19 | P2 | `leftover_mm_table.csv` from A5+V1. | mm only. Not a \(P\). |
| 2026-10-19 | P3 | `g_exam.py` gate. LIST empty; no `GOLD_LOCKED`. Exit 2. | No leftover ECE. |
| 2026-10-19 | P4 | V2 lock then probe. Images exist. voxelmorph missing. torch present unused. | `blocked_on_model`. Not \(\hat U\). |
| 2026-10-19 | V2 venv | `work/V2/venv` --system-site-packages. pip voxelmorph 0.3.4 + neurite 0.3.4 (campus artifactory; ignore quoted pip.conf). Probe re-run. | `model_importable_not_run`. No posterior. Not \(\hat U\). |
| 2026-10-19 | sample_data | `tracktbi_othersite/bids` empty. Extra BTC PAT* BIDS is not leftover y. Packages present. | G still blocked. |
| 2026-10-19 | paper figs | `docs/papers/mapping_u/figures/fig1_ranker_U.png` fig2 fig3 from locked JSON. | 1 mm paper only. |
| 2026-10-19 | V2 GPU | `slurm/v2_gpu.sbatch` + `RUN_LOCK.json`. Not submitted. | Still not posterior. |
| 2026-10-19 | V2 smoke | Local + Slurm **189448**. 32^3 VxmPairwise CPU. | Code check. Not posterior. Not \(\hat U\). |
| 2026-10-19 | sites 2WK | QSIPrep array **189449** (7 subjects, %2). 2WK only. | Opens dwiref. Not gold. Not Extra A. |
| 2026-10-19 | Kirby QSIPrep | **189460_1** COMPLETED. dwiref ses-1 and ses-2. | RETEST win for Kirby. Not leftover y. |
| 2026-10-19 | Kirby freeze | FastSurfer then QSIRecon+DKT count. 2WK FastSurfer array. | Opens C_a,C_b later. Not gold. |
| 2026-10-19 | Boekel eddy fix | 189572 eddy crashed both sessions: last vol of every run is Philips trace (b=1000, zero bvec). Dropped in all 212 runs (backup kept). Resubmit **189586**. | Data repair, not a tuning. Not leftover y. |
| 2026-10-20 | Overnight queue | `general` (7-day). Boekel pp01 FastSurfer **189587** → iFOD2+DKT **189588**. Kirby iFOD2 fallback **189589** (afterany 189574). Freeze scripts take RETEST_DATASET/RETEST_SID. | Same freeze as Kirby. Not leftover ECE. Not gold. |
| 2026-10-20 | P1 | `work/P1/LOCK.json` then `p1_baselines.py` (5 baselines + 3×3 cut grid). U algebra recovered from bytecode; recomputed U = shipped U (5e-9). Slurm **189590**. | Paper 1 tables. Descriptive. No retune. |
| 2026-10-20 | Retest pack | `retest_pack.py`: run-1 U/Ucal/C2 F; shift rule reproduces stored `ty_m1mm` exactly. C2 LOCK amended (retest sigma 0.498 mm, pooled V1) before numbers. Kirby **189592**, Boekel **189593**. Exam gated (LIST n≥2; G needs GOLD_LOCKED). | Papers 2 and 3. Not leftover numbers yet. |
| 2026-10-20 | Docs | Paper 1 `manuscript.md` status + §3.7/3.8 placeholders; new `PAPER2_LEFTOVER_UQ.md`, `PAPER3_C2_SOFT_ASSIGN.md`; `NEXT_EXPERIMENTS.md`, `BUILD_PHASES.md` updated. | — |
| 2026-10-19 | C2 | `work/C2/LOCK.json` before numbers. Per-endpoint soft radial_4, sigma = V1 median / 1.5382, S=32. Array **189577**, exam **189578** (afterok). | Planted 1 mm y only. Leftover exam waits for Kirby/Boekel counts. Not Exp2. Not \(\hat U\). |
