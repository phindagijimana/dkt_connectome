# Preparing your data

Input requirements and preprocessing decisions before running `./run`.

---

## Minimum BIDS inputs

| Modality | Required | Notes |
|----------|----------|-------|
| `dwi/` | Yes | At least one diffusion series |
| `anat/T1w` | Yes | Structural reference for ACT tractography |
| `fmap/` | Recommended | Enables fieldmap SDC; otherwise use `--syn` |
| Lesion mask | Optional | `*_T1w_label-lesion_roi.nii.gz` triggers Steps 1.1 and 4.1 |

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

Reference: [bids.md](https://github.com/phindagijimana/dkt_connectome/blob/main/bids.md) (repo root) · deeper repair notes: [BIDS metadata](bids_metadata.md).

---

## DWI series selection (dwi-select)

<a id="dwi-series-selection-dwi-select"></a>

By default the pipeline filters to the **b=1000** shell and pairs IntendedFor fieldmaps:

```bash
./run BIDS OUT participant --participant-label 001 --dwi-shell 1000
```

Custom filter:

```bash
./run BIDS OUT participant --participant-label 001 \
  --dwi-select config/dwi_select_50dirax_no_fmap.json
```

Disable filtering (all DWI series):

```bash
./run BIDS OUT participant --participant-label 001 --no-dwi-filter
```

---

## Field maps and susceptibility distortion correction (SDC)

<a id="fieldmaps-and-sdc"></a>

How BIDS fieldmaps feed QSIPrep, how the pipeline chooses measured vs SyN SDC, and how **dwi-select** interacts with fmap inclusion.

**Related:** [BIDS metadata](bids_metadata.md) (PE / TRT / `IntendedFor` repair) · [Decision tables § SDC](decision_tables.md#susceptibility-distortion-correction-step-1)

### SDC decision tree

<a id="sdc-decision-tree"></a>

```text
Fieldmap in dwi-select filter with IntendedFor?
  ├─ YES → TOPUP / fieldmap SDC (preferred)
  └─ NO  → Must pass one of:
            --syn          SyN synthetic SDC (recommended for GE / no fmap)
            --fmap-retry   Ignore bad fmaps, force SyN
            --no-sdc       Skip SDC (legacy no-fieldmap compatibility only)
```

Details: [fmaps.md](https://github.com/phindagijimana/dkt_connectome/blob/main/fmaps.md) (repo root).

### BIDS fieldmap cases (QSIPrep)

<a id="bids-fieldmap-cases"></a>

| Case | BIDS files | QSIPrep workflow |
|------|------------|------------------|
| **Case 2 — phasediff** | `magnitude1`, `magnitude2`, `phasediff` | GRE fieldmap → SDC via TOPUP/eddy pipeline |
| **Case 4 — PE-Polar** | `*_dir-*_epi` (blip-up / blip-down) | TOPUP on opposing PE EPI volumes |
| **None** | No usable fmap in BIDS filter | Requires `--use-syn-sdc` (opt-in) or subject fails (strict pipeline) |

QSIPrep reads **`PhaseEncodingDirection` + `TotalReadoutTime` from the target DWI JSON** (not from fmap alone). See [BIDS metadata](bids_metadata.md).

For **phasediff**, `EchoTime1` / `EchoTime2` must be on `phasediff.json`. `IntendedFor` on fmap sidecars links fmaps to the DWI series they correct.

### Measured SDC (default when fmaps are in the filter)

<a id="measured-sdc"></a>

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

### SyN SDC (no measured fieldmap)

<a id="syn-sdc"></a>

When **no fmap** is included in the dwi-select filter, the strict pipeline **does not** silently fall back to SyN. You must opt in:

| Flag / env | QSIPrep flags |
|------------|---------------|
| `--syn` or `QSIPREP_USE_SYN_SDC=1` | `--use-syn-sdc warn` |
| `--fmap-retry` or `QSIPREP_FMAP_RETRY=1` | `--ignore fieldmaps --use-syn-sdc warn` |

If neither measured fmaps nor an explicit SyN flag is set, the pipeline exits with `ERROR [QSIPrep/SDC]`.

### dwi-select and fmaps

<a id="dwi-select-and-fmaps"></a>

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

### BIDS repair before QSIPrep

<a id="bids-repair-before-qsiprep"></a>

Sidecar repair is **not** run inside `./run`. Apply fixes separately, then submit the pipeline:

```bash
./dwi_pipeline/scripts/run_bids_repair.sh /path/to/bids SUBJ01 --dry-run
./dwi_pipeline/scripts/run_bids_repair.sh /path/to/bids SUBJ01
```

See [BIDS metadata § repair](bids_metadata.md) for TRT anchors, `IntendedFor`, and spreadsheet-driven repair.

### SDC checklist

<a id="sdc-checklist"></a>

- [ ] DWI JSON has `PhaseEncodingDirection` + `TotalReadoutTime`
- [ ] phasediff has `EchoTime1` / `EchoTime2` + `IntendedFor` → target DWI
- [ ] dwi-select filter includes the intended DWI **and** its fmaps
- [ ] Run `./dwi_pipeline/scripts/run_bids_repair.sh` before first QSIPrep if sidecars are sparse
- [ ] For GE / no-fmap cohorts, pass `--syn` explicitly

---

## Lesion masks (TBI)

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
