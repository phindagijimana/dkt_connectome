# Preparing your data

Input requirements and preprocessing decisions before running `./run`. Consolidates guidance from [Preprocessing inputs](preprocessing.md) and BIDS repair scripts.

---

## Minimum BIDS inputs

| Modality | Required | Notes |
|----------|----------|-------|
| `dwi/` | Yes | At least one diffusion series |
| `anat/T1w` | Yes | Structural reference for ACT tractography |
| `fmap/` | Recommended | Enables fieldmap SDC; otherwise use `--syn` |
| Lesion mask | Optional | `*_T1w_label-lesion_roi.nii.gz` triggers Steps 1.5 and 4.5 |

Validate with:

```bash
./run BIDS OUT participant --participant-label 001 --bids-validation
# or
bash scripts/run_bids_validator.sh BIDS
```

Test fixture (synthetic, public): `tests/fixtures/bids_minimal/`.

---

## BIDS sidecar repair (Siemens)

QSIPrep requires phase-encoding metadata on DWI and fmap JSON sidecars:

- `PhaseEncodingDirection`
- `TotalReadoutTime` / `EffectiveEchoSpacing`

If dcm2niix omitted these fields:

```bash
python3 scripts/repair_siemens_pe_metadata.py --help
bash scripts/run_bids_repair.sh BIDS_DIR SUBJECT
```

Reference: [bids.md](https://github.com/phindagijimana/dkt_connectome/blob/main/bids.md) (repo root).

---

## DWI series selection (dwi-select)

By default the pipeline filters to the **b=1000** shell and pairs IntendedFor fieldmaps:

```bash
./run BIDS OUT participant --participant-label 001 --dwi-shell 1000
```

Custom filter:

```bash
./run BIDS OUT participant --participant-label 001 \
  --dwi-select config/dwi_select_cidur_50dirax.json
```

Disable filtering (all DWI series):

```bash
./run BIDS OUT participant --participant-label 001 --no-dwi-filter
```

---

## SDC decision tree

```text
Fieldmap in dwi-select filter with IntendedFor?
  ├─ YES → TOPUP / fieldmap SDC (preferred)
  └─ NO  → Must pass one of:
            --syn          SyN synthetic SDC (recommended for GE / no fmap)
            --fmap-retry   Ignore bad fmaps, force SyN
            --no-sdc       Skip SDC (legacy CIDUR compatibility only)
```

Details: [fmaps.md](https://github.com/phindagijimana/dkt_connectome/blob/main/fmaps.md).

---

## Lesion masks (TBI / CIDUR)

Place next to session T1w:

```text
sub-<ID>/ses-<Y>/anat/
  sub-<ID>_ses-<Y>_T1w.nii.gz
  sub-<ID>_ses-<Y>_T1w_label-lesion_roi.nii.gz
```

| Label | Meaning |
|-------|---------|
| 0 | Background |
| 1 | Core |
| 2 | Oedema |

See [Lesion segmentation](lesion_segmentation.md).

---

## Multi-session subjects

Specify exactly one session per `./run` invocation:

```bash
./run BIDS OUT participant --participant-label 001 --session-id ses-1
```

Run separate jobs for each session.

---

## FreeSurfer license

```bash
export FS_LICENSE=/path/to/license.txt
```

Obtain a free license at [FreeSurfer registration](https://surfer.nmr.mgh.harvard.edu/registration.html).

---

## Containers

Configure `.sif` paths before first run — see [Installation](installation.md) and [Containers](containers.md).

---

## See also

- [Usage](usage.md) — all CLI flags
- [Pipeline steps](pipeline_steps.md) — internal workflow
- [Troubleshooting](troubleshooting.md)
