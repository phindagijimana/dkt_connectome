from __future__ import annotations

import subprocess
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
RUN_CONNECTOME = REPO / "dwi_pipeline" / "containers" / "connectome" / "run_connectome.sh"
CONFIG = REPO / "dwi_pipeline" / "workflow" / "config" / "config.yaml"


def test_connectome_multimeasure_contract_is_declared():
    script = RUN_CONNECTOME.read_text()

    subprocess.run(["bash", "-n", str(RUN_CONNECTOME)], check=True)

    assert '"${OUTDIR}/connectome_count.csv"' in script
    assert '"${OUTDIR}/connectome_sift2.csv"' in script
    assert '"${OUTDIR}/connectome_meanlength.csv"' in script
    assert '"${OUTDIR}/connectome_meanfa.csv"' in script
    assert '"${OUTDIR}/connectome_meanmd.csv"' in script
    assert '-tck_weights_in "${SIFT2_WEIGHTS}"' in script
    assert "-scale_length" in script
    assert "-stat_edge mean" in script
    assert (
        'cp -f "${OUTDIR}/connectome_${PRIMARY_MEASURE}.csv" '
        '"${OUTDIR}/connectome.csv"'
    ) in script


def test_tensor_map_and_edge_sampling_contract_is_declared():
    script = RUN_CONNECTOME.read_text()
    assert "dwi2tensor -force" in script
    assert "tensor2metric -force" in script
    assert '-fa "${OUTDIR}/desc-FA_dwi.nii.gz"' in script
    assert '-adc "${OUTDIR}/desc-MD_dwi.nii.gz"' in script
    assert '"${OUTDIR}/streamline_meanfa.csv" -stat_tck mean' in script
    assert '"${OUTDIR}/streamline_meanmd.csv" -stat_tck mean' in script
    assert '-scale_file "${OUTDIR}/streamline_meanfa.csv"' in script
    assert '-scale_file "${OUTDIR}/streamline_meanmd.csv"' in script


def test_count_is_default_primary_measure():
    script = RUN_CONNECTOME.read_text()
    assert 'PRIMARY_MEASURE="count"' in script
    assert "--primary-measure NAME" in script
    assert "primary_measure: count" in CONFIG.read_text()
