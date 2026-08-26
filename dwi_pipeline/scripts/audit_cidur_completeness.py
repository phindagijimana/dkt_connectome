#!/usr/bin/env python3
"""Audit CIDUR pipeline completeness per subject (flat + session_aware sub-009).

Checks upstream steps (QSIPrep, recon, QSIRecon), full Step 4 connectome
deliverables (iFOD2 + SDSTREAM CSVs, FA/MD maps, nodes.mif, metadata), and
Step 5 node strength. Subjects with finished connectome matrices but missing
volumetric maps or nodes.mif are flagged for connectome re-run.
"""
from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

PARC = "dkt"
SESSION_AWARE = {"009": ["1", "2"]}
# ses-1 was the first session-aware nodestrength run with cohort/compare tables.
SESSION_AWARE_EXTENDED_NS = {("009", "1")}

# Minimal set used before FA/MD maps and extended metadata were required.
LEGACY_COMPLETE_KEYS = (
    "qsiprep",
    "recon_aparc",
    "qsirecon",
    "conn_sift2",
    "sdstream_tck",
    "sdstream_conn_sift2",
    "nodestrength_strength",
)

# Missing any of these on an otherwise connectome-finished subject => re-run Step 4.
CONNECTOME_RERUN_KEYS = (
    "conn_fa_map",
    "conn_md_map",
    "conn_nodes_mif",
    "conn_meanfa",
    "conn_meanmd",
    "conn_meanlength",
    "streamline_meanfa",
    "streamline_meanmd",
    "metadata_parcellation",
    "metadata_assignments",
    "metadata_tracks_info",
    "metadata_nodes_info",
    "sdstream_meanfa",
    "sdstream_meanmd",
    "sdstream_meanlength",
)


def ok(p: Path) -> bool:
    try:
        return p.is_file() or (p.is_symlink() and p.exists())
    except OSError:
        return False


def check_unit(
    root: Path, sub: str, *, extended_nodestrength: bool = False
) -> dict[str, bool]:
    s = f"sub-{sub}"
    conn = root / "connectomes" / s
    tract = root / "tractography" / s
    ns = root / "node_strength"

    def c(name: str) -> Path:
        return conn / name

    checks: dict[str, bool] = {
        # --- upstream ---
        "qsiprep": (root / ".snakemake_markers" / s / "qsiprep.done").is_file(),
        "recon_aparc": ok(root / "freesurfer" / s / "mri" / "aparc+aseg.mgz"),
        "qsirecon": (root / ".snakemake_markers" / s / "qsirecon.done").is_file(),
        # --- iFOD2 connectome CSVs ---
        "conn_primary": ok(c(f"{PARC}_connectome.csv")),
        "conn_count": ok(c(f"{PARC}_connectome_count.csv")),
        "conn_sift2": ok(c(f"{PARC}_connectome_sift2.csv")),
        "conn_meanlength": ok(c(f"{PARC}_connectome_meanlength.csv")),
        "conn_meanfa": ok(c(f"{PARC}_connectome_meanfa.csv")),
        "conn_meanmd": ok(c(f"{PARC}_connectome_meanmd.csv")),
        # --- SDSTREAM tractography + connectome CSVs ---
        "sdstream_tck": ok(tract / "model-SDSTREAM_streamlines.tck"),
        "sdstream_conn_count": ok(
            c(f"{PARC}_model-SDSTREAM_connectome_count.csv")
        ),
        "sdstream_conn_sift2": ok(
            c(f"{PARC}_model-SDSTREAM_connectome_sift2.csv")
        ),
        "sdstream_meanlength": ok(
            c(f"{PARC}_model-SDSTREAM_connectome_meanlength.csv")
        ),
        "sdstream_meanfa": ok(
            c(f"{PARC}_model-SDSTREAM_connectome_meanfa.csv")
        ),
        "sdstream_meanmd": ok(
            c(f"{PARC}_model-SDSTREAM_connectome_meanmd.csv")
        ),
        # --- streamline-level FA/MD ---
        "streamline_meanfa": ok(c("streamline_meanfa.csv")),
        "streamline_meanmd": ok(c("streamline_meanmd.csv")),
        "sdstream_streamline_meanfa": ok(
            c(f"{PARC}_model-SDSTREAM_streamline_meanfa.csv")
        ),
        "sdstream_streamline_meanmd": ok(
            c(f"{PARC}_model-SDSTREAM_streamline_meanmd.csv")
        ),
        # --- volumetric maps + parcellation volume ---
        "conn_fa_map": ok(c(f"{PARC}_desc-FA_dwi.nii.gz")),
        "conn_md_map": ok(c(f"{PARC}_desc-MD_dwi.nii.gz")),
        "conn_nodes_mif": ok(c(f"{PARC}_nodes.mif")),
        # --- metadata / QC sidecars ---
        "metadata_parcellation": ok(c("parcellation.json")),
        "metadata_assignments": ok(c("assignments.csv")),
        "metadata_tracks_info": ok(c("tracks.tckinfo.txt")),
        "metadata_nodes_info": ok(c("nodes.mrinfo.txt")),
        # --- Step 5 ---
        "nodestrength_strength": ok(
            ns / "strength" / "per_subject" / f"{s}_strength.csv"
        ),
        "nodestrength_report": ok(ns / "reports" / s / "report.pdf"),
    }

    if extended_nodestrength:
        checks["nodestrength_compare"] = ok(
            ns / "compare" / "strength_vs_volume_ai.csv"
        )
        checks["nodestrength_cohort_summary"] = ok(
            ns / "strength" / "cohort_summary.csv"
        )
        checks["nodestrength_manifest"] = ok(ns / "manifest.json")

    return checks


def missing_keys(checks: dict[str, bool], keys: tuple[str, ...]) -> list[str]:
    return [k for k in keys if not checks.get(k, False)]


def legacy_complete(checks: dict[str, bool]) -> bool:
    return not missing_keys(checks, LEGACY_COMPLETE_KEYS)


def needs_connectome_rerun(checks: dict[str, bool]) -> bool:
    """Connectome matrices exist but maps / nodes / extended CSVs are absent."""
    has_core = checks.get("conn_sift2") and checks.get("sdstream_conn_sift2")
    if not has_core:
        return False
    return bool(missing_keys(checks, CONNECTOME_RERUN_KEYS))


def full_complete(checks: dict[str, bool], *, extended_nodestrength: bool) -> bool:
    required = set(checks)
    if not extended_nodestrength:
        required -= {
            "nodestrength_compare",
            "nodestrength_cohort_summary",
            "nodestrength_manifest",
        }
    return all(checks[k] for k in required)


def audit_subjects(
    root: Path, subjects: list[str]
) -> tuple[
    list[str],
    list[str],
    list[tuple[str, object]],
    list[tuple[str, object]],
    Counter,
]:
    complete: list[str] = []
    legacy_only: list[str] = []
    incomplete: list[tuple[str, object]] = []
    rerun: list[tuple[str, object]] = []
    ctr: Counter[str] = Counter()

    for sub in subjects:
        if sub in SESSION_AWARE:
            per_ses: dict[str, dict[str, bool]] = {}
            bad: dict[str, list[str]] = {}
            rerun_ses: dict[str, list[str]] = {}
            for ses in SESSION_AWARE[sub]:
                ext_ns = (sub, ses) in SESSION_AWARE_EXTENDED_NS
                unit = root / "session_aware" / f"sub-{sub}" / f"ses-{ses}"
                c = check_unit(unit, sub, extended_nodestrength=ext_ns)
                per_ses[ses] = c
                miss = [k for k, v in c.items() if not v]
                if miss:
                    bad[ses] = miss
                    for m in miss:
                        ctr[f"{m}@ses-{ses}"] += 1
                if needs_connectome_rerun(c):
                    rerun_ses[ses] = missing_keys(c, CONNECTOME_RERUN_KEYS)

            all_full = all(
                full_complete(
                    c, extended_nodestrength=(sub, ses) in SESSION_AWARE_EXTENDED_NS
                )
                for ses, c in per_ses.items()
            )
            all_legacy = all(legacy_complete(c) for c in per_ses.values())
            if all_full:
                complete.append(sub)
            elif all_legacy:
                legacy_only.append(sub)
            if bad:
                incomplete.append((sub, bad))
            if rerun_ses:
                rerun.append((sub, rerun_ses))
        else:
            c = check_unit(root, sub)
            bad = [k for k, v in c.items() if not v]
            if full_complete(c, extended_nodestrength=False):
                complete.append(sub)
            elif legacy_complete(c):
                legacy_only.append(sub)
            if bad:
                incomplete.append((sub, bad))
                for m in bad:
                    ctr[m] += 1
            if needs_connectome_rerun(c):
                rerun.append((sub, missing_keys(c, CONNECTOME_RERUN_KEYS)))

    return complete, legacy_only, incomplete, rerun, ctr


def print_incomplete(incomplete: list[tuple[str, object]]) -> None:
    print("=== INCOMPLETE ===")
    for sub, bad in sorted(incomplete, key=lambda x: x[0]):
        if sub == "009":
            print("sub-009 [session_aware]")
            for ses in SESSION_AWARE["009"]:
                print(f"  ses-{ses}: missing {bad.get(ses, []) or 'none'}")
        else:
            print(f"sub-{sub}: missing {bad}")


def print_rerun(rerun: list[tuple[str, object]]) -> None:
    if not rerun:
        return
    print()
    print("=== NEEDS CONNECTOME RE-RUN (maps / nodes.mif / extended CSVs) ===")
    for sub, bad in sorted(rerun, key=lambda x: x[0]):
        if sub == "009":
            print("sub-009 [session_aware]")
            for ses, miss in bad.items():
                print(f"  ses-{ses}: missing {miss}")
        else:
            print(f"sub-{sub}: missing {bad}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--results-root",
        default="/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results",
    )
    ap.add_argument(
        "--subject-list",
        default=str(
            Path(__file__).resolve().parent.parent / "subject_list_cidur_all.txt"
        ),
    )
    args = ap.parse_args()
    root = Path(args.results_root)
    subjects = [
        ln.strip()
        for ln in Path(args.subject_list).read_text().splitlines()
        if ln.strip() and not ln.startswith("#")
    ]

    complete, legacy_only, incomplete, rerun, ctr = audit_subjects(root, subjects)

    print(f"Results root: {root}")
    print(f"Subjects: {len(subjects)}")
    print(f"Full spec complete: {len(complete)}")
    print(f"Legacy complete only (missing maps/metadata): {len(legacy_only)}")
    print(f"Incomplete: {len(incomplete)}")
    print(f"Needs connectome re-run: {len(rerun)}")
    print()
    if complete:
        print("FULL COMPLETE:", ", ".join(f"sub-{s}" for s in complete))
    if legacy_only:
        print(
            "LEGACY COMPLETE (re-run Step 4 for FA/MD maps + nodes.mif):",
            ", ".join(f"sub-{s}" for s in legacy_only),
        )
    print()
    print_incomplete(incomplete)
    print_rerun(rerun)
    print()
    print("=== Missing artifact counts ===")
    for k, n in ctr.most_common():
        print(f"  {k}: {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
