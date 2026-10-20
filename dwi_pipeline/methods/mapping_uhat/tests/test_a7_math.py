"""A7 algebra on a tiny pair. No 10M. Not leftover truth."""

import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))

from leftover import COUNT_FLOOR, RELCHANGE_CUT, moved_mask, proxyuhat, relchange


def test_relchange_and_floor():
    assert abs(relchange(100.0, 80.0) - 0.2) < 1e-12
    assert abs(relchange(100.0, 70.0) - 0.3) < 1e-12
    c0 = np.array([[0.0, 100.0], [100.0, 0.0]])
    ck = np.array([[0.0, 70.0], [70.0, 0.0]])
    m = moved_mask(c0, ck)
    assert m[0, 1]  # 0.3 > 0.25 and max>=10
    tiny = np.array([[0.0, 4.0], [4.0, 0.0]])
    assert not moved_mask(tiny, np.array([[0.0, 1.0], [1.0, 0.0]]))[0, 1]


def test_proxyuhat_frequency():
    c0 = np.array([[0.0, 20.0], [20.0, 0.0]])
    stay = np.array([[0.0, 19.0], [19.0, 0.0]])  # rel ~0.05
    jump = np.array([[0.0, 5.0], [5.0, 0.0]])  # rel = 0.75
    p = proxyuhat(c0, [stay, jump, stay, jump])
    assert abs(p[0, 1] - 0.5) < 1e-12
    assert RELCHANGE_CUT == 0.25
    assert COUNT_FLOOR == 10


if __name__ == "__main__":
    test_relchange_and_floor()
    test_proxyuhat_frequency()
    print("test_a7_math ok")
