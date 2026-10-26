# BIDS App status

DLSurfer ships a **working BIDS App–style entrypoint** with derivatives layout and Boutiques descriptor. It is still **short of** a single published community BIDS App image (meta-SIF is optional).

## Checklist

| Requirement | Status |
|-------------|--------|
| CLI: `bids_dir output_dir analysis_level` | **Yes** — `dlsurfer bids-app` |
| `--participant_label` | **Yes** |
| Derivatives under `output_dir/derivatives/dlsurfer/` | **Yes** — `dataset_description.json` + per-subject sidecars |
| FreeSurfer SUBJECTS_DIR | `output_dir/freesurfer/` |
| Boutiques descriptor | **Yes** — `boutiques/dlsurfer_bids_app.json` (`--bids-exec-spec`) |
| Container entrypoint | **Yes** — `containers/entrypoint_bids.sh` (+ optional `dlsurfer.def`) |
| CI fixture | **Yes** — `.github/workflows/ci.yml` + `tests/fixtures/bids_tiny` |
| `group` level | Summary JSON of completed subjects |

## Usage

```bash
dlsurfer bids-app /data/bids /data/out participant \
  --participant_label 01 --profile core --fs-license $FS_LICENSE
# add --execute to run

dlsurfer bids-app /data/bids /data/out participant --bids-exec-spec
apptainer run --nv -B $FS_LICENSE:/fs_license:ro containers/dlsurfer.sif \
  /data/bids /data/out participant --participant_label 01 --fs-license /fs_license
```

Production explicit-path API remains: `dlsurfer run --t1 … --sd … --sid …`.
