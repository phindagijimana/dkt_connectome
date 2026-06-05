# dk_connectome

**Turn a BIDS diffusion-MRI dataset into Desikan-Killiany structural connectomes — one command per step.**

[![Snakemake](https://img.shields.io/badge/snakemake-≥8.0-brightgreen.svg)](https://snakemake.readthedocs.io)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![BIDS App](https://img.shields.io/badge/BIDS--App-compatible-blue.svg)](https://bids-apps.neuroimaging.io/)

Wraps QSIPrep + QSIRecon + FreeSurfer/FastSurfer + MRtrix3 into one Snakemake DAG.
Every scientific step runs inside a pinned Apptainer/Singularity container.

---

## Prerequisites

* Python 3.8+
* [Apptainer](https://apptainer.org/) (or Singularity) on `PATH`
* A FreeSurfer license — apply (free) at <https://surfer.nmr.mgh.harvard.edu/registration.html>
* A BIDS-formatted DWI dataset (sub-XXX/ folders with `dwi/` and `anat/`)
* *(Optional)* Slurm — the CLI will fall back to local mode if `sbatch` isn't available

---

## Five commands, one pipeline

```bash
git clone https://github.com/phindagijimana/dk_connectome.git
cd dk_connectome

# 1. Install snakemake, pull all containers, scan BIDS, scaffold config
./connectome install --bids /path/to/BIDS

# 2. Open config/config.yaml and fill in fs_license + the few /path/to/... lines
#    the installer flagged

# 3. Launch (Slurm if available, otherwise local)
./connectome start

# 4. Monitor
./connectome check
./connectome logs -f

# 5. Cancel if needed
./connectome stop
```

That's it. Results land under whatever `results_root:` points to in your config; the
DK connectomes themselves are at `<results_root>/dk_connectomes/sub-XXX/dk_connectome.csv`
(84×84 symmetric matrix per subject).

---

## The CLI

| command | what it does |
|---|---|
| `./connectome install` | `pip install` snakemake + slurm executor, `apptainer pull` every container, generate `config/subjects.tsv` from BIDS, and report which `/path/to/...` placeholders still need editing in `config/config.yaml` |
| `./connectome start` | submit the pipeline — uses Slurm via `submit_snakemake.sh` if `sbatch` is on PATH, else runs locally with `-j 4` |
| `./connectome stop` | `scancel` the driver job (or `SIGTERM` the local driver). `--all-children` also cancels in-flight rule jobs. |
| `./connectome check` | per-stage progress across all subjects + live `squeue` status of the driver and child jobs |
| `./connectome logs` | tail the most recent driver log; `--rule qsiprep --subject 01` for a per-task log; `-f` to follow |

Run `./connectome <cmd> --help` for full flags. The CLI is pure-stdlib Python — it
runs *before* `install` has fetched any deps.

### Common variations

```bash
./connectome install --with-fastsurfer            # also pull fastsurfer.sif
./connectome install --no-deps --no-containers    # only refresh subjects.tsv and config audit
./connectome start --mode local --jobs 8          # force local, override parallelism
./connectome start --config config/myconfig.yaml  # use a non-default config
./connectome start -- --forcerun recon            # extra snakemake flags after `--`
./connectome logs --rule recon --subject 01       # specific rule.subject log
```

---

## Outputs

```
<results_root>/
    qsiprep_single_run_output/        # QSIPrep BIDS-Derivatives
    freesurfer/sub-XXX/               # recon-all / FastSurfer subjects dir
    qsirecon_single_run_output/       # QSIRecon BIDS-Derivatives (incl. *.tck.gz)
    dk_connectomes/sub-XXX/
        dk_connectome.csv             # 84×84 DK connectivity matrix  <-- the artifact
        dk_assignments.csv            # streamline -> (node_i, node_j) mapping
        dk_nodes.mif                  # MRtrix node label image
        aparc+aseg_in_dwi.nii.gz      # FS parcellation resampled to DWI grid
        dk_nodes.mrinfo.txt           # space-alignment diagnostic
        tracks.tckinfo.txt            # tractogram header
```

---

## Citing

This workflow only orchestrates other people's tools — cite QSIPrep, QSIRecon,
FreeSurfer (or FastSurfer), MRtrix3, ANTs, and Snakemake when you publish.
See [USER_GUIDE.md § Citing](USER_GUIDE.md#citing) for full references, or
[`CITATION.cff`](CITATION.cff) to cite this pipeline specifically.

---

## License

[Apache License 2.0](LICENSE).

---

## More

* **[USER_GUIDE.md](USER_GUIDE.md)** — full configuration reference, stage-by-stage
  description, atlas choices, SDC options, Slurm tuning, troubleshooting,
  manual `snakemake` usage, and the rationale behind the design (in particular
  why DK resampling uses `antsApplyTransforms` instead of `mri_vol2vol`).
* **Issues / PRs** welcome. For substantial changes, please open an issue first.
