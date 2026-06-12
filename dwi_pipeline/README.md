# DWI pipeline (ACT / connectome)

Per subject, the default `all` mode runs four stages:

1. **QSIPrep** — DWI preprocessing (denoise, SDC, motion/eddy, T1w coregistration)
2. **Recon** — anatomical surface reconstruction producing a FreeSurfer subjects dir
   - Default: `recon-all -all` (FreeSurfer 7.4.1, ~6–10 h CPU)
   - Opt-in faster mode: `--fastsurfer` (~1–2 h CPU, ~20 min GPU)
3. **QSIRecon** — `mrtrix_singleshell_ss3t_ACT-hsvs` (SS3T CSD + ACT tractography, HSVS 5TT)
4. **DK connectome** — `aparc+aseg.mgz` → DWI grid → MRtrix labels → `dk_connectome.csv`

If you skip Step 2 (`--no-recon`) the pipeline auto-degrades QSIRecon to `mrtrix_singleshell_ss3t_ACT-fast` and turns DK off, because both rely on FreeSurfer outputs.

Each `.sh` file has a header and inline comments explaining what each block does.

## Flow

```
submit.sh  →  writes subjects.txt, sbatch array.sh (1-N%5)
array.sh   →  one Slurm task per line in subjects.txt; forwards CLI flags
subject.sh →  QSIPrep → Recon (FreeSurfer | FastSurfer) → QSIRecon → DK connectome
```

## Scripts

| File | Role |
|------|------|
| `submit.sh` | Build subject list, parse CLI flags, submit Slurm array |
| `array.sh` | Slurm array job (one subject per task) |
| `subject.sh` | QSIPrep + Recon + QSIRecon + DK for one subject |

Default subject list: `subjects.txt` (written by `submit.sh`).

## Run

```bash
cd /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub
./dwi_pipeline/submit.sh                  # full pipeline, recon-all (slow but standard)
./dwi_pipeline/submit.sh --fastsurfer     # full pipeline, FastSurfer (much faster)
./dwi_pipeline/submit.sh --no-recon       # skip recon, downgrade to ACT-fast (no DK)
```

## QSIPrep SDC (susceptibility distortion correction)

| BIDS `fmap/` | Default | With `--syn` |
|--------------|---------|----------------|
| present | measured fmaps (TOPUP) | measured fmaps (unchanged) |
| absent | no SyN (`--use-syn-sdc` omitted) | `--use-syn-sdc warn` |

`--fmap-retry` ignores measured fmaps and forces SyN (broken-fmap recovery).

## Recon (Step 2)

Anatomical surface reconstruction on each subject's T1w, writing a FreeSurfer-style subjects directory at `${RESULTS_ROOT}/freesurfer/sub-XXX/` (override with `RECON_OUT`).

- **Default tool — FreeSurfer `recon-all -all`** inside a dedicated full-FreeSurfer 7.4.1 SIF (`freesurfer_7.4.1.sif`), pulled from `docker://freesurfer/freesurfer:7.4.1` via `containers/pull_freesurfer_sif.sbatch`. Slow but the canonical reference. Override with `CONTAINER_FREESURFER`.
  - **Do NOT use** the FastSurfer SIF for `recon-all -all`: it ships a *trimmed* FreeSurfer that is missing `/opt/freesurfer/average/RB_all_withskull_2020_01_02.gca`, which crashes Talairach skull-strip ~30 min in (job 44563 hit exactly this). `subject.sh` now preflights the atlas file and fails fast if you point it at the wrong container.
- **Opt-in — FastSurfer** via `--fastsurfer` (or `RECON_TOOL=fastsurfer`). Same FS subjects-dir layout, much faster. Set `RECON_FASTSURFER_DEVICE=cuda` for GPU. Uses `CONTAINER_FASTSURFER` (the FastSurfer SIF).
- **Idempotent** — skips automatically when `${RECON_OUT}/sub-XXX/mri/aparc+aseg.mgz` already exists. Delete the subject directory to force a rerun.
- Tools preflighted: `recon-all` + the skull-strip atlas (for FreeSurfer), or `/fastsurfer/run_fastsurfer.sh` (for FastSurfer).

### Building the FreeSurfer container

One-shot, takes ~15–30 min on a compute node (login `/tmp` is `noexec` and the squashfs writer needs lots of RAM):

```bash
sbatch dwi_pipeline/containers/pull_freesurfer_sif.sbatch
# watch:  tail -f logs/pull_fs_<jobid>.out
# result: /mnt/nfs/.../others/containers/freesurfer_7.4.1.sif (+ .source.txt audit record)
```

A `Singularity.freesurfer-7.4.1.def` + `build_freesurfer_sif.sbatch` are also in `containers/` for fully-local reproducible builds (no Docker Hub round-trip), used only if Docker Hub is unreachable.

## DK connectome (Step 4)

Full pipeline reference with diagrams and commands: **[dk_connectome.md](dk_connectome.md)**.

After QSIRecon, `mode=all` runs a **Desikan–Killiany** post-step by default (Step 2 produced the FreeSurfer outputs it needs). Disable with `--no-dk` / `RUN_DK_CONNECTOME=0`, or point at an external FreeSurfer tree via `FS_SUBJECTS_DIR=/path/freesurfer`:

- **Input:** QSIRecon `.tck` tractogram + FreeSurfer `aparc+aseg.mgz` + `rawavg.mgz`
- **Tools:** `mri_label2vol` (full FS container), `mri_convert`, `antsApplyTransforms`, `labelconvert`, `tck2connectome`, `mrinfo`, `tckinfo`
- **Output:** `dk_connectomes/sub-XXX/dk_connectome.csv` (+ `dk_assignments.csv`, `aparc+aseg_in_rawavg.mgz`, `dk_nodes.mrinfo.txt`, `tracks.tckinfo.txt`)

### Coordinate-space alignment (important)

`aparc+aseg.mgz` lives in FreeSurfer **conformed (`orig.mgz`) space** (256³);
QSIRecon tractograms live in QSIPrep **DWI/T1w space**. QSIPrep's
`from-orig_to-T1w` xfm maps **native** T1w → QSIPrep T1w, so the pipeline
uses a two-hop warp before `labelconvert`:

1. **`mri_label2vol`** (full `freesurfer_7.4.1.sif`) — conformed → native using `--temp rawavg.mgz` ([FsAnat-to-NativeAnat](https://surfer.nmr.mgh.harvard.edu/fswiki/FsAnat-to-NativeAnat))
2. **`antsApplyTransforms -n GenericLabel`** (`qsirecon.sif`) — native → QSIPrep T1w/DWI grid using `*from-orig_to-T1w_mode-image_xfm.txt` and `*space-T1w_dwiref.nii.gz`

It also writes `mrinfo` of `dk_nodes.mif` and `tckinfo` of the tractogram into the output folder so you can confirm they share the same transform/voxel grid.

Set `DK_RESAMPLE_TO_DWI=0` to skip the resample (only safe if `mrinfo`/`tckinfo` already agree). If the xfm or DWI ref cannot be found, the pipeline prints a warning and falls back to FS conformed space — the connectome may be mis-aligned.

This is separate from QSIRecon’s built-in `--atlases` (AAL, 4S, etc.).

## Overrides

```bash
# Full pipeline with FastSurfer instead of recon-all
./dwi_pipeline/submit.sh --fastsurfer

# Atlas-based connectomes baked in by QSIRecon (in addition to DK)
QSIRECON_ATLASES="Schaefer100 AAL116" ./dwi_pipeline/submit.sh

# GE / no-fmap subjects: synthetic SDC
./dwi_pipeline/submit.sh --syn

# Single subject end-to-end
bash dwi_pipeline/subject.sh all 010 --syn --fastsurfer

# Just rerun Step 2 for one subject
bash dwi_pipeline/subject.sh recon 010 --fastsurfer

# Reuse external FreeSurfer outputs and skip Step 2
RUN_RECON=0 FS_SUBJECTS_DIR=/path/freesurfer ./dwi_pipeline/submit.sh

# DK only (Steps 1–3 already done elsewhere)
PIPELINE_MODE=dk FS_SUBJECTS_DIR=/path/freesurfer ./dwi_pipeline/submit.sh

# GPU FastSurfer
RECON_FASTSURFER_DEVICE=cuda ./dwi_pipeline/submit.sh --fastsurfer
```
