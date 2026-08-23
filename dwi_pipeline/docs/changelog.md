# Changelog

All notable changes to the **DKT Connectome** (`dwi_pipeline/`) are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/). Versioning aligns with [`app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/app.json) `PipelineVersion`.

## [Unreleased]

### Added

- **`dkt_vbt.sif`** — dedicated Step 1.5 virtual brain transplant container (`containers/vbt/`, FSL staged from `qsiprep.sif`)
- **`dkt_lesion_act.sif`** — dedicated Step 3.5 post-QSIRecon lesion-aware ACT container (`containers/lesion_act/`)
- **Snakemake rules** `lesion_aware_act.smk`, `sdstream.smk` with `target_act` / `target_sdstream` modes
- **`--connectome-sift2`** — optional Step 4 SIFT2 matrix (default primary remains count)
- **`--tractography-model both`** (default) — iFOD2 + deterministic SD_STREAM connectomes
- **`--experiment-arm`** presets (`orig-std`, `vbt-lesion`, …) with isolated `RESULTS_ROOT/arms/<arm>/`
- **Validation** — `scripts/validate_vbt_lesion_act.py` + unit tests
- **Theory docs** — methods pages for Steps 1.5, 3.5, 4 multi-measure outputs; experiment-arm citations

### Changed

- README workflow sketch (SVG + mermaid) on GitHub; updated stages and container tables
- Documentation site switched from **MkDocs Material** to **Sphinx + Read the Docs theme** (QSIPrep-style sidebar layout)
- Step 1.5 VBT runs via `CONTAINER_VBT` instead of binding into `qsiprep.sif`
- Step 3.5 runs via `CONTAINER_LESION_ACT` instead of inline `qsirecon.sif` shell
- `submit.sh` exports `CONTAINER_VBT` and `CONTAINER_LESION_ACT` to Slurm jobs
- `connectome.sift2` default **false**; count remains primary `dkt_connectome.csv`
- Documentation: containers catalog, Snakemake targets, config examples updated for new images

## [0.2.0] - 2026-08-14

### Added

- **Snakemake workflow docs** [snakemake_workflow.md](snakemake_workflow.md) — full DAG, all `target_*` rules, registry links
- **CI full-workflow dry-run** — `scripts/snakemake_dryrun_ci.sh` exercises all nine Snakemake targets (with lesion-mask stub)
- **Documentation site pages:** [configuration.md](configuration.md), [faq.md](faq.md), [troubleshooting.md](troubleshooting.md), [changelog.md](changelog.md), [containers.md](containers.md)
- **`./run --version`** flag
- Read the Docs setup — [Maintainer tasks §14 on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/maintainer_tasks.md#14-read-the-docs-auto-rebuild)
- **Material for MkDocs** theme; generated config catalog (GitHub) and [QC doc figures](qc.md)
- Expanded **BIDS App `./run` CLI** (SDC, dwi-select, nodestrength, disconnectome flags)
- **QSIPrep-style docs** under `dwi_pipeline/docs/` with GitHub-navigable links
- **CI** workflow `.github/workflows/dwi_pipeline_ci.yml` (pytest + Snakemake dry-run)
- **Unit tests** in `dwi_pipeline/tests/`
- **Legacy workflow note** — [Comparisons § Legacy root workflow](comparisons.md#vs-legacy-root-dk_connectome-this-repo-only)
- **Opt-in BIDS validation** (`--bids-validation`, `scripts/run_bids_validator.sh`)
- **Derivatives provenance** (`dataset_description.json` via `write_derivatives_description.py`)
- **Container pin reference** in `config.yaml` and [derivatives.md](derivatives.md)
- **Disconnectome HTML QC** (`disconnectome_qc.html`, cohort index via `./run … group`)
- **Unified subject QC dashboard** (`qc/sub-<ID>/subject_qc.html`, cohort index `cohort_qc.html`)
- **BIDS Derivatives export** (`derivatives/` symlink mirror, `export_bids_derivatives.py`)
- **ReadTheDocs** config (`.readthedocs.yaml`, `mkdocs.yml`)
- **Dockstore / WorkflowHub** repointed to `dkt_connectome` (legacy root workflow retained)
- **batch_postprocess.sh** for cohort NAS post-processing (QC + BIDS export)
- **Expanded CI** (MkDocs build, BIDS export smoke test, Snakemake QC target dry-run)
- **Auto-install stack** (`install.sh`, `doctor`, `container_install.py`, Docker Compose)
- **Docker Hub orchestrator** `phindagijimana321/dkt-connectome:0.2.0` (+ GHCR mirror script)
- **Material for MkDocs** theme; generated [config catalog on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/config_catalog.md) and [QC doc figures](qc.md)
- **IDEAS dwi-select** `config/dwi_select_ideas_b2500.json` for 0/300/700/2500 shells
- [Cloud & group deployment](cloud_deployment.md) guide

### Changed

- Disconnectome default: binary union (core + oedema), count weighting, erode 0 primary
- `app.json` documents full `./run` surface and documentation URL

### Fixed

- GitHub Actions Snakemake dry-run (`--quiet` vs target name collision on Snakemake 8+)
- Docker publish workflow: `dkt-connectome` image name + graceful skip when Hub secrets missing
- Disconnectome integrity: count weighting aligned between Step 4 and 4.5
- Documentation test stats and SIFT2 example snippets corrected

## [0.1.0] - 2026-05

### Added

- Initial six-step pipeline (QSIPrep → inpaint → recon → QSIRecon → connectome → nodestrength)
- Snakemake workflow under `dwi_pipeline/workflow/`
- Standalone disconnectome script (`run_disconnectome.py`) and integrity QC
- BIDS App skeleton (`run`, `app.json`)

[0.2.0]: https://github.com/phindagijimana/dkt_connectome/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/phindagijimana/dkt_connectome/releases/tag/v0.1.0
