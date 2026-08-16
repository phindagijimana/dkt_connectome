# Configuration reference

Defaults live in [`workflow/config/config.yaml`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/workflow/config/config.yaml). Override locally with **`workflow/config/config.local.yaml`** (gitignored) or environment variables.

Full CLI + env table: [`flag.md` on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/flag.md).

---

## Path settings

| Key / variable | Default | Description |
|----------------|---------|-------------|
| `results_root` / `RESULTS_ROOT` | *(required)* | Output tree for all steps |
| `random_seed` / `RANDOM_SEED` | `0` | Pseudorandom seed (`--random-seed`) |
| `bids_dir` / `BIDS_DIR` | *(required)* | BIDS input root |
| `recon_out` / `RECON_OUT` | `<results_root>/freesurfer` | FreeSurfer subjects dir |
| `fs_subjects_dir` / `FS_SUBJECTS_DIR` | `recon_out` | FS tree read by QSIRecon / connectome |
| `nodestrength_out` / `NODESTRENGTH_OUT` | `<results_root>/node_strength` | Step 5 outputs |
| `templateflow_home` / `TEMPLATEFLOW_HOME` | `<repo>/templateflow` | TemplateFlow cache |
| `fs_license` / `FS_LICENSE` | *(required for recon)* | FreeSurfer license file |

---

## Containers

Set `.sif` paths in `config.local.yaml` under `containers:` or via `CONTAINER_*` env vars:

| Key | Env variable |
|-----|--------------|
| `containers.qsiprep` | `CONTAINER_QSIPREP` |
| `containers.qsirecon` | `CONTAINER_QSIRECON` |
| `containers.freesurfer` | `CONTAINER_FREESURFER` |
| `containers.fastsurfer` | `CONTAINER_FASTSURFER` |
| `containers.connectome` | `CONTAINER_CONNECTOME` |
| `containers.lit` | `CONTAINER_LIT` |
| `containers.nodestrength` | `CONTAINER_NODESTRENGTH` |

**Pin upstream tags** with `container_pins:` (reference only) — see [Derivatives policy](derivatives.md).

---

## Step 1 — QSIPrep (`qsiprep`)

| Key | CLI / env | Description |
|-----|-----------|-------------|
| `use_syn_sdc` | `--syn`, `QSIPREP_USE_SYN_SDC=1` | SyN SDC when no fmap in filter |
| `fmap_retry` | `--fmap-retry`, `QSIPREP_FMAP_RETRY=1` | Ignore fieldmaps; force SyN |
| `no_sdc` | `--no-sdc`, `QSIPREP_NO_SDC=1` | Skip SDC entirely |
| `bids_filter` | `--bids-filter`, `QSIPREP_BIDS_FILTER` | Static QSIPrep filter JSON |

### DWI selection (`dwi_select`)

| Key | CLI / env | Description |
|-----|-----------|-------------|
| `enabled` | `--no-dwi-filter` disables | Series filter on/off |
| `shell_b` | `--dwi-shell N`, `DWI_SHELL_B` | Default b-value (1000) |
| `json` | `--dwi-select PATH`, `DWI_SELECT_JSON` | Explicit filter JSON |

---

## Step 1.5 — Inpaint (`inpaint`)

| Key | Env | Description |
|-----|-----|-------------|
| `enabled` | `RUN_INPAINT`, `--no-inpaint` | Auto-on; no-op without lesion mask |
| `dilate` | `INPAINT_DILATE` | Mask dilation voxels (default 2) |
| `device` | `INPAINT_DEVICE` | `auto`, `cpu`, `cuda` |
| `min_outside_corr` | `INPAINT_MIN_OUTSIDE_CORR` | QC threshold |
| `fail_on_qc` | `INPAINT_FAIL_ON_QC=1` | Fail when QC `ok=false` |

---

## Step 2 — Recon (`recon`)

| Key | CLI / env | Description |
|-----|-----------|-------------|
| `enabled` | `--no-recon`, `RUN_RECON=0` | Skip Step 2 |
| `tool` | `--fastsurfer` / `--freesurfer`, `RECON_TOOL` | `freesurfer` or `fastsurfer` |
| `fsaparc` | `--fast-fs`, `RECON_FSAPARC=1` | FastSurfer + classic DK aparc |
| `session` | `--session-filter`, `RECON_SESSION` | Override auto session |
| `fastsurfer_device` | `RECON_FASTSURFER_DEVICE` | `cpu` or `cuda` |

---

## Step 3 — QSIRecon (`qsirecon`)

| Key | Env | Default |
|-----|-----|---------|
| `spec` | `QSIRECON_SPEC` | `mrtrix_singleshell_ss3t_ACT-hsvs` |
| `atlases` | `QSIRECON_ATLASES` | `4S156Parcels` |

---

## Step 4 — Connectome (`connectome`)

| Key | Env | Default |
|-----|-----|---------|
| `enabled` | `--no-connectome`, `RUN_CONNECTOME=0` | true |
| `parcellation` | `CONNECTOME_PARCELLATION` | `dkt` (78 nodes) |
| `weighting` | `--connectome-weighting`, `CONNECTOME_WEIGHTING` | **`count`** |
| `deterministic` | `CONNECTOME_DETERMINISTIC` | true |
| `fail_on_empty_nodes` | `CONNECTOME_FAIL_ON_EMPTY_NODES=1` | false |

---

## Step 4.5 — Disconnectome (`disconnectome`)

| Key | CLI | Default |
|-----|-----|---------|
| `enabled` | `--disconnection` / `--disconnectome` | false (opt-in) |
| `lesion_erode_voxels` | `--disconnectome-erode-voxels N` | 0 |
| `core_only` | `--disconnectome-core-only` | false |
| `disconnection_spared` | — | `C` |
| `weighting` | `--disconnectome-weighting` | matches Step 4 (`count`) |
| `qc_html` | — | true |

---

## QC and derivatives export

| Key | Description |
|-----|-------------|
| `qc.subject_html` | Write `qc/sub-<ID>/subject_qc.html` |
| `derivatives.export_enabled` | Export on `./run group` |
| `derivatives.export_copy` | Copy vs symlink for `derivatives/` |
| `bids.validate` | Opt-in BIDS validator |

---

## Slurm (`submit.sh`)

| Variable | Default | Description |
|----------|---------|-------------|
| `ARRAY_CONCURRENCY` | `5` | Slurm `%K` throttle |
| `NTHREADS` | `8` | CPU threads per job |
| `SBATCH_GRES` | auto | GPU when inpaint / FastSurfer cuda |

See [Usage](usage.md) for examples.
