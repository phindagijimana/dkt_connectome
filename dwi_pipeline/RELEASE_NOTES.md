# DKT Connectome 0.2.0

Lesion-aware structural connectomics BIDS App — first release with full Snakemake engine, documentation site, and Docker orchestrator.

**Documentation:** https://dkt-connectome.readthedocs.io/en/latest/  
**Docker (orchestrator):** `phindagijimana321/dkt-connectome:0.2.0`  
**Entrypoint:** `dwi_pipeline/run`

---

## Highlights

- **BIDS App** `./run` with `participant` and `group` analysis levels, QSIPrep-style CLI aliases, and `./run doctor` install check
- **Six-step pipeline:** QSIPrep → optional neuroLIT inpainting → FreeSurfer/FastSurfer → QSIRecon ACT-HSVS → DKT connectome → optional disconnectome → node-strength report
- **Snakemake workflow** as the canonical engine (`workflow/Snakefile`, `run_subject.sh`, `submit.sh`)
- **Documentation site** (Material MkDocs, ~50 pages): installation, usage, methods per step, FAQ, troubleshooting
- **CI:** pytest, MkDocs strict build, full DAG dry-run, BIDS derivatives export smoke test
- **Docker orchestrator** + Compose + auto-install (`DKT_AUTO_INSTALL=1`) for cloud deployments
- **QC:** unified subject HTML dashboard, disconnectome QC, cohort indexes via `./run … group`
- **BIDS Derivatives export** optional mirror under `RESULTS_ROOT/derivatives/`

---

## Added

- Step 4.5 disconnectome in Snakemake, `./run`, and cohort QC
- Opt-in BIDS validation (`--bids-validation`)
- Container pin reference, config catalog, IDEAS `dwi_select_ideas_b2500.json`
- Dockstore / WorkflowHub metadata repointed to `dkt_connectome`
- Read the Docs (`.readthedocs.yaml`, `mkdocs.yml`)

---

## Changed

- Disconnectome default: binary union (core + oedema), count weighting, erode 0
- `app.json` documents full `./run` surface and documentation URL

---

## Fixed

- Snakemake 8+ dry-run (`--quiet` vs target name collision)
- Docker publish workflow image naming and optional Hub push
- Disconnectome integrity count-weighting alignment with Step 4

---

## Upgrade notes

- **Canonical path:** use `dwi_pipeline/run` (not repository-root `./connectome bids`).
- **HPC:** `submit.sh` → Snakemake by default; legacy bash engine documented in `workflow/LEGACY.md` only.
- **Containers:** orchestrator image does not bundle QSIPrep/FreeSurfer/QSIRecon — mount Apptainer `.sif` paths or set `DKT_AUTO_INSTALL=1`.
- **FreeSurfer license** required at runtime for recon (`FS_LICENSE`).

---

## Full changelog

See [`CHANGELOG.md`](CHANGELOG.md).
