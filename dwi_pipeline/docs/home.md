---
orphan: true
---

# DKT Connectome — lesion-aware structural connectomics BIDS App

DKT Connectome turns a BIDS diffusion MRI session (DWI + T1w) into a **structural connectome**: a region-to-region map of reconstructed white-matter pathways. The default graph uses the **Desikan–Killiany–Tourville (DKT)** atlas (78 nodes). When you also provide a lesion mask, the same run can inpaint anatomy before reconstruction and, if you pass `--disconnection`, estimate **which connections the lesion interrupts**.

It is **study-agnostic** — any BIDS DWI + T1w cohort can run. Lesion steps stay off unless a mask and the matching flags are present. The same streamlines can be counted on other atlases (DK, Lausanne-60, QSIRecon 4S156) without a second pipeline. One paragraph per step, including the disconnectome and extra atlases: **[What DKT Connectome does](what_it_does.md)**.

Public software checks: [IDEAS II](datasets/ideas.md) and [BTC glioma](datasets/btc_glioma.md) — reportlets on [Sample results](sample_results.md). TRACK-TBI DoD Phase 1 was run under a data-use agreement (data not in this repo) and is not a public validation claim.

**Also on GitHub:** [README](https://github.com/phindagijimana/dkt_connectome/blob/main/README.md) (same quick start) · **Release:** [v0.3.1](https://github.com/phindagijimana/dkt_connectome/releases/tag/v0.3.1)

```{note} Recommended setup
Use **Linux + Apptainer** on a workstation or HPC (FreeSurfer license required). After `./dkt install`, run **`./dkt check --strict`** to verify pinned container digests from [`release_manifest.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/release_manifest.json). Docker is optional for the orchestrator only — see [Installation § Docker](installation.md).
```

![DKT Connectome pipeline workflow](img/pipeline_overview.svg)

---

## Start here

| If you want… | Read… |
|--------------|--------|
| **What it does (short intro)** | [What DKT Connectome does](what_it_does.md) |
| **Install & first run** | [Installation](installation.md) → [Tutorial](tutorial.md) |
| **Example reportlets** | [Sample results](sample_results.md) (IDEAS II + glioma; QSIPrep/QSIRecon style) |
| **All CLI flags** | [Usage](usage.md) (`./dkt` / `./run`) |
| **Why** the workflow exists | [Science overview](science_overview.md) |
| **Methods & citations** | [Methods](methods/index.md) · [References](references.md) |
| **Prepare BIDS** | [Preparing your data](preparing_data.md) |
| **Upgrade** | [Upgrading](upgrading.md) |
| **Problems** | [FAQ](faq.md) · [Troubleshooting](troubleshooting.md) |

Advanced (linked, not in the main sidebar): [decision tables](decision_tables.md) · [factorial arms](TBI_Experimental_Arms.md) · [pipeline steps](pipeline_steps.md) · [Deep Atropos](deep_atropos_5tt.md) · [lesion-aware ACT](lesion_aware.md) · [disconnectome CLI](disconnectome.md) · [cloud deployment](cloud_deployment.md).

```{note} Upstream tools
This pipeline **orchestrates** [QSIPrep](https://qsiprep.readthedocs.io/), [QSIRecon](https://qsirecon.readthedocs.io/), FreeSurfer/FastSurfer, MRtrix3, and neuroLIT. Cite the primary method papers — [References by step](references.md).
```

---

## Quick start

**Requirements:** Linux · Apptainer · Python 3.9+ · Snakemake ≥ 8 · [FreeSurfer license](installation.md#freesurfer-license-you-must-obtain-this)

After clone, always work from `dwi_pipeline/`:

```bash
git clone https://github.com/phindagijimana/dkt_connectome.git
cd dkt_connectome/dwi_pipeline
chmod +x dkt run install
export FS_LICENSE=/path/to/your/license.txt
export DKT_CONTAINER_CACHE=${DKT_CONTAINER_CACHE:-$HOME/.cache/dkt-connectome/containers}
export APPTAINER_TMPDIR=${APPTAINER_TMPDIR:-$HOME/.cache/dkt-connectome/apptainer_tmp}
export PROOT_TMP_DIR=${PROOT_TMP_DIR:-$APPTAINER_TMPDIR}
mkdir -p "$DKT_CONTAINER_CACHE" "$APPTAINER_TMPDIR"
./dkt install
./dkt check --strict
bash scripts/download_ideas_sample.sh
./dkt run "$(pwd)/sample_data/ideas/bids" "$(pwd)/sample_data/ideas/results/sub-1_tutorial" participant \
  --participant-label 1 --session-filter ses-1 --fastsurfer --syn \
  --dwi-select config/dwi_select_ideas_b2500.json --dry-run
```

Download the sample only with `bash scripts/download_ideas_sample.sh` from `dwi_pipeline/`. `./dkt run` is the same command as `./run` (BIDS App).

| Command | Purpose |
|---------|---------|
| `./dkt install` | Pull step `.sif` images + write `config.local.yaml` |
| `./dkt check --strict` | Verify tools, license, and pinned container digests |
| `./dkt run …` | Run pipeline (same as `./run`) |
| `./dkt log …` | View logs under `RESULTS_ROOT/logs` |

**Sample data:** [IDEAS II (OpenNeuro ds007401)](datasets/ideas.md) — `bash scripts/download_ideas_sample.sh` from `dwi_pipeline/`.

**Docker** (optional; orchestrator only): see [Installation § Docker](installation.md).

### After your first subject (your own BIDS)

```bash
./dkt run /path/to/BIDS /path/to/out participant \
  --participant-label 01 --session-filter ses-1 --n-cpus 8 --fastsurfer --syn
```

HPC cohort (from the repo root, after the IDEAS dry-run above):

```bash
export BIDS_DIR=/path/to/BIDS
export RESULTS_ROOT=/path/to/results
bash dwi_pipeline/submit.sh
```

---

## Contact

<a id="contact"></a>

- **GitHub:** [github.com/phindagijimana/dkt_connectome](https://github.com/phindagijimana/dkt_connectome) · [open an issue](https://github.com/phindagijimana/dkt_connectome/issues)
- **Email:** [phindagiji@gmail.com](mailto:phindagiji@gmail.com)

For usage questions, also see [FAQ](faq.md) and [NeuroStars](https://neurostars.org/) (tag `qsiprep`, `qsirecon`, or link this repo).

---

## Help

- [FAQ](faq.md) · [Troubleshooting](troubleshooting.md)
