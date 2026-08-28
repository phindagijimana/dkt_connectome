# Schema reference

JSON Schemas validated at workflow startup. Source files in [`schemas/`](https://github.com/phindagijimana/dkt_connectome/tree/main/schemas) at the repository root.

Human-readable config defaults: [Configuration](configuration.md).

---

## Config schema (`config.schema.json`)

Validates the merged Snakemake config (`workflow/config/config.yaml` + `config.local.yaml` + `--config` overrides).

### Required top-level keys

| Key | Type | Description |
|-----|------|-------------|
| `bids_dir` | string | BIDS dataset root |
| `results_root` | string | All pipeline outputs |
| `fs_license` | string | Path to FreeSurfer `license.txt` |
| `templateflow_home` | string | TemplateFlow cache directory |
| `containers` | object | Apptainer `.sif` paths |

### Required containers

| Key | Step |
|-----|------|
| `containers.qsiprep` | 1 |
| `containers.qsirecon` | 3 |
| `containers.freesurfer` | 2 |
| `containers.dk_connectome` | 4 |

Optional: `containers.fastsurfer`, `containers.lit`, `containers.nodestrength`.

### Subject selection

| Key | Description |
|-----|-------------|
| `subjects` | Inline array of subject IDs (no `sub-` prefix) |
| `subjects_tsv` | Path to one-ID-per-line file; overrides `subjects` when non-empty |

### Step toggles (legacy root keys)

| Key | Default | Maps to |
|-----|---------|---------|
| `run_recon` | true | Step 2 |
| `run_qsirecon` | true | Step 3 |
| `run_dk_connectome` | true | Step 4 |

Modern config uses nested blocks — see `workflow/config/config.yaml` for `qsiprep:`, `recon:`, `connectome:`, `disconnectome:`, `inpaint:`.

### QSIPrep block (`qsiprep`)

| Property | Type | Description |
|----------|------|-------------|
| `output_resolution` | number | Output voxel size (mm) |
| `use_syn_sdc` | bool | SyN SDC when no fmap |
| `fmap_retry` | bool | Ignore fieldmaps; force SyN |
| `skip_bids_validation` | bool | Skip BIDS validator |

### Recon block (`recon`)

| Property | Type | Description |
|----------|------|-------------|
| `tool` | string | `freesurfer` or `fastsurfer` |
| `fsaparc` | bool | FastSurfer + DK aparc (`--fast-fs`) |
| `enabled` | bool | Run Step 2 |

### Connectome block (`connectome`)

| Property | Type | Description |
|----------|------|-------------|
| `parcellation` | string | `dkt` (default), `dk`, or `auto` |
| `weighting` | string | `count` or `sift2` |
| `deterministic` | bool | Deterministic tractography seeding |
| `fail_on_empty_nodes` | bool | Fail on empty parcellation nodes |

### Disconnectome block (`disconnectome`)

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enabled` | bool | false | Step 4.1 opt-in |
| `lesion_erode_voxels` | int | 0 | Lesion erosion |
| `core_only` | bool | false | Core label only |
| `disconnection_spared` | string | `C` | Spared matrix for D |
| `weighting` | string | matches Step 4 | Edge weights |

---

## Plugin schema (`plugin.schema.json`)

Validates per-rule plugin metadata under `workflow/rules/`. Used when adding new Snakemake steps.

Inspect the schema file for required fields:

```bash
python3 -m json.tool schemas/plugin.schema.json | less
```

---

## Validation at runtime

Preflight and Snakemake lint validate config before executing containers:

```bash
bash workflow/preflight.sh --mode all --quick
snakemake -s workflow/Snakefile --lint
```

Invalid config should fail **before** QSIPrep or recon start.

---

## See also

- [Configuration](configuration.md)
- [Contributing](contributing.md)
- [Snakemake workflow](snakemake_workflow.md)
