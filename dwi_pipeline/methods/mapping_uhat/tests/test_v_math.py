"""V1 tiny algebra. No leftover truth. Not hat{U}."""

import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))

from v_warp_uq import voxel_maps  # noqa: E402


def test_median_and_sd_known():
    stack = np.array(
        [
            [1.0, 2.0, 3.0],
            [1.0, 4.0, 3.0],
            [1.0, 6.0, 3.0],
        ],
        dtype=np.float64,
    )
    med, sd = voxel_maps(stack)
    assert np.allclose(med, [1.0, 4.0, 3.0])
    assert abs(sd[0]) < 1e-12
    assert abs(sd[1] - np.std([2.0, 4.0, 6.0], ddof=1)) < 1e-12
    assert abs(sd[2]) < 1e-12


def test_single_member_sd_zero():
    stack = np.array([[0.7, 0.8]], dtype=np.float64)
    med, sd = voxel_maps(stack)
    assert np.allclose(med, [0.7, 0.8])
    assert np.allclose(sd, [0.0, 0.0])


if __name__ == "__main__":
    test_median_and_sd_known()
    test_single_member_sd_zero()
    print("ok")
