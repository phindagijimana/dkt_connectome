# Snakemake workflow

The **canonical execution engine** for the DKT Connectome is the Snakemake workflow under [`dwi_pipeline/workflow/`](https://github.com/phindagijimana/dkt_connectome/tree/main/dwi_pipeline/workflow).

Each pipeline step is a **plugin rule** (QSIPrep, inpaint, recon, QSIRecon, connectome, disconnectome, nodestrength, subject QC). Snakemake builds the DAG from declared inputs and outputs — the same dependency chain as the legacy `subject.sh` bash path, but declarative and resumable.

---

## Layout

| Path | Role |
|------|------|
| [`workflow/Snakefile`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/workflow/Snakefile) | Top-level targets (`all`, `target_*`) |
| [`workflow/rules/*.smk`](https://github.com/phindagijimana/dkt_connectome/tree/main/dwi_pipeline/workflow/rules) | One file per step |
| [`workflow/config/config.yaml`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/workflow/config/config.yaml) | Defaults (override in `config.local.yaml`) |
| [`workflow/run_subject.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/workflow/run_subject.sh) | Thin CLI → Snakemake |
| [`submit.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/submit.sh) | Slurm array → `run_subject.sh` |

---

## Plugin targets

These wildcard-free targets map 1:1 to `./run --mode` and `run_subject.sh` modes:

| Snakemake target | Pipeline step | `./run --mode` |
|------------------|---------------|----------------|
| `target_qsiprep` | Step 1 — QSIPrep | `qsiprep` |
| `target_inpaint` | Step 1.5 — neuroLIT | `inpaint` |
| `target_recon` | Step 2 — FreeSurfer/FastSurfer | `recon` |
| `target_qsirecon` | Step 3 — QSIRecon | `qsirecon` |
| `target_connectome` | Step 4 — DKT connectome | `connectome` |
| `target_disconnectome` | Step 4.5 — disconnectome | `disconnectome` |
| `target_nodestrength` | Step 5 — node strength | `nodestrength` |
| `target_subject_qc` | Unified QC HTML | (part of participant run) |
| `all` | Full participant pipeline | `all` |

Step details: [Pipeline steps](pipeline_steps.md).

---

## Quick start

From `dwi_pipeline/` with paths set in `workflow/config/config.local.yaml`:

```bash
# Full pipeline for one subject
snakemake -s workflow/Snakefile --cores 8 \
  --config subject=011 -- all

# Single step only
snakemake -s workflow/Snakefile --cores 8 \
  --config subject=011 -- target_recon
```

Prefer the wrappers (same Snakemake engine under the hood):

```bash
# BIDS App (participant level)
./run /path/to/BIDS /path/to/out participant --participant-label 011

# HPC-style single subject
bash workflow/run_subject.sh all 011 --session-filter ses-1

# Slurm array (many subjects)
bash submit.sh
```

---

## Configuration

- **Global defaults:** `workflow/config/config.yaml`
- **Site overrides:** `workflow/config/config.local.yaml` (git-ignored)
- **One-off overrides:** `--config key=value` or env vars via `preflight.sh` / `./run`

See [Configuration](configuration.md) for container paths, recon tool, disconnectome options, and QC flags.

---

## Dry-run and CI

Validate the full DAG without running containers:

```bash
bash scripts/snakemake_dryrun_ci.sh
```

GitHub Actions runs the same script on every push to `main` (`.github/workflows/dwi_pipeline_ci.yml`).

---

## Registries

| Registry | Entry |
|----------|-------|
| **WorkflowHub** | `dkt_connectome` → `dwi_pipeline/workflow/Snakefile` |
| **Dockstore** | `dkt_connectome` (primary) + legacy root `dk_connectome` |
| **BIDS App** | `./run` → Snakemake via `run_subject.sh` |

---

## Legacy bash path

[`subject.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/subject.sh) remains for sites that have not migrated. New work should use Snakemake (`PIPELINE_ENGINE=snakemake`, the default in `submit.sh`).

See [Comparisons § Legacy root dk_connectome](comparisons.md#vs-legacy-root-dk_connectome-this-repo) for the root 4-stage Snakefile.
