# Profiles

List engines / profiles:

```bash
dlsurfer engines
dlsurfer engines --alternatives
```

| Profile | Purpose |
|---------|---------|
| `core` | FastSurfer VINN + CC + Cereb + Hyp + **V2C-Flow** surfaces (no recon-surf) |
| `core-lesion` | **Default lesion path** (DL LIT → seg → V2C → lit-post) |
| `core-lesion-native` | Alias of `core-lesion` |
| `core-recon-surf` | Classical recon-surf fallback (`--allow-classical`) |
| `seg-quick` | `--seg_only --tal_reg` (volume + talairach) |
| `seg-quick-synthseg` | SynthSeg volume alt |
| `strip` / `register-*` / `bias-deepn4` | Utilities |
| `fs-long`, `subfields-ha`, `nuclei-bs-thal` | Classical FS gap-fills (not DL) |
| `structure-hippunfold`, `structure-brainstem-mars`, `nuclei-thalamic-dti-cnn` | **Preferred DL** HA / BS / thalamus |
| `structure-sclimbic`, `seg-wmh-synthseg`, `infant-ibeat` | Limbic / WMH / infant DL |
| `surf-dl-v2c-long` | DL longitudinal (gated) |
| `atlas-destrieux-dl`, `atlas-schaefer-dl` | SUGAR → label transfer (gated) |
| `fs-clinical`, `preprocess-synthsr` | Odd contrast / salvage |
| `atlas-*`, `--atlas dk` | Extra parc |
| `structure-claustrum`, `structure-piriform-synthseg`, … | Specialty |
| `surf-dl-topofit*` | TopoFit WM + FS `surf/` contract (gate: passed) |
| `core-dl-surf` / `recon-surf-dl` | VINN seg + V2C + FS contract (no classical recon-surf; gated) |
| `surf-dl-v2c`, `sphere-sugar`, `thickness-fast` | Still gated open |

Experimental profiles need a **passed gate** or `--allow-experimental`.
