# Registries & Executors

> **Canonical BIDS App (v0.2+):** [`dwi_pipeline/run`](dwi_pipeline/run) — full Steps 1–5 + disconnectome.  
> Docs: [dkt-connectome.readthedocs.io](https://dkt-connectome.readthedocs.io/en/latest/bids_app/).  
> This page also covers the **legacy root** `./connectome` workflow and container images.

`dk_connectome` is intentionally portable across compute backends and
visible from the major neuroimaging registries. This page is the index to
everything needed to publish, share, and run the workflow somewhere new.

---

## Container registry — where images live

| Image                                         | Source                                            | Source of truth          |
|-----------------------------------------------|---------------------------------------------------|--------------------------|
| `pennlinc/qsiprep:1.0.0`                      | [Docker Hub](https://hub.docker.com/r/pennlinc/qsiprep) | QSIPrep upstream         |
| `pennlinc/qsirecon:1.2.1`                     | [Docker Hub](https://hub.docker.com/r/pennlinc/qsirecon) | QSIRecon upstream        |
| `freesurfer/freesurfer:7.4.1`                 | [Docker Hub](https://hub.docker.com/r/freesurfer/freesurfer) | FreeSurfer upstream      |
| `ghcr.io/phindagijimana/dk-connectome:<tag>`  | [GHCR](https://github.com/phindagijimana/dk_connectome/pkgs/container/dk-connectome) | This repo (CI-built)     |
| `deepmi/fastsurfer:latest` *(optional)*       | [Docker Hub](https://hub.docker.com/r/deepmi/fastsurfer) | FastSurfer upstream      |

The `dk-connectome` image is the only one we publish ourselves. It's built
by `.github/workflows/build-dk-connectome.yml` on every push to `main`
(`:main`, `:sha-<sha7>` tags) and on tagged releases (`:<tag>`, `:latest`).

* Recipe — `containers/Dockerfile.dk_connectome`
* Apptainer equivalent — `containers/Apptainer.dk_connectome.def`
* CI workflow — `.github/workflows/build-dk-connectome.yml`
* What's inside — `containers/README.md`

`./connectome install` pulls all four (plus optional fastsurfer) by default.
If `apptainer pull` can't reach ghcr.io (air-gapped cluster, GHCR outage),
the CLI falls back to `apptainer build` from the in-repo recipe — see the
README's *Containers* section.

---

## Workflow registry — where the workflow itself is indexed

| Registry                              | Manifest in this repo  | Effort to publish      |
|---------------------------------------|------------------------|------------------------|
| [Dockstore](https://dockstore.org)    | `.dockstore.yml`       | one-time GitHub link   |
| [WorkflowHub](https://workflowhub.eu) | `workflowhub.yml`      | upload a Workflow RO-Crate |
| [BIDS Apps](https://bids-apps.neuroimaging.io/) | [`dwi_pipeline/run`](dwi_pipeline/run) | optional listing — see [bids_apps_registry.md](dwi_pipeline/docs/maintainer/bids_apps_registry.md) |
| [nf-core](https://nf-co.re) / [Snakemake catalog](https://snakemake.github.io/snakemake-workflow-catalog/) | `Snakefile`, `config/`, `README.md` | tagged release |

### Dockstore

`.dockstore.yml` declares two entries — the native Snakemake workflow (always
on) and a CWL projection (on-demand via `./connectome cwl`). After the
repo is linked from your Dockstore profile, every tagged release is picked
up automatically.

### WorkflowHub

`./connectome start` emits an RO-Crate 1.1 manifest
(`<results_root>/ro-crate-metadata.json` + `ro-crate-preview.html`) on
success. Zip the results root and submit at
<https://workflowhub.eu/workflows/new>; `workflowhub.yml` documents the
metadata you'll be prompted for.

### BIDS Apps

**Canonical entrypoint (v0.2+):**

```bash
cd dwi_pipeline
./run /data/BIDS /data/derivatives participant \
  --participant-label 01 --session-filter ses-1
```

Optional listing on bids-apps.neuroimaging.io: [bids_apps_registry.md](dwi_pipeline/docs/maintainer/bids_apps_registry.md) (not required for release).

The legacy root `./connectome bids` facade matches the older 4-stage workflow only — do not use for new cohort work. See [Comparisons](dwi_pipeline/docs/comparisons.md#vs-legacy-root-dk_connectome-this-repo-only).

### Snakemake workflow catalog

The catalog auto-indexes repos that have a top-level `Snakefile`,
`config/config.yaml`, and a `README.md` with the standard sections. We have
all three; tag a release to get listed.

---

## Executors — where rules run

`./connectome start` auto-detects Slurm vs local. For other backends, point
Snakemake at a profile under `profiles/`.

| Backend                | Profile                       | Required plugin                                | Notes |
|------------------------|-------------------------------|------------------------------------------------|-------|
| Local                  | *(none — default `-j N`)*     | -                                              | dev / single-workstation runs |
| Slurm                  | `profiles/slurm/`             | `snakemake-executor-plugin-slurm`              | HPC default; see `submit_snakemake.sh` |
| Kubernetes             | `profiles/k8s/`               | `snakemake-executor-plugin-kubernetes`         | RWX PVC required; see profile README   |
| AWS Batch              | `profiles/aws-batch/`         | `snakemake-executor-plugin-aws-batch`          | Spot + S3 storage; see profile README  |
| Google Batch           | `profiles/google-batch/`      | `snakemake-executor-plugin-googlebatch`        | Spot + GCS storage; see profile README |

Each non-Slurm profile ships with a `README.md` that walks through the
one-time cluster/cloud setup. None of the profiles modify rule definitions;
they only translate `threads:` / `resources:` into the backend's native
scheduler vocabulary.

To run with any profile from the CLI:

```bash
./connectome start --mode local -- --profile profiles/k8s
./connectome start --mode local -- --profile profiles/aws-batch
./connectome start --mode local -- --profile profiles/google-batch
```

(The `--mode local` argument controls whether `./connectome` itself uses
`sbatch` to background the driver; the actual rule execution backend is
chosen by the profile passed to Snakemake.)
