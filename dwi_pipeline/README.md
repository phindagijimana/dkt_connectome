# dwi_pipeline — QSIPrep → Recon → QSIRecon → DK connectome

Full **anatomically constrained tractography** pipeline with a post-hoc **Desikan–Killiany (DK)** connectome step.

For **atlas-only** connectomes (4S156 in QSIRecon, no DK), use [`dwi_connect_default/`](../dwi_connect_default/) → `RESULTS_ROOT=.../dwi_test_default`.

For **TrackTBI + DK**, use `RESULTS_ROOT=.../dwi_test_TBI` (see [`CIDUR_BIDS/dwi_test_TBI/README.md`](../CIDUR_BIDS/dwi_test_TBI/README.md)).

---

## Stages

| Step | Script mode | Tool | Output |
|------|-------------|------|--------|
| 1 | `qsiprep` | QSIPrep | Preprocessed DWI, `dwiref`, transforms |
| 2 | `recon` | FreeSurfer / FastSurfer | `aparc+aseg.mgz`, surfaces |
| 3 | `qsirecon` | QSIRecon (SS3T + ACT-HSVS) | Tractogram (~10M streamlines), optional 4S156 atlas connectome |
| 4 | `dk` | `dk_connectome.sif` (FreeSurfer + ANTs + MRtrix3) | `dk_connectome.csv` (84×84) |

`bash subject.sh all SUBJECT` runs steps 1–4 sequentially.

---

## Quick start

```bash
cd /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub

# TrackTBI example (full DK pipeline)
export RESULTS_ROOT=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/dwi_test_TBI
export BIDS_DIR=/mnt/nfs/home/URMC-SH/pndagiji/Documents/TrackTBI/phase2_test_bids

bash dwi_pipeline/subject.sh all TBI011204
```

Slurm array:

```bash
export RESULTS_ROOT=.../dwi_test_TBI
export BIDS_DIR=.../phase2_test_bids
export SUBJECT_LIST_FILE=dwi_pipeline/subjects_tbi011204_test.txt
./dwi_pipeline/submit.sh
```

---

## Defaults

| Setting | Default |
|---------|---------|
| `BIDS_DIR` | `.../CIDUR_BIDS/data_bids` |
| `RESULTS_ROOT` | `.../CIDUR_BIDS/dwi_test` |
| `QSIRECON_SPEC` | `mrtrix_singleshell_ss3t_ACT-hsvs` |
| `QSIRECON_ATLASES` | `4S156Parcels` |
| `RECON_TOOL` | `freesurfer` (`recon-all -all`) |
| `RUN_DK_CONNECTOME` | `1` |
| dwi-select | **ON** — `config/dwi_select_b1000.json` (b=1000 + IntendedFor fmaps) |

---

## CLI flags (`subject.sh` / `submit.sh`)

| Flag | Effect |
|------|--------|
| `--dwi-shell N` | Use `dwi_select_bN.json` (default 1000) |
| `--no-dwi-filter` | Process all DWI/fmaps (legacy) |
| `--dwi-select PATH` | Explicit dwi-select JSON |
| `--syn` | SyN SDC when no fmap in filter |
| `--fmap-retry` | Ignore fieldmaps, SyN SDC |
| `--fastsurfer` | FastSurfer instead of recon-all |
| `--no-recon` | Skip Step 2 (requires ACT-fast spec or existing FS dir) |
| `--no-dk` | Skip Step 4 |

---

## Strict fail-fast behavior

The pipeline avoids silent fallbacks. Failures print `ERROR [label]: ...` and exit non-zero.

| Area | Behavior |
|------|----------|
| **FreeSurfer container** | Requires `freesurfer_7.4.1.sif`; **no** fallback to FastSurfer's trimmed FS |
| **SDC** | Measured when fmap in dwi-select filter; else **must** pass `--syn` or `--fmap-retry` |
| **Recon** | If `aparc+aseg.mgz` exists, **fail** unless `RECON_SKIP_IF_EXISTS=1` |
| **DK inputs** | Exactly one tractogram, dwiref, desc-preproc T1w, BIDS T1w (session-coherent) |
| **DK space** | `DK_RESAMPLE_TO_DWI=1` required; no FS-conformed-space shortcut |
| **dwi-select** | No `same_session` fmap fallback; `on_no_match: error` |
| **QSIRecon + `--no-recon`** | Fails if HSVS spec and no FreeSurfer subjects dir |

---

## Containers and paths

| Variable | Default path |
|----------|--------------|
| `CONTAINER_QSIPREP` | `.../others/containers/qsiprep.sif` |
| `CONTAINER_QSIRECON` | `.../others/containers/qsirecon.sif` |
| `CONTAINER_DK_CONNECTOME` | `.../others/containers/dk_connectome.sif` |
| `CONTAINER_FREESURFER` | `.../others/containers/freesurfer_7.4.1.sif` |
| `CONTAINER_FASTSURFER` | `.../others/containers/fastsurfer_latest.sif` |
| `FS_LICENSE` | `.../others/data_mining/freesurfer/license.txt` |
| `TEMPLATEFLOW_HOME` | `TrackTBI-Sub/templateflow` |

Pull FreeSurfer SIF: `sbatch dwi_pipeline/containers/pull_freesurfer_sif.sbatch`

Build DK connectome SIF (Step 4, ~150 MB legacy-staged image):

```bash
bash dwi_pipeline/containers/dk_connectome/build_dk_connectome.sh
# Stages minimal FS + ANTs/MRtrix from qsirecon.sif; see containers/dk_connectome/README.md
```

Legacy dual-container Step 4 (pre-containerization): `DK_LEGACY_DUAL_CONTAINER=1`.

---

## Output layout

Under `${RESULTS_ROOT}/`:

```
qsiprep_single_run_output/
freesurfer/sub-XXX/
qsirecon_single_run_output/
dk_connectomes/sub-XXX/
intermediate_results_qsiprep_single/
logs/
```

---

## BIDS preparation (run before pipeline)

1. Fix PE / TRT / `IntendedFor` sidecars — [`bids.md`](../bids.md), [`fmaps.md`](../fmaps.md)
2. Run repair: `./dwi_pipeline/scripts/run_bids_repair.sh BIDS_DIR SUBJECT`
3. Verify dwi-select filter (dry-run in `bids.md` §9)
4. Submit pipeline

Repair is **not** invoked automatically by `submit.sh`.

---

## Result folder guide

| Folder | Pipeline | DK |
|--------|----------|-----|
| `dwi_test_default` | Atlas connectome (`dwi_connect_default`, `RUN_DK=0`) | off |
| `dwi_test_TBI` | Full TrackTBI DK pipeline | on |
| `dwi_test2` | CIDUR reference cohort (NAS: `Gugger_Lab/NIR/dwi_test2`) | on |

---

## Scripts

| Path | Purpose |
|------|---------|
| `subject.sh` | One subject, one or more stages |
| `submit.sh` | Build subject list + Slurm array |
| `array.sh` | Slurm array worker (do not run directly) |
| `scripts/build_bids_filter.py` | dwi-select → QSIPrep filter JSON |
| `scripts/repair_bids_sidecars.py` | BIDS sidecar repair |
| `scripts/run_bids_repair.sh` | Repair wrapper |
| `containers/dk_connectome/` | Step 4 container (Dockerfile, build script, entrypoint) |
| `config/dwi_select_b1000.json` | Default b1000 + IntendedFor fmaps |

---

## Further reading

- [`DWI_Connectivity_Pipeline_Documentation.md`](../DWI_Connectivity_Pipeline_Documentation.md) — step-by-step technical reference (DK warp chain, QC)
- [`bids.md`](../bids.md) — phase-encoding metadata and dwi-select
- [`fmaps.md`](../fmaps.md) — SDC behavior
