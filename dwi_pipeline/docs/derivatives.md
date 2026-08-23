# Derivatives layout and BIDS compliance

## Policy

The pipeline uses **two layouts**:

| Layout | Path | Purpose |
|--------|------|---------|
| **Internal (live)** | `RESULTS_ROOT/` custom tree | HPC resume, multi-container orchestration |
| **BIDS Derivatives export** | `RESULTS_ROOT/derivatives/` | Sharing, OpenNeuro upload, spec-aligned mirror |

The internal layout remains the default write target during processing. A post-run **export** builds a BIDS Derivatives mirror without moving or breaking existing paths.

---

## Internal layout (live pipeline)

| Directory | Step | Notes |
|-----------|------|-------|
| `qsiprep_single_run_output/` | 1 | QSIPrep default output |
| `inpainted/` | 1.5 | Lesion inpainting |
| `freesurfer/` | 2 | FreeSurfer / FastSurfer |
| `qsirecon_single_run_output/` | 3 | QSIRecon |
| `connectomes/` | 4 + 4.5 | DKT connectome + disconnectome |
| `qc/` | QC | Unified subject dashboards |
| `node_strength/` | 5 | Node strength / ENIGMA report |

Root provenance: `RESULTS_ROOT/dataset_description.json` (written by `./run`).

---

## BIDS Derivatives export

```bash
# Automatic on group runs (default)
./run BIDS OUT group

# Manual export
python3 dwi_pipeline/scripts/export_bids_derivatives.py --results-root OUT

# Copy instead of symlink (for upload bundles)
python3 dwi_pipeline/scripts/export_bids_derivatives.py --results-root OUT --copy

# Participant run with export
./run BIDS OUT participant --participant-label 009 --export-bids-derivatives
```

Export tree:

```text
RESULTS_ROOT/derivatives/
├── dataset_description.json
├── export_manifest.json
├── qsiprep/sub-<ID>/ses-<Y>/...
├── qsirecon/sub-<ID>/...
├── dkt-inpaint/sub-<ID>/ses-<Y>/...
├── dkt-connectome/sub-<ID>/connectome/ + disconnectome/
├── dkt-qc/sub-<ID>/subject_qc.html
└── dkt-nodestrength/reports/sub-<ID>/...
```

Each pipeline subfolder includes its own `dataset_description.json`. Links are **symlinks** by default (space-efficient on NAS); use `--copy` for portable archives.

Configuration (`config.yaml`):

```yaml
derivatives:
  export_enabled: true
  export_dir: null      # default RESULTS_ROOT/derivatives
  export_copy: false
```

---

## Container pins

Pin Apptainer images in `workflow/config/config.local.yaml` (see `container_pins` in `config.yaml`):

| Step | Reference image |
|------|-----------------|
| QSIPrep | `pennlinc/qsiprep:1.0.0` |
| QSIRecon | `pennlinc/qsirecon:1.2.1` |
| FreeSurfer | `freesurfer/freesurfer:7.4.1` |
| Connectome | `ghcr.io/phindagijimana/dk-connectome:0.1.0` |
| LIT | `deepmi/lit:0.6.0` |

Record exact `.sif` paths and digests in your methods section.

---

## Hosted documentation

Read the Docs builds from [`.readthedocs.yaml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.readthedocs.yaml) and [`docs/conf.py`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/conf.py) (Sphinx + RTD theme, QSIPrep-style):

```bash
pip install -r dwi_pipeline/docs/requirements.txt
cd dwi_pipeline/docs && make html
# live preview: python -m http.server --directory _build/html
```
