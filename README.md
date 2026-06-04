# dk_connectome

**A reproducible Snakemake workflow that turns a BIDS diffusion-MRI dataset into Desikan-Killiany structural connectomes.**

[![Snakemake](https://img.shields.io/badge/snakemake-≥8.0-brightgreen.svg)](https://snakemake.readthedocs.io)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![BIDS App](https://img.shields.io/badge/BIDS--App-compatible-blue.svg)](https://bids-apps.neuroimaging.io/)

`dk_connectome` wraps the standard nipreps DWI processing stack — [QSIPrep](https://qsiprep.readthedocs.io/) for preprocessing, [QSIRecon](https://qsirecon.readthedocs.io/) for tractography, [FreeSurfer](https://surfer.nmr.mgh.harvard.edu/) (or [FastSurfer](https://github.com/Deep-MI/FastSurfer)) for anatomical surface reconstruction, and [MRtrix3](https://www.mrtrix.org/) / [ANTs](https://github.com/ANTsX/ANTs) for parcellation + connectome construction — into a single, declarative, restartable Snakemake DAG.

The orchestrator itself is just Snakemake. Every heavy step runs inside a pinned [Apptainer](https://apptainer.org/)/Singularity container, so the scientific output is **reproducible across sites without any per-machine compiler or library setup**.

---

## Pipeline

```
BIDS sub-XXX/
   ├── dwi/  ── rule qsiprep ──────►  qsiprep_single_run_output/sub-XXX/
   │                                       │
   │                                       ▼
   └── anat/ ── rule recon  ──────►  freesurfer/sub-XXX/mri/aparc+aseg.mgz
                                          │
                                          ▼
                          rule qsirecon ─►  qsirecon_single_run_output/.../*.tck.gz
                                          │
                                          ▼
                          rule dk_connectome ─►  dk_connectomes/sub-XXX/dk_connectome.csv
```

Per subject, four stages run in order. Stages can be toggled and individual subjects can be re-run independently — Snakemake skips any stage whose outputs already exist.

| Stage | Tool | Container | Typical wall time (single-shell ~64 dir, 1 session) |
|---|---|---|---|
| 1 — `qsiprep` | QSIPrep | `qsiprep.sif` | 1.5 – 4 h |
| 2 — `recon` | recon-all *or* FastSurfer | `freesurfer.sif` / `fastsurfer.sif` | 4 – 10 h (recon-all) · ~1 h (FastSurfer CPU) |
| 3 — `qsirecon` | QSIRecon (SS3T CSD + ACT + HSVS) | `qsirecon.sif` | 3 – 5 h |
| 4 — `dk_connectome` | ANTs + FreeSurfer + MRtrix3 | `qsirecon.sif` | ~3 min |

### What you get per subject

```
dk_connectomes/sub-XXX/
    dk_connectome.csv             # 84×84 symmetric DK connectivity matrix
    dk_assignments.csv            # streamline → (node_i, node_j) mapping
    dk_nodes.mif                  # MRtrix node label image (post-labelconvert)
    aparc+aseg_in_dwi.nii.gz      # FS parcellation resampled to DWI grid
    aparc+aseg.nii.gz             # FS parcellation in FS conformed space
    dk_nodes.mrinfo.txt           # space diagnostic (header + transform)
    tracks.tckinfo.txt            # tractogram header
```

Plus all QSIPrep, FreeSurfer, and QSIRecon derivatives under their respective output directories — these are full BIDS-App derivatives, usable directly by any downstream nipreps tool.

---

## Quick start

### 1. Install the orchestrator

Snakemake 8+ and its Slurm executor plugin, into any Python ≥ 3.11 env:

```bash
pip install -r requirements.txt
```

Or via conda/mamba:

```bash
mamba env create -f environment.yml
conda activate dk_connectome
```

[Apptainer](https://apptainer.org/docs/admin/main/installation.html) (or Singularity) must be on `PATH`.

### 2. Pull the containers

```bash
mkdir -p containers && cd containers
apptainer pull qsiprep.sif        docker://pennlinc/qsiprep:1.0.0
apptainer pull qsirecon.sif       docker://pennlinc/qsirecon:1.2.1
apptainer pull freesurfer_7.4.1.sif docker://freesurfer/freesurfer:7.4.1
# Optional — only needed if you set recon.tool: fastsurfer
apptainer pull fastsurfer.sif     docker://deepmi/fastsurfer:latest
```

Pin the exact digests you used in your published runs (`apptainer inspect --json containers/qsiprep.sif | jq .data.attributes.deffile`).

### 3. Get a FreeSurfer license

Apply (free) at <https://surfer.nmr.mgh.harvard.edu/registration.html>. Drop the `license.txt` and `FreeSurferColorLUT.txt` (shipped with any FreeSurfer install) somewhere readable.

### 4. Configure

Copy and edit `config/config.yaml`:

```bash
cp config/config.yaml config/myconfig.yaml
$EDITOR config/myconfig.yaml         # set bids_dir, containers.*, fs_license
```

Generate a subject list from your BIDS dataset:

```bash
python workflow/scripts/list_subjects.py /path/to/bids \
    --require-dwi --require-t1w > config/subjects.tsv
```

### 5. Dry-run, then run

```bash
# Inspect the DAG without executing
snakemake --configfile config/myconfig.yaml -n -r

# Run locally
snakemake --configfile config/myconfig.yaml -j 4

# Run on Slurm (recommended)
sbatch submit_snakemake.sh --configfile config/myconfig.yaml
```

The Slurm driver itself is a tiny 1-CPU/4 GB job that fans out one `sbatch` per rule instance via the `snakemake-executor-plugin-slurm` executor; resources per rule come from `config/config.yaml` and `profiles/slurm/config.yaml`.

---

## Configuration reference

All toggles live in `config/config.yaml`. Highlights:

| key | default | effect |
|---|---|---|
| `run_recon` | `true` | gate recon + HSVS in QSIRecon |
| `run_qsirecon` | `true` | run QSIRecon tractography |
| `run_dk_connectome` | `true` | build DK connectome (requires `run_recon`) |
| `qsiprep.use_syn_sdc` | `false` | opt in to SyN distortion correction when no fmap |
| `qsiprep.fmap_retry` | `false` | `--ignore fieldmaps --use-syn-sdc warn` |
| `recon.tool` | `freesurfer` | `freesurfer` (recon-all) or `fastsurfer` |
| `qsirecon.spec` | `mrtrix_singleshell_ss3t_ACT-hsvs` | any built-in QSIRecon spec |
| `qsirecon.atlases` | `[ 4S156Parcels ]` | atlas keys for QSIRecon's connectivity node |
| `dk.resample_to_dwi` | `true` | resample aparc+aseg to DWI grid via `antsApplyTransforms` |
| `dk.tck2connectome_extra` | `[]` | extra flags, e.g. `[-scale_invlength, -scale_invnodevol]` |

### Selecting subjects

Either inline:

```yaml
subjects: [ "001", "007" ]
```

…or via a TSV (one ID per line, lines starting with `#` ignored). TSV wins:

```yaml
subjects_tsv: config/subjects.tsv
```

### Resources / Slurm

`threads` and `resources` (`mem_mb`, `runtime`, optional `slurm_partition`) in `config.yaml` are honoured by both local and Slurm runs. Snakemake translates them into `sbatch` flags via the executor plugin. Edit `profiles/slurm/config.yaml` to add a default partition, account, or node-exclusion list for your cluster.

---

## Why this pipeline?

* **DAG-first**: stages depend on real files, so a missing input never silently produces a broken downstream output.
* **Idempotent**: Snakemake won't redo a job whose output already exists and is newer than its inputs.
* **Selective re-runs**: `--forcerun recon`, `--until qsiprep`, or request a single file — only the necessary subset of the DAG runs.
* **Cluster-native**: per-rule `threads` and `resources` are translated to `sbatch` flags. No more guessing `--cpus-per-task`.
* **Containerised, not conda-fragile**: every scientific step runs in a pinned `.sif`; the orchestrator only needs Python + Snakemake.
* **Honest space alignment**: the DK rule uses `antsApplyTransforms -n GenericLabel` (ITK-native, label-aware) to resample `aparc+aseg` onto the DWI grid via QSIPrep's `from-orig_to-T1w` ITK transform, then runs MRtrix3 `tck2connectome`. The choice of resampler matters: QSIPrep ships transforms in ITK text format (despite the misleading `.lta`/`.txt` BIDS suffix), so FreeSurfer's `mri_vol2vol` is **not** the right tool — see `workflow/rules/dk_connectome.smk` for the full rationale.
* **Diagnostics built in**: every DK run emits `mrinfo` and `tckinfo` dumps so you can verify the parcellation and streamlines actually share a coordinate frame.

---

## Outputs (under `results_root`)

```
qsiprep_single_run_output/        QSIPrep BIDS-Derivatives
freesurfer/sub-XXX/               recon-all / FastSurfer subjects dir
qsirecon_single_run_output/       QSIRecon BIDS-Derivatives (incl. *.tck.gz)
dk_connectomes/sub-XXX/           DK connectome CSV + diagnostics
logs/<rule>.sub-XXX.log           per-task stdout+stderr
.flags/<stage>.sub-XXX.done       sentinel files for dir-tree stages
intermediate_results_*/           nipype workdirs (per-stage scratch)
```

---

## Citing

This workflow only orchestrates other people's tools — if you publish results, please cite them:

* **QSIPrep**: Cieslak M. et al. *QSIPrep: an integrative platform for preprocessing and reconstructing diffusion MRI data.* Nature Methods, 2021.
* **QSIRecon**: Cieslak M. et al. *QSIRecon: an integrative platform for reconstructing diffusion-weighted MRI data.* (see docs)
* **FreeSurfer**: Fischl B. *FreeSurfer.* NeuroImage, 2012.
* **FastSurfer** (if used): Henschel L. et al. *FastSurfer.* NeuroImage, 2020.
* **MRtrix3**: Tournier J-D. et al. *MRtrix3: A fast, flexible and open software framework for medical image processing and visualisation.* NeuroImage, 2019.
* **ANTs**: Avants B. et al. *Advanced Normalization Tools (ANTS).* Insight Journal, 2009.
* **Snakemake**: Mölder F. et al. *Sustainable data analysis with Snakemake.* F1000Research, 2021.

A `CITATION.cff` is provided if you also want to cite this pipeline specifically.

---

## License

[Apache License 2.0](LICENSE). See `LICENSE` for the full text.

---

## Troubleshooting

| symptom | likely fix |
|---|---|
| `WorkflowError: No subjects found` | fill `config/subjects.tsv` or set `subjects:` in your config |
| `MissingInputException` on recon's `aparc+aseg.mgz` | set `run_recon: true`, or point `freesurfer/sub-XXX/` at an existing recon |
| QSIRecon HSVS aborts with `mount source ... doesn't exist` | recon hasn't produced `freesurfer/sub-XXX/` — check that stage first |
| DK warning `dwiref/xfm not found; falling back to FS conformed space` | QSIPrep didn't write `*space-T1w_dwiref.nii.gz` for this subject; check QSIPrep outputs |
| `recon-all` dies ~30 min in with `cannot find .../RB_all_withskull_2020_01_02.gca` | `containers.freesurfer` is pointing at a *trimmed* FreeSurfer (e.g. the FreeSurfer baked into a FastSurfer image); switch to the dedicated `freesurfer_7.4.1.sif` |
| `DK: missing FreeSurferColorLUT.txt` | set `fs_lut:` in config to your host-side `FreeSurferColorLUT.txt` |
| `tckinfo: ... is not a valid track file` | MRtrix 3.0.4 can't read `.tck.gz` directly; the DK rule handles this automatically by gunzipping on the fly — make sure the rule is up to date |
| Need to wipe Snakemake metadata only | `make clean` (`rm -rf .snakemake`) |

---

## Contributing

Issues and pull requests welcome. For substantial changes, please open an issue first to discuss.
