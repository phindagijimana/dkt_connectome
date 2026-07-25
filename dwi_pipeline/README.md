# dwi_pipeline — QSIPrep → Recon → QSIRecon → connectome

Full **anatomically constrained tractography** pipeline with a post-hoc anatomical connectome step.

Step 4 produces a **Desikan–Killiany–Tourville (DKT, 78 nodes)** matrix by default, from either
recon tool, because DKT is the only parcellation both `recon-all` and FastSurfer can deliver.
**Desikan–Killiany (DK, 84 nodes)** is available with `CONNECTOME_PARCELLATION=dk`, but only from
`recon-all` — FastSurfer produces no DK atlas.

For **atlas-only** connectomes (4S156 in QSIRecon, no Step 4), use [`dwi_connect_default/`](../dwi_connect_default/) with its own `RESULTS_ROOT`.

Give each cohort, and each combination of settings, a separate `RESULTS_ROOT`,
so that one run cannot overwrite another's outputs.

---

## Stages

| Step | Script mode | Tool | Output |
|------|-------------|------|--------|
| 1 | `qsiprep` | QSIPrep | Preprocessed DWI, `dwiref`, transforms |
| 2 | `recon` | FreeSurfer / FastSurfer | `aparc+aseg.mgz`, surfaces |
| 3 | `qsirecon` | QSIRecon (SS3T + ACT-HSVS) | Tractogram (~10M streamlines), optional 4S156 atlas connectome |
| 4 | `connectome` | `dkt_connectome.sif` (FreeSurfer + ANTs + MRtrix3) | `dkt_connectome.csv` (78×78) |

`bash subject.sh all SUBJECT` runs steps 1–4 sequentially.

---

## Quick start

```bash
cd /path/to/repo

# Full pipeline
export RESULTS_ROOT=/path/to/results
export BIDS_DIR=/path/to/bids

bash dwi_pipeline/subject.sh all SUBJ01
```

Slurm array:

```bash
export RESULTS_ROOT=/path/to/results
export BIDS_DIR=/path/to/bids
export SUBJECT_LIST_FILE=dwi_pipeline/subjects.txt
./dwi_pipeline/submit.sh
```

---

## Defaults

| Setting | Default |
|---------|---------|
| `BIDS_DIR` | your BIDS dataset root |
| `RESULTS_ROOT` | your output directory |
| `QSIRECON_SPEC` | `mrtrix_singleshell_ss3t_ACT-hsvs` |
| `QSIRECON_ATLASES` | `4S156Parcels` |
| `RECON_TOOL` | `freesurfer` (`recon-all -all`) |
| `RUN_CONNECTOME` | `1` |
| `CONNECTOME_PARCELLATION` | `dkt` (78 nodes, same for both recon tools) |
| `CONNECTOME_DETERMINISTIC` | `1` (ITK pinned to one thread) |
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
| `--no-connectome` | Skip Step 4 (`--no-dk` still accepted) |

---

## Strict fail-fast behavior

The pipeline avoids silent fallbacks. Failures print `ERROR [label]: ...` and exit non-zero.

| Area | Behavior |
|------|----------|
| **FreeSurfer container** | Requires `freesurfer_7.4.1.sif`; **no** fallback to FastSurfer's trimmed FS |
| **SDC** | Measured when fmap in dwi-select filter; else **must** pass `--syn` or `--fmap-retry` |
| **Recon** | If `aparc+aseg.mgz` exists, **fail** unless `RECON_SKIP_IF_EXISTS=1` |
| **Step 4 inputs** | Exactly one tractogram, dwiref, desc-preproc T1w, BIDS T1w (session-coherent) |
| **Step 4 space** | `CONNECTOME_RESAMPLE_TO_DWI=1` required; no FS-conformed-space shortcut |
| **Step 4 parcellation** | DKT from `recon-all` reads `aparc.DKTatlas+aseg.mgz`; requesting DKT on a tree that lacks it **fails** rather than silently applying the DKT table to a DK image |
| **dwi-select** | No `same_session` fmap fallback; `on_no_match: error` |
| **QSIRecon + `--no-recon`** | Fails if HSVS spec and no FreeSurfer subjects dir |

---

## Containers and paths

| Variable | Default path |
|----------|--------------|
| `CONTAINER_QSIPREP` | `.../others/containers/qsiprep.sif` |
| `CONTAINER_QSIRECON` | `.../others/containers/qsirecon.sif` |
| `CONTAINER_CONNECTOME` | `.../others/containers/dkt_connectome.sif` |
| `CONTAINER_FREESURFER` | `.../others/containers/freesurfer_7.4.1.sif` |
| `CONTAINER_FASTSURFER` | `.../others/containers/fastsurfer_latest.sif` |
| `FS_LICENSE` | `.../others/data_mining/freesurfer/license.txt` |
| `TEMPLATEFLOW_HOME` | `templateflow/` in the repo root |

Pull FreeSurfer SIF: `sbatch dwi_pipeline/containers/pull_freesurfer_sif.sbatch`

Build the Step 4 SIF (~150 MB legacy-staged image):

```bash
bash dwi_pipeline/containers/connectome/build_connectome.sh
# Stages minimal FS + ANTs/MRtrix from qsirecon.sif; see containers/connectome/README.md
```

Legacy dual-container Step 4 (pre-containerization): `CONNECTOME_LEGACY_DUAL_CONTAINER=1`.

---

## Output layout

Under `${RESULTS_ROOT}/`:

```
qsiprep_single_run_output/
freesurfer/sub-XXX/
qsirecon_single_run_output/
connectomes/sub-XXX/
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

Keep one `RESULTS_ROOT` per pipeline variant, because the two write different
outputs and Step 4 is on in one and off in the other:

| Pipeline | Step 4 | Connectome produced |
|----------|--------|---------------------|
| `dwi_pipeline` (this launcher) | on | `dkt_connectome.csv`, subject-native DKT, 78 nodes |
| `dwi_connect_default` (`RUN_CONNECTOME=0`) | off | QSIRecon atlas connectome only (4S156) |

---

## Renamed in this version

Step 4 was called `dk` and its variables were prefixed `DK_`, from when it only
produced Desikan–Killiany. It now serves both atlases, so it is `connectome`
throughout. The old mode name, the `--no-dk` flag and the `DK_*` variables still
work; the variables print a deprecation note.

| Old | New |
|-----|-----|
| `subject.sh dk SUB` | `subject.sh connectome SUB` |
| `--no-dk` | `--no-connectome` |
| `CONTAINER_DK_CONNECTOME` | `CONTAINER_CONNECTOME` |
| `RUN_DK_CONNECTOME` | `RUN_CONNECTOME` |
| `DK_PARCELLATION`, `DK_DETERMINISTIC`, … | `CONNECTOME_PARCELLATION`, `CONNECTOME_DETERMINISTIC`, … |
| `dk_connectomes/` | `connectomes/` |
| `dk_nodes.mif`, `dk_assignments.csv`, `dk_parcellation.json` | `nodes.mif`, `assignments.csv`, `parcellation.json` |
| `dk_connectome.sif` | `dkt_connectome.sif` |

The **matrix filename stays parcellation-specific** — `dkt_connectome.csv` or
`dk_connectome.csv` — because 78- and 84-node results must never be pooled.

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
| `scripts/make_dkt_lut.py` | Generate the 78-node `fs_dkt.txt` from `fs_default.txt` |
| `containers/connectome/` | Step 4 container (Dockerfile, build script, entrypoint) |
| `config/dwi_select_b1000.json` | Default b1000 + IntendedFor fmaps |

---

## Further reading

- [`DWI_Connectivity_Pipeline_Documentation.md`](../DWI_Connectivity_Pipeline_Documentation.md) — step-by-step technical reference (warp chain, QC)
- [`pipeline_science.md`](pipeline_science.md) — the science behind each step
- [`bids.md`](../bids.md) — phase-encoding metadata and dwi-select
- [`fmaps.md`](../fmaps.md) — SDC behavior
