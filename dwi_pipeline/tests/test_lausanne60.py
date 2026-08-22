from __future__ import annotations

import subprocess
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
CONFIG = REPO / "dwi_pipeline" / "workflow" / "config" / "config.yaml"
ATLAS_DIR = REPO / "dwi_pipeline" / "atlas" / "lausanne60"
BUILD_SCRIPT = REPO / "dwi_pipeline" / "scripts" / "build_lausanne_parcellation.py"
GENERATE_LUT = REPO / "dwi_pipeline" / "scripts" / "generate_lausanne60_lut.py"


def test_lausanne60_atlas_assets_exist():
    assert (ATLAS_DIR / "resolution150.graphml").is_file()
    assert (ATLAS_DIR / "gcs" / "myatlas_60_lh.gcs").is_file()
    assert (ATLAS_DIR / "gcs" / "myatlas_60_rh.gcs").is_file()
    assert (ATLAS_DIR / "mrtrix_lut" / "lausanne60_mrtrix_lut.txt").is_file()
    assert (ATLAS_DIR / "atlas-Lausanne60_nodes.tsv").is_file()


def test_config_declares_connectome_atlases():
    text = CONFIG.read_text()
    assert "atlases: [dkt]" in text
    assert "lausanne60" in text


def test_build_lausanne_script_is_valid_python():
    subprocess.run(["python3", "-m", "py_compile", str(BUILD_SCRIPT)], check=True)
    subprocess.run(["python3", "-m", "py_compile", str(GENERATE_LUT)], check=True)


def test_lausanne60_node_table_has_129_regions():
    lines = (ATLAS_DIR / "atlas-Lausanne60_nodes.tsv").read_text().strip().splitlines()
    assert len(lines) == 130  # header + 129 nodes
