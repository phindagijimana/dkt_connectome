"""L/C tiny algebra. No 10M. Not leftover truth."""

import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))

from l_plant import draw_plant, translate_labels  # noqa: E402
from l2_plant import translate_endpoints  # noqa: E402


def test_draw_plant_locked_seed():
    a = draw_plant([0.5, 0.7, 0.9], 0)
    b = draw_plant([0.5, 0.7, 0.9], 0)
    assert a == b
    assert a["seed"] == 2601
    assert abs(np.linalg.norm(a["ehat"]) - 1.0) < 1e-12


def test_zero_shift_identity():
    nodes = np.arange(27, dtype=np.int32).reshape(3, 3, 3)
    aff = np.eye(4)
    aff[0, 0] = aff[1, 1] = aff[2, 2] = 2.0
    out = translate_labels(nodes, aff, 0.0, np.array([1.0, 0.0, 0.0]))
    assert np.array_equal(out, nodes)


def test_endpoint_shift_is_subvoxel():
    ends = np.zeros((2, 2, 3), dtype=np.float32)
    out = translate_endpoints(ends, 0.7, np.array([1.0, 0.0, 0.0]))
    assert abs(out[0, 0, 0] - 0.7) < 1e-6
    assert np.allclose(out[..., 1:], 0.0)


if __name__ == "__main__":
    test_draw_plant_locked_seed()
    test_zero_shift_identity()
    test_endpoint_shift_is_subvoxel()
    print("test_lc_math ok")
