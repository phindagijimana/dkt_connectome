# Preprocessing inputs

Steps to run **before** `./run` or `subject.sh` when BIDS sidecars are incomplete or fieldmaps are missing.

---

## BIDS sidecar repair

QSIPrep / eddy / TOPUP require phase-encoding metadata on DWI and fmap JSON sidecars:

- `PhaseEncodingDirection`
- `TotalReadoutTime`
- `EffectiveEchoSpacing`
- `BandwidthPerPixelPhaseEncode`

If dcm2niix omitted these fields (common on some Siemens exports):

```bash
python3 dwi_pipeline/scripts/repair_siemens_pe_metadata.py --help
./dwi_pipeline/scripts/run_bids_repair.sh BIDS_DIR SUBJECT
```

Reference: [bids.md](https://github.com/phindagijimana/dkt_connectome/blob/main/bids.md) · Repair script: [`scripts/repair_siemens_pe_metadata.py`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/scripts/repair_siemens_pe_metadata.py).

---

## Field maps and SDC

| Situation | Pipeline behavior |
|-----------|-------------------|
| fmap in dwi-select filter + `IntendedFor` | TOPUP / fieldmap SDC (preferred) |
| No fmap in filter | **Must** pass `--syn`, `--fmap-retry`, or `--no-sdc` |
| `--syn` | SyN distortion correction |
| `--no-sdc` | Skip SDC (legacy compatibility) |

Details: [fmaps.md](https://github.com/phindagijimana/dkt_connectome/blob/main/fmaps.md).

---

## dwi-select (default b=1000 shell)

By default the pipeline filters to **b=1000** DWI and associated fieldmaps via `config/dwi_select_b1000.json`.

| Flag | Effect |
|------|--------|
| *(default)* | b=1000 + IntendedFor fmaps |
| `--no-dwi-filter` | All DWI series |
| `--dwi-shell N` | Use `dwi_select_bN.json` |
| `--dwi-select PATH` | Custom filter JSON |

Build filter JSON:

```bash
python3 dwi_pipeline/scripts/build_bids_filter.py --help
```

---

## Multi-session subjects

When multiple sessions contain DWI, specify one session per run:

```bash
./run BIDS OUT participant --participant-label 009 --session-filter ses-1
```

The pipeline selects the session-matched tractogram and T1w for connectome building.

---

## Verify before submit

1. Repair sidecars if QSIPrep previously failed with `KeyError: 'TotalReadoutTime'`
2. Confirm fmap `IntendedFor` matches the DWI series you intend to process
3. **Optional:** validate BIDS layout:

```bash
bash dwi_pipeline/scripts/run_bids_validator.sh /path/to/BIDS
# or via BIDS App:
./run BIDS OUT participant --participant-label 009 --bids-validation --dry-run
```

4. Dry-run: `./run BIDS OUT participant --participant-label 009 --dry-run`

See [Derivatives policy](derivatives.md) for output layout vs BIDS Derivatives spec.
