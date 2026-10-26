"""Launch upstream FreeView on a DLSurfer SUBJECTS_DIR tree.

DLSurfer does not reimplement the GUI — this is a thin launcher that prefers
``freeview`` on PATH (after ``source env/cluster_containers.sh``) or falls
back to ``apptainer exec`` of ``DLSURFER_SIF_FREESURFER`` / ``SIF_FREESURFER``.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


def subject_root(sd: Path, sid: str) -> Path:
    return Path(sd).expanduser().resolve() / sid


def build_freeview_argv(
    root: Path,
    *,
    volume: str = "orig.mgz",
    aseg: bool = False,
    surfaces: bool = True,
    white: bool = True,
    pial: bool = False,
    inflated: bool = False,
    hemi: str = "both",
    extra: list[str] | None = None,
) -> list[str]:
    """Build FreeView args (without the ``freeview`` binary)."""
    mri = root / "mri"
    surf = root / "surf"
    vol = mri / volume
    if not vol.is_file():
        # Common FastSurfer / FS names
        for alt in ("orig.mgz", "T1.mgz", "brain.mgz", "norm.mgz"):
            cand = mri / alt
            if cand.is_file():
                vol = cand
                break
        else:
            raise FileNotFoundError(
                f"No volume under {mri} (tried {volume} and common defaults)"
            )

    argv: list[str] = ["-v", str(vol)]
    if aseg:
        for name in ("aseg.mgz", "aparc+aseg.mgz", "aseg.auto.mgz"):
            aseg_p = mri / name
            if aseg_p.is_file():
                argv.extend(["-v", f"{aseg_p}:colormap=lut:opacity=0.25"])
                break

    hemis = ("lh", "rh") if hemi == "both" else (hemi,)
    if surfaces:
        for h in hemis:
            if white:
                w = surf / f"{h}.white"
                if w.is_file():
                    argv.extend(["-f", f"{w}:edgecolor=green:edgethickness=1"])
            if pial:
                p = surf / f"{h}.pial"
                if p.is_file():
                    argv.extend(["-f", f"{p}:edgecolor=red:edgethickness=1"])
            if inflated:
                inf = surf / f"{h}.inflated"
                if inf.is_file():
                    argv.extend(["-f", str(inf)])

    if extra:
        argv.extend(extra)
    return argv


def resolve_freeview_cmd() -> list[str]:
    """Return argv prefix that runs freeview (native or via Apptainer SIF)."""
    native = shutil.which("freeview")
    if native:
        return [native]

    sif = os.environ.get("DLSURFER_SIF_FREESURFER") or os.environ.get("SIF_FREESURFER")
    if not sif or not Path(sif).is_file():
        raise FileNotFoundError(
            "freeview not on PATH and no DLSURFER_SIF_FREESURFER/SIF_FREESURFER. "
            "Source env/cluster_containers.sh (adds env/bin/freeview) or install FreeSurfer."
        )
    apptainer = shutil.which("apptainer") or shutil.which("singularity")
    if not apptainer:
        raise FileNotFoundError("apptainer/singularity not found to run FreeView from SIF")

    cmd = [apptainer, "exec"]
    if os.environ.get("DLSURFER_FS_NV", "1") == "1" and shutil.which("nvidia-smi"):
        cmd.append("--nv")
    # Bind common lab NFS + license so subject trees are visible inside the SIF.
    binds = os.environ.get("DLSURFER_APPTAINER_BINDS", "/mnt/nfs")
    for b in binds.split(","):
        b = b.strip()
        if b:
            cmd.extend(["-B", b])
    lic = os.environ.get("FS_LICENSE")
    if lic and Path(lic).is_file():
        cmd.extend(["-B", f"{lic}:{lic}:ro", "--env", f"FS_LICENSE={lic}"])
    sd = os.environ.get("SUBJECTS_DIR")
    if sd:
        cmd.extend(["--env", f"SUBJECTS_DIR={sd}"])
    cmd.extend([sif, "freeview"])
    return cmd


def check_freeview(*, sd: Path | None = None, sid: str | None = None) -> int:
    """Headless readiness check (binary/SIF + optional subject tree). No GUI."""
    display = os.environ.get("DISPLAY", "")
    try:
        prefix = resolve_freeview_cmd()
    except FileNotFoundError as exc:
        print(f"[MISS] freeview: {exc}")
        return 1
    print(f"[OK ] freeview: {' '.join(prefix[:3])}…")
    if display:
        print(f"[OK ] DISPLAY={display}")
    else:
        print("[MISS] DISPLAY unset (GUI launch needs X11/Wayland / ssh -Y / VNC)")
    if sd is not None and sid is not None:
        root = subject_root(sd, sid)
        if not root.is_dir():
            print(f"[MISS] subject: {root}")
            return 1
        try:
            argv = build_freeview_argv(root)
        except FileNotFoundError as exc:
            print(f"[MISS] volumes/surfaces: {exc}")
            return 1
        print(f"[OK ] subject: {root} ({len(argv)} FreeView args)")
    if not display:
        print("[note] use --dry-run to print the command; GUI needs DISPLAY")
        return 0  # binary OK; display is environmental
    print("[READY] FreeView can launch")
    return 0


def launch_freeview(
    sd: Path,
    sid: str,
    *,
    volume: str = "orig.mgz",
    aseg: bool = False,
    surfaces: bool = True,
    white: bool = True,
    pial: bool = False,
    inflated: bool = False,
    hemi: str = "both",
    extra: list[str] | None = None,
    dry_run: bool = False,
    check_only: bool = False,
) -> int:
    if check_only:
        return check_freeview(sd=sd, sid=sid)

    root = subject_root(sd, sid)
    if not root.is_dir():
        print(f"error: subject tree not found: {root}", file=sys.stderr)
        return 2

    display = os.environ.get("DISPLAY", "")
    if not dry_run and not display:
        print(
            "error: DISPLAY is unset — FreeView needs an X11/Wayland display "
            "(local desktop, SSH -Y, or VNC). Use --dry-run or --check.",
            file=sys.stderr,
        )
        return 2

    try:
        fv_args = build_freeview_argv(
            root,
            volume=volume,
            aseg=aseg,
            surfaces=surfaces,
            white=white,
            pial=pial,
            inflated=inflated,
            hemi=hemi,
            extra=extra,
        )
        prefix = resolve_freeview_cmd()
    except FileNotFoundError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    full = prefix + fv_args
    if dry_run:
        print(" ".join(shlex_quote(a) for a in full))
        return 0

    print(f"[dlsurfer freeview] {root}", flush=True)
    try:
        return subprocess.call(full)
    except OSError as exc:
        print(f"error: failed to launch FreeView: {exc}", file=sys.stderr)
        return 1


def shlex_quote(s: str) -> str:
    if not s or any(c in s for c in " \t\n\"'\\$"):
        return "'" + s.replace("'", "'\"'\"'") + "'"
    return s
