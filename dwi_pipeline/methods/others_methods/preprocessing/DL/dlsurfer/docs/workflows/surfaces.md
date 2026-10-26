# Surfaces (Phase 3)

Default production surfaces are **V2C-Flow + FS contract** (`core` / `core-lesion`). Classical recon-surf is opt-in via `core-recon-surf` (`--allow-classical`).

DL surface methods write FreeSurfer-shaped trees via **`dlsurfer-install-surfaces`**
(`fs_surf_contract`): meshes land in `$SD/$SID/surf/{lh,rh}.{white,pial,sphere.reg}` with
`scripts/dlsurfer_surf_dl.done` (and a soft `recon-surf.done` marker).

| Backend | Profile | Gate | FS contract |
|---------|---------|------|-------------|
| TopoFit (`mris_estimate_wm`) | `surf-dl-topofit*` | `tbi_lit_topofit` **passed** | `--backend topofit --mode white` (promotes `?h.white.topofit`) |
| V2C-Flow | `surf-dl-v2c`, **`core-dl-surf`** | `tbi_lit_surfaces` **open** | `--backend v2c --mode full` |
| SUGAR | `sphere-sugar` | `tbi_lit_sphere_sugar` **open** | `--backend sugar --mode sphere` |

**Replace recon-surf packaging (DL path):**

```bash
dlsurfer plan --profile core-dl-surf --t1 T1.nii.gz --sd $SD --sid $SID
# or tool alias: dlsurfer tool recon-surf-dl …
```

Manual install after a DL run:

```bash
dlsurfer-install-surfaces --sd $SD --sid $SID --backend v2c --mode full --search-dir $SD/$SID
dlsurfer-install-surfaces --sd $SD --sid $SID --check-only --mode full
```

Wrappers `dlsurfer-v2c` / `dlsurfer-sugar` call the installer after successful inference.

Lab report: [lab/TBI_LIT_SURFACES_REPORT.md](../lab/TBI_LIT_SURFACES_REPORT.md).
