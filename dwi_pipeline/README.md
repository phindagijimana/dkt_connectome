# dwi_pipeline — QSIPrep → Inpaint → Recon → QSIRecon → connectome → node strength

Full **anatomically constrained tractography** pipeline with a post-hoc anatomical connectome step,
plus a node-strength / ENIGMA-style clinical report generated from that connectome.

Subjects with a manually-traced lesion mask (`*_T1w_label-lesion_roi.nii.gz`) get an
extra Step 1.5 that fills the lesion on the T1w with a diffusion model
([neuroLIT](containers/lit/README.md)) before FreeSurfer/FastSurfer ever sees it — see
[Inpaint (Step 1.5)](#inpaint-step-15) below. Every other subject is unaffected: no mask,
no Step 1.5, exactly the pipeline that existed before this feature.

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
| 1.5 | `inpaint` | `lit_0.6.0.sif` (neuroLIT/DDPM) — **auto, only if a lesion mask exists** | Lesion-filled T1w, QC report |
| 2 | `recon` | FreeSurfer / FastSurfer | `aparc+aseg.mgz`, surfaces |
| 3 | `qsirecon` | QSIRecon (SS3T + ACT-HSVS) | Tractogram (~10M streamlines), optional 4S156 atlas connectome |
| 4 | `connectome` | `dkt_connectome.sif` (FreeSurfer + ANTs + MRtrix3) | `dkt_connectome.csv` (78×78) |
| 5 | `nodestrength` | `nodestrength_0.1.0.sif` ([dwi-AI](https://github.com/phindagijimana/dwi-AI)) — **auto, whenever a connectome exists** | Node strength/AI CSVs, ENIGMA figures, `report.pdf` |

`bash subject.sh all SUBJECT` runs steps 1–5 sequentially (1.5 runs inside Step 2 whenever
a lesion mask is found for that subject/session; 5 runs inside Step 4 whenever a connectome
was produced).

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

## Inpaint (Step 1.5)

Runs [neuroLIT](containers/lit/README.md) (a DDPM lesion-inpainting model) on the
subject's T1w before Step 2, so a manually-traced lesion doesn't throw off
recon-all/FastSurfer's atlas-based skull-strip, Talairach registration, or cortical
parcellation. It is **auto-on but conditional**: it only actually runs when a sibling
`*_T1w_label-lesion_roi.nii.gz` exists next to the T1w for the target session; for every
other subject it's a silent no-op.

```bash
# Runs automatically as part of Step 2 when sub-01/ses-2WK has a lesion mask:
bash dwi_pipeline/subject.sh all 01

# Run/test Step 1.5 in isolation:
bash dwi_pipeline/subject.sh inpaint 01

# Force-skip even if a mask exists:
bash dwi_pipeline/subject.sh all 01 --no-inpaint
```

Pipeline: `scripts/prepare_lesion_mask.py` (resample onto the T1w grid, select
labels, optionally binarize, record provenance) → `lit-inpainting` inside
`CONTAINER_LIT` with `--keepgeom` (so the result stays on the T1w's native
grid) → `scripts/check_inpainting.py` (QC: correlation outside the lesion vs.
a resampling-only control). Writes
`${INPAINT_OUT}/sub-XXX/ses-YYY/{lesion_mask_prepared.nii.gz, inpainting_volumes/inpainting_result.nii.gz, inpainting.json}`.
Steps 2 and 4 then use `inpainting_result.nii.gz` in place of the raw BIDS T1w
for that subject/session.

Build the container once: `bash dwi_pipeline/containers/lit/build_lit.sh`.

See `subject.sh`'s header (Environment section) for the full `INPAINT_*` variable list,
and [`pipeline_science.md` §Inpaint](pipeline_science.md) for the science (DDPM, VINN
layers, QC methodology).

---

## Node strength / ENIGMA report (Step 5)

Runs the standalone [`nodestrength`](https://github.com/phindagijimana/dwi-AI) container
against the Step 4 connectome to compute node strength, interhemispheric asymmetry index
(AI), and volume AI, then render an ENIGMA-style report. It is **not part of this repo** —
it lives in its own repo/container and is invoked, not built, from here.

```bash
# Runs automatically as part of Step 4:
bash dwi_pipeline/subject.sh all 01

# Run/rerun Step 5 in isolation (needs an existing connectome):
bash dwi_pipeline/subject.sh nodestrength 01

# Skip Step 5 only (keep the connectome):
bash dwi_pipeline/subject.sh all 01 --no-node-strength
```

Atlas-agnostic: auto-detects 78-node DKT vs. 84-node DK from the connectome's own shape,
so it works unmodified whether Step 4 ran with the pipeline default (DKT) or
`CONNECTOME_PARCELLATION=dk`. Cortical asymmetry is rendered on the standard ENIGMA
DK-based fsaverage5 surface regardless of which atlas the numbers came from.

Bind-mounts `CONNECTOME_OUT` (read-only, `--include SUBJECT` so a shared `connectomes/`
tree used by many subjects is safe) and `FS_SUBJECTS_DIR` (read-only, for per-node
volumes from `nodes.mif`), and writes to `NODESTRENGTH_OUT`
(default `${RESULTS_ROOT}/node_strength`) — a cohort-level directory shared across
subjects, not a per-subject one, since the container itself groups output by
`--include`. Default run computes strength + volume + compare + a one-page `report.pdf`
with figures; `--strength-only` / `--no-report` (or `NODESTRENGTH_STRENGTH_ONLY=1` /
`NODESTRENGTH_NO_REPORT=1`) thin that out.

See [`node_strength/README.md`](/path/to/node_strength/README.md)
and [`node_strength/containers/README.md`](/path/to/node_strength/containers/README.md)
for the full CLI, output layout, and the underlying Piper et al. 2026 methodology.

---

## Defaults

| Setting | Default |
|---------|---------|
| `BIDS_DIR` | your BIDS dataset root |
| `RESULTS_ROOT` | your output directory |
| `QSIRECON_SPEC` | `mrtrix_singleshell_ss3t_ACT-hsvs` |
| `QSIRECON_ATLASES` | `4S156Parcels` |
| `RECON_TOOL` | `freesurfer` (`recon-all -all`) |
| `RECON_FSAPARC` | `0` (`--fast-fs` sets this to `1`, adds a DK-68 atlas on top of FastSurfer's DKT) |
| `RUN_INPAINT` | `1` (auto: only runs when a lesion mask is found) |
| `RUN_CONNECTOME` | `1` |
| `RUN_NODESTRENGTH` | `1` (auto: runs whenever Step 4 produced a connectome) |
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
| `--fast-fs` | FastSurfer + `--fsaparc` (adds a classic DK-68 aparc/ribbon alongside FastSurfer's native DKT) |
| `--no-recon` | Skip Step 2 (requires ACT-fast spec or existing FS dir) |
| `--no-connectome` | Skip Step 4 (`--no-dk` still accepted; skips Step 5 too) |
| `--inpaint` / `--no-inpaint` | Force Step 1.5 on/off (default: auto — on only if a lesion mask exists) |
| `--node-strength` / `--no-node-strength` | Force Step 5 on/off (default: auto — on whenever Step 4 ran) |
| `--strength-only` | Step 5: skip `volume/` and `compare/` |
| `--no-report` | Step 5: skip `reports/` (PDF + figures) |

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
| **Inpaint (Step 1.5)** | More than one lesion mask for a subject/session **fails**; QC failure **warns** by default, `INPAINT_FAIL_ON_QC=1` to fail instead; missing/no mask is **not** a failure (silent skip) unless `INPAINT_REQUIRE_MASK=1` |
| **Node strength (Step 5)** | Missing connectome CSV or missing `CONTAINER_NODESTRENGTH` **fails**; container exiting without writing `manifest.json` **fails** |

---

## Containers and paths

| Variable | Default path |
|----------|--------------|
| `CONTAINER_QSIPREP` | `.../others/containers/qsiprep.sif` |
| `CONTAINER_QSIRECON` | `.../others/containers/qsirecon.sif` |
| `CONTAINER_CONNECTOME` | `.../others/containers/dkt_connectome.sif` |
| `CONTAINER_FREESURFER` | `.../others/containers/freesurfer_7.4.1.sif` |
| `CONTAINER_FASTSURFER` | `.../others/containers/fastsurfer_latest.sif` |
| `CONTAINER_LIT` | `.../others/containers/lit_0.6.0.sif` (only required if a lesion mask is found) |
| `CONTAINER_NODESTRENGTH` | `.../node_strength/containers/nodestrength_0.1.0.sif` — standalone repo, not built by this pipeline |
| `FS_LICENSE` | `.../others/data_mining/freesurfer/license.txt` |
| `TEMPLATEFLOW_HOME` | `templateflow/` in the repo root |

Pull FreeSurfer SIF: `sbatch dwi_pipeline/containers/pull_freesurfer_sif.sbatch`

Build the Step 4 SIF (~150 MB legacy-staged image):

```bash
bash dwi_pipeline/containers/connectome/build_connectome.sh
# Stages minimal FS + ANTs/MRtrix from qsirecon.sif; see containers/connectome/README.md
```

Legacy dual-container Step 4 (pre-containerization): `CONNECTOME_LEGACY_DUAL_CONTAINER=1`.

Build the Step 1.5 SIF (straight Docker Hub pull, no custom layers):

```bash
bash dwi_pipeline/containers/lit/build_lit.sh
# See containers/lit/README.md
```

Get the Step 5 SIF — this is a separate repo
(`/path/to/node_strength`), build or pull it there:

```bash
bash /path/to/node_strength/containers/build.sh
# or: apptainer pull nodestrength_0.1.0.sif oras://index.docker.io/phindagijimana321/nodestrength:0.1.0
```

---

## Output layout

Under `${RESULTS_ROOT}/`:

```
inpainted/sub-XXX/ses-YYY/   (only for subjects with a lesion mask)
qsiprep_single_run_output/
freesurfer/sub-XXX/
qsirecon_single_run_output/
connectomes/sub-XXX/
node_strength/               (strength/, volume/, compare/, reports/sub-XXX/, manifest.json — cohort-shared)
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

| Pipeline | Step 4 | Connectome produced | Step 5 |
|----------|--------|---------------------|--------|
| `dwi_pipeline` (this launcher) | on | `dkt_connectome.csv`, subject-native DKT, 78 nodes | on (needs Step 4) |
| `dwi_connect_default` (`RUN_CONNECTOME=0`) | off | QSIRecon atlas connectome only (4S156) | off (no Step 4 connectome to read) |

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
| `scripts/prepare_lesion_mask.py` | Step 1.5: resample/select-labels/binarize a lesion mask + provenance |
| `scripts/check_inpainting.py` | Step 1.5 QC: correlation outside the lesion vs. a resampling-only control |
| `containers/connectome/` | Step 4 container (Dockerfile, build script, entrypoint) |
| `containers/lit/` | Step 1.5 container (`build_lit.sh` pulls `deepmi/lit` from Docker Hub) |
| `config/dwi_select_b1000.json` | Default b1000 + IntendedFor fmaps |
| `reports/scripts/` | Per-subject visualization scripts (connectome, morphometry, imaging, ENIGMA 3D) |
| [`node_strength/`](/path/to/node_strength) | Step 5 — separate repo/container (`nodestrength`, aka `dwi-AI`); node strength, AI, ENIGMA figures, `report.pdf` |

---

## Further reading

- [`DWI_Connectivity_Pipeline_Documentation.md`](../DWI_Connectivity_Pipeline_Documentation.md) — step-by-step technical reference (warp chain, QC)
- [`pipeline_science.md`](pipeline_science.md) — the science behind each step
- [`acquisition.md`](acquisition.md) — how the images are acquired, and why they need the corrections this pipeline applies
- [`brain.md`](brain.md) — brain anatomy, physiology and pathology for pipeline engineers
- [`bids.md`](../bids.md) — phase-encoding metadata and dwi-select
- [`fmaps.md`](../fmaps.md) — SDC behavior
