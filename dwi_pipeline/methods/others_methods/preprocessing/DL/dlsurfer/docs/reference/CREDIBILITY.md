# Credibility & product identity

**DLSurfer = deep-learning FreeSurfer-suite methods** — not T1-only morphometry, not
TBI-only. Core is FreeSurfer-shaped T1 morphometry; **specialty includes multimodal
DL** that replaces FreeSurfer non-morphometry streams where credible tools exist.

Credibility = peer-reviewed evidence + public/reproducible tooling + appropriate
contract (FS tree or modality outputs) + lab readiness.

## Scale

| Tier | Meaning | Public surface |
|------|---------|----------------|
| **A** | Production-trust | Defaults + first-class specialty |
| **B** | Ready literature specialty | Preferred specialty; ops/deps may be open |
| **C** | Research / experimental specialty | **Allowed**; not default |
| **D** | Classical non-DL | Hidden; `--allow-classical` |

## A — Morphometry defaults + first-class T1 specialty

FastSurferVINN / CC / CerebNet / HypVINN (incl. `--t2`) · neuroLIT (optional) ·
SynthSeg (+ `--robust`/`--qc`) · SynthStrip / SynthSR / EasyReg · TopoFit ·
ScLimbic · Mauri claustrum · CortexMorph (thickness biomarker only).

`dlsurfer recon-all` → `core`.

## B — Ready specialty (T1 + multimodal)

**T1 / FS wiki DL:** HippUnfold · MARS · iBEAT · WMH-SynthSeg · thalamic DTI-CNN ·
V2C · SUGAR · Hippodeep / HD-BET · `atlas-*-dl` · `fs-clinical` · **SuperSynth** ·
**EasyAtlas** · **histo atlas (FireANTs)** · **FS8 embedded DL helpers** inventory.

**Multimodal (FS suite gaps now wired):**

| FS classical | DLSurfer DL | Profile / tool |
|--------------|-------------|----------------|
| TRACULA | **TractSeg** | `dwi-tractseg` / `dlsurfer tool tractseg` |
| PET helpers (MRI parc → SUVR) | **PET-DL quant** | `pet-dl-quant` / `pet-dl` |
| FS-FAST / fMRI helpers | **DeepPrep** | `fmri-deepprep` / `deepprep` |
| FreeView-only raw QC triage | **BrainQCNet** | `qc-brainqcnet` / `brainqcnet` |

## C — Experimental specialty (allowed)

VBG · SynthSeg-PC · nnU-Net PC · Deep-THOMAS · Albishri · AmygdalaGo · dHCP · CSR
zoo · DL+DiReCT · **DeepWMA** (TractSeg backup).

## D — Classical (not DL identity)

Bayesian HA/BS/thal · FS `-base`/`-long` · classical Destrieux/Schaefer ·
enantiomorphic · interactive `-autorecon2-*` edit loops (no DL replacement).

## Still no DL drop-in

Interactive **FreeView topology edit loops** (`-autorecon2-*`) — automated QC
assists triage only; humans still edit.

## CLI

```bash
dlsurfer credibility
dlsurfer tools                    # includes tractseg, pet-dl, deepprep, brainqcnet,
                                  # super-synth, easyatlas, histo-atlas, hypvinn-t2, …
dlsurfer recon-all -i T1 -sd SD -s SID
dlsurfer tool tractseg --t1 T1 --sd SD --sid SID   # needs DWI env — see STRUCTURE_MODULES
dlsurfer tool deepprep --t1 T1 --sd SD --sid SID
# FS wiki DL (literature + run): docs/reference/FS_DL_METHODS.md
dlsurfer cite --profile seg-super-synth
dlsurfer tool super-synth --t1 T1 --sd SD --sid SID -q
```
