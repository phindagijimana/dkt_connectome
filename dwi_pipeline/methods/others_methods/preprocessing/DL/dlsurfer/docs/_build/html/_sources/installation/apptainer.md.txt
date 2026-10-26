# Apptainer containers

## Lab wrapper (this cluster)

```bash
cd /path/to/dlsurfer
source env/cluster_containers.sh
```

Sets:

| Variable | Meaning |
|----------|---------|
| `FASTSURFER_HOME` | Wrapper dir with `run_fastsurfer.sh` → SIF |
| `FREESURFER_HOME` | Thin FS home + `env/bin/*` tool wrappers |
| `FS_LICENSE` | FreeSurfer license path |
| `DLSURFER_SIF_*` / `SIF_*` | Paths to FastSurfer, LIT, FreeSurfer SIFs |

Wrappers under `env/bin/` (`lit-inpainting`, `mri_synthstrip`, `mris_estimate_wm`, …) call `apptainer exec` with NFS binds. GPU tools pass `--nv` when `nvidia-smi` is available (`DLSURFER_FASTSURFER_NV`, `DLSURFER_LIT_NV`, `DLSURFER_FS_NV`).

## Expected SIF names (example)

```text
fastsurfer_cu126_v2.6.0.sif
lit_0.6.0.sif
freesurfer_7.4.1.sif
```

Point `env/cluster_containers.sh` (or env vars) at your container store. Do **not** commit SIFs or license files to git.

## Optional meta-image

`containers/dlsurfer.def` is a scaffold for a single image that bundles the CLI; production runs here use the three SIFs above.
