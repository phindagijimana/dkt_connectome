# Changelog

All notable changes to the **DKT Connectome** (`dwi_pipeline/`) are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/). Versioning aligns with [`app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/app.json) `PipelineVersion`.

## [Unreleased]

### Added

- **`dkt_deep_atropos.sif`** — Deep Atropos integer seg → `base_5tt_native.mif` on BIDS T1w grid (`containers/deep_atropos/`)
- **`dkt_deep_atropos_seg.sif`** — ANTsPyNet `deep_atropos` segmentation on native T1w (`containers/deep_atropos_seg/`)
- **Snakemake rules** `deep_atropos_seg.smk`, `deep_atropos_5tt.smk` for optional native-T1 5TT branch
- **`--act-5tt-source hsvs|deep-atropos-native`** — HSVS ACPC (default) vs native Deep Atropos
- **`--deep-atropos-seg-mode auto|import|generate`** and **`--deep-atropos-seg PATH`** — segmentation discovery / import / ANTsPyNet generate
- **`scripts/convert_deep_atropos_to_5tt.py`**, **`scripts/run_deep_atropos_seg.py`** — label→5TT conversion and ANTsPyNet wrapper
- **`act.deep_atropos.antsxnet_cache`** — persistent ANTsXNet weight cache for HPC
- **`dkt_vbt.sif`** — dedicated Step 1.1 virtual brain transplant container (`containers/vbt/`, FSL staged from `qsiprep.sif`)
- **`dkt_lesion_act.sif`** — dedicated Step 3.1 post-QSIRecon lesion-aware ACT container (`containers/lesion_act/`)
- **Snakemake rules** `lesion_aware_act.smk`, `sdstream.smk` with `target_act` / `target_sdstream` modes
- **`--connectome-sift2`** — optional Step 4 SIFT2 matrix (default primary remains count)
- **`--tractography-model both`** (default) — iFOD2 + deterministic SD_STREAM connectomes
- **`--experiment-arm`** presets (`orig-std`, `vbt-lesion`, …) with isolated `RESULTS_ROOT/arms/<arm>/`
- **`scripts/publish_act_containers.sh`** — Docker Hub + GHCR publish for Step 3.1 images
- **`act_containers_publish.yml`** — CI build/push for `dkt-lesion-act`, `dkt-deep-atropos`, `dkt-deep-atropos-seg`
- **`--prefetch-only`** on `run_deep_atropos_seg.py` — login-node ANTsXNet weight warmup
- **ACT Snakemake CI dry-run** — `target_act` + Deep Atropos branch via `snakemake_act_ci_setup.sh`
- **Theory docs** — methods pages for Steps 1.1, 3.1, 4 multi-measure outputs; experiment-arm citations

### Changed

- **`run_lesion_aware_act.sh`** — split HSVS ACPC (`run_hsvs_acpc_workflow`) and Deep Atropos native (`run_deep_atropos_native_workflow`) paths; shared clip/renormalize and tractography
- **`lesion_aware_act.smk`** — `find -L` for QSIRecon discovery when outputs are symlinked
- **`sdstream.smk`**, **`connectome.smk`** — `find -L` for symlinked qsiprep/qsirecon trees
- **Deep Atropos bind-mounts** gated behind `ACT_BIND_MOUNT_DEV=1` (default: in-container scripts)
- **Preflight** requires `antsxnet_cache` when Deep Atropos seg mode is `auto`/`generate`
- **Container fallbacks** — `act.mode=lesion-aware` fails fast if dedicated ACT SIF keys missing
- Pinned Python deps in ACT Dockerfiles/Apptainer.defs (`act_python_requirements.txt`)
- **`container_install.py`** — GHCR fallbacks for ACT images
- **Documentation** — removed person-specific workflow labels; new public [Deep Atropos branch](deep_atropos_5tt.md); updated pipeline SVG sketch with Step 3.2 (segmentation) / 3.2
- Step 3.1 methods docs — HSVS ACPC workflow, Deep Atropos native branch, three-container architecture
- README workflow sketch (SVG + mermaid) on GitHub; updated stages and container tables
- Documentation site switched from **MkDocs Material** to **Sphinx + Read the Docs theme** (QSIPrep-style sidebar layout)
- Step 1.1 VBT runs via `CONTAINER_VBT` instead of binding into `qsiprep.sif`
- Step 3.1 runs via `CONTAINER_LESION_ACT` instead of inline `qsirecon.sif` shell
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
