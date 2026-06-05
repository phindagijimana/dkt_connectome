# dk_connectome — User Guide

In-depth reference for users who want to go beyond `./connectome install / start / check`.
For the quick start, see [README.md](README.md).

---

## Contents

1. [Pipeline overview](#pipeline-overview)
2. [What gets produced](#what-gets-produced)
3. [Installation in detail](#installation-in-detail)
4. [Configuration reference](#configuration-reference)
5. [Selecting subjects](#selecting-subjects)
6. [SDC: distortion correction options](#sdc-distortion-correction-options)
7. [Recon: FreeSurfer vs FastSurfer](#recon-freesurfer-vs-fastsurfer)
8. [QSIRecon spec + atlases](#qsirecon-spec--atlases)
9. [DK connectome step — design rationale](#dk-connectome-step--design-rationale)
10. [Slurm tuning](#slurm-tuning)
11. [Manual Snakemake usage](#manual-snakemake-usage)
12. [Re-running, selective targets, partial re-execution](#re-running-selective-targets-partial-re-execution)
13. [Citing](#citing)
14. [Troubleshooting](#troubleshooting)

---

## Pipeline overview

```
BIDS sub-XXX/
   ├── dwi/  ── rule qsiprep ──────►  qsiprep_single_run_output/sub-XXX/
   │                                       │
   │                                       ▼
   └── anat/ ── rule recon  ──────►  freesurfer/sub-XXX/mri/aparc+aseg.mgz
                                          │
                                          ▼
                          rule qsirecon ─►  qsirecon_single_run_output/.../*.tck.gz
                                          │
                                          ▼
                          rule dk_connectome ─►  dk_connectomes/sub-XXX/dk_connectome.csv
```

Per subject, four stages run in dependency order. Stages can be toggled and
individual subjects can be re-run independently — Snakemake skips any stage
whose outputs already exist and whose inputs are not newer.

| Stage | Tool | Container | Typical wall time (single-shell ~64 dir, 1 session) |
|---|---|---|---|
| 1 — `qsiprep` | QSIPrep | `qsiprep.sif` | 1.5 – 4 h |
| 2 — `recon` | recon-all *or* FastSurfer | `freesurfer.sif` / `fastsurfer.sif` | 4 – 10 h (recon-all) · ~1 h (FastSurfer CPU) |
| 3 — `qsirecon` | QSIRecon (SS3T CSD + ACT + HSVS) | `qsirecon.sif` | 3 – 5 h |
| 4 — `dk_connectome` | ANTs + FreeSurfer + MRtrix3 | `qsirecon.sif` | ~3 min |

---

## What gets produced

```
<results_root>/
    qsiprep_single_run_output/        QSIPrep BIDS-Derivatives
    freesurfer/sub-XXX/               recon-all / FastSurfer subjects dir
    qsirecon_single_run_output/       QSIRecon BIDS-Derivatives (incl. *.tck.gz)
    dk_connectomes/sub-XXX/
        dk_connectome.csv             # 84×84 symmetric DK connectivity matrix
        dk_assignments.csv            # streamline → (node_i, node_j) mapping
        dk_nodes.mif                  # MRtrix node label image (post-labelconvert)
        aparc+aseg_in_dwi.nii.gz      # FS parcellation resampled to DWI grid
        aparc+aseg.nii.gz             # FS parcellation in FS conformed space
        dk_nodes.mrinfo.txt           # space diagnostic (header + transform)
        tracks.tckinfo.txt            # tractogram header
    logs/<rule>.sub-XXX.log           per-task stdout+stderr
    .flags/<stage>.sub-XXX.done       sentinel files for dir-tree stages
    intermediate_results_*/           nipype workdirs (per-stage scratch)
```

The QSIPrep, FreeSurfer, and QSIRecon outputs are full BIDS-App derivatives — they
work directly with any downstream nipreps tool.

---

## Installation in detail

The `./connectome install` command runs five steps; each is independently
re-runnable so you can iterate as you fix things.

```
1/5  Toolchain         python3 + container runtime + slurm presence check
2/5  Python deps       pip install snakemake>=8.0 snakemake-executor-plugin-slurm>=0.6
3/5  Containers        apptainer pull each .sif into ./containers (or --containers-dir)
4/5  Subjects          run workflow/scripts/list_subjects.py to populate config/subjects.tsv
5/5  Config audit      print every /path/to/... placeholder still in config.yaml
```

Useful flags:

```bash
./connectome install --user                 # pip install --user (no venv/conda env active)
./connectome install --no-deps              # skip step 2 (already installed)
./connectome install --no-containers        # skip step 3 (already pulled)
./connectome install --with-fastsurfer      # also pull fastsurfer.sif (default skipped)
./connectome install --containers-dir /shared/sifs   # central .sif cache
./connectome install --force-pull           # re-pull containers even if present
./connectome install --config config/myconfig.yaml --bids /shared/BIDS  # custom config + scan
```

### Manual container pulls

If you prefer pulling by hand or pinning specific digests:

```bash
mkdir -p containers && cd containers
apptainer pull qsiprep.sif          docker://pennlinc/qsiprep:1.0.0
apptainer pull qsirecon.sif         docker://pennlinc/qsirecon:1.2.1
apptainer pull freesurfer_7.4.1.sif docker://freesurfer/freesurfer:7.4.1
apptainer pull fastsurfer.sif       docker://deepmi/fastsurfer:latest      # optional
```

Pin the digests you actually used in published runs:

```bash
apptainer inspect --json containers/qsiprep.sif | jq .data.attributes
```

### FreeSurfer license & color LUT

Get the license at <https://surfer.nmr.mgh.harvard.edu/registration.html> (free).
The DK step also needs `FreeSurferColorLUT.txt`, which ships with any FreeSurfer
install — copy or symlink it next to your `license.txt`, then point both `fs_license`
and `fs_lut` in `config/config.yaml` at them.

---

## Configuration reference

Everything lives in `config/config.yaml`. Top-level keys:

| key | default | effect |
|---|---|---|
| `bids_dir` | *(required)* | path to BIDS dataset root |
| `results_root` | `./results` | where all outputs land |
| `containers.qsiprep` / `.qsirecon` / `.freesurfer` / `.fastsurfer` | *(required for whichever stages you run)* | absolute paths to `.sif` files |
| `fs_license` | *(required)* | FreeSurfer license file |
| `fs_lut` | `<fs_license parent>/FreeSurferColorLUT.txt` | LUT bind-mounted into the DK step |
| `templateflow_home` | `~/.cache/templateflow` | QSIRecon atlas cache (reuse across runs!) |
| `subjects` | `[]` | inline subject ID list (no `sub-` prefix) |
| `subjects_tsv` | `config/subjects.tsv` | one ID per line, `#` comments; **wins over `subjects`** |
| `run_recon` | `true` | gate Step 2 + HSVS in Step 3 |
| `run_qsirecon` | `true` | gate Step 3 |
| `run_dk_connectome` | `true` | gate Step 4 (requires `run_recon: true`) |
| `qsiprep.output_resolution` | `2` | mm; passed to `qsiprep --output_resolution` |
| `qsiprep.use_syn_sdc` | `false` | use `--use-syn-sdc warn` when no fieldmaps present |
| `qsiprep.fmap_retry` | `false` | force `--ignore fieldmaps --use-syn-sdc warn` |
| `qsiprep.skip_bids_validation` | `true` | pass `--skip-bids-validation` |
| `recon.tool` | `freesurfer` | `freesurfer` (recon-all) or `fastsurfer` |
| `recon.fastsurfer_device` | `cpu` | `cpu` or `cuda` (FastSurfer only) |
| `qsirecon.spec` | `mrtrix_singleshell_ss3t_ACT-hsvs` | any built-in QSIRecon spec |
| `qsirecon.atlases` | `[ 4S156Parcels ]` | atlas keys for QSIRecon's connectivity node (see below) |
| `dk.resample_to_dwi` | `true` | resample aparc+aseg to DWI grid via `antsApplyTransforms` |
| `dk.tck2connectome_extra` | `[]` | e.g. `[ "-scale_invlength", "-scale_invnodevol" ]` |
| `threads.<stage>` | `{qsiprep:4, recon:4, qsirecon:4, dk:2}` | CPUs per task |
| `resources.<stage>` | see [Slurm tuning](#slurm-tuning) | `mem_mb`, `runtime`, optional `slurm_partition` |
| `slurm.exclude_nodes` | `""` | comma-separated nodelist passed through to `--exclude` |

You can override any single key on the CLI:

```bash
./connectome start -- --config qsiprep='{"use_syn_sdc":true}' --config run_dk_connectome=false
```

---

## Selecting subjects

Either inline in YAML:

```yaml
subjects: [ "001", "007" ]
```

…or via TSV (one ID per line, `#` comments allowed; **TSV wins if both are set**):

```yaml
subjects_tsv: config/subjects.tsv
```

Auto-generate the TSV from your BIDS dataset:

```bash
python workflow/scripts/list_subjects.py /path/to/bids \
    --require-dwi --require-t1w > config/subjects.tsv
```

`./connectome install --bids /path/to/BIDS` does this automatically.

---

## SDC: distortion correction options

QSIPrep auto-detects fieldmaps. Three behaviours:

| `use_syn_sdc` | `fmap_retry` | What QSIPrep is told |
|:-:|:-:|---|
| `false` (default) | `false` | use whatever fieldmaps live in BIDS; nothing extra if none |
| `true` | `false` | add `--use-syn-sdc warn` so SyN runs as a fallback when no fmap |
| `*` | `true` | add `--ignore fieldmaps --use-syn-sdc warn` (force SyN even if a bad fmap exists) |

SyN-SDC is slower and depends on the T1w being good — prefer real fieldmaps when
you have them.

---

## Recon: FreeSurfer vs FastSurfer

`recon.tool: freesurfer` runs full `recon-all` inside `containers.freesurfer`.
Wall time: 4–10 h per subject, CPU-bound, single-threaded for most of the run.

`recon.tool: fastsurfer` runs FastSurfer inside `containers.fastsurfer`.
Wall time: ~1 h on CPU, ~10 min on GPU (set `recon.fastsurfer_device: cuda`).
The output is `aparc+aseg.mgz`-compatible, so the rest of the pipeline doesn't
notice the swap.

**Trap:** the FreeSurfer that ships *inside* `qsirecon.sif` and inside `fastsurfer.sif`
is trimmed — it lacks the skull-strip atlas (`RB_all_withskull_2020_01_02.gca`).
Always set `containers.freesurfer` to a dedicated full image, e.g.
`docker://freesurfer/freesurfer:7.4.1`. The CLI installer pulls this for you.

---

## QSIRecon spec + atlases

`qsirecon.spec: mrtrix_singleshell_ss3t_ACT-hsvs` is the default and what the
pipeline is tuned for: single-shell SS3T-CSD, Anatomically-Constrained Tractography,
Hybrid Surface-Volume Segmentation. Other built-in QSIRecon specs (multi-shell MSMT,
SS3T variants, ssst, ...) work as long as the corresponding container is on disk.

QSIRecon's MRtrix specs include a `connectivity-estimation` node that **requires**
at least one atlas; without any, qsirecon aborts with:

```
ValueError: Connectivity estimation requires atlases. Please set --atlases ...
```

Recognised keys (shipped inside `qsirecon.sif` via TemplateFlow):

```
AAL116, AICHA384Ext, Brainnetome246Ext, Gordon333Ext,
4S156Parcels, 4S256Parcels, 4S356Parcels, 4S456Parcels, 4S556Parcels,
4S656Parcels, 4S756Parcels, 4S856Parcels, 4S956Parcels, 4S1056Parcels
```

The default is `4S156Parcels` (Schaefer-100 cortex + Tian/HCP 56 subcortex) — small,
fast, widely cited.

This atlas is what QSIRecon uses for its **own** connectivity output. **It is
independent of the DK connectome** the pipeline builds in Step 4: that one is
always Desikan-Killiany derived from `aparc+aseg.mgz`.

---

## DK connectome step — design rationale

The DK rule produces a DWI-space DK connectome with explicit, label-aware resampling.
**It does not use `mri_vol2vol`.** Here is why.

QSIPrep ships its `from-orig_to-T1w` transform as an **ITK text transform**, but
gives the file a `.txt` or sometimes `.lta` suffix that misleads tools into
assuming it's FreeSurfer LTA. When you feed it to `mri_vol2vol`:

```
mri_vol2vol --lta sub-01_from-orig_to-T1w_mode-image_xfm.txt \
    --mov aparc+aseg.mgz --targ dwiref.nii.gz --o aparc+aseg_in_dwi.nii.gz
```

…you get either `LTA registration file needs to have .lta extension!` (if the
suffix is wrong) or `LTA ... has no valid src geometry!` (if you rename — because
the file isn't LTA at all).

The right tool is **ANTs `antsApplyTransforms`**, which understands ITK natively:

```
antsApplyTransforms \
    -i aparc+aseg.nii.gz \
    -r dwiref.nii.gz \
    -t sub-01_from-orig_to-T1w_mode-image_xfm.txt \
    -n GenericLabel \
    -o aparc+aseg_in_dwi.nii.gz
```

`-n GenericLabel` is critical: it does nearest-label resampling so integer parcel
codes survive intact (no fractional voxels at boundaries). `qsirecon.sif`
already ships ANTs, so the DK rule stays in a single container.

After resampling, the rule runs MRtrix3's `labelconvert` to renumber from the
1000s/2000s of FreeSurfer's color LUT to the 1..84 sequential DK index space,
then `tck2connectome` with the streamline file.

### Tractogram gunzipping

QSIRecon writes tractograms as `*.tck.gz`. MRtrix 3.0.4 inside `qsirecon.sif`
does **not** transparently decompress them and will reject the file with
`tckinfo: ... is not a valid track file`. The DK rule handles this by
gunzipping to `<output_dir>/tracks.tck` on the fly and removing the temp file
afterwards.

### Diagnostics

Every DK run emits two text dumps that prove the parcellation and streamlines
actually live in the same coordinate frame:

* `dk_nodes.mrinfo.txt` — `mrinfo` of the resampled, relabeled node image
* `tracks.tckinfo.txt`  — `tckinfo` of the tractogram

Compare the voxel grid, transform, and bounding box if a downstream tool
complains.

---

## Slurm tuning

`./connectome start` (on a Slurm host) submits a tiny driver job
(`submit_snakemake.sh`, 1 CPU / 4 GB / 12 h) that fans out one `sbatch` per rule
instance via `snakemake-executor-plugin-slurm`.

Resources per rule come from two places, merged by Snakemake:

* `config/config.yaml` — `threads.<stage>`, `resources.<stage>.{mem_mb, runtime, slurm_partition}`
* `profiles/slurm/config.yaml` — defaults + `set-threads:` / `set-resources:` overrides

Defaults shipped in this repo (tuned for ~2 mm DWI with ~10M streamlines):

| stage | threads | mem_mb | runtime (min) |
|---|---:|---:|---:|
| qsiprep | 4 | 24 000 | 700 |
| recon | 4 | 16 000 | 720 |
| qsirecon | 4 | 24 000 | 700 |
| dk | 2 | 8 000 | 30 |

To target a specific partition, add `slurm_partition` to each `resources:` entry
(or to `default-resources:` in `profiles/slurm/config.yaml`). To exclude broken
nodes globally, set `slurm.exclude_nodes: "node01,node02"` (gets translated into
an `--exclude=` Slurm flag).

### Restartability

The Slurm profile sets `restart-times: 1` — Snakemake auto-resubmits any rule
that exits non-zero **once**. Useful for transient I/O and node reboots.

### `--rerun-incomplete` is intentionally off by default

If a previous driver was `scancel`'d while a child rule was running, Snakemake
records the rule as "incomplete". Starting the next driver with
`--rerun-incomplete` then **deletes the sentinel and re-runs that rule from
scratch** — including expensive ones like `qsiprep`. Don't pass
`--rerun-incomplete` unless you actually want that. See the comment block
inside `submit_snakemake.sh` for details and the safe `--touch` workaround.

---

## Manual Snakemake usage

The `./connectome` CLI is a convenience wrapper. You can drive Snakemake directly:

```bash
# Dry-run + DAG inspection
snakemake --configfile config/config.yaml -n -r
snakemake --configfile config/config.yaml --dag | dot -Tsvg > dag.svg

# Local run, 8 cores
snakemake --configfile config/config.yaml -j 8

# Slurm run
sbatch submit_snakemake.sh --configfile config/config.yaml

# Generate report.html after a run
snakemake --configfile config/config.yaml --report report.html
```

A `Makefile` is also shipped with shortcuts: `make help`.

---

## Re-running, selective targets, partial re-execution

```bash
# Run only one stage across all subjects
snakemake --configfile config/config.yaml qsiprep_all
snakemake --configfile config/config.yaml recon_all
snakemake --configfile config/config.yaml qsirecon_all
snakemake --configfile config/config.yaml dk_all

# Force a specific rule to re-run
snakemake --configfile config/config.yaml --forcerun dk_connectome

# Re-run for a single subject
snakemake --configfile config/config.yaml results/dk_connectomes/sub-001/dk_connectome.csv

# Stop after a stage
snakemake --configfile config/config.yaml --until qsiprep
```

Snakemake won't re-execute any job whose output is newer than its inputs.

### Pass-through to snakemake via the CLI

```bash
./connectome start -- --forcerun recon --until qsirecon --rerun-incomplete
```

Everything after the `--` separator is appended verbatim to the underlying
`snakemake` invocation.

---

## Citing

This workflow only orchestrates other people's tools. Please cite them:

* **QSIPrep**: Cieslak M. et al. *QSIPrep: an integrative platform for preprocessing and reconstructing diffusion MRI data.* Nature Methods, 2021.
* **QSIRecon**: Cieslak M. et al. *QSIRecon: an integrative platform for reconstructing diffusion-weighted MRI data.* (see docs)
* **FreeSurfer**: Fischl B. *FreeSurfer.* NeuroImage, 2012.
* **FastSurfer** (if used): Henschel L. et al. *FastSurfer.* NeuroImage, 2020.
* **MRtrix3**: Tournier J-D. et al. *MRtrix3: A fast, flexible and open software framework for medical image processing and visualisation.* NeuroImage, 2019.
* **ANTs**: Avants B. et al. *Advanced Normalization Tools (ANTS).* Insight Journal, 2009.
* **Snakemake**: Mölder F. et al. *Sustainable data analysis with Snakemake.* F1000Research, 2021.

A [`CITATION.cff`](CITATION.cff) is provided if you want to cite this pipeline specifically.

---

## Troubleshooting

| symptom | likely fix |
|---|---|
| `WorkflowError: No subjects found` | populate `config/subjects.tsv` or set `subjects:` in your config; `./connectome install --bids /path/to/BIDS --no-deps --no-containers` regenerates the TSV |
| `MissingInputException` on recon's `aparc+aseg.mgz` | set `run_recon: true`, or point `freesurfer/sub-XXX/` at an existing recon dir |
| QSIRecon HSVS aborts with `mount source ... doesn't exist` | recon hasn't produced `freesurfer/sub-XXX/` — check that stage first (`./connectome check`) |
| DK warning `dwiref/xfm not found; falling back to FS conformed space` | QSIPrep didn't write `*space-T1w_dwiref.nii.gz` for this subject; inspect QSIPrep outputs |
| `recon-all` dies ~30 min in with `cannot find .../RB_all_withskull_2020_01_02.gca` | `containers.freesurfer` is pointing at a *trimmed* FreeSurfer (e.g. the one baked into a FastSurfer image); switch to the dedicated `freesurfer_7.4.1.sif` |
| `DK: missing FreeSurferColorLUT.txt` | set `fs_lut:` in config to your host-side `FreeSurferColorLUT.txt` |
| `tckinfo: ... is not a valid track file` | MRtrix 3.0.4 can't read `.tck.gz` directly; the DK rule already handles this — make sure your local copy is up to date |
| `LockException` on restart | a previous driver was killed while holding `.snakemake/locks/`; run `snakemake --unlock` from the repo root |
| Need to wipe Snakemake metadata only (keep outputs) | `rm -rf .snakemake` (or `make clean`) |
| `pip install` snakemake fails on a managed Python | rerun with `./connectome install --user` to install into `~/.local`, or activate a venv/conda env first |
| Slurm driver stays `PENDING` for hours | low fairshare on your default partition; either swap to an `interactive` partition (set `slurm_partition` in `config/config.yaml`) or shrink per-stage resources |
