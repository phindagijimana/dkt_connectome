# dk_connectome

**Turn a BIDS diffusion-MRI dataset into Desikan-Killiany structural connectomes — one command per step.**

[![Snakemake](https://img.shields.io/badge/snakemake-≥8.0-brightgreen.svg)](https://snakemake.readthedocs.io)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![BIDS App](https://img.shields.io/badge/BIDS--App-compatible-blue.svg)](https://bids-apps.neuroimaging.io/)
[![Container image](https://img.shields.io/badge/ghcr.io-dk--connectome-blue?logo=github)](https://github.com/phindagijimana/dk_connectome/pkgs/container/dk-connectome)

The workflow is an **orchestration of four containers**, one per stage:

| stage | container | size | source |
|---|---|---:|---|
| 1. qsiprep | `pennlinc/qsiprep:1.0.0` | ~3.5 GB | upstream |
| 2. recon | `freesurfer/freesurfer:7.4.1` (or `deepmi/fastsurfer:latest`) | ~6 GB | upstream |
| 3. qsirecon | `pennlinc/qsirecon:1.2.1` | ~5 GB | upstream |
| 4. dk_connectome | `ghcr.io/phindagijimana/dk-connectome:0.1.0` | ~900 MB | **this repo** ([`containers/`](containers/)) |

Snakemake is just the glue. Every scientific step happens inside a pinned
Apptainer/Singularity image, so the science is reproducible across sites
without any per-machine compiler or library setup.

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
| `./connectome report` | self-contained HTML run report (DAG, per-rule benchmarks, config snapshot). Wraps `snakemake --report`. |
| `./connectome bids` | [BIDS-App](https://bids-apps.neuroimaging.io/)-compliant facade: `./connectome bids BIDS_DIR OUTPUT_DIR participant [opts]` |
| `./connectome cwl`  | export the workflow as a CWL document (wraps `snakemake --export-cwl`) for Dockstore / Cromwell consumers |

Run `./connectome <cmd> --help` for full flags. The CLI is pure-stdlib Python — it
runs *before* `install` has fetched any deps.

### Common variations

```bash
./connectome install --with-fastsurfer                       # also pull fastsurfer.sif
./connectome install --no-deps --no-containers               # only refresh subjects.tsv and config audit
./connectome start --mode local --jobs 8                     # force local, override parallelism
./connectome start --subjects 01,02,07                       # subset of subjects, this run only
./connectome start --multi-shell --atlas 4S256Parcels        # swap default QSIRecon spec + atlas
./connectome start --fastsurfer                              # FastSurfer instead of FreeSurfer
./connectome start --syn                                     # SyN-based SDC fallback
./connectome start --no-dk                                   # skip the DK connectome step
./connectome start --cache-dir /scratch/dk_cache             # share dk_connectome outputs across runs
./connectome start -- --profile profiles/k8s                 # Kubernetes (see REGISTRY.md)
./connectome start -- --forcerun recon                       # extra snakemake flags after `--`
./connectome bids /data/BIDS /data/derivs participant        # BIDS-App invocation
./connectome bids /data/BIDS /data/derivs participant --participant-label 01 02
./connectome report --open                                   # HTML run summary, opened in default browser
./connectome cwl -o build/dk_connectome.cwl                  # CWL projection
./connectome logs --rule recon --subject 01                  # specific rule.subject log
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
* **[REGISTRY.md](REGISTRY.md)** — where the container images live, how the
  workflow is indexed in Dockstore / WorkflowHub / BIDS-Apps, and the executor
  profiles (`profiles/{slurm,k8s,aws-batch,google-batch}/`) for running on
  HPC, Kubernetes, or cloud-native batch.
* **[containers/](containers/)** — Docker + Apptainer recipes for the
  in-house `dk-connectome` image (MRtrix3 + ANTs + FS color LUT, ~900 MB).
* **`schemas/`** — JSON Schemas (`config.schema.json`, `plugin.schema.json`)
  enforced at workflow start; catch config typos before the DAG is built.
* **`.github/workflows/lint.yml`** — CI runs `snakemake --lint` + dry-run +
  schema-negative tests on every PR.
* **Provenance** — every successful `./connectome start` emits an RO-Crate
  1.1 manifest (`<results_root>/ro-crate-metadata.json` + `ro-crate-preview.html`)
  capturing workflow source, container digests, config snapshot, per-rule
  benchmarks, and per-subject outputs.
* **Issues / PRs** welcome. For substantial changes, please open an issue first.
