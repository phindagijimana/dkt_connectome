"""
common.py -- shared paths and FreeSurfer/DKT lookup helpers for the
dwi_pipeline/reports/scripts/build_*.py visualization scripts.

Set RESULTS_ROOT, REPORT_SUBJECT, REPORT_SESSION, and INPAINT_DIR via the
environment before running. Defaults use placeholder paths only (safe for a
public repo); never commit real subject IDs or local NFS home directories here.
"""

import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]

SUBJECT = os.environ.get("REPORT_SUBJECT", "sub-PLACEHOLDER")
SESSION = os.environ.get("REPORT_SESSION", "ses-1")

RESULTS_ROOT = Path(os.environ.get("RESULTS_ROOT", "/path/to/results"))
INPAINT_DIR = Path(
    os.environ.get(
        "INPAINT_DIR",
        str(RESULTS_ROOT / "inpainted" / SUBJECT / SESSION),
    )
)

FS_DIR = RESULTS_ROOT / "freesurfer" / SUBJECT
CONNECTOME_DIR = RESULTS_ROOT / "connectomes" / SUBJECT
QSIPREP_DIR = RESULTS_ROOT / "qsiprep_single_run_output" / SUBJECT / SESSION
LUT_PATH = REPO_ROOT / "dwi_pipeline/containers/connectome/mrtrix_lut/fs_dkt.txt"
LESION_MASK = INPAINT_DIR / "lesion_mask_prepared.nii.gz"

REPORTS_DIR = REPO_ROOT / "dwi_pipeline/reports" / SUBJECT
DATA_DIR = REPORTS_DIR / "data"


def out_dir(name):
    d = REPORTS_DIR / name
    d.mkdir(parents=True, exist_ok=True)
    return d


# --- Standard FreeSurfer numeric codes -------------------------------------
# ctx-lh-* = 1000 + N, ctx-rh-* = 2000 + N (same N both hemispheres). This is
# the classic Desikan-Killiany numbering FreeSurfer has used unchanged for
# over a decade; DKT drops N in {1, 4, 32, 33} (bankssts, corpuscallosum,
# frontalpole, temporalpole) and their rh equivalents.
FS_CTX_CODE = {
    "bankssts": 1, "caudalanteriorcingulate": 2, "caudalmiddlefrontal": 3,
    "corpuscallosum": 4, "cuneus": 5, "entorhinal": 6, "fusiform": 7,
    "inferiorparietal": 8, "inferiortemporal": 9, "isthmuscingulate": 10,
    "lateraloccipital": 11, "lateralorbitofrontal": 12, "lingual": 13,
    "medialorbitofrontal": 14, "middletemporal": 15, "parahippocampal": 16,
    "paracentral": 17, "parsopercularis": 18, "parsorbitalis": 19,
    "parstriangularis": 20, "pericalcarine": 21, "postcentral": 22,
    "posteriorcingulate": 23, "precentral": 24, "precuneus": 25,
    "rostralanteriorcingulate": 26, "rostralmiddlefrontal": 27,
    "superiorfrontal": 28, "superiorparietal": 29, "superiortemporal": 30,
    "supramarginal": 31, "frontalpole": 32, "temporalpole": 33,
    "transversetemporal": 34, "insula": 35,
}
# DKT (78-node) protocol excludes these four bilateral pairs.
DKT_EXCLUDED = {"bankssts", "corpuscallosum", "frontalpole", "temporalpole"}

FS_SUBCORT_CODE = {
    "Left-Cerebellum-Cortex": 8, "Left-Thalamus": 10, "Left-Caudate": 11,
    "Left-Putamen": 12, "Left-Pallidum": 13, "Left-Hippocampus": 17,
    "Left-Amygdala": 18, "Left-Accumbens-area": 26,
    "Right-Cerebellum-Cortex": 47, "Right-Thalamus": 49, "Right-Caudate": 50,
    "Right-Putamen": 51, "Right-Pallidum": 52, "Right-Hippocampus": 53,
    "Right-Amygdala": 54, "Right-Accumbens-area": 58,
}


def fs_code_for_ctx_name(hemi_prefix_stripped_name):
    """'fusiform' -> 7 (add 1000/2000 for the hemisphere yourself)."""
    return FS_CTX_CODE[hemi_prefix_stripped_name]


def fs_code_for_node(long_name):
    """Map a DKT LUT long name (e.g. 'ctx-lh-fusiform', 'Left-Thalamus') to
    its raw FreeSurfer numeric code, as stored in aparc(.DKTatlas)+aseg.mgz."""
    if long_name.startswith("ctx-lh-"):
        return 1000 + FS_CTX_CODE[long_name[len("ctx-lh-"):]]
    if long_name.startswith("ctx-rh-"):
        return 2000 + FS_CTX_CODE[long_name[len("ctx-rh-"):]]
    if long_name in FS_SUBCORT_CODE:
        return FS_SUBCORT_CODE[long_name]
    raise KeyError(f"No FreeSurfer code known for region '{long_name}'")


def load_dkt_lut(path=LUT_PATH):
    """index -> (abbrev, long_name) from an mrtrix-style LUT (fs_dkt.txt).

    Index 0 ("???" / Unknown) is skipped: its abbreviation has no "." in it,
    so treating it like every other row (abbrev.split(".")[1]) would raise
    IndexError, and it is not a real connectome node anyway.
    """
    lut = {}
    for line in Path(path).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 3:
            continue
        idx = int(parts[0])
        if idx == 0:
            continue
        lut[idx] = (parts[1], parts[2])
    return lut


def hemisphere_of(name):
    if name.startswith("ctx-lh-") or name.startswith("Left-"):
        return "L"
    if name.startswith("ctx-rh-") or name.startswith("Right-"):
        return "R"
    return "?"


def bilateral_pairs(lut):
    """(left_index, right_index, short_label) for every region present on
    both hemispheres in a {index: (abbrev, long_name)} LUT dict, matched by
    their common suffix after ctx-lh-/ctx-rh-/Left-/Right-."""
    by_stem = {}
    for idx, (_, name) in lut.items():
        if name.startswith("ctx-lh-"):
            by_stem.setdefault(("ctx", name[7:]), {})["L"] = idx
        elif name.startswith("ctx-rh-"):
            by_stem.setdefault(("ctx", name[7:]), {})["R"] = idx
        elif name.startswith("Left-"):
            by_stem.setdefault(("sub", name[5:]), {})["L"] = idx
        elif name.startswith("Right-"):
            by_stem.setdefault(("sub", name[6:]), {})["R"] = idx
    pairs = []
    for (_, stem), sides in sorted(by_stem.items()):
        if "L" in sides and "R" in sides:
            pairs.append((sides["L"], sides["R"], stem))
    return pairs


def parse_aparc_stats(path):
    """StructName -> dict(NumVert, SurfArea, GrayVol, ThickAvg, ThickStd, ...)."""
    cols = None
    rows = {}
    for line in Path(path).read_text().splitlines():
        if line.startswith("# ColHeaders"):
            cols = line.split()[2:]
            continue
        if line.startswith("#") or not line.strip():
            continue
        parts = line.split()
        rows[parts[0]] = dict(zip(cols[1:], (float(v) for v in parts[1:])))
    return rows


def parse_aseg_stats(path):
    """Returns (eTIV_mm3, {StructName: volume_mm3})."""
    etiv = None
    vols = {}
    for line in Path(path).read_text().splitlines():
        if line.startswith("# Measure EstimatedTotalIntraCranialVol"):
            etiv = float(line.split(",")[3])
            continue
        if line.startswith("#") or not line.strip():
            continue
        parts = line.split()
        vols[parts[4]] = float(parts[3])
    return etiv, vols
