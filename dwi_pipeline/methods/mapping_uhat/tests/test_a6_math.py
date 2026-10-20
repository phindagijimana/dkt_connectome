"""A6 algebra on a tiny pair. No 10M. Not leftover truth."""

import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))

from assign_frozen import assign_endpoints, connectome_from_assignments


def test_assign_endvoxel_and_radial():
    nodes = np.zeros((8, 8, 8), dtype=np.int32)
    nodes[2, 2, 2] = 3
    nodes[5, 2, 2] = 7
    aff = np.eye(4, dtype=np.float64)
    aff[:3, :3] *= 2.0
    ends = np.array([[[4.0, 4.0, 4.0], [10.0, 4.0, 4.0]]], dtype=np.float32)
    ev = assign_endpoints(ends, nodes, aff, kind="end_voxels", radius_mm=4.0)
    assert ev[0, 0] == 3
    assert ev[0, 1] == 7
    miss = np.array([[[5.0, 4.0, 4.0], [11.0, 4.0, 4.0]]], dtype=np.float32)
    rad = assign_endpoints(miss, nodes, aff, kind="radial", radius_mm=4.0)
    assert rad[0, 0] == 3
    assert rad[0, 1] == 7


def test_connectome_count():
    asg = np.array([[1, 2], [2, 1], [1, 3], [0, 4]], dtype=np.int32)
    mat = connectome_from_assignments(asg, n_nodes=4)
    assert mat.shape == (4, 4)
    assert mat[0, 1] == 2
    assert mat[0, 2] == 1
    assert mat[1, 0] == 2


if __name__ == "__main__":
    test_assign_endvoxel_and_radial()
    test_connectome_count()
    print("test_a6_math ok")
