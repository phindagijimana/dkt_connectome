# Atlases — DKT is default, not exclusive

DLSurfer produces a FreeSurfer-shaped subject tree. **Which cortical atlas** is labeled is a profile/engine choice. DKT is the **default** because FastSurferVINN / common DWI handoffs use it — not because DLSurfer is a “DKT-only” tool.

## Supported atlas surface

| Atlas | Status in DLSurfer | FreeSurfer | FastSurfer | How |
|-------|--------------------|------------|------------|-----|
| **DKT** (DKTatlas) | **Default** (`core`) | Yes | **Native** | `--atlas dkt` (default) |
| **Desikan–Killiany (DK)** | **Wired** | Yes | `--fsaparc` | `--atlas dk` or profile `core-dk` |
| **Destrieux (a2009s)** | **Wired** | Yes | After `sphere.reg` | profile `atlas-destrieux` |
| **Schaefer** | **Wired** | Project | Project | profile `atlas-schaefer` (`SCHAEFER_ANNOT_*`) |
| **HCP-MMP / Yeo** | Same pattern as Schaefer | Project | Project | Documented runner-up; reuse surf2surf |
| **aseg** | Always with core | Yes | Yes | Not a cortical choice |

## Design rules

1. **Default profile stays DKT** for FastSurferVINN parity.  
2. **Atlas is a parameter**, not a fork of the package.  
3. **Do not bake DKT connectome node tables into DLSurfer.** Node lists / LUT / disconnectome live in the connectome pipeline.  
4. Multiple atlases can coexist in one SUBJECTS_DIR as additional `.annot` / stats files (FreeSurfer pattern).

## CLI

```text
dlsurfer atlases
dlsurfer run --profile core --atlas dkt
dlsurfer run --profile core --atlas dk          # FastSurfer --fsaparc
dlsurfer run --profile core-dk                  # same intent
dlsurfer run --profile atlas-destrieux --t1 …   # needs existing surfaces
dlsurfer run --profile atlas-schaefer --t1 …
```
