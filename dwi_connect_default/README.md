# dwi_connect_default

Default **atlas-based connectome** pipeline: **QSIPrep → FreeSurfer → QSIRecon** with anatomically constrained tractography (ACT) using FreeSurfer tissue models (HSVS/5TT).

Connectome matrices are produced **inside QSIRecon** via `--atlases` (default: **4S156Parcels**). This pipeline does **not** run the post-hoc Desikan–Killiany (DK) step. For DK connectomes, use [`dwi_pipeline/`](../dwi_pipeline/).

## Stages

| Step | Tool | Purpose |
|------|------|---------|
| 1 | QSIPrep | DWI preprocessing, SDC, registration to T1w |
| 2 | FreeSurfer (`recon-all -all`) | Surfaces, `aparc+aseg.mgz`, HSVS inputs |
| 3 | QSIRecon | SS3T CSD + ACT tractography + **atlas connectome** |

QSIPrep and FreeSurfer both read from BIDS and can be run in parallel in principle; `subject.sh all` runs them sequentially (QSIPrep first, then recon).

## Defaults

| Setting | Value |
|---------|-------|
| `QSIRECON_SPEC` | `mrtrix_singleshell_ss3t_ACT-hsvs` |
| `QSIRECON_ATLASES` | `4S156Parcels` (156 regions: Schaefer-100 cortex + 56 subcortex/brainstem) |
| `RECON_TOOL` | `freesurfer` (`recon-all -all`) |
| `RUN_DK_CONNECTOME` | `0` (off) |
| `RESULTS_ROOT` | `.../CIDUR_BIDS/dwi_test_default` |

## Outputs

Under `${RESULTS_ROOT}/`:

```
qsiprep_single_run_output/     # preprocessed DWI, transforms, dwiref
freesurfer/sub-XXX/            # FreeSurfer subject dir (aparc+aseg, surfaces)
qsirecon_single_run_output/    # tractography + atlas connectome
```

Primary connectome files (per session, names vary slightly):

- `*_space-T1w_connectivity.mat` — streamline-count matrix for the requested atlas
- `*_space-T1w_model-ifod2_streamlines.tck.gz` — ACT tractogram (~10M streamlines)

Atlas parcellation images live under `qsirecon_single_run_output/` (e.g. `*4S156*` label maps).

## Run

### Slurm array (cohort)

```bash
cd /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/TrackTBI-Sub
./dwi_connect_default/submit.sh
```

### Single subject (interactive)

```bash
bash dwi_connect_default/subject.sh all 001
```

### Per-stage

```bash
bash dwi_connect_default/subject.sh qsiprep 001
bash dwi_connect_default/subject.sh recon 001
bash dwi_connect_default/subject.sh qsirecon 001
```

### Common options

```bash
./dwi_connect_default/submit.sh --fastsurfer    # FastSurfer instead of recon-all
./dwi_connect_default/submit.sh --syn           # SyN SDC when no fieldmaps
QSIRECON_ATLASES="4S156Parcels AAL116" ./dwi_connect_default/submit.sh
RESULTS_ROOT=/path/to/my_run ./dwi_connect_default/submit.sh
```

## Requirements

- BIDS dataset with DWI (+ T1w for recon)
- Apptainer images: `qsiprep.sif`, `qsirecon.sif`, `freesurfer_7.4.1.sif`
- FreeSurfer license + TemplateFlow cache

See [`dwi_pipeline/README.md`](../dwi_pipeline/README.md) for container paths, SDC behaviour, and FreeSurfer image build instructions.

## Relationship to dwi_pipeline

`dwi_connect_default` is a thin wrapper around [`dwi_pipeline/subject.sh`](../dwi_pipeline/subject.sh) with atlas-connectome defaults and DK disabled. Bug fixes and container logic live in `dwi_pipeline/`; this folder only sets environment and submission defaults.
