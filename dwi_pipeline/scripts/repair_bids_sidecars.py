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
