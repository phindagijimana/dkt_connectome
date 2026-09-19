#!/usr/bin/env bash
# Remove intermediate CIDUR artifacts for subjects with verified networks_URMC* exports.
#
# Default (Tier 1): tractography/, connectome tractogram copies, debug assignments.
# Optional: --with-qsirecon-derivatives, --with-qsiprep, --with-snakemake-workdir
#
# Usage:
#   bash scripts/prune_cidur_intermediates.sh              # dry-run (default)
#   bash scripts/prune_cidur_intermediates.sh --apply      # delete after checks
#   bash scripts/prune_cidur_intermediates.sh --apply --with-qsirecon-derivatives
#
set -euo pipefail

DWI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAIN_RESULTS="${RESULTS_ROOT:-/mnt/nfs/Gugger_Lab/NIR/dwi_CIDUR/results}"
EXPORTS=(
  "${DWI_ROOT}/networks_URMC_Siemens"
  "${DWI_ROOT}/networks_URMC_GE"
)

APPLY=0
WITH_QSIRECON_DERIV=0
WITH_QSIPREP=0
WITH_SNAKEMAKE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --with-qsirecon-derivatives) WITH_QSIRECON_DERIV=1; shift ;;
    --with-qsiprep) WITH_QSIPREP=1; shift ;;
    --with-snakemake-workdir) WITH_SNAKEMAKE=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

python3 - "${MAIN_RESULTS}" "${APPLY}" "${WITH_QSIRECON_DERIV}" "${WITH_QSIPREP}" "${WITH_SNAKEMAKE}" "${EXPORTS[@]}" <<'PY'
import csv
import os
import shutil
import subprocess
import sys
from pathlib import Path

main_results = Path(sys.argv[1])
apply = sys.argv[2] == "1"
with_qsirecon_deriv = sys.argv[3] == "1"
with_qsiprep = sys.argv[4] == "1"
with_snakemake = sys.argv[5] == "1"
export_roots = [Path(p) for p in sys.argv[6:]]

REQUIRED_SOURCE = "dkt_connectome_sift2.csv"


def du_bytes(path: Path) -> int:
    if not path.exists():
        return 0
    r = subprocess.run(["du", "-sb", str(path)], capture_output=True, text=True)
    if r.returncode != 0:
        return 0
    return int(r.stdout.split()[0])


def fmt(n: int) -> str:
    for unit, div in [("T", 1 << 40), ("G", 1 << 30), ("M", 1 << 20), ("K", 1 << 10)]:
        if n >= div:
            return f"{n / div:.1f}{unit}"
    return f"{n}B"


def parse_manifest(manifest: Path, export_root: Path) -> dict[tuple[str, str], dict]:
    """Return {(subject, session): info} for verified exports."""
    out: dict[tuple[str, str], dict] = {}
    if not manifest.is_file():
        print(f"WARNING: missing manifest {manifest}", file=sys.stderr)
        return out
    with manifest.open(newline="") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        for row in reader:
            if not row.get("measure", "").startswith("SIFT2"):
                continue
            subject = row["subject"]
            session = row["session"]
            source = Path(row["source"])
            exported = export_root / row["exported_file"]
            if source.name != REQUIRED_SOURCE:
                continue
            if not source.is_file():
                print(f"SKIP {subject} {session}: missing source {source}")
                continue
            if not exported.is_file() or exported.stat().st_size == 0:
                print(f"SKIP {subject} {session}: missing export {exported}")
                continue
            # results base: parent of connectomes/
            parts = source.parts
            try:
                idx = parts.index("connectomes")
            except ValueError:
                print(f"SKIP {subject} {session}: cannot parse connectomes path {source}")
                continue
            results_base = Path(*parts[:idx])
            key = (subject, session)
            out[key] = {
                "results_base": results_base,
                "export_root": export_root,
                "source": source,
                "exported": exported,
            }
    return out


def collect_targets(info: dict) -> list[Path]:
    base = info["results_base"]
    subject = info["source"].parts[info["source"].parts.index("connectomes") + 1]
    conn = base / "connectomes" / subject
    targets = [
        base / "tractography" / subject,
        conn / "streamlines_sift2.tck",
        conn / "assignments.csv",
        conn / "tracks.tckinfo.txt",
    ]
    if with_qsiprep:
        targets.append(base / "qsiprep_single_run_output" / subject)
    if with_snakemake:
        targets.append(base / ".snakemake_workdir" / subject)
    if with_qsirecon_deriv:
        deriv = base / "qsirecon_single_run_output" / "derivatives"
        sid = subject.replace("sub-", "")
        if deriv.is_dir():
            for p in deriv.rglob(subject):
                if p.is_dir() and p.name == subject:
                    targets.append(p)
            # also per-subject under derivatives tree
            for p in deriv.glob(f"**/sub-{sid}"):
                if p.is_dir():
                    targets.append(p)
        # small non-derivatives qsirecon subject tree (safe after connectome)
        targets.append(base / "qsirecon_single_run_output" / subject)
    return targets


def main() -> int:
    merged: dict[tuple[str, str], dict] = {}
    for er in export_roots:
        manifest = er / "manifest.tsv"
        for key, info in parse_manifest(manifest, er).items():
            merged[key] = info

    if not merged:
        print("No verified export subjects found.")
        return 1

    print(f"Verified export subjects: {len(merged)}")
    print(f"Mode: {'APPLY (delete)' if apply else 'DRY-RUN'}")
    print(
        f"Options: qsirecon_deriv={with_qsirecon_deriv} qsiprep={with_qsiprep} "
        f"snakemake={with_snakemake}"
    )
    print()

    total_bytes = 0
    delete_paths: list[tuple[str, str, Path, int]] = []

    for (subject, session), info in sorted(merged.items()):
        base = info["results_base"]
        rel_base = base.relative_to(main_results) if str(base).startswith(str(main_results)) else base
        print(f"=== {subject} {session} ({rel_base}) ===")
        subtotal = 0
        for path in collect_targets(info):
            if not path.exists():
                continue
            size = du_bytes(path)
            if size == 0 and path.is_file():
                size = path.stat().st_size
            print(f"  {fmt(size):>8}  {path}")
            subtotal += size
            delete_paths.append((subject, session, path, size))
        if subtotal == 0:
            print("  (nothing to prune)")
        else:
            print(f"  subtotal: {fmt(subtotal)}")
        print()
        total_bytes += subtotal

    print(f"Total reclaimable: {fmt(total_bytes)} across {len(delete_paths)} paths")

    if not apply:
        print("\nDry-run only. Re-run with --apply to delete.")
        return 0

    if not delete_paths:
        print("Nothing to delete.")
        return 0

    removed = 0
    for subject, session, path, size in delete_paths:
        try:
            if path.is_dir():
                shutil.rmtree(path)
            else:
                path.unlink()
            removed += size
            print(f"DELETED {path}")
        except OSError as exc:
            print(f"ERROR deleting {path}: {exc}", file=sys.stderr)

    print(f"\nRemoved ~{fmt(removed)}")
    return 0


sys.exit(main())
PY
