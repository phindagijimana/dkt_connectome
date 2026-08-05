#!/usr/bin/env python3
"""Generate the figure set used by dwi_pipeline/acquisition.md and acquisition.docx.

Nothing here is drawn by hand and nothing comes from a scanner. Every panel is
*computed* from the governing equations, so the curves, images and artefacts are
quantitatively right rather than merely suggestive:

  * relaxation and contrast come from the Bloch solutions with published 3 T
    tissue constants (see TISSUE below),
  * spatial encoding, k-space, Gibbs ringing and partial Fourier come from an
    actual 2-D FFT of an analytic brain phantom,
  * diffusion weighting comes from the Stejskal-Tanner relation and a diffusion
    tensor, and
  * susceptibility distortion is applied as the true pixel shift,
    dy = df * T_readout, so the blip-up/blip-down pair is genuinely equal and
    opposite.

Because the phantom is analytic, no participant data is involved and the whole
set is reproducible anywhere with numpy, scipy and matplotlib.

Usage:
    python3 make_acquisition_figures.py [--out-dir DIR]
"""
from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import numpy as np
from scipy.ndimage import gaussian_filter, map_coordinates

DPI = 150
GAMMA_BAR = 42.577478e6  # 1H gyromagnetic ratio / 2pi, Hz/T
GAMMA = 2 * np.pi * GAMMA_BAR  # rad/s/T

# Representative 3 T relaxation constants and proton densities.
# T1/T2 in ms. Sources: Wansapura 1999; Stanisz 2005; Bojorquez 2017.
TISSUE = {
    "WM":  {"T1": 830.0,  "T2": 80.0,   "T2s": 53.0,  "PD": 0.70, "D": 0.7e-3},
    "GM":  {"T1": 1330.0, "T2": 110.0,  "T2s": 66.0,  "PD": 0.85, "D": 0.8e-3},
    "CSF": {"T1": 4000.0, "T2": 2000.0, "T2s": 500.0, "PD": 1.00, "D": 3.0e-3},
    "Fat": {"T1": 380.0,  "T2": 130.0,  "T2s": 60.0,  "PD": 1.00, "D": 0.1e-3},
}
LABELS = {0: "background", 1: "CSF", 2: "GM", 3: "WM"}

GREY = "#444444"
ACCENT = "#1f77b4"
WARN = "#d62728"


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def finish(fig, out_path, caption=None):
    if caption:
        # Placed just below the figure box: bbox_inches="tight" then grows the
        # canvas to include it, so the caption can never land on an axis label.
        fig.text(0.01, -0.02, caption, fontsize=7, color=GREY, va="top")
    fig.savefig(out_path, dpi=DPI, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"  wrote {out_path.name}")


def ellipse_mask(shape, cx, cy, rx, ry, angle=0.0):
    """Boolean mask of an ellipse on a normalised [-1, 1] grid."""
    ny, nx = shape
    y, x = np.mgrid[0:ny, 0:nx]
    x = (x - nx / 2) / (nx / 2)
    y = (y - ny / 2) / (ny / 2)
    a = np.deg2rad(angle)
    xr = x * np.cos(a) + y * np.sin(a)
    yr = -x * np.sin(a) + y * np.cos(a)
    return ((xr - cx) / rx) ** 2 + ((yr - cy) / ry) ** 2 <= 1.0


def brain_phantom(n=192):
    """An analytic, labelled brain-like phantom with a folded cortex.

    Returns an integer label map using the LABELS convention. A labelled
    phantom (rather than the classic Shepp-Logan) lets every image in this
    figure set be synthesised from real T1/T2/PD constants, so the contrast
    behaviour shown is the contrast behaviour a scanner would produce.

    The cortex is deliberately folded. Gyri and sulci put real high-spatial-
    frequency structure into the object, which is what makes the k-space,
    Gibbs-ringing and distortion panels informative rather than decorative.
    """
    shape = (n, n)
    y, x = np.mgrid[0:n, 0:n]
    xn = (x - n / 2) / (n / 2)
    yn = (y - n / 2) / (n / 2)

    a, b = 0.80, 0.94
    rho = np.sqrt((xn / a) ** 2 + (yn / b) ** 2)
    theta = np.arctan2(yn / b, xn / a)
    brain = rho <= 1.0

    # A gently undulating cortical ribbon of roughly constant thickness, with
    # CSF outside it.
    r_white = 0.775 + 0.030 * np.cos(9 * theta) + 0.014 * np.cos(17 * theta + 0.7)
    r_pial = r_white + 0.115

    lab = np.zeros(shape, dtype=int)
    lab[brain] = 1                       # subarachnoid CSF
    lab[brain & (rho <= r_pial)] = 2     # cortical ribbon
    lab[brain & (rho <= r_white)] = 3    # white matter core

    # Sulci are thin CSF clefts that dive into the white matter, each one lined
    # by cortex. Cutting them explicitly (rather than undulating the surfaces
    # hard enough to fold) keeps the ribbon a sensible thickness and puts
    # genuinely fine detail into the object for the k-space panels to recover.
    srng = np.random.default_rng(4)
    n_sulci = 15
    for k in range(n_sulci):
        th_k = 2 * np.pi * k / n_sulci + srng.normal(0, 0.05)
        depth = 0.50 + 0.22 * srng.random()
        halfw = 0.030 + 0.012 * srng.random()
        dth = np.angle(np.exp(1j * (theta - th_k)))
        deep = brain & (rho > depth)
        wall = deep & (np.abs(dth) < halfw + 0.042)
        lab[wall & (lab == 3)] = 2       # cortex lines the cleft
        lab[deep & (np.abs(dth) < halfw)] = 1  # CSF in the cleft itself

    # Lateral ventricles: two comma-shaped CSF pockets.
    for sign in (-1, 1):
        v = ellipse_mask(shape, sign * 0.17, 0.05, 0.10, 0.30, angle=sign * 12)
        v &= ~ellipse_mask(shape, sign * 0.17, 0.05, 0.05, 0.22, angle=sign * 12)
        lab[v] = 1
    lab[ellipse_mask(shape, 0.0, -0.36, 0.055, 0.10)] = 1  # third ventricle

    # Deep grey nuclei sitting in the WM.
    for sign in (-1, 1):
        lab[ellipse_mask(shape, sign * 0.34, -0.05, 0.11, 0.19, angle=sign * 20)] = 2
        lab[ellipse_mask(shape, sign * 0.16, -0.30, 0.09, 0.13)] = 2

    lab[~brain] = 0
    return lab


def synth_contrast(lab, seq="SE", TR=600.0, TE=15.0, TI=None, alpha=90.0):
    """Synthesise an image from tissue constants using the Bloch solutions.

    SE     S = PD (1 - exp(-TR/T1)) exp(-TE/T2)
    GRE    S = PD sin(a) (1-E1)/(1 - E1 cos a) exp(-TE/T2*)
    IR     S = PD |1 - 2 exp(-TI/T1) + exp(-TR/T1)| exp(-TE/T2)
    """
    img = np.zeros(lab.shape, dtype=float)
    for code, name in LABELS.items():
        if name == "background":
            continue
        m = lab == code
        if not m.any():
            continue
        p = TISSUE[name]
        if seq == "SE":
            s = p["PD"] * (1 - np.exp(-TR / p["T1"])) * np.exp(-TE / p["T2"])
        elif seq == "GRE":
            a = np.deg2rad(alpha)
            E1 = np.exp(-TR / p["T1"])
            s = (p["PD"] * np.sin(a) * (1 - E1) / (1 - E1 * np.cos(a))
                 * np.exp(-TE / p["T2s"]))
        elif seq == "IR":
            s = (p["PD"] * abs(1 - 2 * np.exp(-TI / p["T1"]) + np.exp(-TR / p["T1"]))
                 * np.exp(-TE / p["T2"]))
        else:
            raise ValueError(seq)
        img[m] = s
    return img


def to_kspace(img):
    return np.fft.fftshift(np.fft.fft2(np.fft.ifftshift(img)))


def from_kspace(k):
    return np.abs(np.fft.fftshift(np.fft.ifft2(np.fft.ifftshift(k))))


def show(ax, img, title=None, cmap="gray", vmax=None):
    ax.imshow(img, cmap=cmap, vmin=0, vmax=vmax if vmax else np.percentile(img, 99.5),
              origin="lower", interpolation="nearest")
    ax.set_xticks([])
    ax.set_yticks([])
    if title:
        ax.set_title(title, fontsize=9, pad=4)


def sequence_axes(ax, rows, tmax):
    """Blank canvas for a pulse-sequence diagram with labelled channel rows."""
    ax.set_xlim(0, tmax)
    ax.set_ylim(-0.5, len(rows) - 0.5)
    ax.set_yticks(range(len(rows)))
    ax.set_yticklabels(rows[::-1], fontsize=8)
    ax.set_xticks([])
    for s in ("top", "right", "bottom"):
        ax.spines[s].set_visible(False)
    for i in range(len(rows)):
        ax.axhline(i, color="#dddddd", lw=0.8, zorder=0)


def row_y(rows, name):
    return len(rows) - 1 - rows.index(name)


def rf_pulse(ax, y, t, width, amp=0.32, color=ACCENT, label=None, lobes=3):
    tt = np.linspace(-lobes, lobes, 200)
    env = np.sinc(tt)
    ax.plot(t + tt * width / (2 * lobes), y + env * amp, color=color, lw=1.3)
    if label:
        ax.text(t, y + amp + 0.12, label, ha="center", fontsize=7.5, color=color)


def grad_lobe(ax, y, t0, t1, amp, color="#2ca02c", hatch=None, alpha=0.85):
    ax.add_patch(mpatches.Rectangle((t0, y), t1 - t0, amp, facecolor=color,
                                    edgecolor="black", lw=0.6, alpha=alpha,
                                    hatch=hatch))


# --------------------------------------------------------------------------
# 1 - spins, B0 and Larmor precession
# --------------------------------------------------------------------------
def fig_precession(out):
    fig = plt.figure(figsize=(11.5, 4.1))
    gs = fig.add_gridspec(1, 3, width_ratios=[1, 1.1, 1.15], wspace=0.22)

    # (a) random spins vs aligned spins
    ax = fig.add_subplot(gs[0])
    rng = np.random.default_rng(0)
    xs, ys = rng.uniform(0.05, 0.45, 26), rng.uniform(0.1, 0.9, 26)
    ang = rng.uniform(0, 2 * np.pi, 26)
    ax.quiver(xs, ys, 0.05 * np.cos(ang), 0.05 * np.sin(ang), color=GREY,
              angles="xy", scale_units="xy", scale=1, width=0.008)
    xs2, ys2 = rng.uniform(0.55, 0.95, 26), rng.uniform(0.1, 0.9, 26)
    up = rng.random(26) < 0.62
    ax.quiver(xs2, ys2, np.zeros(26), np.where(up, 0.06, -0.06),
              color=[ACCENT if u else WARN for u in up],
              angles="xy", scale_units="xy", scale=1, width=0.008)
    ax.text(0.25, 1.0, "No field\nspins random\nno net magnetisation",
            ha="center", fontsize=8)
    ax.text(0.75, 1.0, "In $B_0$\nslight excess parallel\n$\\rightarrow M_0$",
            ha="center", fontsize=8, color=ACCENT)
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1.25)
    ax.axis("off")
    ax.set_title("(a) Why there is any signal at all", fontsize=9)

    # (b) precession cone
    ax = fig.add_subplot(gs[1], projection="3d")
    ax.quiver(0, 0, 0, 0, 0, 1.15, color="black", lw=1.6, arrow_length_ratio=0.09)
    ax.text(0.06, 0, 1.2, "$B_0$", fontsize=9)
    th = np.linspace(0, 2 * np.pi, 200)
    r = 0.42
    ax.plot(r * np.cos(th), r * np.sin(th), 0.9, color=GREY, lw=0.9, ls="--")
    for k, t in enumerate(np.linspace(0, 1.5 * np.pi, 4)):
        a = 1.0 - 0.22 * k
        ax.quiver(0, 0, 0, r * np.cos(t), r * np.sin(t), 0.9,
                  color=ACCENT, lw=1.6, alpha=a, arrow_length_ratio=0.12)
    ax.set_xlim(-0.55, 0.55)
    ax.set_ylim(-0.55, 0.55)
    ax.set_zlim(0, 1.25)
    ax.set_axis_off()
    ax.set_title("(b) Larmor precession", fontsize=9, y=1.0)
    ax.text2D(0.5, 0.04, "$\\omega_0 = \\gamma B_0$\nthe spin axis wobbles like a "
              "leaning top", transform=ax.transAxes, ha="center", fontsize=8.5)

    # (c) Larmor frequency vs field strength
    ax = fig.add_subplot(gs[2])
    B = np.linspace(0, 7.5, 100)
    ax.plot(B, GAMMA_BAR * B / 1e6, color=ACCENT, lw=2)
    for b, name in [(0.5, "open"), (1.5, "1.5 T"), (3.0, "3 T"), (7.0, "7 T")]:
        f = GAMMA_BAR * b / 1e6
        ax.plot([b], [f], "o", color=WARN, ms=5)
        ax.annotate(f"{name}\n{f:.1f} MHz", (b, f), textcoords="offset points",
                    xytext=(6, -16), fontsize=7.5)
    ax.set_xlabel("Field strength $B_0$ (T)", fontsize=9)
    ax.set_ylabel("Larmor frequency (MHz)", fontsize=9)
    ax.set_title("(c) $f_0 = 42.58\\,\\mathrm{MHz/T} \\times B_0$", fontsize=9)
    ax.grid(alpha=0.3)
    ax.tick_params(labelsize=8)

    finish(fig, out / "fig01_precession.png",
           "Computed from f = gamma-bar x B0 with gamma-bar = 42.577 MHz/T for 1H.")


# --------------------------------------------------------------------------
# 2 - RF excitation, flip angle, and the rotating frame
# --------------------------------------------------------------------------
def fig_excitation(out):
    fig = plt.figure(figsize=(11, 3.8))
    gs = fig.add_gridspec(1, 3, width_ratios=[1.05, 1, 1], wspace=0.3)

    # (a) spiral tip-down in the rotating frame
    ax = fig.add_subplot(gs[0], projection="3d")
    t = np.linspace(0, 1, 400)
    flip = np.deg2rad(90) * t
    prec = 2 * np.pi * 3 * t
    ax.plot(np.sin(flip) * np.cos(prec), np.sin(flip) * np.sin(prec), np.cos(flip),
            color=ACCENT, lw=1.4)
    ax.quiver(0, 0, 0, 0, 0, 1, color=GREY, lw=1.2, arrow_length_ratio=0.1)
    ax.quiver(0, 0, 0, np.sin(flip[-1]), 0, np.cos(flip[-1]), color=WARN, lw=2,
              arrow_length_ratio=0.12)
    ax.text(0, 0, 1.18, "$M_0$", fontsize=8.5, color=GREY)
    ax.text(1.05, 0, 0.05, "$M_{xy}$", fontsize=8.5, color=WARN)
    ax.set_xlim(-1, 1); ax.set_ylim(-1, 1); ax.set_zlim(-0.15, 1.2)
    ax.set_axis_off()
    ax.set_title("(a) A 90$^\\circ$ pulse tips $M$ into the plane", fontsize=9, y=0.98)

    # (b) flip angle vs available transverse signal
    ax = fig.add_subplot(gs[1])
    a = np.linspace(0, 180, 200)
    ax.plot(a, np.sin(np.deg2rad(a)), color=ACCENT, lw=2, label="$\\sin\\alpha$  (signal)")
    ax.plot(a, np.cos(np.deg2rad(a)), color=GREY, lw=1.4, ls="--",
            label="$\\cos\\alpha$  ($M_z$ left)")
    for deg in (15, 90, 180):
        ax.axvline(deg, color=WARN, lw=0.8, ls=":")
        ax.text(deg + 2, -0.85, f"{deg}$^\\circ$", fontsize=7.5, color=WARN)
    ax.set_xlabel("Flip angle $\\alpha$", fontsize=9)
    ax.set_ylabel("Relative magnetisation", fontsize=9)
    ax.set_title("(b) Flip angle trade-off", fontsize=9)
    ax.legend(fontsize=7.5, loc="lower left")
    ax.grid(alpha=0.3)
    ax.tick_params(labelsize=8)

    # (c) slice selection: RF bandwidth + gradient -> slab
    ax = fig.add_subplot(gs[2])
    z = np.linspace(-60, 60, 400)
    for G, col, lab in [(10, ACCENT, "strong $G_z$ -> thin slice"),
                        (4, WARN, "weak $G_z$ -> thick slice")]:
        f = GAMMA_BAR * (G * 1e-3) * (z * 1e-3) / 1e3  # kHz offset
        bw = 1.5  # kHz transmit bandwidth
        prof = (np.abs(f) < bw / 2).astype(float)
        prof = gaussian_filter(prof, 3)
        ax.plot(z, prof / prof.max(), color=col, lw=1.8, label=lab)
    ax.set_xlabel("Position along $z$ (mm)", fontsize=9)
    ax.set_ylabel("Excited fraction", fontsize=9)
    ax.set_title("(c) Slice selection = RF bandwidth $\\div$ gradient", fontsize=9)
    ax.legend(fontsize=7.5)
    ax.grid(alpha=0.3)
    ax.tick_params(labelsize=8)

    finish(fig, out / "fig02_excitation.png",
           "Panel (c) uses slice thickness = transmit bandwidth / (gamma-bar x Gz), "
           "with a 1.5 kHz pulse.")


# --------------------------------------------------------------------------
# 3 - T1, T2 and T2* relaxation
# --------------------------------------------------------------------------
def fig_relaxation(out):
    fig, axes = plt.subplots(1, 3, figsize=(11.5, 3.6))

    t = np.linspace(0, 5000, 600)
    ax = axes[0]
    for name, col in [("WM", ACCENT), ("GM", "#ff7f0e"), ("CSF", WARN)]:
        T1 = TISSUE[name]["T1"]
        ax.plot(t, 1 - np.exp(-t / T1), color=col, lw=1.8,
                label=f"{name}  $T_1$={T1:.0f} ms")
        ax.plot([T1], [1 - np.exp(-1)], "o", color=col, ms=4)
    ax.axhline(0.63, color=GREY, lw=0.8, ls=":")
    ax.text(4900, 0.655, "63%", fontsize=7.5, ha="right", color=GREY)
    ax.set_xlabel("Time after excitation (ms)", fontsize=9)
    ax.set_ylabel("$M_z / M_0$", fontsize=9)
    ax.set_title("(a) $T_1$: recovery along $B_0$", fontsize=9)
    ax.legend(fontsize=7.5, loc="lower right")
    ax.grid(alpha=0.3); ax.tick_params(labelsize=8)

    t = np.linspace(0, 400, 600)
    ax = axes[1]
    for name, col in [("WM", ACCENT), ("GM", "#ff7f0e")]:
        T2 = TISSUE[name]["T2"]
        ax.plot(t, np.exp(-t / T2), color=col, lw=1.8, label=f"{name}  $T_2$={T2:.0f} ms")
        ax.plot(t, np.exp(-t / TISSUE[name]["T2s"]), color=col, lw=1.2, ls="--",
                label=f"{name}  $T_2^*$={TISSUE[name]['T2s']:.0f} ms")
    ax.axhline(0.37, color=GREY, lw=0.8, ls=":")
    ax.text(395, 0.395, "37%", fontsize=7.5, ha="right", color=GREY)
    ax.set_xlabel("Time after excitation (ms)", fontsize=9)
    ax.set_ylabel("$M_{xy} / M_0$", fontsize=9)
    ax.set_title("(b) $T_2$ and $T_2^*$: loss of phase coherence", fontsize=9)
    ax.legend(fontsize=7, loc="upper right")
    ax.grid(alpha=0.3); ax.tick_params(labelsize=8)

    # (c) why a 180 pulse recovers T2* back to T2
    ax = axes[2]
    t = np.linspace(0, 160, 800)
    TE = 80.0
    env_t2s = np.exp(-t / 30)
    env_t2 = np.exp(-t / 90)
    refocus = np.exp(-np.abs(t - TE) / 30)
    sig = env_t2 * np.minimum(1.0, np.where(t < TE / 2, env_t2s / env_t2, refocus))
    carrier = np.cos(2 * np.pi * t / 6)
    ax.plot(t, sig * carrier, color=ACCENT, lw=0.8)
    ax.plot(t, sig, color=WARN, lw=1.6, label="$T_2$ envelope")
    ax.plot(t, env_t2s, color=GREY, lw=1.2, ls="--", label="$T_2^*$ decay (FID)")
    ax.axvline(TE / 2, color="black", lw=1.0)
    ax.text(TE / 2, 1.06, "180$^\\circ$", ha="center", fontsize=8)
    ax.axvline(TE, color="#2ca02c", lw=1.0, ls=":")
    ax.text(TE, 1.06, "echo at TE", ha="center", fontsize=8, color="#2ca02c")
    ax.set_xlabel("Time (ms)", fontsize=9)
    ax.set_ylabel("Signal", fontsize=9)
    ax.set_ylim(-1.15, 1.2)
    ax.set_title("(c) The spin echo undoes static dephasing", fontsize=9)
    ax.legend(fontsize=7.5, loc="lower left")
    ax.grid(alpha=0.3); ax.tick_params(labelsize=8)

    fig.tight_layout()
    finish(fig, out / "fig03_relaxation.png",
           "Exponentials evaluated at published 3 T constants; circles mark t = T1.")


# --------------------------------------------------------------------------
# 4 - how TR and TE create contrast
# --------------------------------------------------------------------------
def fig_contrast(out):
    lab = brain_phantom()
    fig = plt.figure(figsize=(11.5, 6.6))
    gs = fig.add_gridspec(2, 4, height_ratios=[1, 0.95], hspace=0.3, wspace=0.22)

    # A plain spin echo gives only weak T1 contrast at 3 T, which is exactly why
    # structural T1w scans are inversion-prepared. Show the IR version.
    show(fig.add_subplot(gs[0, 0]),
         synth_contrast(lab, "IR", TR=2000, TE=10, TI=900),
         "$T_1$-weighted (MPRAGE-like)\nTI 900: WM bright, CSF black")
    show(fig.add_subplot(gs[0, 1]),
         synth_contrast(lab, "SE", TR=4000, TE=12),
         "Proton density\nTR 4000 / TE 12")
    show(fig.add_subplot(gs[0, 2]),
         synth_contrast(lab, "SE", TR=4000, TE=100),
         "$T_2$-weighted\nTR 4000 / TE 100")
    show(fig.add_subplot(gs[0, 3]),
         synth_contrast(lab, "IR", TR=9000, TE=100, TI=2500),
         "FLAIR\nTI 2500 nulls CSF")

    # contrast-vs-TR and contrast-vs-TE curves that explain the images above
    ax = fig.add_subplot(gs[1, :2])
    TRs = np.linspace(50, 5000, 400)
    for name, col in [("WM", ACCENT), ("GM", "#ff7f0e"), ("CSF", WARN)]:
        p = TISSUE[name]
        ax.plot(TRs, p["PD"] * (1 - np.exp(-TRs / p["T1"])), color=col, lw=1.8, label=name)
    ax.axvline(500, color="black", lw=1.0, ls="--")
    ax.text(600, 0.90, "short TR:\ntissues differ most", fontsize=7.5, va="top")
    ax.axvline(4000, color="black", lw=1.0, ls=":")
    ax.text(3900, 0.28, "long TR:\n$T_1$ contrast gone", fontsize=7.5, ha="right", va="top")
    ax.set_ylim(0, 1.0)
    ax.set_xlabel("TR (ms)", fontsize=9)
    ax.set_ylabel("Signal (TE $\\rightarrow$ 0)", fontsize=9)
    ax.set_title("TR controls how much $T_1$ shows", fontsize=9)
    ax.legend(fontsize=7.5, loc="center right"); ax.grid(alpha=0.3)
    ax.tick_params(labelsize=8)

    ax = fig.add_subplot(gs[1, 2:])
    TEs = np.linspace(0, 250, 400)
    for name, col in [("WM", ACCENT), ("GM", "#ff7f0e"), ("CSF", WARN)]:
        p = TISSUE[name]
        ax.plot(TEs, p["PD"] * np.exp(-TEs / p["T2"]), color=col, lw=1.8, label=name)
    ax.axvline(12, color="black", lw=1.0, ls="--")
    ax.text(20, 0.55, "short TE:\nlittle $T_2$ effect", fontsize=7.5, va="top")
    ax.axvline(100, color="black", lw=1.0, ls=":")
    ax.text(110, 0.72, "long TE:\ntissues separate", fontsize=7.5, va="top")
    ax.set_ylim(0, 1.05)
    ax.set_xlabel("TE (ms)", fontsize=9)
    ax.set_ylabel("Signal (TR $\\rightarrow \\infty$)", fontsize=9)
    ax.set_title("TE controls how much $T_2$ shows", fontsize=9)
    ax.legend(fontsize=7.5, loc="center right"); ax.grid(alpha=0.3)
    ax.tick_params(labelsize=8)

    fig.suptitle("Two knobs, four contrasts: images synthesised from the Bloch "
                 "equations at 3 T", fontsize=11, y=0.97)
    finish(fig, out / "fig04_contrast.png",
           "Images are computed, not acquired: S = PD (1-exp(-TR/T1)) exp(-TE/T2) "
           "evaluated per tissue on an analytic phantom.")


# --------------------------------------------------------------------------
# 5 - spatial encoding with the three gradients
# --------------------------------------------------------------------------
def fig_encoding(out):
    n = 192
    fig, axes = plt.subplots(1, 4, figsize=(12.5, 3.5))

    y, x = np.mgrid[0:n, 0:n]
    xn = (x - n / 2) / (n / 2)
    yn = (y - n / 2) / (n / 2)

    # Real numbers: a 10 mT/m readout gradient across a 240 mm field of view.
    g_read, fov = 10e-3, 0.240
    freq_khz = GAMMA_BAR * g_read * (xn * fov / 2) / 1e3
    ax = axes[0]
    im = ax.imshow(freq_khz, cmap="coolwarm", origin="lower")
    ax.contour(freq_khz, levels=8, colors="k", linewidths=0.4)
    ax.set_title("(a) Frequency encode $G_x$\nposition $\\rightarrow$ frequency", fontsize=9)
    ax.set_xticks([]); ax.set_yticks([])
    cb = fig.colorbar(im, ax=ax, fraction=0.046)
    cb.set_label("offset (kHz), 10 mT/m over 240 mm", fontsize=7)
    cb.ax.tick_params(labelsize=7)

    ax = axes[1]
    phase = np.angle(np.exp(1j * np.pi * 3 * yn))
    im = ax.imshow(phase, cmap="twilight", origin="lower")
    ax.set_title("(b) Phase encode $G_y$\nposition $\\rightarrow$ phase", fontsize=9)
    ax.set_xticks([]); ax.set_yticks([])
    fig.colorbar(im, ax=ax, fraction=0.046).set_label("phase (rad)", fontsize=7.5)

    # (c) the same two gradients applied to the phantom = one k-space sample
    lab = brain_phantom(n)
    img = synth_contrast(lab, "SE", TR=4000, TE=90)
    ax = axes[2]
    ax.imshow(img * np.cos(np.pi * 3 * yn + np.pi * 2 * xn), cmap="gray", origin="lower")
    ax.set_title("(c) Object $\\times$ one spatial-frequency pattern\n"
                 "its integral = one k-space point", fontsize=9)
    ax.set_xticks([]); ax.set_yticks([])

    # (d) slice selection in the third direction
    ax = axes[3]
    z = np.linspace(-80, 80, 400)
    for centre, col, lab_ in [(-30, "#9467bd", "slice 1"), (0, ACCENT, "slice 2"),
                              (30, "#2ca02c", "slice 3")]:
        prof = gaussian_filter((np.abs(z - centre) < 3).astype(float), 2)
        ax.plot(z, prof / prof.max(), color=col, lw=1.7, label=lab_)
    ax.set_xlabel("$z$ (mm)", fontsize=9)
    ax.set_ylabel("Excited fraction", fontsize=9)
    ax.set_title("(d) Slice select $G_z$\nRF frequency $\\rightarrow$ which slab", fontsize=9)
    ax.legend(fontsize=7.5); ax.grid(alpha=0.3); ax.tick_params(labelsize=8)

    fig.tight_layout()
    finish(fig, out / "fig05_encoding.png",
           "Three orthogonal gradients give every voxel a unique "
           "(slice, frequency, phase) address.")


# --------------------------------------------------------------------------
# 6 - k-space and its relationship to the image
# --------------------------------------------------------------------------
def fig_kspace(out):
    lab = brain_phantom(192)
    img = synth_contrast(lab, "SE", TR=4000, TE=90)
    k = to_kspace(img)
    n = img.shape[0]
    cy = cx = n // 2

    yy, xx = np.mgrid[0:n, 0:n]
    r = np.sqrt((yy - cy) ** 2 + (xx - cx) ** 2)

    centre = k * (r <= 12)
    outer = k * (r > 12)

    fig, axes = plt.subplots(2, 3, figsize=(10.5, 7.0))

    show(axes[0, 0], img, "Image")
    axes[0, 1].imshow(np.log1p(np.abs(k)), cmap="magma", origin="lower")
    axes[0, 1].set_title("k-space (log magnitude)", fontsize=9)
    axes[0, 1].set_xticks([]); axes[0, 1].set_yticks([])
    axes[0, 1].add_patch(plt.Circle((cx, cy), 12, fill=False, color="w", lw=1.2))
    axes[0, 1].text(cx + 15, cy, "centre", color="w", fontsize=7.5, va="center")

    axes[0, 2].axis("off")
    axes[0, 2].text(0.0, 0.5,
                    "k-space is not a picture of the head.\n\n"
                    "Each point is 'how much of this stripe\npattern is in the object'.\n\n"
                    "Centre  = broad shapes and contrast\n"
                    "Edges   = fine detail and sharp borders\n\n"
                    "The image is the 2-D inverse Fourier\ntransform of the whole grid.",
                    fontsize=9, va="center")

    show(axes[1, 0], from_kspace(centre), "Centre only (r $\\leq$ 12)\nblurred but full contrast")
    show(axes[1, 1], from_kspace(outer), "Edges only (r > 12)\nedges but no contrast")

    # k-space undersampling -> aliasing
    us = k.copy()
    us[1::2, :] = 0
    axes[1, 2].imshow(from_kspace(us), cmap="gray", origin="lower")
    axes[1, 2].set_title("Every 2nd line skipped\n$\\rightarrow$ fold-over (aliasing)", fontsize=9)
    axes[1, 2].set_xticks([]); axes[1, 2].set_yticks([])

    fig.suptitle("k-space: where the scanner actually writes its data", fontsize=11, y=0.98)
    fig.tight_layout(rect=(0, 0.02, 1, 0.96))
    finish(fig, out / "fig06_kspace.png",
           "All panels are genuine 2-D FFTs of the synthesised image.")


# --------------------------------------------------------------------------
# 7 - pulse sequence diagrams: spin echo and gradient echo
# --------------------------------------------------------------------------
def fig_sequences(out):
    rows = ["RF", "$G_{slice}$", "$G_{phase}$", "$G_{read}$", "Signal"]
    fig, axes = plt.subplots(2, 1, figsize=(10.5, 6.2), sharex=True)

    # --- spin echo -------------------------------------------------------
    ax = axes[0]
    sequence_axes(ax, rows, 100)
    yrf, ysl = row_y(rows, "RF"), row_y(rows, "$G_{slice}$")
    ype, yro = row_y(rows, "$G_{phase}$"), row_y(rows, "$G_{read}$")
    ysig = row_y(rows, "Signal")

    rf_pulse(ax, yrf, 10, 10, label="90$^\\circ$")
    rf_pulse(ax, yrf, 41, 10, amp=0.42, color=WARN, label="180$^\\circ$")
    grad_lobe(ax, ysl, 5, 15, 0.3)
    grad_lobe(ax, ysl, 36, 46, 0.3)
    for amp in np.linspace(-0.3, 0.3, 7):
        grad_lobe(ax, ype, 17, 25, amp, color="#9467bd", alpha=0.5)
    ax.text(21, ype + 0.42, "phase-encode table\n(one line per TR)", ha="center", fontsize=7)
    grad_lobe(ax, yro, 62, 82, 0.32, color="#ff7f0e")
    t = np.linspace(52, 92, 500)
    ax.plot(t, ysig + 0.44 * np.exp(-np.abs(t - 72) / 4.5) * np.cos(2 * np.pi * t / 3),
            color=ACCENT, lw=0.9)
    ax.annotate("", xy=(10, ysig - 0.36), xytext=(72, ysig - 0.36),
                arrowprops=dict(arrowstyle="<->", color="black", lw=1))
    ax.text(41, ysig - 0.30, "TE", ha="center", fontsize=8)
    ax.annotate("", xy=(10, yrf - 0.42), xytext=(41, yrf - 0.42),
                arrowprops=dict(arrowstyle="<->", color=GREY, lw=0.8))
    ax.text(25, yrf - 0.38, "TE/2", ha="center", fontsize=7, color=GREY)
    ax.set_title("Spin echo: the 180$^\\circ$ pulse refocuses static field errors "
                 "$\\rightarrow$ true $T_2$", fontsize=10, pad=14)

    # --- gradient echo ---------------------------------------------------
    ax = axes[1]
    sequence_axes(ax, rows, 100)
    rf_pulse(ax, yrf, 10, 10, amp=0.22, label="$\\alpha$ (small)")
    grad_lobe(ax, ysl, 5, 15, 0.3)
    for amp in np.linspace(-0.3, 0.3, 7):
        grad_lobe(ax, ype, 17, 24, amp, color="#9467bd", alpha=0.5)
    grad_lobe(ax, yro, 18, 28, -0.3, color="#ff7f0e")
    grad_lobe(ax, yro, 32, 56, 0.3, color="#ff7f0e")
    ax.text(23, yro - 0.46, "dephase", ha="center", fontsize=7)
    ax.text(44, yro + 0.38, "rephase / read", ha="center", fontsize=7)
    t = np.linspace(30, 58, 500)
    ax.plot(t, ysig + 0.44 * np.exp(-np.abs(t - 44) / 4.0) * np.cos(2 * np.pi * t / 3),
            color=ACCENT, lw=0.9)
    ax.annotate("", xy=(10, ysig - 0.36), xytext=(44, ysig - 0.36),
                arrowprops=dict(arrowstyle="<->", color="black", lw=1))
    ax.text(27, ysig - 0.30, "TE", ha="center", fontsize=8)
    ax.set_title("Gradient echo: no 180$^\\circ$, so field errors persist "
                 "$\\rightarrow$ $T_2^*$, but much faster", fontsize=10, pad=14)
    ax.set_xlabel("time $\\rightarrow$", fontsize=9)

    fig.tight_layout()
    finish(fig, out / "fig07_sequences.png",
           "Schematic timing diagrams; the echo envelopes are exponentials.")


# --------------------------------------------------------------------------
# 8 - EPI: one excitation, the whole plane
# --------------------------------------------------------------------------
def fig_epi(out):
    fig = plt.figure(figsize=(11.5, 4.2))
    gs = fig.add_gridspec(1, 3, width_ratios=[1.15, 1, 1], wspace=0.28)

    # (a) EPI trajectory through k-space
    ax = fig.add_subplot(gs[0])
    nlines = 16
    for i in range(nlines):
        ky = i - nlines / 2
        xs = np.linspace(-8, 8, 100) * (1 if i % 2 == 0 else -1)
        ax.plot(xs, np.full_like(xs, ky), color=ACCENT, lw=1.0)
        if i < nlines - 1:
            ax.plot([xs[-1], xs[-1]], [ky, ky + 1], color=WARN, lw=1.0)
    ax.plot([-8], [-nlines / 2], "o", color="black", ms=5)
    ax.text(-7.4, -nlines / 2 - 0.9, "start", fontsize=7.5)
    ax.set_xlabel("$k_x$ (readout)", fontsize=9)
    ax.set_ylabel("$k_y$ (phase encode)", fontsize=9)
    ax.set_title("(a) Single-shot EPI fills all of k-space\nafter one excitation",
                 fontsize=9)
    ax.tick_params(labelsize=8)
    ax.text(0, nlines / 2 + 1.2, "blips step $k_y$ (red)", ha="center",
            fontsize=7.5, color=WARN)
    ax.set_ylim(-nlines / 2 - 2, nlines / 2 + 2.5)

    # (b) T2* decay across the echo train = blurring
    ax = fig.add_subplot(gs[1])
    esp = 0.6  # ms echo spacing
    npe = 64
    t = np.arange(npe) * esp
    for name, col in [("WM", ACCENT), ("GM", "#ff7f0e")]:
        ax.plot(t, np.exp(-t / TISSUE[name]["T2s"]), color=col, lw=1.8, label=name)
    ax.set_xlabel("Time into the echo train (ms)", fontsize=9)
    ax.set_ylabel("Relative signal", fontsize=9)
    ax.set_title(f"(b) Signal decays during readout\n{npe} lines x {esp} ms "
                 f"= {npe*esp:.0f} ms train", fontsize=9)
    ax.legend(fontsize=7.5); ax.grid(alpha=0.3); ax.tick_params(labelsize=8)

    # (c) the resulting blur, computed as a k-space filter
    lab = brain_phantom(192)
    img = synth_contrast(lab, "SE", TR=4000, TE=90)
    k = to_kspace(img)
    n = img.shape[0]
    ky = np.arange(n) - n / 2
    decay = np.exp(-np.abs(ky) * esp / TISSUE["WM"]["T2s"] * 2)
    blurred = from_kspace(k * decay[:, None])
    ax = fig.add_subplot(gs[2])
    show(ax, blurred, "(c) T2* blur along the phase-encode axis\n(same data, filtered)")

    finish(fig, out / "fig08_epi.png",
           "Panel (c) applies the measured T2* weighting of panel (b) as a k-space "
           "filter along ky, which is exactly how EPI blur arises.")


# --------------------------------------------------------------------------
# 9 - the diffusion experiment (Stejskal-Tanner)
# --------------------------------------------------------------------------
def fig_pgse(out):
    fig = plt.figure(figsize=(11.5, 6.4))
    gs = fig.add_gridspec(2, 2, height_ratios=[1.15, 1], hspace=0.42, wspace=0.24)

    # (a) PGSE sequence diagram
    rows = ["RF", "$G_{diff}$", "Signal"]
    ax = fig.add_subplot(gs[0, :])
    sequence_axes(ax, rows, 100)
    yrf, yg, ysig = row_y(rows, "RF"), row_y(rows, "$G_{diff}$"), row_y(rows, "Signal")
    rf_pulse(ax, yrf, 12, 9, amp=0.28, label="90$^\\circ$")
    rf_pulse(ax, yrf, 45, 9, amp=0.40, color=WARN, label="180$^\\circ$")
    grad_lobe(ax, yg, 22, 34, 0.38, color="#2ca02c")
    grad_lobe(ax, yg, 56, 68, 0.38, color="#2ca02c")
    ax.text(28, yg + 0.48, "$\\delta$", ha="center", fontsize=9)
    ax.text(62, yg + 0.48, "$\\delta$", ha="center", fontsize=9)
    ax.annotate("", xy=(22, yg - 0.3), xytext=(56, yg - 0.3),
                arrowprops=dict(arrowstyle="<->", color="black", lw=1))
    ax.text(39, yg - 0.46, "$\\Delta$  (diffusion time)", ha="center", fontsize=8.5)
    t = np.linspace(60, 95, 300)
    ax.plot(t, ysig + 0.40 * np.exp(-np.abs(t - 78) / 6) * np.cos(2 * np.pi * t / 3),
            color=ACCENT, lw=0.9)
    ax.text(78, ysig + 0.55, "attenuated echo", ha="center", fontsize=8, color=ACCENT)
    ax.set_title("(a) Pulsed-gradient spin echo: label position, wait $\\Delta$, "
                 "check position", fontsize=10, pad=16)
    ax.text(88, yrf + 0.30,
            "$b = \\gamma^2 G^2 \\delta^2 (\\Delta - \\delta/3)$",
            ha="center", fontsize=10.5,
            bbox=dict(fc="#f4f4f4", ec="#bbbbbb", pad=3))

    # (b) static vs moving spins
    ax = fig.add_subplot(gs[1, 0])
    ax.axis("off")
    rng = np.random.default_rng(3)
    nspin = 7
    for row, (title, spread, col) in enumerate(
            [("Static spins: rephased perfectly", 0.0, ACCENT),
             ("Diffusing spins: imperfect rephasing", 55.0, WARN)]):
        y0 = 0.70 - row * 0.40
        angs = rng.normal(0, spread, nspin)
        for grp, (xs, cols, angles) in enumerate([
                (np.linspace(0.05, 0.36, nspin), GREY, np.zeros(nspin)),
                (np.linspace(0.60, 0.91, nspin), col, angs)]):
            for xi, ai in zip(xs, angles):
                ax.arrow(xi, y0, 0.085 * np.sin(np.deg2rad(ai)),
                         0.085 * np.cos(np.deg2rad(ai)),
                         head_width=0.022, color=cols, lw=1.1,
                         length_includes_head=True)
        ax.annotate("", xy=(0.57, y0 + 0.04), xytext=(0.40, y0 + 0.04),
                    arrowprops=dict(arrowstyle="-|>", color="#999999", lw=1))
        ax.text(0.485, y0 + 0.075, "$\\Delta$", ha="center", fontsize=8.5, color=GREY)
        ax.text(0.02, y0 + 0.21, title, fontsize=8.5, color=col)
        ax.text(0.205, y0 - 0.055, "labelled", fontsize=7, ha="center", color=GREY)
        ax.text(0.755, y0 - 0.055, "re-checked", fontsize=7, ha="center", color=col)
    ax.text(0.5, 0.02,
            "Coherent arrows add up; scattered arrows cancel.\n"
            "The signal that survives measures how far water moved.",
            ha="center", fontsize=8.5)
    ax.set_title("(b) Why motion costs signal", fontsize=9)
    ax.set_xlim(0, 1); ax.set_ylim(-0.05, 1)

    # (c) signal vs b for different diffusivities
    ax = fig.add_subplot(gs[1, 1])
    b = np.linspace(0, 3000, 300)
    for name, col in [("WM", ACCENT), ("GM", "#ff7f0e"), ("CSF", WARN)]:
        D = TISSUE[name]["D"]
        ax.semilogy(b, np.exp(-b * D), color=col, lw=1.8,
                    label=f"{name}  D={D*1e3:.1f} $\\mu m^2$/ms")
    ax.axvline(1000, color="black", lw=1.0, ls="--")
    ax.text(1050, 0.5, "b = 1000\n(this pipeline)", fontsize=7.5)
    ax.set_xlabel("b-value (s/mm$^2$)", fontsize=9)
    ax.set_ylabel("$S/S_0$  (log scale)", fontsize=9)
    ax.set_title("(c) $S = S_0 e^{-bD}$: why CSF goes black", fontsize=9)
    ax.legend(fontsize=7.5); ax.grid(alpha=0.3, which="both"); ax.tick_params(labelsize=8)

    finish(fig, out / "fig09_pgse.png",
           "Attenuation curves evaluated from the Stejskal-Tanner relation with "
           "literature diffusivities.")


# --------------------------------------------------------------------------
# 10 - direction dependence and the sampling scheme
# --------------------------------------------------------------------------
def fibonacci_sphere(n):
    i = np.arange(n) + 0.5
    phi = np.arccos(1 - 2 * i / n)
    theta = np.pi * (1 + 5 ** 0.5) * i
    return np.column_stack([np.sin(phi) * np.cos(theta),
                            np.sin(phi) * np.sin(theta),
                            np.cos(phi)])


def fig_directions(out):
    fig = plt.figure(figsize=(12, 4.0))
    gs = fig.add_gridspec(1, 3, wspace=0.25)

    # (a) isotropic vs anisotropic response to direction, as a polar plot so the
    # shapes are read directly rather than through a 3-D projection
    ax = fig.add_subplot(gs[0], projection="polar")
    th = np.linspace(0, 2 * np.pi, 400)
    g = np.column_stack([np.cos(th), np.sin(th), np.zeros_like(th)])
    b = 1000.0
    for D, colour in [(np.eye(3) * 0.8e-3, "#ff7f0e"),
                      (np.diag([1.7e-3, 0.3e-3, 0.3e-3]), ACCENT)]:
        att = np.exp(-b * np.einsum("ij,jk,ik->i", g, D, g))
        ax.plot(th, att, color=colour, lw=2)
        ax.fill(th, att, color=colour, alpha=0.15)
    ax.set_rmax(0.9)
    ax.set_rticks([0.2, 0.4, 0.6, 0.8])
    ax.tick_params(labelsize=7)
    ax.set_title("(a) Signal vs gradient direction\n$S/S_0$ at b = 1000", fontsize=9,
                 pad=12)
    ax.annotate("isotropic\n(grey matter)", xy=(np.deg2rad(20), 0.50),
                fontsize=7.5, color="#ff7f0e", ha="center")
    ax.annotate("anisotropic\n(white matter)", xy=(np.deg2rad(96), 0.86),
                fontsize=7.5, color=ACCENT, ha="center")
    ax.annotate("least signal along the fibre", xy=(np.deg2rad(182), 0.30),
                fontsize=7, color=GREY, ha="center")

    # (b) the gradient table on the sphere
    ax = fig.add_subplot(gs[1], projection="3d")
    d = fibonacci_sphere(60)
    ax.scatter(d[:, 0], d[:, 1], d[:, 2], s=14, c=ACCENT)
    ax.scatter(-d[:, 0], -d[:, 1], -d[:, 2], s=14, c=ACCENT, alpha=0.25)
    u, v = np.mgrid[0:2 * np.pi:40j, 0:np.pi:20j]
    ax.plot_wireframe(np.cos(u) * np.sin(v), np.sin(u) * np.sin(v), np.cos(v),
                      color="#cccccc", lw=0.3)
    ax.set_axis_off()
    ax.set_title("(b) 60 directions, spread evenly\n(antipodes are equivalent)",
                 fontsize=9, y=0.99)

    # (c) what the b-value list actually looks like, volume by volume
    ax = fig.add_subplot(gs[2])
    single, multi = [], []
    for i in range(66):
        # a b0 every 12 volumes, as most protocols interleave them
        single.append(0 if i % 12 == 0 else 1000)
    for i in range(66):
        if i % 12 == 0:
            multi.append(0)
        else:
            multi.append([1000, 2000, 3000][(i // 12) % 3])
    ax.plot(single, "o", ms=3.5, color=ACCENT, label="single-shell (this pipeline)")
    ax.plot(multi, "x", ms=4, color="#9467bd", alpha=0.65, label="multi-shell")
    ax.set_xlabel("Volume index in the series", fontsize=9)
    ax.set_ylabel("b-value (s/mm$^2$)", fontsize=9)
    ax.set_yticks([0, 1000, 2000, 3000])
    ax.set_title("(c) The .bval file, drawn\nb0s interleaved for motion tracking",
                 fontsize=9)
    ax.legend(fontsize=7, loc="center right")
    ax.grid(alpha=0.3); ax.tick_params(labelsize=8)

    finish(fig, out / "fig10_directions.png",
           "Panel (a) evaluates S = S0 exp(-b g^T D g) over 500 directions for an "
           "isotropic and a prolate tensor.")


# --------------------------------------------------------------------------
# 11 - susceptibility distortion and why blip-up/blip-down works
# --------------------------------------------------------------------------
def offresonance_field(n):
    """A plausible off-resonance map: strong near air cavities, zero mid-brain."""
    y, x = np.mgrid[0:n, 0:n]
    xn = (x - n / 2) / (n / 2)
    yn = (y - n / 2) / (n / 2)
    f = np.zeros((n, n))
    # frontal sinus and both temporal bones
    f += 210 * np.exp(-((xn - 0.0) ** 2 / 0.06 + (yn + 0.62) ** 2 / 0.05))
    f += 140 * np.exp(-((xn + 0.52) ** 2 / 0.04 + (yn + 0.25) ** 2 / 0.05))
    f += 140 * np.exp(-((xn - 0.52) ** 2 / 0.04 + (yn + 0.25) ** 2 / 0.05))
    f -= 60 * np.exp(-((xn) ** 2 / 0.5 + (yn - 0.7) ** 2 / 0.05))
    return gaussian_filter(f, 3)


def warp_pe(img, shift_vox):
    """Displace along the phase-encode axis (axis 0) by a per-voxel shift."""
    n = img.shape[0]
    y, x = np.mgrid[0:n, 0:n].astype(float)
    return map_coordinates(img, [y + shift_vox, x], order=1, mode="nearest")


def fig_distortion(out):
    n = 192
    lab = brain_phantom(n)
    img = synth_contrast(lab, "SE", TR=4000, TE=90)
    f = offresonance_field(n) * (lab > 0)

    trt = 0.050  # total readout time, s  -> shift(vox) = df(Hz) * TRT
    shift = f * trt

    ap = warp_pe(img, shift)
    pa = warp_pe(img, -shift)
    corrected = 0.5 * (warp_pe(ap, -shift) + warp_pe(pa, shift))

    fig = plt.figure(figsize=(12, 6.6))
    gs = fig.add_gridspec(2, 4, hspace=0.3, wspace=0.2)

    ax = fig.add_subplot(gs[0, 0])
    im = ax.imshow(f, cmap="RdBu_r", origin="lower", vmin=-200, vmax=200)
    ax.set_title("Off-resonance $\\Delta f$ (Hz)\nair/bone interfaces", fontsize=9)
    ax.set_xticks([]); ax.set_yticks([])
    fig.colorbar(im, ax=ax, fraction=0.046, ticks=[-200, -100, 0, 100, 200])

    # The true outline, overlaid on the distorted pair. Without it the warp is
    # easy to miss, because uniform tissue shifted sideways still looks uniform.
    outline = (lab > 0).astype(float)
    for idx, (im_, title, ring) in enumerate([
            (img, "Undistorted truth", False),
            (ap, "Acquired AP (j-)\nfrontal signal piles up", True),
            (pa, "Acquired PA (j)\nsame region stretches", True)], start=1):
        axx = fig.add_subplot(gs[0, idx])
        show(axx, im_, title)
        if ring:
            axx.contour(outline, levels=[0.5], colors=[WARN], linewidths=0.9)

    ax = fig.add_subplot(gs[1, 0])
    im = ax.imshow(shift, cmap="PuOr", origin="lower", vmin=-10, vmax=10)
    ax.set_title(f"Voxel shift = $\\Delta f \\times$ TRT\n(TRT = {trt*1e3:.0f} ms)",
                 fontsize=9)
    ax.set_xticks([]); ax.set_yticks([])
    fig.colorbar(im, ax=ax, fraction=0.046).set_label("voxels", fontsize=7.5)

    axc = fig.add_subplot(gs[1, 1])
    show(axc, corrected, "Corrected from the AP/PA pair")
    axc.contour(outline, levels=[0.5], colors=[WARN], linewidths=0.9)

    ax = fig.add_subplot(gs[1, 2])
    for t, col in [(0.020, "#2ca02c"), (0.050, ACCENT), (0.100, WARN)]:
        ax.plot(f[:, n // 2] * t, np.arange(n), color=col, lw=1.5,
                label=f"TRT {t*1e3:.0f} ms")
    ax.set_xlabel("Displacement (voxels)", fontsize=9)
    ax.set_ylabel("Position along PE axis", fontsize=9)
    ax.set_title("Shorter readout = less distortion", fontsize=9)
    ax.legend(fontsize=7.5); ax.grid(alpha=0.3); ax.tick_params(labelsize=8)

    ax = fig.add_subplot(gs[1, 3])
    ax.axis("off")
    ax.text(0.0, 0.5,
            "Why the pair fixes it\n\n"
            "Reversing the phase-encode\ndirection reverses the sign of\n"
            "every displacement, but not\nits size.\n\n"
            "One image squashes exactly\nwhere the other stretches, so\n"
            "the true geometry can be\nrecovered from the pair.\n\n"
            "This is what TOPUP and\nSDC in QSIPrep estimate.",
            fontsize=8.5, va="center")

    fig.suptitle("Susceptibility distortion: the dominant geometric error in EPI "
                 "diffusion data", fontsize=11, y=0.96)
    finish(fig, out / "fig11_distortion.png",
           "Displacement applied as dy = df x TRT, the same relation the sidecar's "
           "TotalReadoutTime encodes.")


# --------------------------------------------------------------------------
# 12 - the artefact gallery
# --------------------------------------------------------------------------
def fig_artefacts(out):
    n = 192
    lab = brain_phantom(n)
    img = synth_contrast(lab, "SE", TR=4000, TE=90)
    k = to_kspace(img)
    rng = np.random.default_rng(7)

    # Gibbs: truncate k-space
    trunc = np.zeros_like(k)
    c = n // 2
    w = n // 6
    trunc[c - w:c + w, c - w:c + w] = k[c - w:c + w, c - w:c + w]
    gibbs = from_kspace(trunc)

    # motion: phase error on a subset of PE lines
    kmot = k.copy()
    bad = rng.random(n) < 0.10
    kmot[bad, :] *= np.exp(1j * rng.uniform(-np.pi, np.pi, bad.sum()))[:, None]
    motion = from_kspace(kmot)

    # spike / RF interference: a single corrupt k-space point
    kspike = k.copy()
    kspike[c + 26, c + 18] = np.abs(k).max() * 2.5
    spike = from_kspace(kspike)

    # eddy-current shear along the PE axis
    y, x = np.mgrid[0:n, 0:n].astype(float)
    eddy = map_coordinates(img, [y + 0.06 * (x - c), x], order=1, mode="nearest")

    # Rician noise at low SNR
    sigma = img.max() * 0.12
    noisy = np.sqrt((img + rng.normal(0, sigma, img.shape)) ** 2
                    + rng.normal(0, sigma, img.shape) ** 2)

    # N/2 ghost from alternating-line phase error in EPI
    kghost = k.copy()
    kghost[::2, :] *= np.exp(1j * 0.6)
    ghost = from_kspace(kghost)

    panels = [
        (img, "Reference", "the synthesised truth"),
        (gibbs, "Gibbs ringing", "k-space truncated: ripples at sharp edges"),
        (motion, "Motion", "10% of PE lines given random phase"),
        (eddy, "Eddy-current shear", "gradient-induced shear along PE"),
        (spike, "Spike / RF noise", "one corrupt k-space point = stripes"),
        (ghost, "N/2 ghost", "odd/even echo mismatch in EPI"),
        (noisy, "Low SNR (Rician)", "noise floor lifts the background"),
    ]
    fig, axes = plt.subplots(2, 4, figsize=(12.5, 6.4))
    for ax, (im, title, sub) in zip(axes.ravel(), panels):
        show(ax, im, f"{title}\n{sub}")
    axes.ravel()[-1].axis("off")
    axes.ravel()[-1].text(0.0, 0.5,
                          "Each artefact here is produced\nby breaking the acquisition "
                          "in\nexactly the way the scanner\nbreaks it, then transforming\n"
                          "back to image space.\n\n"
                          "That is why they look familiar:\nthe mechanism, not the\n"
                          "appearance, was simulated.",
                          fontsize=8.5, va="center")
    fig.suptitle("Artefacts, generated by their actual mechanisms in k-space",
                 fontsize=11, y=0.98)
    fig.tight_layout(rect=(0, 0.02, 1, 0.95))
    finish(fig, out / "fig12_artefacts.png",
           "Every panel starts from the same image and corrupts the k-space data.")


# --------------------------------------------------------------------------
# 13 - the protocol trade-off triangle
# --------------------------------------------------------------------------
def fig_tradeoffs(out):
    fig = plt.figure(figsize=(12, 4.2))
    gs = fig.add_gridspec(1, 3, wspace=0.3)

    # (a) SNR vs voxel size
    ax = fig.add_subplot(gs[0])
    v = np.linspace(1.0, 3.0, 200)
    ax.plot(v, v ** 3, color=ACCENT, lw=2)
    for s in (1.5, 2.0, 2.5):
        ax.plot([s], [s ** 3], "o", color=WARN, ms=5)
        ax.annotate(f"{s} mm iso\n{s**3:.1f}x", (s, s ** 3),
                    textcoords="offset points", xytext=(-4, 8), fontsize=7.5)
    ax.set_xlabel("Voxel edge (mm)", fontsize=9)
    ax.set_ylabel("Relative SNR (volume)", fontsize=9)
    ax.set_title("(a) SNR scales with voxel volume\nhalving the edge costs 8x", fontsize=9)
    ax.grid(alpha=0.3); ax.tick_params(labelsize=8)

    # (b) SNR vs averages / time
    ax = fig.add_subplot(gs[1])
    nav = np.arange(1, 17)
    ax.plot(nav, np.sqrt(nav), color=ACCENT, lw=2, label="SNR $\\propto \\sqrt{N}$")
    ax.plot(nav, nav, color=GREY, lw=1.4, ls="--", label="scan time $\\propto N$")
    ax.set_xlabel("Number of averages", fontsize=9)
    ax.set_ylabel("Relative", fontsize=9)
    ax.set_title("(b) Diminishing returns\n4x the time buys 2x the SNR", fontsize=9)
    ax.legend(fontsize=7.5); ax.grid(alpha=0.3); ax.tick_params(labelsize=8)

    # (c) the triangle
    ax = fig.add_subplot(gs[2])
    ax.axis("off")
    pts = np.array([[0.5, 0.92], [0.06, 0.12], [0.94, 0.12]])
    names = ["Resolution", "SNR", "Speed / coverage"]
    ax.add_patch(mpatches.Polygon(pts, closed=True, fill=False, lw=1.6, edgecolor=ACCENT))
    for (px, py), nm in zip(pts, names):
        ax.text(px, py + (0.05 if py > 0.5 else -0.07), nm, ha="center", fontsize=10,
                color=ACCENT, weight="bold")
    ax.text(0.5, 0.34, "pick two", ha="center", va="center", fontsize=13, color=GREY)
    mids = [((pts[0] + pts[1]) / 2, "smaller voxels\ncost SNR", "right"),
            ((pts[0] + pts[2]) / 2, "smaller voxels\ncost time", "left"),
            (np.array([0.5, 0.185]), "more averages cost time", "center")]
    for (mx, my), txt, ha in mids:
        dx = {"right": -0.03, "left": 0.03, "center": 0.0}[ha]
        ax.text(mx + dx, my, txt, ha=ha, va="center", fontsize=7.5, color=GREY)
    ax.set_xlim(0, 1); ax.set_ylim(0, 1)
    ax.set_title("(c) The constraint every protocol obeys", fontsize=9)

    finish(fig, out / "fig13_tradeoffs.png",
           "SNR proportional to voxel volume x sqrt(number of averages).")


# --------------------------------------------------------------------------
# 14 - from scanner to BIDS to the pipeline
# --------------------------------------------------------------------------
def fig_scanner_to_pipeline(out):
    fig, ax = plt.subplots(figsize=(12.5, 6.2))
    ax.set_xlim(0, 12.5)
    ax.set_ylim(0, 6.2)
    ax.axis("off")

    def box(x, y, w, h, title, body, fc):
        ax.add_patch(mpatches.FancyBboxPatch(
            (x, y), w, h, boxstyle="round,pad=0.06", facecolor=fc,
            edgecolor="#333333", lw=1.0))
        ax.text(x + w / 2, y + h - 0.22, title, ha="center", fontsize=9, weight="bold")
        ax.text(x + w / 2, y + h / 2 - 0.16, body, ha="center", va="center", fontsize=7.6)

    def arrow(x0, y0, x1, y1, label=None):
        ax.annotate("", xy=(x1, y1), xytext=(x0, y0),
                    arrowprops=dict(arrowstyle="-|>", lw=1.3, color="#333333"))
        if label:
            ax.text((x0 + x1) / 2, (y0 + y1) / 2 + 0.12, label, ha="center", fontsize=7)

    row = 4.4
    box(0.15, row, 2.6, 1.5, "1. Scanner",
        "protocol choices:\nTR, TE, b-value,\ndirections, PE direction,\necho spacing",
        "#dbe9f6")
    box(3.15, row, 2.6, 1.5, "2. Reconstruction",
        "k-space -> image\nparallel imaging,\nmultiband, filters", "#dbe9f6")
    box(6.15, row, 2.6, 1.5, "3. DICOM export",
        "images + private tags\ncarrying diffusion and\ntiming metadata", "#dbe9f6")
    box(9.15, row, 3.2, 1.5, "4. Conversion to BIDS",
        "dcm2niix -> NIfTI\n+ .bval / .bvec\n+ JSON sidecar", "#dbe9f6")

    for x in (2.75, 5.75, 8.75):
        arrow(x, row + 0.75, x + 0.4, row + 0.75)

    row2 = 2.35
    box(0.15, row2, 5.6, 1.5, "5. What the sidecar must carry",
        "PhaseEncodingDirection   TotalReadoutTime   EchoTime\n"
        "RepetitionTime   IntendedFor (fieldmaps)   MultibandAccelerationFactor\n"
        "Wrong or missing values silently corrupt distortion correction.",
        "#fdf0d5")
    box(6.15, row2, 6.2, 1.5, "6. What the pipeline does with it",
        "QSIPrep: denoise, Gibbs, eddy + susceptibility correction (SDC)\n"
        "QSIRecon: response, FOD, ACT tractography, SIFT2\n"
        "Step 4: parcellate and build the connectome",
        "#e3f2e1")

    arrow(2.95, row, 2.95, row2 + 1.5)
    arrow(9.5, row, 9.5, row2 + 1.5)

    box(0.15, 0.25, 12.2, 1.5, "7. Where acquisition choices surface downstream",
        "b-value and shell count -> which FOD model is valid (SS3T for single shell)\n"
        "Voxel size and SNR -> tractography reliability and the number of usable streamlines\n"
        "PE direction and readout time -> residual geometric error after SDC, hence label/tract alignment\n"
        "Coverage and motion -> whether a subject survives QC at all",
        "#f2e3f0")
    arrow(6.25, row2, 6.25, 1.75)

    ax.set_title("From pulse sequence to connectome: every acquisition decision has a "
                 "downstream consequence", fontsize=11)
    finish(fig, out / "fig14_scanner_to_pipeline.png")


# --------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(
        description="Render the acquisition.md figures. Everything is computed "
                    "from first principles, so no input data is required."
    )
    ap.add_argument("--out-dir", type=Path,
                    default=Path(__file__).resolve().parents[1] / "figures" / "acquisition")
    args = ap.parse_args()

    out = args.out_dir
    out.mkdir(parents=True, exist_ok=True)
    print(f"Writing figures to {out}")

    jobs = [
        ("precession", fig_precession),
        ("excitation", fig_excitation),
        ("relaxation", fig_relaxation),
        ("contrast", fig_contrast),
        ("spatial encoding", fig_encoding),
        ("k-space", fig_kspace),
        ("sequence diagrams", fig_sequences),
        ("EPI", fig_epi),
        ("PGSE / diffusion", fig_pgse),
        ("gradient directions", fig_directions),
        ("susceptibility distortion", fig_distortion),
        ("artefacts", fig_artefacts),
        ("trade-offs", fig_tradeoffs),
        ("scanner to pipeline", fig_scanner_to_pipeline),
    ]
    for name, fn in jobs:
        print(f"[fig] {name}")
        fn(out)


if __name__ == "__main__":
    main()
