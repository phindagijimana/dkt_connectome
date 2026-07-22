# BIDS phase-encoding metadata (DWI / fmap sidecars)

This note documents **phase-encoding (PE) readout fields** and **fieldmap linking** in BIDS JSON sidecars: what BIDS requires, what QSIPrep needs, credible formulas, and how we repaired sparse Siemens exports (notably **sub-TBI011204**).

**Related:**

- Field maps and QSIPrep SDC behavior: [`fmaps.md`](fmaps.md)
- Repair script: [`dwi_pipeline/scripts/repair_siemens_pe_metadata.py`](dwi_pipeline/scripts/repair_siemens_pe_metadata.py) (heuristic PE only)
- **Sidecar repair pipeline:** [`dwi_pipeline/scripts/repair_bids_sidecars.py`](dwi_pipeline/scripts/repair_bids_sidecars.py) + [`dwi_pipeline/config/bids_repair_defaults.json`](dwi_pipeline/config/bids_repair_defaults.json)

**Spec:** [BIDS MRI / diffusion sidecars](https://bids-specification.readthedocs.io/en/stable/modality-specific-files/magnetic-resonance-imaging-data.html)

---

## 1. Which files need which fields?

These metadata fields apply to **EPI modalities used for distortion correction** (`dwi/`, relevant `fmap/`, sometimes `func/` / `sbref/`). They are **not** required on every file in the dataset (e.g. not on `anat/` T1w unless doing EPI-style SDC on anatomicals).

Each NIfTI has its **own JSON sidecar** (`sub-XXX_dwi.json` paired with `sub-XXX_dwi.nii.gz`).

### 1.1 BIDS requirement levels (common metadata table)

| Field | Default | BIDS makes it **REQUIRED** when… |
|-------|---------|----------------------------------|
| `PhaseEncodingDirection` | RECOMMENDED | Fieldmap data is present for correction, **or** multiple runs differ in PE |
| `TotalReadoutTime` | RECOMMENDED | **Case 4 PE-Polar** fmaps (opposing PE `_epi` volumes) |
| `EffectiveEchoSpacing` | OPTIONAL / RECOMMENDED | Described as needed for fieldmap unwarping; keep with fmaps |

`PhaseEncodingDirection` values: `i`, `i-`, `j`, `j-`, `k`, `k-` — axis letter + optional `-` for reversed polarity.  
Example: `"j-"` = phase encode along column axis, reverse direction.  
**Not** the same as DICOM `InPlanePhaseEncodingDirection` (`ROW` / `COL`).

`TotalReadoutTime` is the **FSL-effective** readout duration (center of first → center of last PE line), **not** the physical echo train length. QSIPrep/TOPUP expect the FSL definition ([LCNI wiki](https://lcni.uoregon.edu/wiki/acquiring-and-using-field-maps/)).

### 1.2 By fieldmap case

| Fmap type | Example files | PE / TRT on **DWI** | PE / TRT on **fmap** | Other fmap fields |
|-----------|---------------|---------------------|----------------------|-------------------|
| **Case 2 — phasediff** | `magnitude1`, `magnitude2`, `phasediff` | PE **required** (BIDS, with fmaps); TRT **recommended**; QSIPrep **needs TRT on DWI** | PE/TRT **optional** (BIDS); copy from DWI for consistency | **`EchoTime1` / `EchoTime2` required on `phasediff.json`**; **`IntendedFor` recommended** |
| **Case 4 — PE-Polar** | `*_dir-*_epi.nii.gz` (blip-up / blip-down) | PE + TRT **required** | PE + TRT **required on each `_epi` JSON** (can differ per volume) | **`IntendedFor` recommended**; `_dir-` filename is **not** a substitute for JSON PE |

---

## 2. QSIPrep: DWI vs fmap — what actually matters

**The DWI sidecar is primary.** QSIPrep applies SDC to the **target EPI (DWI)** and reads PE readout metadata from the **DWI JSON** to scale warping and configure eddy/SDC.

| Location | QSIPrep need | Notes |
|----------|--------------|-------|
| **DWI JSON** | **`PhaseEncodingDirection` + `TotalReadoutTime`** | Missing TRT on DWI caused `KeyError: 'TotalReadoutTime'` for TBI011204 |
| **phasediff JSON** | **`EchoTime1` + `EchoTime2`** | Builds the fieldmap (Case 2) |
| **phasediff / magnitude JSON** | PE + TRT **optional** | Good practice; values should **match DWI** if present |
| **Fmap-only PE/TRT** | Does **not** replace DWI metadata | If PE/TRT are only on fmaps and missing from DWI, QSIPrep still fails |

**Minimum to unblock QSIPrep `gather_inputs`:** `PhaseEncodingDirection` + `TotalReadoutTime` on **DWI**.  
`EffectiveEchoSpacing` is strongly recommended; derive it from TRT when possible (§4).

---

## 3. JSON field order

**Field order in a JSON sidecar does not matter** to QSIPrep, BIDS validators, or standard parsers. Tools read by **key name**, not position.

What matters:

- Correct key names (no typos)
- Correct values (consistent TRT/EES across DWI and fmaps when copied)
- Valid JSON syntax
- Sidecar filename matches NIfTI (`sub-XXX_dwi.json` ↔ `sub-XXX_dwi.nii.gz`)

We group PE fields after `PhaseEncodingAxis` in TBI011204 sidecars **for human readability only**.

---

## 4. Standard formulas (authoritative)

### 4.1 Total readout time ↔ effective echo spacing

**Source:** [BIDS Specification — MRI sidecars](https://bids-specification.readthedocs.io/en/stable/modality-specific-files/magnetic-resonance-imaging-data.html)

```
TotalReadoutTime = EffectiveEchoSpacing × (ReconMatrixPE − 1)
EffectiveEchoSpacing = TotalReadoutTime / (ReconMatrixPE − 1)
```

Same identity in NiPreps: [sdcflows `epimanip`](https://www.nipreps.org/sdcflows/2.3/api/sdcflows.utils.epimanip.html), [fMRIPrep SDC](https://fmriprep.org/en/latest/sdc.html).

Use **`ReconMatrixPE − 1`**, not `PhaseEncodingSteps − 1`. Partial Fourier can make `PhaseEncodingSteps` (e.g. 72) differ from recon matrix size (e.g. 96).

### 4.2 Siemens: effective echo spacing from bandwidth per PE pixel

**Sources:** BIDS Siemens footnote; [LCNI fieldmap wiki](https://lcni.uoregon.edu/wiki/acquiring-and-using-field-maps/)

```
EffectiveEchoSpacing = 1 / (BandwidthPerPixelPhaseEncode × ReconMatrixPE)
BandwidthPerPixelPhaseEncode = 1 / (EffectiveEchoSpacing × ReconMatrixPE)
                              = (ReconMatrixPE − 1) / (TotalReadoutTime × ReconMatrixPE)
```

**DICOM:** Siemens BWpppe = private tag **(0019, 1028)** (dcm2niix also reads **(0021, 1153)** on XA*). See [Neurostars / dcm2niix](https://neurostars.org/t/how-is-bandwidthperpixelphaseencode-calculated/26526).

### 4.3 What you can derive without estimation (given TRT anchor)

When **`TotalReadoutTime`** and **`ReconMatrixPE`** are known (measured):

| Field | How obtained |
|-------|----------------|
| `EffectiveEchoSpacing` | **BIDS formula** — fully derived |
| `BandwidthPerPixelPhaseEncode` | **Siemens inverse** — algebraically consistent, not independent DICOM read |
| `PixelBandwidth / AcquisitionMatrixPE` | **Heuristic only** — do not use when TRT is available (§5) |

---

## 5. Heuristic when BWpppe and TRT are both missing

When dcm2niix exports **no** `BandwidthPerPixelPhaseEncode` and DICOM is unavailable, `repair_siemens_pe_metadata.py` uses a **fallback** (**not** in BIDS spec):

```
BandwidthPerPixelPhaseEncode ≈ PixelBandwidth / AcquisitionMatrixPE
EffectiveEchoSpacing         = 1 / (BWpppe × ReconMatrixPE)
TotalReadoutTime             = EffectiveEchoSpacing × (AcquisitionMatrixPE − 1)
```

Calibrated against TrioTim sidecars where dcm2niix exported full PE metadata (e.g. **sub-TBI011011**). Prefer §4 formulas anchored on vendor TRT when available.

---

## 6. ReconMatrixPE vs AcquisitionMatrixPE

| Field | Source | Role in TRT/EES formula |
|-------|--------|-------------------------|
| **`ReconMatrixPE`** | dcm2niix-computed; **confirm from NIfTI** dim along PE axis | **Use this** in BIDS TRT/EES (`N − 1`) |
| **`AcquisitionMatrixPE`** | DICOM **(0018,9231)** via dcm2niix | Acquisition k-space lines; **can differ** from recon |
| **`PhaseEncodingSteps`** | DICOM / dcm2niix | k-space coverage (e.g. partial Fourier); **do not** substitute for `ReconMatrixPE` |

BIDS warns `ReconMatrixPE` is **not always equal** to `AcquisitionMatrixPE` (GRAPPA, oversampling, interpolation). For **TBI011204** both are **96**, matching NIfTI shape `(96, 96, 64)` with `PhaseEncodingDirection: j-` → column dim = 96.

**Confirm recon PE size:** read NIfTI dimensions along the PE axis from `PhaseEncodingDirection`, or trust dcm2niix `ReconMatrixPE` when it matches the NIfTI.

---

## 7. `IntendedFor` (fmap → target linking)

BIDS **recommends** `IntendedFor` on fieldmap sidecars to list which target image(s) the fmap corrects. Paths are **relative to the subject folder** (may include `ses-<label>/`).

**Alternative (newer BIDS):** `B0FieldIdentifier` / `B0FieldSource` — optional; `IntendedFor` alone is sufficient for QSIPrep on Case 2 datasets.

### TBI011204 (current)

All three fmap sidecars (`magnitude1`, `magnitude2`, `phasediff`) in `phase2_test_bids` and `phase2_test`:

```json
"IntendedFor": [
    "ses-2WK/dwi/sub-TBI011204_ses-2WK_acq-b1000_dwi.nii.gz"
]
```

| Check | Status |
|-------|--------|
| `IntendedFor` on all fmap JSONs | ✅ |
| Target NIfTI exists | ✅ `acq-b1000_dwi.nii.gz` |
| `EchoTime1` / `EchoTime2` on `phasediff.json` | ✅ `0.00492` / `0.00738` |
| `EchoTime1` / `EchoTime2` on magnitude JSONs | Not required (absent is OK) |

**Caveat:** Session also has **`acq-b3000_dwi`**, which is **not** in `IntendedFor`. Fine when QSIPrep runs **b1000 only** (BIDS filter). To SDC b3000 with the same fmaps, add:

```json
"IntendedFor": [
    "ses-2WK/dwi/sub-TBI011204_ses-2WK_acq-b1000_dwi.nii.gz",
    "ses-2WK/dwi/sub-TBI011204_ses-2WK_acq-b3000_dwi.nii.gz"
]
```

---

## 8. TrackTBI011204 worked example

**Problem:** b1000 DWI + GRE fmap sidecars lacked `PhaseEncodingDirection`, `TotalReadoutTime`, and `EffectiveEchoSpacing` → QSIPrep `KeyError: 'TotalReadoutTime'`.

### Stage A — heuristic (before vendor TRT)

| Field | Value | Method |
|-------|-------|--------|
| `PhaseEncodingDirection` | `j-` | Scanner / series convention |
| `BandwidthPerPixelPhaseEncode` | `PixelBandwidth / 96` | Heuristic (§5) |
| `EffectiveEchoSpacing` | `1 / (BWpppe × 96)` | Siemens + BIDS |
| `TotalReadoutTime` | `EES × 95` | BIDS |

First estimated TRT: **`0.0419611`** s (superseded).

### Stage B — vendor-anchored (current sidecars)

**Anchor:** `TotalReadoutTime = 0.0522511` s (vendor/series report).

**Inputs (measured):**

| Input | Value | Source |
|-------|-------|--------|
| `TotalReadoutTime` | `0.0522511` s | Vendor / user |
| `ReconMatrixPE` | `96` | NIfTI j-dim + JSON |
| `PhaseEncodingDirection` | `j-` | Scanner / series |

**Derived:**

```
EffectiveEchoSpacing = 0.0522511 / 95 = 0.000550012 s
BandwidthPerPixelPhaseEncode = 1 / (0.000550012 × 96) = 18.938995 Hz/px
```

**Round-trip check:** `0.000550012 × 95 = 0.0522511` ✓

**Sidecar PE block** (DWI + all fmap JSONs; order optional — §3):

```json
"PhaseEncodingAxis": "j",
"PhaseEncodingDirection": "j-",
"TotalReadoutTime": 0.0522511,
"EffectiveEchoSpacing": 0.000550012,
"BandwidthPerPixelPhaseEncode": 18.938995
```

**Paths updated (both BIDS trees):**

- `TrackTBI/phase2_test_bids/sub-TBI011204/ses-2WK/dwi/sub-TBI011204_ses-2WK_acq-b1000_dwi.json`
- `.../fmap/magnitude1.json`, `magnitude2.json`, `phasediff.json`
- Copied to `TrackTBI/phase2_test/sub-TBI011204/...`

**Note:** QSIPrep outputs generated **before** the TRT update still used the old readout time unless rerun.

---

## 9. QSIPrep series selection (`dwi-select`)

Pipeline config: `dwi_pipeline/config/dwi_select_b1000.json` → generates QSIPrep `--bids-filter-file` per subject via `build_bids_filter.py`.

**DK connectome pipeline (`dwi_pipeline/subject.sh`):** dwi-select runs **by default at the start of QSIPrep** (before the container). Default shell is **b=1000** (`--dwi-shell 1000`). Disable with `--no-dwi-filter`. Run BIDS sidecar repair **separately** before submitting the pipeline (see § Sidecar repair pipeline below).

```bash
# Full cohort (default b1000 + IntendedFor fmaps)
./dwi_pipeline/submit.sh

# Different shell
./dwi_pipeline/submit.sh --dwi-shell 3000
```

### DWI selection

Keeps DWI series whose `.bval` non-zero shells match **`target_shell_b: 1000`** (not by `IntendedFor`).

### Fmap selection (two gates)

**Gate A — filename exclude (does not delete files):**

`exclude_fmap_acquisitions: ["rs"]` **skips** `acq-rs` fmaps when building the filter.  
Files **stay in `fmap/`** on disk; QSIPrep simply **never sees them** because of `--bids-filter-file`. Nothing is removed from BIDS unless you move/delete files yourself.

**Gate B — `IntendedFor` only (no session fallback):**

```json
"fmap_fallback": "intended_for"
```

A fmap JSON is included **only if** its `IntendedFor` lists a DWI path that was kept in step 1.  
Fmaps with **no** `IntendedFor` are **not** included (the old `same_session` fallback is disabled).

### Cohort requirements

For each subject/session:

- Default fmaps (`magnitude1/2`, `phasediff`, no `acq` label): **`IntendedFor` → b1000 DWI**
- Optional `acq-rs` fmaps: may remain in `fmap/`; excluded by Gate A
- Run QSIPrep with dwi-select (automatic in `submit.sh` / `subject.sh`; or manual `--dwi-select`)

### Verify (dry-run)

```bash
python3 dwi_pipeline/scripts/build_bids_filter.py \
  --bids-dir /path/to/bids \
  --subject SUBJECT_ID \
  --select-json dwi_pipeline/config/dwi_select_b1000.json \
  --output /tmp/bids_filter_check.json
```

Expect log lines: keep `acq-b1000_dwi`; keep default fmaps `(IntendedFor)`; **no** `acq-rs` lines.

### Sidecar repair pipeline (before QSIPrep)

Apply the TBI011204 metadata fixes reproducibly:

```bash
# Dry-run
./dwi_pipeline/scripts/run_bids_repair.sh /path/to/bids TBI011204 --dry-run

# Apply (TRT from config subjects.TBI011204.total_readout_time)
./dwi_pipeline/scripts/run_bids_repair.sh /path/to/bids TBI011204

# Override TRT for one run
python3 dwi_pipeline/scripts/repair_bids_sidecars.py \
  --bids-dir /path/to/bids --subject TBI011204 --total-readout-time 0.0522511
```

**Per subject in config** (`bids_repair_defaults.json`): set `subjects.<ID>.total_readout_time` (vendor anchor).  
The script:

1. Writes PE block on **b1000 DWI** + **default fmaps** (not `acq-rs`)
2. Sets **`EchoTime1`/`EchoTime2`** on each `phasediff` from paired magnitudes
3. Sets **`IntendedFor` → b1000 DWI** on default fmaps; **strips** `IntendedFor` on excluded fmap acqs (`rs`)

Pair with dwi-select at QSIPrep time (default in the DK pipeline). Run this repair **before** `./submit.sh`, not inside it.

### Result folders

| Folder | Use |
|--------|-----|
| `CIDUR_BIDS/dwi_test_default` | Atlas connectome only (`dwi_connect_default`, no DK) |
| `CIDUR_BIDS/dwi_test_TBI` | TrackTBI full pipeline with DK |
| `CIDUR_BIDS/dwi_test2` / NAS `Gugger_Lab/NIR/dwi_test2` | CIDUR reference cohort |

See [`dwi_pipeline/README.md`](dwi_pipeline/README.md) and [`fmaps.md`](fmaps.md) for SDC and strict fail-fast behavior.

### Subject table (Excel / CSV)

Put vendor **`TotalReadoutTime`** and **`PhaseEncodingDirection`** per subject in a spreadsheet.  
Template: [`dwi_pipeline/config/bids_repair_subjects.template.csv`](dwi_pipeline/config/bids_repair_subjects.template.csv)

Required columns (flexible names):

| Column | Accepted headers |
|--------|------------------|
| Subject ID | `subject`, `sub`, `participant_id`, … |
| TRT (seconds) | `TotalReadoutTime`, `total_readout_time`, `TRT` |
| PE direction | `PhaseEncodingDirection`, `PE` (optional; falls back to config default) |

**CSV / TSV** — works out of the box.

**Excel (`.xlsx`)** — requires `pip install pandas openpyxl`, or export the sheet to CSV.

```bash
# All subjects in the sheet
./dwi_pipeline/scripts/run_bids_repair.sh \
  /path/to/bids \
  --subjects-table /path/to/subjects.xlsx \
  --all-from-table \
  --dry-run

# One subject; TRT/PE taken from the sheet row for that ID
python3 dwi_pipeline/scripts/repair_bids_sidecars.py \
  --bids-dir /path/to/bids \
  --subject TBI011204 \
  --subjects-table /path/to/subjects.csv
```

Table values **override** `subjects.<ID>` in `bids_repair_defaults.json` for matching IDs.

---

## 10. Quick reference checklist

Before QSIPrep on a DWI + phasediff session:

- [ ] **DWI JSON:** `PhaseEncodingDirection`, `TotalReadoutTime` (and derived `EffectiveEchoSpacing`)
- [ ] **phasediff JSON:** `EchoTime1`, `EchoTime2`, `IntendedFor` → target DWI path(s)
- [ ] **fmap JSONs:** `IntendedFor` consistent; optional PE block matches DWI
- [ ] **Target paths in `IntendedFor`** exist on disk
- [ ] **TRT/EES values** consistent across DWI and fmaps (if duplicated)
- [ ] **ReconMatrixPE** verified from NIfTI PE axis (not `PhaseEncodingSteps`)

---

## 11. Citation stack

1. **BIDS Specification** — PE/TRT definitions, fmap cases, `TRT = EES × (ReconMatrixPE − 1)`  
   https://bids-specification.readthedocs.io/en/stable/modality-specific-files/magnetic-resonance-imaging-data.html

2. **LCNI fieldmap wiki** — Siemens BWpppe, EES, FSL total readout time  
   https://lcni.uoregon.edu/wiki/acquiring-and-using-field-maps/

3. **NiPreps / sdcflows** — how BIDS metadata feeds SDC  
   https://www.nipreps.org/sdcflows/

4. **dcm2niix BIDS README** — `AcquisitionMatrixPE`, `ReconMatrixPE`, DICOM tag mapping  
   https://github.com/rordenlab/dcm2niix/blob/master/BIDS/README.md

5. **Neurostars / dcm2niix** — `BandwidthPerPixelPhaseEncode` from DICOM  
   https://neurostars.org/t/how-is-bandwidthperpixelphaseencode-calculated/26526

6. **This repo** — `repair_siemens_pe_metadata.py` (§5 heuristic); prefer §4 when vendor TRT is available.
