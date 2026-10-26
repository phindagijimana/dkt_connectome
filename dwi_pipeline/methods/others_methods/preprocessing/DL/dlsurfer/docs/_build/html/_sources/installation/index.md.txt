# Installation

DLSurfer is a thin Python CLI. **Science tools** (FastSurfer, FreeSurfer, neuroLIT) run via **Apptainer/Singularity SIFs** or a host install.

## Recommended (cluster)

1. Clone the repo and install the Python package (editable is fine).
2. Place or point to SIFs (FastSurfer cu126 2.6, FreeSurfer 7.4+, neuroLIT).
3. `source env/cluster_containers.sh` then `dlsurfer doctor` → **`[READY]`**.

See:

- [Apptainer containers](apptainer.md)
- [Python package](python.md)
- [Doctor check](doctor.md)

## External dependencies

| Dependency | Role |
|------------|------|
| Apptainer / Singularity | Run SIFs |
| FreeSurfer license file | `FS_LICENSE` / `--fs-license` |
| NVIDIA driver (GPU nodes) | FastSurfer VINN, LIT fill |
| Python ≥ 3.9 + PyYAML | DLSurfer CLI |

Optional: HippUnfold, SynthSeg-PC weights, Schaefer annots — only for specialty profiles.
