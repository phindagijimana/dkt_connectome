# Snakemake workflow

The **canonical execution engine** for the DKT Connectome is the Snakemake workflow under [`dwi_pipeline/workflow/`](https://github.com/phindagijimana/dkt_connectome/tree/main/dwi_pipeline/workflow).

Each pipeline step is a **plugin rule** (QSIPrep, inpaint, recon, QSIRecon, Deep Atropos seg/5TT, lesion-aware ACT, connectome, SD_STREAM, disconnectome, nodestrength, subject QC). Snakemake builds the DAG from declared inputs and outputs — declarative, resumable, and skip-if-done.

**Step 3.1 optional branch** (`--act-5tt-source deep-atropos-native`):

| Sub-step | Rule file | Container |
|----------|-----------|-----------|
| 3.2-seg | `deep_atropos_seg.smk` | `dkt_deep_atropos_seg.sif` |
| 3.2 | `deep_atropos_5tt.smk` | `dkt_deep_atropos.sif` |
| 3.1 | `lesion_aware_act.smk` | `dkt_lesion_act.sif` |

Details: [Deep Atropos native-T1 5TT](deep_atropos_5tt.md) · [Pipeline steps § 3.1](pipeline_steps.md#step-31-lesion-aware-act-optional).

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

| Snakemake target | Pipeline step | `./run --mode` / `run_subject.sh` |
|------------------|---------------|-------------------------------------|
| `target_qsiprep` | Step 1 — QSIPrep | `qsiprep` |
| `target_inpaint` | Step 1.1 — neuroLIT or VBT | `inpaint` |
| `target_recon` | Step 2 — FreeSurfer/FastSurfer | `recon` |
| `target_qsirecon` | Step 3 — QSIRecon | `qsirecon` |
| `target_act` | Step 3.1 — lesion-aware ACT | `act` |
| `target_sdstream` | SD_STREAM tractography + connectomes | `sdstream` |
| `target_connectome` | Step 4 — DKT connectome (+ SD if `both`) | `connectome` |
| `target_disconnectome` | Step 4.1 — disconnectome | `disconnectome` |
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

See [Comparisons § Legacy root workflow](comparisons.md#vs-legacy-root-dk_connectome-this-repo-only) for the repository root 4-stage Snakefile (Dockstore legacy entry).
