# Pipeline architecture

How the DKT Connectome is structured for **reproducibility**: which components run in Apptainer step images, which run on the host, and which use **hybrid** bind-mounted scripts.

The pipeline is **multi-container by design**. The BIDS App orchestrator (`phindagijimana321/dkt-connectome`) ships Snakemake and host glue; **compute** still runs in pinned step `.sif` files mounted at runtime.

---

## Layer overview

```mermaid
flowchart TB
  subgraph HOST["Host / orchestrator (not step containers)"]
    DKT["./dkt · ./run · submit.sh"]
    SMK["Snakemake DAG"]
    LIB["common.sh · resolve_session.py"]
    DKT --> SMK --> LIB
  end

  subgraph S1["Step 1 — QSIPrep"]
    BF["build_bids_filter.py<br/>host"]
    QS["qsiprep.sif"]
    BF --> QS
  end

  subgraph S11["Step 1.1 — Inpaint (optional)"]
    PLM["prepare_lesion_mask.py<br/>host"]
    VBT["run_vbt.py bind-mount → qsiprep.sif"]
    LIT["lit.sif"]
    CHK["check_inpainting.py<br/>host"]
    PLM --> VBT
    PLM --> LIT
    VBT --> CHK
    LIT --> CHK
  end

  subgraph S2["Step 2 — Recon"]
    REC["freesurfer / fastsurfer.sif"]
  end

  subgraph S3["Step 3 — QSIRecon + ACT"]
    QR["qsirecon.sif"]
    ACT["dkt_lesion_act.sif"]
    QR --> ACT
  end

  subgraph S4["Step 4 — Connectome"]
    RC["run_connectome.sh bind-mount"]
    CC["dkt_connectome.sif"]
    RC --> CC
  end

  subgraph S41["Step 4.1 — Disconnectome (optional)"]
    RD["run_disconnectome.py<br/>host → calls connectome.sif"]
  end

  subgraph S5["Step 5 — Node strength"]
    NS["nodestrength.sif"]
  end

  subgraph QC["QC & export (host)"]
    SQC["render_subject_qc.py"]
    EXP["export_bids_derivatives.py"]
  end

  HOST --> S1 --> S11 --> S2 --> S3 --> S4
  S4 --> S41
  S4 --> S5
  S4 --> QC
  S5 --> QC
```

---

## Legend

| Symbol | Meaning |
|--------|---------|
| **Step container** | Apptainer `.sif` image (see [Containers](containers.md)) |
| **Host** | Python/shell on the login/compute node or inside the orchestrator image |
| **Bind-mount** | Repo script overlaid into a container at runtime — not a separate image |

---

## Step-by-step placement

| Step | Container | Host / hybrid |
|------|-----------|---------------|
| **Orchestration** | — | Snakemake, `./dkt`, `./run`, `preflight.sh`, `submit.sh` |
| **1 — QSIPrep** | `qsiprep_1.0.0.sif` | `build_bids_filter.py` |
| **1.1 — Inpaint** | `lit.sif` or `qsiprep.sif` + bind `run_vbt.py` | `prepare_lesion_mask.py`, `check_inpainting.py` |
| **2 — Recon** | `freesurfer` / `fastsurfer.sif` | — |
| **3 — QSIRecon** | `qsirecon_1.2.1.sif` | — |
| **3.1 — Lesion ACT** | `dkt_lesion_act.sif` | `prepare_lesion_mask.py` |
| **3.2 — Deep Atropos** | `dkt_deep_atropos*.sif` | optional dev bind-mounts (`ACT_BIND_MOUNT_DEV=1`) |
| **4 — Connectome** | `dkt_connectome.sif` | **always** bind `run_connectome.sh`; Lausanne via host `build_lausanne_parcellation.py` |
| **4 — SD-stream** | `qsirecon` + `connectome.sif` | provenance JSON (inline host Python) |
| **4.1 — Disconnectome** | calls into `connectome.sif` | `run_disconnectome.py` orchestrates on host |
| **5 — Node strength** | `nodestrength_0.1.0.sif` | — |
| **QC / export** | — | `render_*_qc.py`, `export_bids_derivatives.py` |
| **Group level** | — | `render_cohort_qc.py`, BIDS export via `./run … group` |

---

## Hybrid scripts (reproducibility notes)

These live in git and can be updated without rebuilding step `.sif` files when bind-mounted:

| Script | Runs in | Purpose |
|--------|---------|---------|
| `containers/connectome/run_connectome.sh` | `dkt_connectome.sif` | Step 4 parcellation, rigid FS→ACPC registration |
| `scripts/run_vbt.py` | `qsiprep.sif` | LeAPP-compatible virtual brain transplant |
| `scripts/run_deep_atropos_seg.py` | `dkt_deep_atropos_seg.sif` | optional when `ACT_BIND_MOUNT_DEV=1` |
| `scripts/convert_deep_atropos_to_5tt.py` | `dkt_deep_atropos.sif` | optional when `ACT_BIND_MOUNT_DEV=1` |

For **frozen reproducibility**, pin both the step `.sif` digest ([container digests on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/container_digests.md)) **and** the git commit of the orchestrator repo.

---

## Deployment models

| Environment | Orchestrator | Step compute |
|-------------|--------------|--------------|
| **HPC (recommended)** | Host Snakemake + `./dkt` / `submit.sh` | Apptainer `.sif` from `DKT_CONTAINER_CACHE` |
| **Docker / cloud** | `phindagijimana321/dkt-connectome:<version>` | Same `.sif` files mounted into cache volume |
| **BIDS App contract** | `./run` entrypoint | Unchanged — `./dkt run …` is equivalent |

Install and verify:

```bash
./dkt install
./dkt check --with-dry-run
```

See [Installation](installation.md), [Containers](containers.md), and [Usage § Unified CLI](usage.md#unified-cli-dkt).

---

## Outside the shareable pipeline

Site-specific backfill scripts (`scripts/array_*`, `scripts/submit_*`, cohort verify utilities) sit beside the BIDS App path and are not required for external reproducibility.
