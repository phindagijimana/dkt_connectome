# Specialty modules

| Profile | Tool | DL? |
|---------|------|-----|
| `structure-claustrum` | Mauri `mri_claustrum_seg` | yes |
| `structure-piriform-synthseg` | SynthSeg-PC (gated) | yes |
| `structure-hippunfold` | HippUnfold (**preferred HA**) | yes |
| `structure-brainstem-mars` | MARS nnU-Net brainstem | yes |
| `structure-sclimbic` | ScLimbic limbic U-Net | yes |
| `nuclei-thalamic-dti-cnn` | FS thalamic DTI-CNN | yes |
| `seg-wmh-synthseg` | WMH-SynthSeg | yes |
| `infant-ibeat` | iBEAT V2.0 infant CSR | yes |
| `preprocess-synthsr` | SynthSR T1 salvage | yes |
| `seg-synthseg-robust` | SynthSeg `--robust`/`--qc` | yes |
| `seg-super-synth` | SuperSynth (`mri_super_synth`) | yes |
| `atlas-easyatlas` | EasyAtlas group template | yes |
| `structure-histo-atlas` | NextBrain FireANTs histo | yes |
| `structure-hypvinn-t2` | HypVINN + T2 | yes |
| `fs8-dl-modules` | FS8 embedded DL inventory | yes (runs `recon-all`) |
| `subfields-ha` / `nuclei-bs-thal` | FS Bayesian HA / BS / thalamic | **no** (classical fallbacks) |
| `atlas-destrieux-dl` / `atlas-schaefer-dl` | SUGAR → label transfer | DL reg + classical labels |
| `surf-dl-v2c-long` | V2C-Long (gated) | yes |

See [reference/STRUCTURE_MODULES.md](../reference/STRUCTURE_MODULES.md) ·
**sources + how to run:** [reference/FS_DL_METHODS.md](../reference/FS_DL_METHODS.md).
