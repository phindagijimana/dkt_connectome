#!/usr/bin/env python3
"""
build_seed_connectivity.py -- seed-based connectivity fingerprints

For each lesion-adjacent region, plot its full row of the DKT connectome --
its connection strength to all 77 other nodes -- with its contralateral
homolog called out. This is the most specific, most defensible panel in the
whole report set: it needs no normative comparison and no group template,
just this subject's own matrix, read the way a tractography/connectomics
reader already reads a connectome row.

The two default seeds are the strongest lesion-adjacent regions found by
build_panels.py's find_lesion_adjacent_nodes() for this subject:
  R.MTG   ctx-rh-middletemporal
  R.LOFG  ctx-rh-lateralorbitofrontal

  O_seed_fingerprint_RMTG.png
  O_seed_fingerprint_RLOFG.png
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

OUT = C.out_dir("seed_connectivity")

SEEDS = ["ctx-rh-middletemporal", "ctx-rh-lateralorbitofrontal"]


def homolog_of(name):
    if name.startswith("ctx-lh-"):
        return "ctx-rh-" + name[7:]
    if name.startswith("ctx-rh-"):
        return "ctx-lh-" + name[7:]
    if name.startswith("Left-"):
        return "Right-" + name[5:]
    if name.startswith("Right-"):
        return "Left-" + name[6:]
    return None


def plot_seed(mat, lut, name_to_idx, seed_name):
    seed_idx = name_to_idx[seed_name]
    homolog_name = homolog_of(seed_name)
    homolog_idx = name_to_idx.get(homolog_name)

    row = mat[seed_idx - 1].copy()
    row[seed_idx - 1] = 0  # no self-connection

    order = np.argsort(row)[::-1]
    labels = [lut[i + 1][0] for i in order]
    values = row[order]
    seed_hemi = C.hemisphere_of(seed_name)
    colors = []
    for i in order:
        idx = i + 1
        if idx == homolog_idx:
            colors.append("crimson")
        elif C.hemisphere_of(lut[idx][1]) == seed_hemi:
            colors.append("steelblue")
        else:
            colors.append("darkgray")

    fig, ax = plt.subplots(figsize=(6, 14))
    ax.barh(range(len(values)), values, color=colors)
    ax.set_yticks(range(len(values)))
    ax.set_yticklabels(labels, fontsize=6)
    ax.invert_yaxis()
    ax.set_xlabel("Streamline count (Step 4 DKT connectome)")
    homolog_note = f", homolog={lut[homolog_idx][0]}" if homolog_idx else ""
    ax.set_title(f"{C.SUBJECT}\nseed = {lut[seed_idx][0]} ({seed_name}){homolog_note}\n"
                 f"crimson = contralateral homolog", fontsize=10)
    fig.tight_layout()
    abbrev = lut[seed_idx][0].replace(".", "")
    fname = f"O_seed_fingerprint_{abbrev}.png"
    fig.savefig(OUT / fname, dpi=150)
    plt.close(fig)
    print(f"Wrote {fname}")
    if homolog_idx:
        print(f"  seed-homolog connection strength: {mat[seed_idx - 1, homolog_idx - 1]:.0f}")


def main():
    lut = C.load_dkt_lut()
    mat = pd.read_csv(C.CONNECTOME_DIR / "dkt_connectome.csv", header=None).to_numpy(dtype=float)
    name_to_idx = {name: idx for idx, (_abbrev, name) in lut.items()}

    for seed_name in SEEDS:
        if seed_name not in name_to_idx:
            print(f"WARNING: '{seed_name}' not found in LUT, skipping", file=sys.stderr)
            continue
        plot_seed(mat, lut, name_to_idx, seed_name)
    print(f"Wrote panels to {OUT}")


if __name__ == "__main__":
    main()
