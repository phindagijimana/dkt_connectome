# FreeSurfer / FastSurfer vs individual DL methods

## Short answer

**Keep wrapping FastSurfer / FreeSurfer for default morphometry (`core`, `core-lesion`).**  
Use **individual engines** as cited stages, utilities, and specialty modules — not as a full replacement of `run_fastsurfer.sh` / `recon-all` for SUBJECTS_DIR production.

## Why wrapping is better for the default path

| Need | Individual tools only | FastSurfer / FS wrap |
|------|----------------------|----------------------|
| FreeSurfer-shaped `SUBJECTS_DIR` (DKT, white/pial, stats) | Fragile glue; easy to break QSIRecon/downstream | **Native contract** |
| Device split (GPU seg / CPU surf) | DIY | Upstream `--seg_only` / `--surf_only` |
| Versioned, cited stack | Many pins | One FastSurfer pin + modules |
| DLSurfer claim (“orchestrate, don’t replace”) | Looks like a fork | Matches claim |

DLSurfer already **names** the individual methods in `engines.yaml` (VINN, CC, CerebNet, HypVINN, recon-surf, SynthStrip, …). The planner **collapses** contiguous FastSurfer modules into `run_fastsurfer.sh` so citations stay honest without reimplementing the stack.

## When individual methods *are* better

| Case | Profile / engine | Notes |
|------|------------------|-------|
| Volume seg only | `seg-quick` (VINN) / `seg-quick-synthseg` | No surfaces |
| Odd contrast / clinical | `fs-clinical`, SynthSR preprocess | Not VINN default |
| Skull-strip / reg utils | `strip`, `register-*`, `bias-deepn4` | Standalone FS Synth* |
| Lesion fill | `neurolit` standalone in `core-lesion` | Intentionally *outside* FastSurfer |
| Structures FS lacks | claustrum, SynthSeg-PC, HippUnfold, HA/BS/thal | Specialty profiles |
| Experimental CSR | `surf-dl-*`, SUGAR, DL-CTE | Behind TBI±LIT gate |

## What not to do

- Do **not** replace `recon-surf` with a zoo of CSR nets for production connectome handoff until the TBI±LIT gate passes.  
- Do **not** call Mauri claustrum / SynthSeg-PC as substitutes for VINN whole-brain parc.  
- Do **not** require DKT connectome code inside DLSurfer.

## Cluster practice here

Use **Apptainer SIFs** (FastSurfer 2.6, FreeSurfer, neuroLIT) via `env/cluster_containers.sh` so `dlsurfer doctor` can go READY without a host module install. Still one orchestrated stack — not a DIY VINN-only pipeline.
