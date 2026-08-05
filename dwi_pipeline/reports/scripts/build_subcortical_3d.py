#!/usr/bin/env python3
"""
build_subcortical_3d.py -- ENIGMA-style 3D subcortical surface renders

Paints this subject's own subcortical volumes (from aseg.stats) onto the
ENIGMA subcortical mesh (enigmatoolbox.plotting.plot_subcortical), the same
rendering ENIGMA papers use for group-level subcortical findings -- but here
with a single subject's raw values and their own L/R asymmetry, not a
z-score against a normative cohort (see ENIGMA.md Sec2 for why that
normative step needs external reference data this pipeline does not ship).

  N_subcortical_volumes_raw.png   raw volumes (mm^3), viridis
  N_subcortical_asymmetry.png     (L-R)/(L+R) per structure, mirrored onto
                                   each hemisphere with a diverging colormap

IMPORTANT: this script needs enigmatoolbox + a VTK build that can render
without an X server. The system python3 does not have either (that's what
build_panels.py/build_morphometry_panels.py/etc. use). Run this one with the
dedicated venv instead:

    dwi_pipeline/reports/scripts/venv_enigma_vtk/bin/python3 \\
        dwi_pipeline/reports/scripts/build_subcortical_3d.py

See dwi_pipeline/reports/README.md for how venv_enigma_vtk was built
(vtk==9.3.1 + vtk-osmesa, pinned because enigmatoolbox's PointSet wrapper
raises AttributeError against newer VTK).
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.image as mpimg
import numpy as np
from enigmatoolbox.plotting import plot_subcortical

OUT = C.out_dir("subcortical_3d")


def render_with_caption(array_name, cmap, color_range, caption, filename):
    """enigmatoolbox's own label_text overflows the VTK canvas at this size
    (it does not wrap/scale), so render without a title and caption the
    screenshot with matplotlib instead."""
    raw_path = OUT / f"_raw_{filename}"
    plot_subcortical(
        array_name=array_name, ventricles=True, color_bar=True, cmap=cmap,
        color_range=color_range,
        screenshot=True, filename=str(raw_path),
        interactive=False, embed_nb=False, size=(900, 500), transparent_bg=False,
    )
    img = mpimg.imread(str(raw_path))
    fig, ax = plt.subplots(figsize=(9, 5.3))
    ax.imshow(img)
    ax.axis("off")
    ax.set_title(caption, fontsize=12)
    fig.tight_layout()
    fig.savefig(OUT / filename, dpi=150)
    plt.close(fig)
    raw_path.unlink(missing_ok=True)

# Exact order enigmatoolbox.utils.parcellation.subcorticalvertices expects.
STRUCT_ORDER = [
    ("L", "Accumbens-area"), ("L", "Amygdala"), ("L", "Caudate"), ("L", "Hippocampus"),
    ("L", "Pallidum"), ("L", "Putamen"), ("L", "Thalamus"), ("L", "Lateral-Ventricle"),
    ("R", "Accumbens-area"), ("R", "Amygdala"), ("R", "Caudate"), ("R", "Hippocampus"),
    ("R", "Pallidum"), ("R", "Putamen"), ("R", "Thalamus"), ("R", "Lateral-Ventricle"),
]
SIDE_NAME = {"L": "Left", "R": "Right"}


def load_volumes():
    _etiv, vols = C.parse_aseg_stats(C.FS_DIR / "stats" / "aseg.stats")
    out = np.zeros(16, dtype=float)
    for i, (side, struct) in enumerate(STRUCT_ORDER):
        out[i] = vols.get(f"{SIDE_NAME[side]}-{struct}", np.nan)
    return out


def main():
    raw = load_volumes()
    print("Raw subcortical volumes (mm^3), ENIGMA order:")
    for (side, struct), v in zip(STRUCT_ORDER, raw):
        print(f"  {side} {struct:<20s} {v:>10.1f}")

    render_with_caption(
        raw, cmap="viridis", color_range=None,
        caption=f"{C.SUBJECT} -- raw subcortical volumes (mm^3)",
        filename="N_subcortical_volumes_raw.png",
    )

    # Mirror the same (L-R)/(L+R) index onto both hemispheres of each pair so
    # the diverging colormap reads as "which side is bigger", not two
    # unrelated numbers.
    asym = np.zeros(16, dtype=float)
    for i in range(8):
        l, r = raw[i], raw[i + 8]
        a = 0.0 if (l + r) == 0 or np.isnan(l) or np.isnan(r) else (l - r) / (l + r)
        asym[i] = a
        asym[i + 8] = -a

    print("\nLeft/right asymmetry (L-R)/(L+R):")
    for i in range(8):
        print(f"  {STRUCT_ORDER[i][1]:<20s} {asym[i]:+.4f}")

    render_with_caption(
        asym, cmap="RdBu_r", color_range="sym",
        caption=f"{C.SUBJECT} -- L/R asymmetry (L-R)/(L+R), mirrored across hemispheres",
        filename="N_subcortical_asymmetry.png",
    )
    print(f"\nWrote panels to {OUT}")


if __name__ == "__main__":
    main()
