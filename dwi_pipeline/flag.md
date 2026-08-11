# dwi_pipeline flags reference

CLI flags and environment overrides for `submit.sh`, `subject.sh`, and `workflow/run_subject.sh`. Most flags are shared; a few are entry-point specific (noted below).

**Pipeline steps:** QSIPrep → Inpaint (1.5) → Recon → QSIRecon → Connectome → Node strength

**Modes** (`PIPELINE_MODE` or first arg to `subject.sh` / `run_subject.sh`):

| Mode | What runs |
|------|-----------|
| `all` | Full pipeline (default for submit) |
| `qsiprep` | Step 1 only |
| `inpaint` | Step 1.5 only (needs lesion mask) |
| `recon` | Step 2 only |
| `qsirecon` | Step 3 only (needs QSIPrep) |
| `connectome` | Step 4 only (needs QSIRecon + FS tree) |
| `nodestrength` | Step 5 only (needs connectome CSV) |
| `dk` | Alias for `connectome` (legacy) |

---

## CLI flags (shared)

Pass after `./submit.sh …` or `bash subject.sh <mode> <subject> …` / `bash run_subject.sh <mode> <subject> …`.

### Distortion correction (QSIPrep / Step 1)

| Flag | Env equivalent | What it does |
|------|----------------|--------------|
| `--syn` / `--use-syn-sdc` | `QSIPREP_USE_SYN_SDC=1` | Use SyN synthetic SDC (`--use-syn-sdc error`) when there is no measured fieldmap in the dwi-select filter. Recommended for GE / no-fmap subjects when you want a real distortion correction. |
| `--fmap-retry` | `QSIPREP_FMAP_RETRY=1` | Ignore BIDS fieldmaps and force SyN SDC (`--ignore fieldmaps --use-syn-sdc error`). Use when fmaps exist but are bad. |
| `--no-sdc` | `QSIPREP_NO_SDC=1` | Skip SDC entirely — no fmap, no SyN. Reproduces the previous CIDUR GE runs (log line: `explicit no_sdc -> NO SDC`). Use only for reproducibility of prior no-SDC outputs; prefer `--syn` for new cohort processing. |

Without measured fmaps in the filter, the pipeline **fails** unless `--syn`, `--fmap-retry`, or `--no-sdc` is set.

Both `--syn` and `--fmap-retry` pass QSIPrep `--use-syn-sdc error` (strict): if SyN estimation itself fails on a subject, the pipeline fails loudly for that subject rather than silently completing without SDC. `warn` would have proceeded on failure — misleading naming. Use `--no-sdc` explicitly when you really do want a subject without SDC.

### DWI series selection (QSIPrep)

| Flag | Env equivalent | What it does |
|------|----------------|--------------|
| `--dwi-shell <B>` | `DWI_SHELL_B=<B>` | Select DWI with that b-value via `config/dwi_select_b<B>.json` (default `1000`). Clears any explicit `--dwi-select`. Keeps matching DWI + IntendedFor fmaps; drops `acq-rs` fmaps. |
| `--dwi-select <path.json>` | `DWI_SELECT_JSON=<path>` | Explicit dwi-select config JSON (overrides `--dwi-shell` path). Mutually exclusive with `--bids-filter`. |
| `--bids-filter <path.json>` | `QSIPREP_BIDS_FILTER=<path>` | Static QSIPrep `--bids-filter-file`. Mutually exclusive with `--dwi-select`. |
| `--no-dwi-filter` | `QSIPREP_NO_DWI_FILTER=1` | Disable series filtering; process all DWI/fmaps (legacy). |

### Recon (Step 2)

| Flag | Env equivalent | What it does |
|------|----------------|--------------|
| `--fastsurfer` | `RECON_TOOL=fastsurfer` | Run FastSurfer instead of FreeSurfer `recon-all`. Default atlas is **DKT** (`aparc+aseg.mgz`). Faster (~1–2 h CPU). |
| `--freesurfer` | `RECON_TOOL=freesurfer` | Run FreeSurfer `recon-all` (default without `--fastsurfer`). Produces classic DK + DKT volumes. |
| `--fast-fs` | `RECON_TOOL=fastsurfer` + `RECON_FSAPARC=1` | FastSurfer **plus** `--fsaparc`: also writes classic **DK-68** aparc/ribbon alongside native DKT. Needed if you want both DK and DKT from FastSurfer. |
| `--no-recon` | `RUN_RECON=0` | Skip Step 2 in `all` mode. For QSIRecon ACT-hsvs you must already have an FS subjects dir, or switch to an ACT-fast spec. |

### Inpaint (Step 1.5)

| Flag | Env equivalent | What it does |
|------|----------------|--------------|
| `--inpaint` | `RUN_INPAINT=1` | Enable inpaint step (default on). Still a no-op per subject unless a lesion mask is found. |
| `--no-inpaint` | `RUN_INPAINT=0` | Force-skip Step 1.5 even if a lesion mask exists. |

### Connectome (Step 4)

| Flag | Env equivalent | What it does |
|------|----------------|--------------|
| `--no-connectome` / `--no-dk` | `RUN_CONNECTOME=0` | Skip Step 4 (and Step 5 with it in `all` mode). `--no-dk` is the legacy name. |

### Node strength (Step 5)

| Flag | Env equivalent | What it does |
|------|----------------|--------------|
| `--node-strength` | `RUN_NODESTRENGTH=1` | Enable Step 5 (default on when connectome runs). |
| `--no-node-strength` | `RUN_NODESTRENGTH=0` | Skip Step 5 only; keep the connectome CSV. |
| `--strength-only` | `NODESTRENGTH_STRENGTH_ONLY=1` | Skip volume/ and compare/ outputs in the nodestrength container. (`subject.sh` / `run_subject.sh` only; not on `submit.sh` CLI — use the env var with submit.) |
| `--no-report` | `NODESTRENGTH_NO_REPORT=1` | Skip PDF + figures/. (Same: CLI on subject/run_subject; env with submit.) |

### Help / Snakemake-only

| Flag | Where | What it does |
|------|-------|--------------|
| `-h` / `--help` | all entry points | Print usage header and exit. |
| `--recon-session <label>` | `run_subject.sh` only | Override auto-resolved session for recon T1w (e.g. `2WK`). Env: `RECON_SESSION`. |
| `--dry-run` / `-n` | `run_subject.sh` only | Forward `-n` to Snakemake (show plan, run nothing). |
| `--` | `run_subject.sh` only | Pass remaining args through to Snakemake as-is. |

---

## Environment variables (no CLI flag, or submit-only)

Set before `./submit.sh` or before `subject.sh` / `run_subject.sh`.

### Paths and engine

| Variable | Default | What it does |
|----------|---------|--------------|
| `BIDS_DIR` | (config / placeholder) | BIDS input root. |
| `RESULTS_ROOT` | (config / placeholder) | Output tree (`qsiprep_…`, `freesurfer/`, `connectomes/`, etc.). |
| `RECON_OUT` | `$RESULTS_ROOT/freesurfer` | FreeSurfer-format subjects directory written by recon. |
| `FS_SUBJECTS_DIR` | `$RECON_OUT` | Subjects dir read by QSIRecon / connectome (can point at an external tree). |
| `NODESTRENGTH_OUT` | `$RESULTS_ROOT/node_strength` | Step 5 output directory (cohort-shared). |
| `INPAINT_OUT` | `$RESULTS_ROOT/inpainted` | Inpainted T1w output directory. |
| `PIPELINE_ENGINE` | `snakemake` | `snakemake` (default) or `bash` (legacy `subject.sh` path). |
| `PIPELINE_MODE` | `all` | Which stage(s) to run (see modes table). |
| `NTHREADS` / `OMP_NTHREADS` | `8` | Thread counts for containers / OpenMP. |
| `OUTPUT_RES` | `2` | QSIPrep output resolution (mm). |
| `SUBJECT_LIST_FILE` | `dwi_pipeline/subjects.txt` | Subject list for Slurm array. |
| `SUBJECT_LIST_ONLY_DWI` | `1` | Only list subjects with DWI under BIDS (`0` = all `sub-*`). |
| `SUBJECT_LIST_USE_EXISTING` | `0` | If `1` and list non-empty, do not rebuild subjects.txt. |
| `ARRAY_CONCURRENCY` | `5` | Slurm array throttle (`%K`). |

### Containers and licenses

| Variable | What it does |
|----------|--------------|
| `CONTAINER_QSIPREP` | QSIPrep Apptainer image |
| `CONTAINER_QSIRECON` | QSIRecon image |
| `CONTAINER_FASTSURFER` | FastSurfer image |
| `CONTAINER_FREESURFER` | FreeSurfer `recon-all` image |
| `CONTAINER_CONNECTOME` | Connectome / DKT tooling image |
| `CONTAINER_LIT` | LIT inpainting image |
| `CONTAINER_NODESTRENGTH` | Node strength / ENIGMA report image |
| `FS_LICENSE` | FreeSurfer license file |
| `TEMPLATEFLOW_HOME` | TemplateFlow cache directory |

### Recon extras

| Variable | Default | What it does |
|----------|---------|--------------|
| `RECON_FASTSURFER_DEVICE` | `cpu` | `cpu` or `cuda` for FastSurfer. |
| `RECON_SESSION` | auto | Bare session label for recon T1w (e.g. `2WK`). |
| `RECON_SKIP_IF_EXISTS` | fail if present | If `1`, skip recon when `aparc+aseg.mgz` already exists. |

### QSIRecon

| Variable | Default | What it does |
|----------|---------|--------------|
| `QSIRECON_SPEC` | `mrtrix_singleshell_ss3t_ACT-hsvs` | QSIRecon reconstruction spec. Use `…ACT-fast` if skipping FreeSurfer-dependent HSVS. |
| `QSIRECON_ATLASES` | `4S156Parcels` | Space-separated atlas names for QSIRecon connectivity. |

### Inpaint extras

| Variable | Default | What it does |
|----------|---------|--------------|
| `INPAINT_REQUIRE_MASK` | `0` | If `1`, fail when no lesion mask (instead of silent skip). |
| `INPAINT_DILATE` | `2` | Voxels to dilate lesion mask before inpainting. |
| `INPAINT_DEVICE` | `auto` | `auto` \| `cpu` \| `cuda`. |
| `INPAINT_BATCH_SIZE` | `4` | GPU batch size (lower if OOM on small MIG slices). |
| `INPAINT_LABELS` | `all` | Mask label values to inpaint, or `all`. |
| `INPAINT_BINARIZE` | `0` | Collapse selected labels to one value before inpaint. |
| `INPAINT_MIN_OUTSIDE_CORR` | `0.995` | QC: correlation outside lesion. |
| `INPAINT_MAX_CORR_DROP` | `0.01` | QC: max drop vs resampling-only control. |
| `INPAINT_FAIL_ON_QC` | `0` | If `1`, fail when inpaint QC reports `ok=false`. |
| `INPAINT_SKIP_IF_EXISTS` | `1` | Skip if `inpainting.json` already exists (`0` = force rerun). |

### Connectome extras

| Variable | Default | What it does |
|----------|---------|--------------|
| `CONNECTOME_PARCELLATION` | `dkt` | `dkt` (78 nodes) \| `dk` (84; recon-all / `--fast-fs`) \| `auto` (follow tree; can mix cohort node counts). |
| `CONNECTOME_LUT_DKT` | package LUT | Path to MRtrix DKT LUT (`fs_dkt.txt`). |
| `CONNECTOME_FAIL_ON_EMPTY_NODES` | `0` | If `1`, fail when a node has no streamlines. |
| `CONNECTOME_DETERMINISTIC` | `1` | Pin ITK to 1 thread for a reproducible matrix. |
| `CONNECTOME_RESAMPLE_TO_DWI` | `1` | Resample segmentation onto the DWI grid. |

Legacy `DK_*` env names still work and print a deprecation note (`DK_PARCELLATION` → `CONNECTOME_PARCELLATION`, etc.).

### Node strength extras

| Variable | Default | What it does |
|----------|---------|--------------|
| `NODESTRENGTH_SKIP_IF_EXISTS` | `1` | Skip if subject already in manifest / has `report.pdf` (`0` = force rerun). |

### Slurm / submit.sh only

| Variable | Default | What it does |
|----------|---------|--------------|
| `EXCLUDE_NODES` | `smdodwork05` | Comma-list for `sbatch --exclude`. |
| `SBATCH_GRES` | auto when inpaint/GPU | e.g. `gpu:l40s.24g:1`. Auto-set when inpaint may run or FastSurfer cuda. |
| `SBATCH_DEPENDENCY` | unset | e.g. `afterok:JOBID` to chain arrays. |
| `SBATCH_PARTITION` | from `array.sh` | Override partition. |
| `SBATCH_TIME` | from `array.sh` | Override walltime (must fit partition MaxTime). |
| `SBATCH_CPUS` | from `array.sh` | Override `--cpus-per-task` (keep aligned with `NTHREADS`). |
| `SBATCH_MEM` | from `array.sh` | Override `--mem`. |
| `SBATCH_JOB_NAME` | from `array.sh` | Override job name and log filenames. |

---

## Quick examples

```bash
# Full cohort, FastSurfer + DKT, SyN SDC (no fmaps)
./submit.sh --fastsurfer --syn

# FastSurfer with both DKT and classic DK (--fsaparc)
./submit.sh --fast-fs --syn

# Single subject via Snakemake wrapper
bash workflow/run_subject.sh all TBI011011 --fastsurfer --syn

# Recon only, FastSurfer + DK, GPU
RECON_FASTSURFER_DEVICE=cuda bash subject.sh recon TBI011011 --fast-fs

# Skip connectome + node strength
./submit.sh --fastsurfer --syn --no-connectome
```

---

## Where defaults live

| File | Role |
|------|------|
| `workflow/config/config.yaml` | Snakemake defaults (mirrors env defaults) |
| `workflow/config/config.local.yaml` | Site-specific paths (containers, RESULTS_ROOT, BIDS) |
| `submit.sh` / `subject.sh` | CLI parsing + env export |
| `workflow/run_subject.sh` | CLI → Snakemake `--configfile` overrides |

See also: `README.md`, `workflow/README.md`, `../fmaps.md` (SDC behavior).
