#!/usr/bin/env python3
"""Patch ai-med/V2C-Long supported_datasets.py for DLSurfer longitudinal runs.

Idempotent: rewrites RAW_DATA_DIR / FIXED_SPLIT to read V2C_LONG_RAW_DATA_DIR and
V2C_LONG_CSV from the environment at import time.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

MARKER = "# DLSurfer patch: env-driven TEST_DATASET_LONG paths"
VOXEL_LABELS_MARKER = "# DLSurfer patch: combine_labels over dict items"
VOXEL_LABELS_OLD = """                self.voxel_labels = [
                    combine_labels(vl, self.voxel_label_names, self.LabelMap)
                    for vl in self.voxel_labels
                ]"""
VOXEL_LABELS_NEW = """                self.voxel_labels = {
                    sid: combine_labels(vl, self.voxel_label_names, self.LabelMap)
                    for sid, vl in self.voxel_labels.items()
                }"""

PATCHED_BLOCK = f"""
{MARKER}
dataset_paths = {{
    SupportedDatasets.TEST_DATASET_LONG.name: {{
        'RAW_DATA_DIR': os.environ.get(
            'V2C_LONG_RAW_DATA_DIR',
            os.path.expanduser('~/Documents/others/V2C-Long/data/raw'),
        ),
        'FIXED_SPLIT': [
            LongitudinalInfo(
                os.environ.get('V2C_LONG_CSV', '../supplementary_material/example_data.csv'),
                scan_col="IMAGEUID",
            ),
            LongitudinalInfo(
                os.environ.get('V2C_LONG_CSV', '../supplementary_material/example_data.csv'),
                scan_col="IMAGEUID",
            ),
            LongitudinalInfo(
                os.environ.get('V2C_LONG_CSV', '../supplementary_material/example_data.csv'),
                scan_col="IMAGEUID",
            ),
        ],
    }},
}}
"""


def patch_voxel_labels_dict(v2c_long_root: Path) -> None:
    target = v2c_long_root / "vox2organ" / "data" / "image_and_mesh_dataset.py"
    if not target.is_file():
        raise SystemExit(f"missing {target}")
    text = target.read_text()
    if VOXEL_LABELS_MARKER in text:
        print(f"already patched: {target}")
        return
    if VOXEL_LABELS_OLD not in text:
        raise SystemExit(f"could not find voxel_labels listcomp in {target}")
    text = text.replace(
        VOXEL_LABELS_OLD,
        f"{VOXEL_LABELS_MARKER}\n{VOXEL_LABELS_NEW}",
        1,
    )
    target.write_text(text)
    print(f"patched {target}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--v2c-long-root",
        type=Path,
        default=Path(
            __import__("os").environ.get(
                "V2C_LONG_ROOT",
                Path.home() / "Documents/others/V2C-Long",
            )
        ),
    )
    args = ap.parse_args()
    target = args.v2c_long_root / "vox2organ" / "data" / "supported_datasets.py"
    if not target.is_file():
        raise SystemExit(f"missing {target}")

    text = target.read_text()
    if MARKER not in text:
        m = re.search(r"\ndataset_paths\s*=\s*\{", text)
        if not m:
            raise SystemExit(f"could not find dataset_paths in {target}")
        new_text = text[: m.start()] + "\n" + PATCHED_BLOCK.strip() + "\n"
        target.write_text(new_text)
        print(f"patched {target}")
    else:
        print(f"already patched: {target}")

    patch_voxel_labels_dict(args.v2c_long_root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
