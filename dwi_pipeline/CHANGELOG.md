# Changelog

All notable changes to the **DKT Connectome** (`dwi_pipeline/`) are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/). Versioning aligns with [`app.json`](app.json) `PipelineVersion`.

**Canonical changelog:** [docs/changelog.md](docs/changelog.md) (includes [Unreleased] and v0.2.1+).

## [Unreleased]

See [docs/changelog.md](docs/changelog.md#unreleased).

## [0.2.0] - 2026-08-14

### Added

- **Snakemake workflow docs** — see `docs/snakemake_workflow.md`
- **CI full-workflow dry-run** — `scripts/snakemake_dryrun_ci.sh`
- **Step 4.1 disconnectome** wired into Snakemake (`disconnectome.smk`), `subject.sh`, and `./run`
- Expanded **BIDS App `./run` CLI** (SDC, dwi-select, nodestrength, disconnectome flags)
- **QSIPrep-style docs** under `dwi_pipeline/docs/` with GitHub-navigable links
- **CI** workflow `.github/workflows/dwi_pipeline_ci.yml` (pytest + Snakemake dry-run)
- **Unit tests** in `dwi_pipeline/tests/`
- **Legacy workflow note** — [Comparisons § Legacy root workflow](docs/comparisons.md#vs-legacy-root-dk_connectome-this-repo-only)
- **Opt-in BIDS validation** (`--bids-validation`, `scripts/run_bids_validator.sh`)
- **Derivatives provenance** (`dataset_description.json` via `write_derivatives_description.py`)
- **Container pin reference** in `config.yaml` and [`docs/derivatives.md`](docs/derivatives.md)
- **Disconnectome HTML QC** (`disconnectome_qc.html`, cohort index via `./run … group`)
- **Unified subject QC dashboard** (`qc/sub-<ID>/subject_qc.html`, cohort index `cohort_qc.html`)
- **BIDS Derivatives export** (`derivatives/` symlink mirror, `export_bids_derivatives.py`)
- **ReadTheDocs** config (`.readthedocs.yaml`, `mkdocs.yml`)
- **Dockstore / WorkflowHub** repointed to `dkt_connectome` (legacy root workflow retained)
- **batch_postprocess.sh** for cohort NAS post-processing (QC + BIDS export)
- **Expanded CI** (MkDocs build, BIDS export smoke test, Snakemake QC target dry-run)
- Optional local-only `Dockerfile` (orchestrator — **not** required on HPC; not published)

### Changed

- Disconnectome default: binary union (core + oedema), count weighting, erode 0 primary
- `app.json` documents full `./run` surface and GitHub documentation URL

### Fixed

- GitHub Actions Snakemake dry-run (`--quiet` vs target name collision on Snakemake 8+)
- Docker publish workflow: `dkt-connectome` image name + graceful skip when Hub secrets missing
- Disconnectome integrity: count weighting aligned between Step 4 and 4.1
- Documentation test stats and SIFT2 example snippets corrected

## [0.1.0] - 2026-05

### Added

- Initial six-step pipeline (QSIPrep → inpaint → recon → QSIRecon → connectome → nodestrength)
- Snakemake workflow under `dwi_pipeline/workflow/`
- Standalone disconnectome script (`run_disconnectome.py`) and integrity QC
- BIDS App skeleton (`run`, `app.json`)

[0.2.0]: https://github.com/phindagijimana/dkt_connectome/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/phindagijimana/dkt_connectome/releases/tag/v0.1.0
