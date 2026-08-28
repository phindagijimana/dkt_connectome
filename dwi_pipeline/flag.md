# dwi_pipeline flags reference

CLI flags and environment overrides for `submit.sh`, `subject.sh`, and `workflow/run_subject.sh`. Most flags are shared; a few are entry-point specific (noted below).

**Pipeline steps:** QSIPrep → Inpaint (1.5) → Recon → QSIRecon → Lesion-aware ACT (3.5, optional) → Connectome → Node strength

**Modes** (`PIPELINE_MODE` or first arg to `subject.sh` / `run_subject.sh`):

| Mode | What runs |
|------|-----------|
| `all` | Full pipeline (default for submit) |
| `qsiprep` | Step 1 only |
| `inpaint` | Step 1.5 only (needs lesion mask) |
| `recon` | Step 2 only |
| `qsirecon` | Step 3 only (needs QSIPrep) |
| `act` | Step 3.5 only (needs QSIRecon + lesion mask) |
| `sdstream` | SD_STREAM tractography + connectomes (needs QSIRecon + Step 4 nodes) |
| `connectome` | Step 4 (+ SD connectomes if `tractography.model: both`) |
| `disconnectome` | Step 4.5 only (needs lesion mask + DKT connectome) |
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
| `--no-sdc` | `QSIPREP_NO_SDC=1` | Skip SDC entirely — no fmap, no SyN. Reproduces legacy no-fieldmap GE runs (log line: `explicit no_sdc -> NO SDC`). Use only for reproducibility of prior no-SDC outputs; prefer `--syn` for new cohort processing. |

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
| `--anat-mitigation none\|neurolit\|vbt` | `ANAT_MITIGATION` | Select original T1w, neuroLIT (default), or LeAPP-compatible virtual brain transplant. `--inpaint` aliases `neurolit`; `--no-inpaint` aliases `none`. |

VBT uses `VBT_SMOOTHING_FACTOR=2.0` by default, matching the Gaussian sigma in
the published LeAPP code. neuroLIT and VBT use separate output roots so one
backend cannot overwrite the other.

### Connectome (Step 4)

| Flag | Env equivalent | What it does |
|------|----------------|--------------|
| `--no-connectome` / `--no-dk` | `RUN_CONNECTOME=0` | Skip Step 4 (and Step 5 with it in `all` mode). `--no-dk` is the legacy name. |
| `--connectome-weighting count\|sift2` | `CONNECTOME_WEIGHTING` | Edge weights for disconnectome (default `count`); must match any SIFT2 matrix you use in Step 4.5. |
| `--primary-connectome-measure count\|sift2` | `PRIMARY_CONNECTOME_MEASURE` | Select which matrix is copied to `dkt_connectome.csv`. Default: `count`. Requires `--connectome-sift2` when set to `sift2`. |
| `--connectome-sift2` | `CONNECTOME_SIFT2=1` | Optional extra Step 4 job: write `*_connectome_sift2.csv` (and SD_STREAM SIFT2 when `--tractography-model both`). |

Step 4 always writes `dkt_connectome_count.csv`, `dkt_connectome_meanlength.csv`,
`dkt_connectome_meanfa.csv`, and `dkt_connectome_meanmd.csv` from the same
tractogram and DKT node image. Enable `--connectome-sift2` for
`dkt_connectome_sift2.csv`. It also derives `dkt_desc-FA_dwi.nii.gz` and
`dkt_desc-MD_dwi.nii.gz` from the QSIPrep preprocessed DWI. The existing
`dkt_connectome.csv` remains the primary compatibility alias used by Step 5 and
existing analyses (count by default).

### ACT and experiment arms (Steps 3.5–4)

| Flag | Env equivalent | What it does |
|------|----------------|--------------|
| `--act-mode standard\|lesion-aware` | `ACT_MODE` | Use the QSIRecon tractogram or rebuild matched iFOD2/SIFT2 after inserting the lesion into the fifth 5TT channel. |
| `--act-5tt-source hsvs\|deep-atropos-native` | `ACT_FIVE_TT_SOURCE` | Base 5TT for lesion-aware ACT: QSIRecon ACPC HSVS (default) or native Deep Atropos. |
| `--deep-atropos-seg PATH` | `DEEP_ATROPOS_SEG` | Path to Deep Atropos integer segmentation (optional; `{subject}` `{session}` placeholders). |
| `--deep-atropos-seg-mode auto\|import\|generate` | `DEEP_ATROPOS_SEG_MODE` | Seg discovery: auto (default), require external, or always run ANTsPyNet. |
| `--act-streamlines N` | `ACT_STREAMLINES` | Number of lesion-aware streamlines; default `10000000`. |
| `--tractography-model ifod2\|sd_stream\|both` | `TRACTOGRAPHY_MODEL` | Default `both`: iFOD2 (QSIRecon) plus deterministic SD_STREAM Count/MeanLength/MeanFA/MeanMD matrices. |
| `--experiment-arm ARM` | `EXPERIMENT_ARM` | Maps an anatomy × ACT arm and isolates it under `RESULTS_ROOT/arms/ARM`. |

Supported arms: `orig-std`, `orig-lesion`, `neurolit-std`,
`neurolit-lesion`, `vbt-std`, and `vbt-lesion`. Set
`EXPERIMENT_ISOLATE_OUTPUTS=0` only for deliberate advanced reuse; the default
prevents one arm from overwriting another.

| Arm | `--anat-mitigation` | `--act-mode` |
|-----|---------------------|--------------|
| `orig-std` | `none` | `standard` |
| `orig-lesion` | `none` | `lesion-aware` |
| `neurolit-std` | `neurolit` | `standard` |
| `neurolit-lesion` | `neurolit` | `lesion-aware` |
| `vbt-std` | `vbt` | `standard` |
| `vbt-lesion` | `vbt` | `lesion-aware` |

User guide: [docs/usage.md](docs/usage.md) (Read the Docs — experiment arms section).

### Disconnectome (Step 4.5)

| Flag | Env equivalent | What it does |
|------|----------------|--------------|
| `--disconnection` | `RUN_DISCONNECTOME=1` | Opt in to Step 4.5 disconnectome (default **off**; method under validation). Requires lesion mask + DKT connectome. |
| `--disconnectome` | `RUN_DISCONNECTOME=1` | Alias for `--disconnection`. |
| `--no-disconnectome` | `RUN_DISCONNECTOME=0` | Explicitly skip Step 4.5. |
| `--disconnectome-core-only` | `DISCONNECTOME_CORE_ONLY=1` | Sensitivity: core lesion label only. |
| `--disconnectome-erode-voxels N` | `DISCONNECTOME_ERODE_VOXELS=N` | Erode lesion mask by N voxels before excision. |
| `--disconnectome-weighting count\|sift2` | `DISCONNECTOME_WEIGHTING` | Edge weighting for Step 4.5 (must match Step 4). |

Standalone: `subject.sh disconnectome <ID>` or `--mode disconnectome` (does not require `--disconnection`).

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
| `CONTAINER_VBT` | Virtual brain transplant (Step 1.5 VBT) image |
| `CONTAINER_LESION_ACT` | Post-QSIRecon lesion-aware ACT (Step 3.5) image |
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
| `CONNECTOME_ATLASES` | `dkt` | Comma/space-separated Step 4 atlases: `dkt`, `dk`, `auto`, `lausanne60` (e.g. `dkt,lausanne60` for robustness). |
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
bash workflow/run_subject.sh all EXAMPLE --fastsurfer --syn

# Recon only, FastSurfer + DK, GPU
RECON_FASTSURFER_DEVICE=cuda bash subject.sh recon EXAMPLE --fast-fs

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
