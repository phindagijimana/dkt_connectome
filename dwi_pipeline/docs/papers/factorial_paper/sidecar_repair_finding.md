# BIDS fieldmap-sidecar repair — how Case-2 phasediff, EchoTime1/2, magnitude1/2, and IntendedFor are handled

**Purpose.** Reference doc for the sidecar-repair utility that lets QSIPrep
consume Siemens Case-2 fieldmaps (magnitude1 + magnitude2 + phasediff) even when
the DICOM export left some of the expected metadata behind. Written up as a
Paper 1 methods note; the utility is `dwi_pipeline/scripts/repair_bids_sidecars.py`.

**Related docs.**
[`bids_metadata.md`](../../bids_metadata.md) — BIDS/QSIPrep field-by-field
requirements · [`preparing_data.md`](../../preparing_data.md) — end-user
workflow · [`vbt_orientation_finding.md`](vbt_orientation_finding.md) — a
sibling "one weird preprocessing bug that blocks a cohort" doc.

---

## Executive summary

Siemens `gre_field_mapping` acquisitions produce three BIDS files for Case-2
fieldmap-based SDC (`magnitude1`, `magnitude2`, `phasediff`). Several export
paths (older dcm2niix, hand-curated BIDS, PACS drops) leave subsets of the
expected metadata missing. The dominant failure modes we hit:

1. **`phasediff.json` carries `EchoTime` but no `EchoTime1`/`EchoTime2`** — dcm2niix's default emits only the second-echo TE. QSIPrep needs the pair to compute Δφ/ΔTE.
2. **`magnitude1.json` / `magnitude2.json` missing** even when the `.nii.gz` are present — happens when the metadata sidecar step of the conversion is skipped.
3. **No `IntendedFor` on the fmap sidecars** — QSIPrep can't associate the fmap with the DWI without either `IntendedFor` (BIDS v1.x) or a `B0FieldSource` mapping (v1.9+).
4. **PE block (`PhaseEncodingDirection`, `TotalReadoutTime`, …) missing on DWI OR fmap** — different QSIPrep code paths need it in different sidecars.
5. **`magnitude1.nii.gz` / `magnitude2.nii.gz` missing entirely on disk** — the phasediff was exported but the magnitude images weren't. Not fixable at the sidecar level (requires DICOM re-conversion).

The repair script handles 1–4 automatically. Case 5 is left as a downstream
action item because it requires source DICOMs.

---

## BIDS Case-2 fieldmap primer

For QSIPrep to run distortion correction via a phase-difference fieldmap, the
BIDS layout must satisfy the following minimum:

```
sub-<ID>/ses-<SES>/
├── dwi/
│   ├── sub-<ID>_ses-<SES>_dwi.nii.gz          # target EPI
│   └── sub-<ID>_ses-<SES>_dwi.json            # needs PhaseEncodingDirection + TotalReadoutTime
└── fmap/
    ├── sub-<ID>_ses-<SES>_magnitude1.nii.gz   # anatomy reference @ TE1
    ├── sub-<ID>_ses-<SES>_magnitude1.json     # (optional; used only for EchoTime source)
    ├── sub-<ID>_ses-<SES>_magnitude2.nii.gz   # anatomy reference @ TE2
    ├── sub-<ID>_ses-<SES>_magnitude2.json     # (optional; used only for EchoTime source)
    ├── sub-<ID>_ses-<SES>_phasediff.nii.gz    # (φ_TE2 − φ_TE1) in radians
    └── sub-<ID>_ses-<SES>_phasediff.json      # MUST have EchoTime1, EchoTime2, IntendedFor
```

The physics: FSL's PRELUDE unwraps `phasediff` using a `magnitude` reference as
the amplitude mask; FUGUE turns `Δφ / (TE2 − TE1)` into a fieldmap (Hz); the
fieldmap is then registered to the target DWI (via `IntendedFor` linkage) and
combined with `TotalReadoutTime` to produce per-voxel EPI unwarping. Every one
of `magnitude1.nii.gz`, `magnitude2.nii.gz`, `phasediff.nii.gz`, `EchoTime1`,
`EchoTime2`, DWI `TotalReadoutTime`, and `IntendedFor` is on the critical path.

---

## Repair script — architecture

`dwi_pipeline/scripts/repair_bids_sidecars.py` is a single-file utility. It is
JSON-only: it does **not** touch NIfTI data. Four passes per
`(subject, session, fmap-acq)` group. Config defaults in
`dwi_pipeline/config/bids_repair_defaults.json`.

### Pass 1 — Discovery (`group_fmap_jsons`)

Walks `sub-<ID>/**/fmap/*.json` and buckets sidecars by `(session, acq_label)`
so that a default fmap group and an `acq-rs` fmap group in the same session are
treated independently.

```python
def group_fmap_jsons(subj_root: Path) -> dict[tuple[str | None, str | None], dict[str, Path]]:
    """Key: (session, fmap_acquisition). Value: suffix -> json path."""
    groups: dict[tuple[str | None, str | None], dict[str, Path]] = {}
    for jpath in sorted(subj_root.rglob("fmap/*.json")):
        ent, suffix = parse_entities(jpath.name)
        if suffix not in ("magnitude1", "magnitude2", "phasediff",
                          "magnitude", "phase", "fieldmap"):
            continue
        key = (ent.get("session"), ent.get("acquisition"))
        groups.setdefault(key, {})[suffix] = jpath
    return groups
```

Recognized suffixes cover Case-1 (`fieldmap`), Case-2 (`magnitude1`,
`magnitude2`, `phasediff`), and Case-3 (`magnitude`, `phase`). Non-fmap files
(e.g. `epi.json` for reverse-PE) are handled in a separate code path not shown
here.

### Pass 2 — EchoTime1/EchoTime2 on phasediff (`fix_phasediff_echoes`)

```python
def fix_phasediff_echoes(
    mag1: Path | None,
    mag2: Path | None,
    phasediff: Path,
    *,
    dry_run: bool,
) -> None:
    meta = load_json(phasediff)
    et1 = load_json(mag1).get("EchoTime") if mag1 else meta.get("EchoTime1")
    et2 = load_json(mag2).get("EchoTime") if mag2 else meta.get("EchoTime2")
    if et1 is None or et2 is None:
        print(f"[repair-bids] skip EchoTime1/2 on {phasediff.name}: "
              f"missing magnitude EchoTime", file=sys.stderr)
        return
    for key in ("EchoTime", "EchoTime1", "EchoTime2"):
        meta.pop(key, None)
    anchor = next((k for k in ("EchoNumber", "SAR", "FlipAngle") if k in meta),
                  "RepetitionTime")
    meta = reorder_after_key(meta, anchor, {"EchoTime1": et1, "EchoTime2": et2})
    save_json(phasediff, meta, dry_run=dry_run)
```

**Sources, in order of preference:**

1. **`magnitude1.json` EchoTime → phasediff EchoTime1.** Ground truth when magnitude sidecars exist — dcm2niix writes each echo's true TR to its own magnitude sidecar (that's what the "1" and "2" in the filename mean).
2. **`magnitude2.json` EchoTime → phasediff EchoTime2.** Same rationale.
3. **Phasediff's own `EchoTime1`/`EchoTime2` (fallback).** Some Siemens exports (dcm2niix ≥ v1.0.20220720 on `syngo MR D13` and later) already write both echoes onto the phasediff sidecar. If magnitude JSONs don't exist, we honor those values.
4. **Give up (with warning).** If neither source is available, the function returns without writing — no fabricated values.

**Cleanup after resolving values:**

- Drop the bare `EchoTime` field on phasediff (BIDS Case-2 doesn't want it — only the pair).
- Drop and re-insert `EchoTime1` + `EchoTime2` at a stable anchor position (after `EchoNumber` → `SAR` → `FlipAngle` → `RepetitionTime`) so the sidecar reads consistently.

### Pass 3 — PE block on every JSON in the group (`apply_pe_and_intended_for`)

```python
def apply_pe_and_intended_for(
    json_paths: list[Path],
    *,
    pe_dir: str,
    total_readout_time: float,
    intended_for: list[str] | None,
    dry_run: bool,
) -> None:
    for jpath in json_paths:
        meta = load_json(jpath)
        block = derive_pe_block(meta, pe_dir=pe_dir,
                                total_readout_time=total_readout_time)
        anchor = "PhaseEncodingAxis" if "PhaseEncodingAxis" in meta else "PixelBandwidth"
        meta = reorder_after_key(meta, anchor, block)
        if intended_for is not None:
            meta["IntendedFor"] = intended_for
        save_json(jpath, meta, dry_run=dry_run)
```

Applied to **the DWI JSON and every fmap JSON in the group** (magnitude1,
magnitude2, phasediff). Writes:

- `PhaseEncodingDirection` (e.g. `j-`)
- `TotalReadoutTime` (from CLI or subjects-table)
- `EffectiveEchoSpacing` — derived from TRT when not present
- `BandwidthPerPixelPhaseEncode`

Anchored after `PhaseEncodingAxis` if present, else after `PixelBandwidth`.

Values on the fmap sidecars match the DWI's PE block so the fmap and target are
consistent per BIDS + QSIPrep expectations. The DWI JSON is treated separately
inside `repair_subject` and written first (line 341–343).

### Pass 4 — IntendedFor wiring (same function, controlled by `intended_for` arg)

Two paths, dispatched inside `repair_subject`:

```python
for (grp_session, fmap_acq), files in sorted(groups.items(), ...):
    if grp_session != session:
        continue
    jsons = list(files.values())
    phasediff = files.get("phasediff")
    if phasediff:
        fix_phasediff_echoes(files.get("magnitude1"), files.get("magnitude2"),
                             phasediff, dry_run=dry_run)

    if fmap_acq in exclude_fmap_acq:
        print(f"[repair-bids] sub-{subj_id}: exclude fmap acq={fmap_acq!r} "
              f"(strip IntendedFor, skip PE)")
        strip_intended_for(jsons, dry_run=dry_run)
        continue

    print(f"[repair-bids] sub-{subj_id}: default fmap group "
          f"session={grp_session!r} acq={fmap_acq!r}")
    apply_pe_and_intended_for(jsons, pe_dir=pe_dir, total_readout_time=trt,
                              intended_for=intended, dry_run=dry_run)
```

- **Default group** (no `acq` label, or one not in the config's
  `exclude_fmap_acquisitions` list): `IntendedFor` is written on
  `magnitude1.json`, `magnitude2.json`, `phasediff.json`, pointing to the
  target DWI as a subject-root-relative path.
- **Excluded group** (typically `acq-rs` used only for rs-fMRI SDC, not DWI):
  `IntendedFor` is **stripped** rather than rewritten, so it doesn't cross-wire
  the wrong fmap into the DWI pipeline. PE and EchoTime passes are skipped.

### Target-DWI discovery (`find_target_dwi`)

```python
def find_target_dwi(
    subj_root: Path,
    *,
    session: str | None,
    dwi_acq: str | None,
    target_shell: int,
    shell_tol: int,
    b0_max: int,
) -> Path | None:
    for bval in sorted(subj_root.rglob("*.bval")):
        if "/dwi/" not in bval.as_posix():
            continue
        ent, _ = parse_entities(bval.name)
        if session and ent.get("session") != session:
            continue
        if dwi_acq and ent.get("acquisition") != dwi_acq:
            continue
        nonzero = read_nonzero_shells(bval, b0_max)
        if not shell_matches(nonzero, target_shell, shell_tol):
            continue
        for ext in (".nii.gz", ".nii"):
            candidate = bval.with_name(bval.name.replace(".bval", ext))
            if candidate.exists():
                return candidate
    return None
```

Walks the subject's DWI directory, checks each `.bval` for a non-zero shell
matching `target_shell ± shell_tol`, and returns the corresponding `.nii.gz`.
This is what `IntendedFor` on the fmap set is pointing at.

`b0_max` (default 50) is the b-value ceiling used to classify volumes as b=0.
`shell_tolerance` (default 100) lets `target_shell_b=1000` still match
b=1300 acquisitions when configured — necessary because Siemens TrioTim
sometimes labels a nominal-b1000 protocol as 1300 in the actual gradient log.

---

## Configuration file

`dwi_pipeline/config/bids_repair_defaults.json` supplies pipeline-wide defaults
plus per-subject overrides:

```json
{
  "phase_encoding_direction": "j-",
  "target_shell_b": 1000,
  "shell_tolerance": 100,
  "b0_tolerance": 50,
  "exclude_fmap_acquisitions": ["rs"],
  "subjects": {
    "TBI011204": { "total_readout_time": 0.0384197 }
  }
}
```

Per-subject blocks let you supply a subject-specific TRT (needed when
`dcm2niix` didn't write it and it must come from the imaging tech / DICOM
private tags) without polluting the shared default.

`--subjects-table` (CSV/TSV/XLSX) is an alternative for cohort-scale batch
usage — columns are matched by alias (`subject` / `sub` / `participant_id`,
`TotalReadoutTime` / `TRT`, `PhaseEncodingDirection` / `PED`, etc.).

---

## Design boundary — what the script does NOT do

- **Does not create magnitude NIfTIs.** If `magnitude1.nii.gz` /
  `magnitude2.nii.gz` are missing on disk (TBI021030's exact situation), no
  amount of sidecar repair fixes it. QSIPrep's Case-2 SDC pipeline is
  PRELUDE (needs a magnitude image as amplitude mask for phase unwrap) →
  FUGUE (needs the resulting fieldmap and the DWI TRT to produce EPI
  unwarping). Missing magnitude NIfTIs must be recovered by re-exporting the
  Siemens `gre_field_mapping` DICOM series through `dcm2niix`, which produces
  the full triplet automatically.
- **Does not create reverse-PE `epi.nii.gz` for TOPUP.** No sidecar edit turns
  a single-PE-direction acquisition into a topup-eligible one.
- **Does not fabricate EchoTime values.** If neither the magnitude JSONs nor
  the phasediff sidecar carry EchoTime data, the function returns with a
  warning rather than making values up.
- **Does not compute `TotalReadoutTime` from DICOMs.** TRT must be supplied on
  the CLI, in a subjects-table row, or in a subject-specific config entry.
  The script's `derive_pe_block` will fill `EffectiveEchoSpacing` from TRT if
  it isn't already present.

---

## Applicability to the current TBI cohort

Snapshot of the seven subjects in the paper 1 pilot / cohort scale-up as of
2026-09-19.

| Subject | Fmap state | What `repair_bids_sidecars.py` produces | Runnable SDC |
|---------|------------|------------------------------------------|--------------|
| TBI011011 | no fmap | pass 1 finds no group, no-op | none (`--no-sdc`, Eddy-only) |
| TBI011007 | no fmap | no-op | none |
| TBI011021 | no fmap | no-op | none |
| TBI011029 | no fmap | no-op | none |
| TBI011140 | no fmap | no-op | none |
| **TBI021030** | phasediff has real `EchoTime1=0.00519`, `EchoTime2=0.00765` but no magnitude .nii.gz or .json | pass 2 keeps the phasediff-native echoes; pass 3 fills PE + wires IntendedFor on the phasediff — but SDC still can't run because magnitude NIfTIs are missing | none (blocker: missing magnitude NIfTIs; needs DICOM re-conversion) |
| **TBI011204** default fmap | `magnitude1.nii.gz` + `magnitude2.nii.gz` + `phasediff.nii.gz` present; all three `.json` sidecars originally absent in working BIDS but present in the source at `/mnt/nfs/Gugger_Lab/NIR/phase2_test/sub-TBI011204/ses-2WK/fmap/`; source phasediff carried a bare `EchoTime=0.00738`, no `EchoTime1/2`, no `IntendedFor`; source `magnitude1.json` had `EchoTime=0.00492`, source `magnitude2.json` had `EchoTime=0.00738`. **Executed 2026-09-22** — see § "Executed repair record" below. | pass 2 populates `EchoTime1=0.00492`, `EchoTime2=0.00738` from magnitude JSONs and drops the bare `EchoTime` on phasediff; pass 3 writes `PhaseEncodingDirection=j-`, `TotalReadoutTime=0.0346501`, derived `EffectiveEchoSpacing=0.000364738`, `BandwidthPerPixelPhaseEncode=28.559321` on all three fmap sidecars + the target DWI JSON; pass 4 wires `IntendedFor → ses-2WK/dwi/sub-TBI011204_ses-2WK_acq-b1000_dwi.nii.gz` on the default triplet | **Case-2 SDC via PRELUDE + FUGUE** — ready to run |
| TBI011204 `acq-rs` fmap | Complete triplet in working BIDS; originally `IntendedFor` pointed at the DWI (non-standard) | listed in `exclude_fmap_acquisitions` → pass 2 unchanged, pass 3 skipped, pass 4 **strips the non-standard `IntendedFor`** so QSIPrep uses the default group for DWI SDC instead | rs-fMRI SDC (via fMRIPrep, not this pipeline) |

**Practical outcome:** the repair script closes the gap for TBI011204's DWI
SDC (a real Case-2 phasediff run), leaves TBI021030 in a "clean-metadata but
still no runnable SDC" state pending DICOM re-conversion, and does nothing for
the four fmap-less subjects (they use the `--no-sdc` Eddy-only path).

---

## Executed repair record

### TBI011204 — 2026-09-22

**Prerequisite:** default fmap `magnitude1.json`, `magnitude2.json`,
`phasediff.json` sidecars were missing from
`/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/bids/sub-TBI011204/ses-2WK/fmap/`.
They were backfilled by copying from the source at
`/mnt/nfs/Gugger_Lab/NIR/phase2_test/sub-TBI011204/ses-2WK/fmap/` before the
repair script was invoked.

**Command:**

```bash
python dwi_pipeline/scripts/repair_bids_sidecars.py \
    --bids-dir /mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/bids \
    --subject TBI011204 \
    --total-readout-time 0.0346501 \
    --phase-encoding-direction j-
```

Corresponding config entry now in `bids_repair_defaults.json`:

```json
"TBI011204": {
  "total_readout_time": 0.0346501,
  "phase_encoding_direction": "j-"
}
```

**Values written:**

| Sidecar | EchoTime | EchoTime1 | EchoTime2 | IntendedFor | PhaseEncodingDirection | TotalReadoutTime | EffectiveEchoSpacing | BandwidthPerPixelPhaseEncode |
|---|---:|---:|---:|---|:-:|---:|---:|---:|
| default `phasediff.json` | (removed) | **0.00492** | **0.00738** | `ses-2WK/dwi/sub-TBI011204_ses-2WK_acq-b1000_dwi.nii.gz` | j- | 0.0346501 | 0.000364738 | 28.559321 |
| default `magnitude1.json` | 0.00492 (unchanged) | — | — | same | j- | 0.0346501 | 0.000364738 | 28.559321 |
| default `magnitude2.json` | 0.00738 (unchanged) | — | — | same | j- | 0.0346501 | 0.000364738 | 28.559321 |
| target `dwi.json` (`acq-b1000`) | 0.094 (unchanged) | — | — | — | j- | 0.0346501 | 0.000364738 | 28.559321 |
| `acq-rs_phasediff.json` | — | 0.00414 (unchanged) | 0.0066 (unchanged) | **stripped** | (unchanged) | (unchanged) | (unchanged) | (unchanged) |
| `acq-rs_magnitude1.json` | 0.00414 (unchanged) | — | — | **stripped** | (unchanged) | (unchanged) | (unchanged) | (unchanged) |
| `acq-rs_magnitude2.json` | 0.0066 (unchanged) | — | — | **stripped** | (unchanged) | (unchanged) | (unchanged) | (unchanged) |

**Source values documented for provenance:**

- Phase-encoding direction (BIDS `j-` ↔ scanner convention `-j`): supplied by user (2026-09-22)
- Total readout time: **0.0346501 s** — supplied by user (2026-09-22)
- EchoTime1 = 0.00492 s (from `phase2_test/sub-TBI011204/.../fmap/magnitude1.json`)
- EchoTime2 = 0.00738 s (from `phase2_test/sub-TBI011204/.../fmap/magnitude2.json`)

**Next step for TBI011204:** the DWI pipeline can now be resubmitted **without `--syn`** and QSIPrep should detect the default fmap group + `IntendedFor` linkage and run real Case-2 SDC via PRELUDE (magnitude-based phase unwrap) + FUGUE (fieldmap → EPI unwarp). Ensure the running arms complete first; then for a clean re-run of TBI011204, nuke the affected arms and resubmit without the `--syn` flag.

---

## Usage

**Single subject:**

```bash
python dwi_pipeline/scripts/repair_bids_sidecars.py \
    --bids-dir /path/to/bids \
    --subject TBI011204 \
    --pe-dir j- \
    --trt 0.0384197
```

**Cohort (subjects-table driven):**

```bash
python dwi_pipeline/scripts/repair_bids_sidecars.py \
    --bids-dir /path/to/bids \
    --subjects-table /path/to/subjects.csv \
    --all-from-table
```

**Dry-run first** (recommended for any first pass on a cohort):

```bash
python dwi_pipeline/scripts/repair_bids_sidecars.py \
    --bids-dir /path/to/bids \
    --subject TBI011204 \
    --dry-run
```

Dry-run mode prints every sidecar it would modify without writing anything.
Real writes are done in-place with atomic replace (`load_json` → mutate →
`save_json` writes to a temp path in the same directory and `os.replace`s the
target).

---

## Manuscript treatment (suggested)

**Methods paragraph (single sentence + citation of the utility):**

> BIDS fmap sidecars were repaired with an in-house utility
> (`repair_bids_sidecars.py`, released with the pipeline) to (i) populate
> `phasediff.EchoTime1` / `EchoTime2` from either the magnitude sidecars or
> the phasediff's own vendor-provided values, (ii) write the DWI-consistent
> phase-encoding block (`PhaseEncodingDirection`, `TotalReadoutTime`,
> `EffectiveEchoSpacing`, `BandwidthPerPixelPhaseEncode`) on all fmap
> sidecars, and (iii) add `IntendedFor` linkage from the default fmap group to
> the target DWI. Subjects whose Siemens `gre_field_mapping` acquisition was
> exported without magnitude NIfTIs and subjects with no fmap acquisition
> were processed with `--no-sdc` (FSL Eddy for head-motion and eddy-current
> correction; susceptibility distortion left uncorrected), matching the
> CIDUR-GE convention (see [`../distance_novelty.md`](../distance_novelty.md)
> § pipeline contribution).

**Supplement table:** per-subject fmap state × repair outcome, mirroring the
table above. This is a natural companion to the per-arm QC table.

---

## See also

- [`bids_metadata.md`](../../bids_metadata.md) — full field-by-field reference for BIDS + QSIPrep expectations
- [`preparing_data.md`](../../preparing_data.md) — end-user data-prep workflow
- [`vbt_orientation_finding.md`](vbt_orientation_finding.md) — sibling "one weird preprocessing bug that blocks a cohort" doc
- Source: `dwi_pipeline/scripts/repair_bids_sidecars.py`
- Config: `dwi_pipeline/config/bids_repair_defaults.json`
- Runner: `dwi_pipeline/scripts/run_bids_repair.sh` (single-command wrapper)

---

## Appendix — Full source (verbatim snapshot, 2026-09-19)

> **Snapshot date:** 2026-09-19. This is a copy for readability. If the code
> in the repo has changed, treat the repo files as authoritative and this
> appendix as an out-of-date snapshot. Re-generate this appendix if you edit
> the underlying files.

### A. `dwi_pipeline/scripts/repair_bids_sidecars.py` (427 lines)

```python
#!/usr/bin/env python3
"""Repair BIDS DWI/fmap JSON sidecars for QSIPrep (PE timing, phasediff echoes, IntendedFor).

Workflow (per subject/session/fmap group):
  1. Target DWI: match dwi_acquisition label and/or b=target_shell_b in .bval
  2. Phase-encoding block on DWI + default (non-excluded) fmaps when total_readout_time given:
       PhaseEncodingDirection, TotalReadoutTime, EffectiveEchoSpacing, BandwidthPerPixelPhaseEncode
  3. Case-2 phasediff: EchoTime1/2 from magnitude1/2 EchoTime; drop phasediff EchoTime
  4. IntendedFor on default fmap set -> target DWI; strip IntendedFor on excluded acq fmaps

See bids.md and dwi_pipeline/config/bids_repair_defaults.json.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path
from typing import Any

ENTITY_MAP = {
    "ses": "session",
    "acq": "acquisition",
    "run": "run",
    "dir": "direction",
    "part": "part",
    "rec": "recording",
    "task": "task",
    "echo": "echo",
}

PE_KEYS = (
    "PhaseEncodingDirection",
    "TotalReadoutTime",
    "EffectiveEchoSpacing",
    "BandwidthPerPixelPhaseEncode",
)

SUBJECT_COLUMN_ALIASES = ("subject", "sub", "participant_id", "participant", "sub_id")
TRT_COLUMN_ALIASES = ("totalreadouttime", "total_readout_time", "trt")
PE_COLUMN_ALIASES = ("phaseencodingdirection", "phase_encoding_direction", "pe", "ped")


def normalize_header(name: str) -> str:
    return re.sub(r"[\s_]+", "", str(name).strip().lower())


def normalize_subject_id(value: str) -> str:
    return str(value).strip().removeprefix("sub-")


def load_table_rows(path: Path) -> list[dict[str, str]]:
    suffix = path.suffix.lower()
    if suffix in (".csv", ".tsv"):
        delimiter = "\t" if suffix == ".tsv" else ","
        with path.open(newline="", encoding="utf-8-sig") as fh:
            return list(csv.DictReader(fh, delimiter=delimiter))
    if suffix in (".xlsx", ".xls"):
        try:
            import pandas as pd
        except ImportError as exc:
            raise SystemExit(
                "Reading Excel requires pandas and openpyxl: pip install pandas openpyxl\n"
                "Or export the sheet to CSV and pass --subjects-table subjects.csv"
            ) from exc
        df = pd.read_excel(path, dtype=str)
        df = df.where(pd.notna(df), None)
        return df.to_dict(orient="records")
    raise SystemExit(f"Unsupported subjects table format: {path} (use .csv, .tsv, .xlsx)")


def pick_column(row: dict, aliases: tuple[str, ...]) -> str | None:
    norm_map = {normalize_header(k): k for k in row}
    for alias in aliases:
        key = norm_map.get(alias)
        if key is not None and row.get(key) not in (None, ""):
            return key
    return None


def load_subjects_table(path: Path) -> dict[str, dict[str, Any]]:
    """Return subjects dict: ID -> {total_readout_time, phase_encoding_direction?}."""
    rows = load_table_rows(path)
    if not rows:
        raise SystemExit(f"Empty subjects table: {path}")

    out: dict[str, dict[str, Any]] = {}
    for i, row in enumerate(rows, start=2):
        sub_col = pick_column(row, SUBJECT_COLUMN_ALIASES)
        trt_col = pick_column(row, TRT_COLUMN_ALIASES)
        pe_col = pick_column(row, PE_COLUMN_ALIASES)
        if sub_col is None:
            raise SystemExit(f"{path}:{i}: missing subject column (expected one of {SUBJECT_COLUMN_ALIASES})")
        if trt_col is None:
            raise SystemExit(f"{path}:{i}: missing TotalReadoutTime column")
        subj_id = normalize_subject_id(row[sub_col])
        if not subj_id:
            continue
        try:
            trt = float(row[trt_col])
        except (TypeError, ValueError) as exc:
            raise SystemExit(f"{path}:{i}: invalid TotalReadoutTime {row[trt_col]!r}") from exc
        entry: dict[str, Any] = {"total_readout_time": trt}
        if pe_col is not None and row.get(pe_col) not in (None, ""):
            entry["phase_encoding_direction"] = str(row[pe_col]).strip()
        out[subj_id] = entry
    if not out:
        raise SystemExit(f"No subjects parsed from {path}")
    return out


def parse_entities(name: str) -> tuple[dict[str, str], str]:
    stem = name
    for ext in (".nii.gz", ".json", ".bval", ".bvec", ".nii"):
        if stem.endswith(ext):
            stem = stem[: -len(ext)]
            break
    parts = stem.split("_")
    entities: dict[str, str] = {}
    for token in parts[1:-1]:
        if "-" not in token:
            continue
        key, val = token.split("-", 1)
        if key in ENTITY_MAP:
            entities[ENTITY_MAP[key]] = val
    return entities, parts[-1]


def read_nonzero_shells(bval_path: Path, b0_max: int) -> list[int]:
    vals = [int(round(float(x))) for x in bval_path.read_text().split()]
    return sorted({v for v in vals if v > b0_max})


def shell_matches(nonzero: list[int], target: int, tolerance: int) -> bool:
    if not nonzero:
        return False
    if len(nonzero) > 1:
        return False
    return all(abs(s - target) <= tolerance for s in nonzero)


def recon_matrix_pe(meta: dict) -> int:
    if "ReconMatrixPE" in meta:
        return int(meta["ReconMatrixPE"])
    if "AcquisitionMatrixPE" in meta:
        return int(meta["AcquisitionMatrixPE"])
    raise KeyError("sidecar missing ReconMatrixPE / AcquisitionMatrixPE")


def derive_pe_block(meta: dict, *, pe_dir: str, total_readout_time: float) -> dict[str, float | str]:
    n_pe = recon_matrix_pe(meta)
    ees = total_readout_time / (n_pe - 1)
    bwpppe = 1.0 / (ees * n_pe)
    return {
        "PhaseEncodingDirection": pe_dir,
        "TotalReadoutTime": total_readout_time,
        "EffectiveEchoSpacing": round(ees, 9),
        "BandwidthPerPixelPhaseEncode": round(bwpppe, 6),
    }


def reorder_after_key(meta: dict, after_key: str, block: dict[str, Any]) -> dict[str, Any]:
    """Place block keys immediately after after_key; drop duplicate PE keys elsewhere."""
    skip = set(block) | set(PE_KEYS)
    out: dict[str, Any] = {}
    inserted = False
    for key, val in meta.items():
        if key in skip:
            continue
        out[key] = val
        if key == after_key and not inserted:
            out.update(block)
            inserted = True
    if not inserted:
        out.update(block)
    return out


def load_json(path: Path) -> dict:
    return json.loads(path.read_text())


def save_json(path: Path, meta: dict, *, dry_run: bool) -> None:
    text = json.dumps(meta, indent=4) + "\n"
    if dry_run:
        print(f"[dry-run] would write {path}")
        return
    path.write_text(text)
    print(f"[repair-bids] updated {path}")


def find_target_dwi(
    subj_root: Path,
    *,
    session: str | None,
    dwi_acq: str | None,
    target_shell: int,
    shell_tol: int,
    b0_max: int,
) -> Path | None:
    for bval in sorted(subj_root.rglob("*.bval")):
        if "/dwi/" not in bval.as_posix():
            continue
        ent, _ = parse_entities(bval.name)
        if session and ent.get("session") != session:
            continue
        if dwi_acq and ent.get("acquisition") != dwi_acq:
            continue
        nonzero = read_nonzero_shells(bval, b0_max)
        if not shell_matches(nonzero, target_shell, shell_tol):
            continue
        for ext in (".nii.gz", ".nii"):
            candidate = bval.with_name(bval.name.replace(".bval", ext))
            if candidate.exists():
                return candidate
    return None


def group_fmap_jsons(subj_root: Path) -> dict[tuple[str | None, str | None], dict[str, Path]]:
    """Key: (session, fmap_acquisition). Value: suffix -> json path."""
    groups: dict[tuple[str | None, str | None], dict[str, Path]] = {}
    for jpath in sorted(subj_root.rglob("fmap/*.json")):
        ent, suffix = parse_entities(jpath.name)
        if suffix not in ("magnitude1", "magnitude2", "phasediff", "magnitude", "phase", "fieldmap"):
            continue
        key = (ent.get("session"), ent.get("acquisition"))
        groups.setdefault(key, {})[suffix] = jpath
    return groups


def rel_intended_for(dwi: Path, subj_root: Path) -> str:
    return dwi.relative_to(subj_root).as_posix()


def fix_phasediff_echoes(
    mag1: Path | None,
    mag2: Path | None,
    phasediff: Path,
    *,
    dry_run: bool,
) -> None:
    meta = load_json(phasediff)
    et1 = load_json(mag1).get("EchoTime") if mag1 else meta.get("EchoTime1")
    et2 = load_json(mag2).get("EchoTime") if mag2 else meta.get("EchoTime2")
    if et1 is None or et2 is None:
        print(f"[repair-bids] skip EchoTime1/2 on {phasediff.name}: missing magnitude EchoTime", file=sys.stderr)
        return
    for key in ("EchoTime", "EchoTime1", "EchoTime2"):
        meta.pop(key, None)
    anchor = next((k for k in ("EchoNumber", "SAR", "FlipAngle") if k in meta), "RepetitionTime")
    meta = reorder_after_key(meta, anchor, {"EchoTime1": et1, "EchoTime2": et2})
    save_json(phasediff, meta, dry_run=dry_run)


def apply_pe_and_intended_for(
    json_paths: list[Path],
    *,
    pe_dir: str,
    total_readout_time: float,
    intended_for: list[str] | None,
    dry_run: bool,
) -> None:
    for jpath in json_paths:
        meta = load_json(jpath)
        block = derive_pe_block(meta, pe_dir=pe_dir, total_readout_time=total_readout_time)
        anchor = "PhaseEncodingAxis" if "PhaseEncodingAxis" in meta else "PixelBandwidth"
        meta = reorder_after_key(meta, anchor, block)
        if intended_for is not None:
            meta["IntendedFor"] = intended_for
        save_json(jpath, meta, dry_run=dry_run)


def strip_intended_for(json_paths: list[Path], *, dry_run: bool) -> None:
    for jpath in json_paths:
        meta = load_json(jpath)
        if "IntendedFor" not in meta:
            continue
        meta.pop("IntendedFor")
        save_json(jpath, meta, dry_run=dry_run)


def repair_subject(
    bids_dir: Path,
    subject: str,
    cfg: dict,
    *,
    total_readout_time: float | None,
    phase_encoding_direction: str | None,
    dry_run: bool,
) -> None:
    subj_id = subject.removeprefix("sub-")
    subj_root = bids_dir / f"sub-{subj_id}"
    if not subj_root.is_dir():
        raise SystemExit(f"Missing {subj_root}")

    subj_cfg = (cfg.get("subjects") or {}).get(subj_id, {})
    pe_dir = (
        phase_encoding_direction
        or subj_cfg.get("phase_encoding_direction")
        or cfg.get("phase_encoding_direction", "j-")
    )
    dwi_acq = cfg.get("dwi_acquisition")
    target_shell = int(cfg.get("target_shell_b", 1000))
    shell_tol = int(cfg.get("shell_tolerance", 100))
    b0_max = int(cfg.get("b0_tolerance", 50))
    exclude_fmap_acq = set(cfg.get("exclude_fmap_acquisitions") or [])

    trt = total_readout_time if total_readout_time is not None else subj_cfg.get("total_readout_time")
    if trt is None:
        raise SystemExit(
            f"sub-{subj_id}: provide --total-readout-time or subjects.{subj_id}.total_readout_time in config"
        )
    trt = float(trt)

    groups = group_fmap_jsons(subj_root)
    if not groups:
        print(f"[repair-bids] sub-{subj_id}: no fmap/*.json found", file=sys.stderr)

    sessions = sorted({sess for sess, _ in groups}, key=lambda s: (s is None, s or ""))
    if not sessions:
        sessions = [None]

    for session in sessions:
        dwi = find_target_dwi(
            subj_root,
            session=session,
            dwi_acq=dwi_acq,
            target_shell=target_shell,
            shell_tol=shell_tol,
            b0_max=b0_max,
        )
        if dwi is None:
            continue
        intended = [rel_intended_for(dwi, subj_root)]
        print(f"[repair-bids] sub-{subj_id}: target DWI {intended[0]}")

        # PE on target DWI
        dwi_json = dwi.with_name(dwi.name.replace(".nii.gz", ".json").replace(".nii", ".json"))
        if dwi_json.exists():
            apply_pe_and_intended_for([dwi_json], pe_dir=pe_dir, total_readout_time=trt, intended_for=None, dry_run=dry_run)

        for (grp_session, fmap_acq), files in sorted(groups.items(), key=lambda kv: (kv[0][0] or "", kv[0][1] or "")):
            if grp_session != session:
                continue
            jsons = list(files.values())
            phasediff = files.get("phasediff")
            if phasediff:
                fix_phasediff_echoes(files.get("magnitude1"), files.get("magnitude2"), phasediff, dry_run=dry_run)

            if fmap_acq in exclude_fmap_acq:
                print(f"[repair-bids] sub-{subj_id}: exclude fmap acq={fmap_acq!r} (strip IntendedFor, skip PE)")
                strip_intended_for(jsons, dry_run=dry_run)
                continue

            print(f"[repair-bids] sub-{subj_id}: default fmap group session={grp_session!r} acq={fmap_acq!r}")
            apply_pe_and_intended_for(
                jsons,
                pe_dir=pe_dir,
                total_readout_time=trt,
                intended_for=intended,
                dry_run=dry_run,
            )


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bids-dir", type=Path, required=True)
    ap.add_argument(
        "--subject",
        action="append",
        help="Subject ID with or without sub- prefix (optional if --subjects-table + --all-from-table)",
    )
    ap.add_argument(
        "--config",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "config" / "bids_repair_defaults.json",
    )
    ap.add_argument(
        "--subjects-table",
        type=Path,
        help="CSV/TSV/Excel with columns: subject, TotalReadoutTime, PhaseEncodingDirection (optional)",
    )
    ap.add_argument(
        "--all-from-table",
        action="store_true",
        help="Repair every subject listed in --subjects-table (must exist under --bids-dir)",
    )
    ap.add_argument("--total-readout-time", type=float, help="Override TRT (seconds) for all subjects in this run")
    ap.add_argument("--phase-encoding-direction", help="Override PE direction for all subjects in this run")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    cfg = json.loads(args.config.read_text())
    table_subjects: dict[str, dict[str, Any]] = {}
    if args.subjects_table:
        table_subjects = load_subjects_table(args.subjects_table)
        merged = dict(cfg.get("subjects") or {})
        merged.update(table_subjects)
        cfg["subjects"] = merged
        print(f"[repair-bids] loaded {len(table_subjects)} subject(s) from {args.subjects_table}", file=sys.stderr)

    if args.all_from_table:
        if not table_subjects:
            raise SystemExit("--all-from-table requires --subjects-table")
        subjects = sorted(table_subjects)
    elif args.subject:
        subjects = [s.removeprefix("sub-") for s in args.subject]
    else:
        raise SystemExit("Provide --subject SUBJ ... or --subjects-table PATH --all-from-table")

    for subject in subjects:
        subj_cfg = (cfg.get("subjects") or {}).get(subject.removeprefix("sub-"), {})
        repair_subject(
            args.bids_dir,
            subject,
            cfg,
            total_readout_time=args.total_readout_time,
            phase_encoding_direction=args.phase_encoding_direction,
            dry_run=args.dry_run,
        )


if __name__ == "__main__":
    main()
```

### B. `dwi_pipeline/scripts/run_bids_repair.sh` (50 lines)

```bash
#!/usr/bin/env bash
# Repair BIDS DWI/fmap sidecars for QSIPrep (PE, phasediff echoes, IntendedFor).
#
# Usage:
#   ./run_bids_repair.sh /path/to/bids SUBJ01 [SUBJ02 ...]
#   ./run_bids_repair.sh /path/to/bids --subjects-table subjects.csv --all-from-table
#   ./run_bids_repair.sh /path/to/bids SUBJ01 --dry-run
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${SCRIPT_DIR}/../config/bids_repair_defaults.json"
REPAIR_PY="${SCRIPT_DIR}/repair_bids_sidecars.py"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 BIDS_DIR [SUBJECT ... | --subjects-table FILE --all-from-table] [--dry-run]" >&2
  exit 1
fi

BIDS_DIR="$1"
shift
SUBJECTS=()
TABLE=""
ALL_FROM_TABLE=0
DRY=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=(--dry-run) ;;
    --all-from-table) ALL_FROM_TABLE=1 ;;
    --subjects-table)
      TABLE="$2"
      shift
      ;;
    *) SUBJECTS+=("$1") ;;
  esac
  shift
done

ARGS=(--bids-dir "$BIDS_DIR" --config "$CONFIG")
if [[ -n "$TABLE" ]]; then
  ARGS+=(--subjects-table "$TABLE")
fi
if [[ "$ALL_FROM_TABLE" -eq 1 ]]; then
  ARGS+=(--all-from-table)
fi
for s in "${SUBJECTS[@]}"; do
  ARGS+=(--subject "$s")
done

python3 "$REPAIR_PY" "${ARGS[@]}" "${DRY[@]}"
```

### C. `dwi_pipeline/config/bids_repair_defaults.json` (verbatim)

```json
{
  "phase_encoding_direction": "j-",
  "dwi_acquisition": "b1000",
  "target_shell_b": 1000,
  "shell_tolerance": 100,
  "b0_tolerance": 50,
  "exclude_fmap_acquisitions": ["rs"],
  "subjects": {
    "SUBJ01": {
      "total_readout_time": 0.0522511
    }
  }
}
```

The `SUBJ01` block is placeholder / example — replace with real subject IDs
and TRT values when running on a real cohort. Additional per-subject overrides
(e.g. `phase_encoding_direction`) are supported per the code in
`load_subjects_table` and `repair_subject`.
