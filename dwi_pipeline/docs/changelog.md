# Changelog

All notable changes to the **TrackTBI Connectome Pipeline** (`dwi_pipeline/`) are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/). Versioning aligns with [`app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/app.json) `PipelineVersion`.

## [0.2.0] - 2026-08-14

### Added

- **Documentation site pages:** [configuration.md](configuration.md), [faq.md](faq.md), [troubleshooting.md](troubleshooting.md), [changelog.md](changelog.md), [containers.md](containers.md)
- **`./run --version`** flag
- [Read the Docs setup guide](readthedocs_setup.md)
- MkDocs **strict** build enabled (out-of-tree links → GitHub URLs)

### Added (pipeline)
- Expanded **BIDS App `./run` CLI** (SDC, dwi-select, nodestrength, disconnectome flags)
- **QSIPrep-style docs** under `dwi_pipeline/docs/` with GitHub-navigable links
- **CI** workflow `.github/workflows/dwi_pipeline_ci.yml` (pytest + Snakemake dry-run)
- **Unit tests** in `dwi_pipeline/tests/`
- **Legacy workflow guide** [legacy_workflow.md](legacy_workflow.md)
- **Opt-in BIDS validation** (`--bids-validation`, `scripts/run_bids_validator.sh`)
- **Derivatives provenance** (`dataset_description.json` via `write_derivatives_description.py`)
- **Container pin reference** in `config.yaml` and [derivatives.md](derivatives.md)
- **Disconnectome HTML QC** (`disconnectome_qc.html`, cohort index via `./run … group`)
- **Unified subject QC dashboard** (`qc/sub-<ID>/subject_qc.html`, cohort index `cohort_qc.html`)
- **BIDS Derivatives export** (`derivatives/` symlink mirror, `export_bids_derivatives.py`)
- **ReadTheDocs** config (`.readthedocs.yaml`, `mkdocs.yml`)
- **Dockstore / WorkflowHub** repointed to `tracktbi_connectome` (legacy root workflow retained)
- **batch_postprocess.sh** for cohort NAS post-processing (QC + BIDS export)
- **Expanded CI** (MkDocs build, BIDS export smoke test, Snakemake QC target dry-run)

### Changed

- Disconnectome default: binary union (core + oedema), count weighting, erode 0 primary
- `app.json` documents full `./run` surface and documentation URL

### Fixed

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
