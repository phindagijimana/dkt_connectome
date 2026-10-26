# Specialty structure + Synth* preprocess modules

Optional engines that fill anatomy **not** in default FastSurferVINN / DKT.  
Orchestrator-only — code stays in this folder; weights/tools live under lab `Documents/`.

| Profile | Engine | Lab path | Status |
|---------|--------|----------|--------|
| `preprocess-synthsr` | `synthsr` (`mri_synthsr`) | FS / `piriform/synthseg_pc/maybe_synthsr.sh` | **P** preprocess only |
| `structure-claustrum` | `mauri_claustrum` | `Documents/clau_seg` | **P** |
| `structure-piriform-synthseg` | `synthseg_pc` | `Documents/piriform/synthseg_pc` | **E** until JLF gate |
| `structure-hippunfold` | `hippunfold` | `Documents/HippUnfold` | **R** (HA alt) |
| `clinical-claustrum` | SynthSR → Mauri | both | **P** chain |

## Hard rules

1. **Mauri claustrum ≠ piriform.** Never run claustrum weights as Steinbart 125/126.  
2. **SynthSeg-PC ≠ `mri_synthseg`.** Stock FreeSurfer SynthSeg has no PC class.  
3. **SynthSR does not segment** PC or claustrum — T1 salvage only.  
4. **IDEAS production PC** stays **JLF** until SynthSeg-PC / nnU-Net clears the documented eval bar (`piriform` claims).  
5. Isolation: no DKT connectome imports; write under DLSurfer `--sd/--sid`.

## Env for SynthSeg-PC dry-run → execute

```bash
export SYNTHSEG_PC_ROOT=/path/to/Documents/piriform/synthseg_pc
export SYNTHSEG_PC_MODEL=/path/to/weights.h5
export SYNTHSEG_PC_LABELS=/path/to/segmentation_labels.npy
export SYNTHSEG_ROOT=/path/to/Documents/clau_seg/tools/SynthSeg   # or CLAU_SEG_ROOT
```

## Alternatives (PC)

Chosen experimental: SynthSeg-PC. Documented runners-up: **JLF** (production), **MAPER** (Steinbart paper), nnU-Net PC (research scaffold).

```bash
dlsurfer engines --id synthseg_pc
dlsurfer engines --id mauri_claustrum
dlsurfer cite --profile structure-claustrum
```
