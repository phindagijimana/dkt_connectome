# Profiles

List engines / profiles:

```bash
dlsurfer engines
dlsurfer engines --alternatives
```

| Profile | Purpose |
|---------|---------|
| `core` | FastSurfer VINN + CC + Cereb + Hyp + recon-surf |
| `core-lesion` | **Default lesion path**: LIT fill → core → lit-post |
| `core-lesion-native` | Native `--lesion_mask` (no seg/surf split) |
| `seg-quick` | `--seg_only --tal_reg` (volume + talairach) |
| `seg-quick-synthseg` | SynthSeg volume alt |
| `strip` / `register-*` / `bias-deepn4` | Utilities |
| `fs-long`, `subfields-ha`, `nuclei-bs-thal` | FS gap-fills |
| `fs-clinical`, `preprocess-synthsr` | Odd contrast / salvage |
| `atlas-*`, `--atlas dk` | Extra parc |
| `structure-claustrum`, `structure-hippunfold`, … | Specialty |
| `surf-dl-topofit*` | TopoFit WM (gate: passed machine check) |
| `surf-dl-v2c`, `sphere-sugar`, `thickness-fast` | Still gated open |

Experimental profiles need a **passed gate** or `--allow-experimental`.
