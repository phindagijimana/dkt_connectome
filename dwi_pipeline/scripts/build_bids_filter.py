#!/usr/bin/env python3
"""Build QSIPrep --bids-filter-file JSON from DWI shell criteria + paired fmaps."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ENTITY_MAP = {
    "ses": "session",
    "acq": "acquisition",
    "run": "run",
    "dir": "direction",
    "part": "part",
    "rec": "recording",
    "task": "task",
    "echo": "echo",
    "flip": "flip",
    "inv": "inv",
    "mt": "mt",
    "chunk": "chunk",
}


def parse_entities(basename: str) -> tuple[dict[str, str], str]:
    stem = basename
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


def shell_matches(
    nonzero: list[int],
    target: int,
    tolerance: int,
    allow_multi_shell: bool,
    match_mode: str,
) -> bool:
    if not nonzero:
        return False
    if match_mode == "dominant_nonzero":
        return abs(max(nonzero) - target) <= tolerance
    if not allow_multi_shell and len(nonzero) > 1:
        return False
    if match_mode == "exact_shell_set":
        shells = [s for s in nonzero if abs(s - target) <= tolerance]
        extras = [s for s in nonzero if abs(s - target) > tolerance]
        return bool(shells) and not extras
    return all(abs(s - target) <= tolerance for s in nonzero)


def rel_subject_path(path: Path, subj_root: Path) -> str:
    return path.relative_to(subj_root).as_posix()


def intended_for_matches(intended, kept_relpaths: set[str]) -> bool:
    if not intended:
        return False
    if isinstance(intended, str):
        intended = [intended]
    kept_names = {Path(p).name for p in kept_relpaths}
    for item in intended:
        item = item.lstrip("./")
        if item in kept_relpaths or Path(item).name in kept_names:
            return True
    return False


def merge_filters(rows: list[dict[str, str]], suffix) -> dict:
    out: dict = {}
    out["suffix"] = suffix
    keys = sorted({k for row in rows for k in row})
    for key in keys:
        vals = sorted({row[key] for row in rows if key in row})
        out[key] = vals if len(vals) > 1 else vals[0]
    return out


def fmap_allowed(jpath: Path, exclude_fmap_acq: set[str]) -> bool:
    _, suffix = parse_entities(jpath.name)
    if suffix not in ("epi", "magnitude", "magnitude1", "magnitude2", "phase", "phasediff", "fieldmap"):
        return False
    ent, _ = parse_entities(jpath.name)
    return ent.get("acquisition") not in exclude_fmap_acq


def build_from_select(bids_dir: Path, subject: str, cfg: dict) -> dict:
    subj_root = bids_dir / f"sub-{subject}"
    if not subj_root.is_dir():
        raise SystemExit(f"Missing subject directory: {subj_root}")

    target = int(cfg["target_shell_b"])
    tolerance = int(cfg.get("shell_tolerance", 100))
    b0_max = int(cfg.get("b0_tolerance", 50))
    allow_multi = bool(cfg.get("allow_multi_shell", False))
    match_mode = cfg.get("match_mode", "contains_target")
    include_sessions = cfg.get("include_sessions")
    exclude_acq = set(cfg.get("exclude_acquisitions") or [])
    exclude_fmap_acq = set(cfg.get("exclude_fmap_acquisitions") or [])
    include_fmaps = bool(cfg.get("include_fmaps", True))
    dwi_acq = cfg.get("dwi_acquisition")
    allow_multiple_dwi = bool(cfg.get("allow_multiple_dwi", False))

    kept_dwi: list[Path] = []
    kept_rel: set[str] = set()

    for bval in sorted(subj_root.rglob("*.bval")):
        if "/dwi/" not in bval.as_posix():
            continue
        dwi = bval.with_name(bval.name.replace(".bval", ".nii.gz"))
        if not dwi.exists():
            dwi = bval.with_name(bval.name.replace(".bval", ".nii"))
        if not dwi.exists():
            continue
        ent, _ = parse_entities(dwi.name)
        if include_sessions and ent.get("session") not in include_sessions:
            continue
        if ent.get("acquisition") in exclude_acq:
            continue
        if dwi_acq and ent.get("acquisition") != dwi_acq:
            continue
        nonzero = read_nonzero_shells(bval, b0_max)
        if shell_matches(nonzero, target, tolerance, allow_multi, match_mode):
            kept_dwi.append(dwi)
            kept_rel.add(rel_subject_path(dwi, subj_root))
            print(
                f"[dwi-select] sub-{subject}: keep DWI {dwi.name} (nonzero b={nonzero})",
                file=sys.stderr,
            )

    if not kept_dwi:
        raise SystemExit(f"[dwi-select] sub-{subject}: no DWI matched target_shell_b={target}")

    if not allow_multiple_dwi and len(kept_dwi) > 1:
        names = ", ".join(p.name for p in kept_dwi)
        raise SystemExit(
            f"[dwi-select] sub-{subject}: expected exactly one DWI, matched {len(kept_dwi)}: {names}"
        )

    dwi_sessions = {parse_entities(p.name)[0].get("session") for p in kept_dwi}
    dwi_sessions.discard(None)
    if len(dwi_sessions) > 1:
        raise SystemExit(
            f"[dwi-select] sub-{subject}: DWI matches span multiple sessions: {sorted(dwi_sessions)}"
        )

    kept_fmap_json: list[Path] = []
    if include_fmaps:
        for jpath in sorted(subj_root.rglob("fmap/*.json")):
            if not fmap_allowed(jpath, exclude_fmap_acq):
                continue
            meta = json.loads(jpath.read_text())
            if not intended_for_matches(meta.get("IntendedFor"), kept_rel):
                continue
            kept_fmap_json.append(jpath)
            print(
                f"[dwi-select] sub-{subject}: keep fmap {jpath.name} (IntendedFor)",
                file=sys.stderr,
            )

    out: dict = {}
    if kept_dwi:
        rows = [parse_entities(p.name)[0] for p in kept_dwi]
        out["dwi"] = merge_filters(rows, "dwi")
    if kept_fmap_json:
        rows = []
        suffixes: list[str] = []
        for jpath in kept_fmap_json:
            ent, suffix = parse_entities(jpath.name)
            rows.append(ent)
            suffixes.append(suffix)
        uniq = sorted(set(suffixes))
        out["fmap"] = merge_filters(rows, uniq if len(uniq) > 1 else uniq[0])
        if not any("acquisition" in row for row in rows) and exclude_fmap_acq:
            out["fmap"]["acquisition"] = None
    if not out:
        raise SystemExit(f"[dwi-select] sub-{subject}: empty bids filter")
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--bids-dir", type=Path, required=True)
    ap.add_argument("--subject", required=True)
    ap.add_argument(
        "--session",
        help="Restrict selection to one BIDS session (bare label, for example 1)",
    )
    ap.add_argument("--select-json", type=Path)
    ap.add_argument("--static-filter", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    subject = args.subject.removeprefix("sub-")
    if args.static_filter:
        data = json.loads(args.static_filter.read_text())
        if args.session:
            data.setdefault("dwi", {})["session"] = args.session.removeprefix("ses-")
            if "fmap" in data:
                data["fmap"]["session"] = args.session.removeprefix("ses-")
    elif args.select_json:
        select = json.loads(args.select_json.read_text())
        if args.session:
            select["include_sessions"] = [args.session.removeprefix("ses-")]
        data = build_from_select(args.bids_dir, subject, select)
    else:
        raise SystemExit("Provide --select-json or --static-filter")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, indent=2) + "\n")
    print(f"[dwi-select] wrote {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
