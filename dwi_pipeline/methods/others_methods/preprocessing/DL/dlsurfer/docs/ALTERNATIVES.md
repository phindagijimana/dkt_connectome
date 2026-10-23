# All credible alternatives (chosen + runners-up)

**Policy.** Each stage has **one chosen** default in `engines.yaml` (`chosen: true`). All other credible options stay documented here and under `alternatives:` / `deferred:` for future swaps — without pulling them into the default path or into DKT connectome.

Readiness: **P** Production · **R** Ready · **S** Research · **E** Early · **C** Classical kept

| Stage | **Chosen** | Other best alternatives (keep for later) | Why not default |
|-------|------------|------------------------------------------|-----------------|
| Skull-strip | **SynthStrip (P)** | HD-BET (R); ROBEX (classic ML); nnU-Net/MONAI extractors (S) | SynthStrip already in FS; one-license path |
| Bias field | **DeepN4 (R)** | Simkó implicit CNN (S); Log-Gabor CNN bias (S); N4ITK classical (C) | DeepN4 portable + public weights; optional util only |
| Whole-brain seg | **FastSurferVINN (P)** | SynthSeg (P); QuickNAT (R/S); DeepSCAN (R/S); AssemblyNet (S); SLANT (S) | VINN = DKT-native + hi-res; SynthSeg kept as odd-contrast profile |
| CC | **FastSurfer-CC (P)** | Classical FS CC post (C) | Upstream FastSurfer default |
| Cerebellum | **CerebNet (P)** | Classical / atlas cereb (C) | Upstream module |
| Hypothalamus | **HypVINN (P)** | ScLimbic (P, FS); other subunit nets (S) | XOR: HypVINN with FastSurfer engine |
| Lesion fill | **neuroLIT standalone (P)** | Native `--lesion_mask` (P); VBG (R); LeAPP VBT (R); enantiomorphic (C/R) | Standalone keeps GPU/CPU split; VBG mixed on TBI; VBT TBI crash risk |
| Surfaces (default) | **recon-surf (C)** | — | Still best SUBJECTS_DIR contract |
| White surface DL | **TopoFit (P)** | V2C-Flow (R); Vox2Cortex (R); CortexODE (S); CorticalFlow (S); SurfNN (S); DeepCSR (S); FastCSR (S) | TopoFit ships in FS; others need TBI±LIT gate |
| Pial / joint CSR | **V2C-Flow (R)** (Phase 3) | PialNN (S); CortexODE (S); SurfNN (S); Vox2Cortex (R); CorticalFlow (S); recon-all-clinical SynthDist (P hybrid) | V2C-Flow = best Ready full WM+pial + template IDs |
| sphere.reg | **recon-surf spectral/FS (C)**; SUGAR (R) Phase 3 | S3Reg (R); V2C-Flow baked-in IDs (R) | Classical default; SUGAR if reg is bottleneck |
| Volume registration | **EasyReg + SynthMorph (P)** | VoxelMorph (S); TransMorph (S); ANTs (C) | Both ship in FS |
| Thickness w/o mesh | **DL-CTE family (R)** | DL+DiReCT (R); CortexMorph (R); direct CNN maps (S) | Biomarker only — never default morphometry |
| Alt full engine | **FreeSurfer 8 (P)** | FastSurfer `core` (P) | XOR per subject — never mix mid-tree |
| Longitudinal | **FS `-base`/`-long` (P)** via `fs-long` | SynthSeg-per-TP (P partial); V2C-Long (E) | Classical long is still best |
| Subfields HA | **segmentHA_T1 (P)** via `subfields-ha` | HippUnfold (R); Hippodeep (S) | Wired gap-fill |
| Brainstem / thalamic | **segmentBS + ThalamicNuclei (P)** via `nuclei-bs-thal` | (none stronger for FS-tree) | Wired gap-fill |
| Clinical / odd contrast | **recon-all-clinical (P)** via `fs-clinical` | SynthSeg volume; Infant FS (neonates) | Infant FS stays external |
| Cortical DK | **`--fsaparc` / `core-dk` (P)** | FS8 aparc | Wired |
| Destrieux | **`-a2009s` / `atlas-destrieux` (P)** | `mris_ca_label` | Wired |
| Schaefer / MMP | **`atlas-schaefer` surf2surf (R)** | HCP-MMP / Yeo same pattern | Wired |
| HPC launcher | **`--hpc srun\|brun` (P)** | `hpc/slurm_core_lesion.sh` | Wired |
| Hires VINN | **`--vox-size` (P)** | — | Wired |
| Module off switches | **`--no-cc/cereb/hypothal` (P)** | — | Wired |
| Claustrum | **Mauri `mri_claustrum_seg` (P)** via `structure-claustrum` | Albishri CNN; Casamitjana Bayesian | Lab `Documents/clau_seg` |
| Piriform (125/126) | **SynthSeg-PC (R/E)** via `structure-piriform-synthseg` | **JLF (P, IDEAS now)**; MAPER (P); nnU-Net PC (S) | Gate before production |
| Clinical T1 salvage | **SynthSR (P)** via `preprocess-synthsr` | skip; `fs-clinical` | Preprocess only |
| HA unfold morphometry | **HippUnfold (R)** via `structure-hippunfold` | segmentHA (default); Hippodeep | Lab `Documents/HippUnfold` |

Gaps with **no** credible alternative: [`GAPS_WITHOUT_ALTERNATIVES.md`](GAPS_WITHOUT_ALTERNATIVES.md).  
Specialty wiring: [`STRUCTURE_MODULES.md`](STRUCTURE_MODULES.md).

## Citations for runners-up (quick)

- HD-BET — Isensee et al. (brain extraction)  
- QuickNAT — Roy et al.  
- DeepSCAN — McKinley et al.  
- VBG — Radwan et al. NeuroImage 2021  
- LeAPP / VBT — Bey et al. HBM 2024  
- Enantiomorphic — Nachev et al.; Fekonja et al. 2022 (with FastSurfer)  
- CortexODE — Ma et al. TMI 2022  
- PialNN — Ma et al. 2021  
- CorticalFlow — Lebrat et al. 2022  
- SurfNN — Zheng et al. ISBI 2023  
- DeepCSR — Santa Cruz et al. WACV 2021  
- FastCSR — Ren et al. Brain Informatics 2022  
- S3Reg — Zhao et al. TMI 2021  
- Deutscher et al. 2025 — VBG caution on ms-TBI  

Machine-readable mirrors: `engines.yaml` → `alternatives:` on each chosen engine + top-level `deferred:`.
