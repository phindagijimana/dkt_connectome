# Field maps and susceptibility distortion correction (SDC)

How BIDS fieldmaps feed QSIPrep, how the pipeline chooses measured vs SyN SDC, and how **dwi-select** interacts with fmap inclusion.

Part of the [DKT Connectome documentation](index.md).

**Related:**

- PE / TRT / `IntendedFor` sidecar repair: [BIDS metadata](bids_metadata.md)
- Pipeline launcher: [README](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/README.md)
- Repair scripts: [`run_bids_repair.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/scripts/run_bids_repair.sh)

---

## BIDS fieldmap cases (QSIPrep)

| Case | BIDS files | QSIPrep workflow |
|------|------------|------------------|
| **Case 2 — phasediff** | `magnitude1`, `magnitude2`, `phasediff` | GRE fieldmap → SDC via TOPUP/eddy pipeline |
| **Case 4 — PE-Polar** | `*_dir-*_epi` (blip-up / blip-down) | TOPUP on opposing PE EPI volumes |
| **None** | No usable fmap in BIDS filter | Requires `--use-syn-sdc` (opt-in) or subject fails (strict pipeline) |

QSIPrep reads **`PhaseEncodingDirection` + `TotalReadoutTime` from the target DWI JSON** (not from fmap alone). See [`bids.md`](bids_metadata.md) §2.

For **phasediff**, `EchoTime1` / `EchoTime2` must be on `phasediff.json`. `IntendedFor` on fmap sidecars links fmaps to the DWI series they correct.

---

## Measured SDC (default when fmaps are in the filter)

When the QSIPrep `--bids-filter-file` includes fmap entities, the pipeline logs:

```
QSIPrep: sub-XXX: dwi-select includes fmap -> measured SDC
```

QSIPrep runs **TOPUP** (when opposing PE volumes exist) or the phasediff workflow. Logs may show:

```
Using single-stage SDC, TOPUP-only
[Node] Executing "topup" ...
```

No extra CLI flags are needed beyond passing the filter file.

---

## SyN SDC (no measured fieldmap)

When **no fmap** is included in the dwi-select filter, the strict pipeline **does not** silently fall back to SyN. You must opt in:

| Flag / env | QSIPrep flags |
|------------|---------------|
| `--syn` or `QSIPREP_USE_SYN_SDC=1` | `--use-syn-sdc warn` |
| `--fmap-retry` or `QSIPREP_FMAP_RETRY=1` | `--ignore fieldmaps --use-syn-sdc warn` |

If neither measured fmaps nor an explicit SyN flag is set, the pipeline exits with `ERROR [QSIPrep/SDC]`.

---

## dwi-select and fmaps

Default config: `dwi_pipeline/config/dwi_select_b1000.json`.

**Fmap inclusion rules:**

1. **Gate A — filename exclude:** `exclude_fmap_acquisitions: ["rs"]` skips `acq-rs` fmaps (files remain on disk; QSIPrep never sees them).
2. **Gate B — IntendedFor only:** a fmap is kept only if its `IntendedFor` lists a DWI path that survived DWI shell selection. There is **no** `same_session` fallback.

Dry-run the filter:

```bash
python3 dwi_pipeline/scripts/build_bids_filter.py \
  --bids-dir /path/to/bids \
  --subject SUBJECT_ID \
  --select-json dwi_pipeline/config/dwi_select_b1000.json \
  --output /tmp/bids_filter_check.json
```

---

## BIDS repair (before QSIPrep)

Sidecar repair is **not** run inside `./run`. Apply fixes separately, then submit the pipeline:

```bash
./dwi_pipeline/scripts/run_bids_repair.sh /path/to/bids SUBJ01 --dry-run
./dwi_pipeline/scripts/run_bids_repair.sh /path/to/bids SUBJ01
```

See [`bids.md`](bids_metadata.md) §9 for TRT anchors, `IntendedFor`, and spreadsheet-driven repair.

---

## Quick checklist

- [ ] DWI JSON has `PhaseEncodingDirection` + `TotalReadoutTime`
- [ ] phasediff has `EchoTime1` / `EchoTime2` + `IntendedFor` → target DWI
- [ ] dwi-select filter includes the intended DWI **and** its fmaps
- [ ] Run `./dwi_pipeline/scripts/run_bids_repair.sh` before first QSIPrep if sidecars are sparse
- [ ] For GE / no-fmap cohorts, pass `--syn` explicitly
