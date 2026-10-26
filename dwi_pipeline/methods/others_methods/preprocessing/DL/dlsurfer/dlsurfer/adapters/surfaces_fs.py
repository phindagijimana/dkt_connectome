"""Install DL surface meshes into a FreeSurfer-shaped SUBJECTS_DIR contract.

Maps TopoFit / V2C-Flow / SUGAR (and generic mesh) outputs into::

    $SD/$SID/surf/{lh,rh}.{white,pial,sphere.reg,…}
    $SD/$SID/scripts/dlsurfer_surf_dl.done

so FreeView / aparc / connectome consumers see a recon-surf-like tree.
Does not claim morphometric equivalence to classical recon-surf until gates pass.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from pathlib import Path
from typing import Iterable

FULL_SURF_REQUIRED = (
    "lh.white",
    "rh.white",
    "lh.pial",
    "rh.pial",
)
WHITE_ONLY_REQUIRED = (
    "lh.white",
    "rh.white",
)
SPHERE_REQUIRED = (
    "lh.sphere.reg",
    "rh.sphere.reg",
)
OPTIONAL_SURF = (
    "lh.inflated",
    "rh.inflated",
    "lh.smoothwm",
    "rh.smoothwm",
    "lh.sphere",
    "rh.sphere",
    "lh.sphere.reg",
    "rh.sphere.reg",
)


def subject_surf(sd: Path, sid: str) -> Path:
    return Path(sd) / sid / "surf"


def subject_scripts(sd: Path, sid: str) -> Path:
    return Path(sd) / sid / "scripts"


def _which_mris_convert() -> str | None:
    return shutil.which("mris_convert")


def _is_binary_ply(path: Path) -> bool:
    try:
        with path.open("rb") as fh:
            head = fh.read(256)
    except OSError:
        return False
    if not head.startswith(b"ply"):
        return False
    return b"format binary" in head[:128]


def _write_freesurfer_geometry(src: Path, dest: Path) -> None:
    """Read a mesh (PLY/STL/OBJ/…) and write FreeSurfer binary surf via nibabel."""
    import numpy as np
    import trimesh
    from nibabel.freesurfer import write_geometry

    mesh = trimesh.load(str(src.resolve()), process=False, force="mesh")
    if isinstance(mesh, trimesh.Scene):
        geoms = list(mesh.geometry.values())
        if not geoms:
            raise ValueError(f"empty scene mesh: {src}")
        mesh = geoms[0]
    verts = np.asarray(mesh.vertices, dtype=np.float64)
    faces = np.asarray(mesh.faces, dtype=np.int32)
    if verts.ndim != 2 or verts.shape[1] != 3 or faces.ndim != 2 or faces.shape[1] != 3:
        raise ValueError(f"unsupported mesh topology from {src}")
    write_geometry(str(dest), verts, faces)


def _ply_to_ascii_temp(src: Path) -> Path:
    """Binary PLY → ASCII PLY in a temp file for mris_convert fallback."""
    import os
    import tempfile

    import trimesh

    mesh = trimesh.load(str(src.resolve()), process=False, force="mesh")
    if isinstance(mesh, trimesh.Scene):
        geoms = list(mesh.geometry.values())
        if not geoms:
            raise ValueError(f"empty scene mesh: {src}")
        mesh = geoms[0]
    fd, name = tempfile.mkstemp(suffix=".ply", prefix="dlsurfer_fs_")
    os.close(fd)
    tmp_path = Path(name)
    mesh.export(str(tmp_path), file_type="ply")
    return tmp_path


def _copy_or_convert(src: Path, dest: Path) -> str:
    """Copy mesh into FreeSurfer surf name; convert via mris_convert when needed."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    src = src.resolve()
    if not src.is_file():
        raise FileNotFoundError(f"missing surface mesh: {src}")

    if dest.is_file() and not dest.is_symlink():
        bak = dest.with_name(dest.name + ".recon-surf.bak")
        if not bak.exists():
            shutil.copy2(dest, bak)

    # Prefer FS binary / already-named surfaces as copy
    suffix = src.suffix.lower()
    if suffix in {"", ".mgz"} or src.name.startswith(("lh.", "rh.")):
        if src.resolve() != dest.resolve():
            shutil.copy2(src, dest)
        return "copy"

    mesh_suffixes = {".gii", ".vtk", ".stl", ".ply", ".obj", ".fsmesh"}
    if suffix in mesh_suffixes:
        mesh_err: Exception | None = None
        try:
            _write_freesurfer_geometry(src, dest)
            return "nibabel_fs_geometry"
        except ImportError:
            pass
        except (ValueError, OSError) as exc:
            mesh_err = exc

        mris = _which_mris_convert()
        if not mris:
            if mesh_err is not None:
                raise mesh_err
            shutil.copy2(src, dest)
            return "copy_raw"

        convert_src = src
        tmp_ply: Path | None = None
        if suffix == ".ply" and _is_binary_ply(src):
            tmp_ply = _ply_to_ascii_temp(src)
            convert_src = tmp_ply
        try:
            subprocess.run([mris, str(convert_src), str(dest)], check=True)
        finally:
            if tmp_ply is not None:
                tmp_ply.unlink(missing_ok=True)
        return "mris_convert"

    shutil.copy2(src, dest)
    return "copy_raw"


def _first_hit(roots: Iterable[Path], patterns: tuple[str, ...]) -> Path | None:
    for root in roots:
        if not root.is_dir():
            continue
        for g in patterns:
            if "*" in g:
                hits = sorted(p for p in root.rglob(g) if p.is_file())
            else:
                cand = root / g
                hits = [cand] if cand.is_file() else []
            if hits:
                return hits[0]
    return None


def _discover(backend: str, sd: Path, sid: str, search_dirs: Iterable[Path]) -> dict[str, Path]:
    """Heuristic discovery of DL meshes for a backend."""
    found: dict[str, Path] = {}
    surf = subject_surf(sd, sid)
    roots = [Path(d) for d in search_dirs if d]
    if surf.is_dir():
        roots.insert(0, surf)

    if backend == "topofit":
        for hemi in ("lh", "rh"):
            for cand in (surf / f"{hemi}.white.topofit", surf / f"{hemi}.white"):
                if cand.is_file():
                    found[f"{hemi}.white"] = cand
                    break
            hit = _first_hit(roots, (f"{hemi}.white.topofit", f"{hemi}_white*", f"*{hemi}*white*.gii"))
            if hit and f"{hemi}.white" not in found:
                found[f"{hemi}.white"] = hit
        return found

    patterns: dict[str, tuple[str, ...]] = {
        "lh.white": (
            "lh.white",
            "lh.white.topofit",
            "lh_white_epoch*.ply",
            "lh_white*",
            "*lh*white*.gii",
            "*lh*white*.ply",
        ),
        "rh.white": (
            "rh.white",
            "rh.white.topofit",
            "rh_white_epoch*.ply",
            "rh_white*",
            "*rh*white*.gii",
            "*rh*white*.ply",
        ),
        "lh.pial": (
            "lh.pial",
            "lh.pial.t1",
            "lh_pial_epoch*.ply",
            "lh_pial*",
            "*lh*pial*.gii",
            "*lh*pial*.ply",
        ),
        "rh.pial": (
            "rh.pial",
            "rh.pial.t1",
            "rh_pial_epoch*.ply",
            "rh_pial*",
            "*rh*pial*.gii",
            "*rh*pial*.ply",
        ),
        "lh.sphere.reg": ("lh.sphere.reg", "lh.sphere.reg.sugar", "*lh*sphere*reg*"),
        "rh.sphere.reg": ("rh.sphere.reg", "rh.sphere.reg.sugar", "*rh*sphere*reg*"),
    }
    for name, globs in patterns.items():
        hit = _first_hit(roots, globs)
        if hit:
            found[name] = hit
    return found


def install_surfaces(
    sd: Path,
    sid: str,
    *,
    backend: str = "generic",
    meshes: dict[str, Path] | None = None,
    search_dirs: list[Path] | None = None,
    mode: str = "full",
    replace: bool = True,
    allow_partial_sphere: bool = False,
) -> dict:
    """Install DL surfaces into $SD/$SID/surf. Returns a manifest dict."""
    sd = Path(sd)
    surf = subject_surf(sd, sid)
    scripts = subject_scripts(sd, sid)
    surf.mkdir(parents=True, exist_ok=True)
    scripts.mkdir(parents=True, exist_ok=True)

    discovered = _discover(backend, sd, sid, search_dirs or [])
    if meshes:
        discovered.update({k: Path(v) for k, v in meshes.items() if v})

    if mode == "white":
        required = WHITE_ONLY_REQUIRED
    elif mode == "sphere":
        if allow_partial_sphere:
            required = tuple(r for r in SPHERE_REQUIRED if r in discovered)
            if not required:
                raise FileNotFoundError(
                    f"cannot install FS surface contract ({backend}/{mode}): "
                    f"missing lh/rh sphere.reg meshes. Pass --sphere-lh/… or --search-dir."
                )
        else:
            required = SPHERE_REQUIRED
    else:
        required = FULL_SURF_REQUIRED

    missing = [r for r in required if r not in discovered]
    if missing:
        raise FileNotFoundError(
            f"cannot install FS surface contract ({backend}/{mode}): "
            f"missing meshes for {missing}. Pass --white-lh/… or --search-dir."
        )

    actions: dict[str, str] = {}
    for name, src in discovered.items():
        dest = surf / name
        if not replace and dest.is_file():
            actions[name] = "skipped_exists"
            continue
        actions[name] = _copy_or_convert(src, dest)

    (scripts / "dlsurfer_surf_dl.done").write_text(
        f"backend={backend}\nmode={mode}\nreplace={replace}\n", encoding="utf-8"
    )
    done = scripts / "recon-surf.done"
    if not done.exists():
        done.write_text(
            f"# installed by dlsurfer from DL backend={backend} (not classical recon-surf)\n",
            encoding="utf-8",
        )

    manifest = {
        "sd": str(sd),
        "sid": sid,
        "backend": backend,
        "mode": mode,
        "surf": str(surf),
        "actions": actions,
        "required": list(required),
        "optional_present": [o for o in OPTIONAL_SURF if (surf / o).is_file()],
    }
    (scripts / "dlsurfer_surf_dl_manifest.json").write_text(
        json.dumps(manifest, indent=2), encoding="utf-8"
    )
    return manifest


def check_surf_contract(
    sd: Path, sid: str, *, mode: str = "full", allow_partial_sphere: bool = False
) -> list[str]:
    surf = subject_surf(sd, sid)
    if not surf.is_dir():
        return [f"missing surf/: {surf}"]
    if mode == "sphere" and allow_partial_sphere:
        present = [name for name in SPHERE_REQUIRED if (surf / name).is_file()]
        if present:
            return []
        return ["missing surf/lh.sphere.reg and surf/rh.sphere.reg (partial sphere allowed)"]
    req = {"white": WHITE_ONLY_REQUIRED, "sphere": SPHERE_REQUIRED}.get(mode, FULL_SURF_REQUIRED)
    return [f"missing surf/{name}" for name in req if not (surf / name).is_file()]


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        description="Install DL surface meshes into FreeSurfer SUBJECTS_DIR contract"
    )
    p.add_argument("--sd", type=Path, required=True, help="SUBJECTS_DIR")
    p.add_argument("--sid", required=True)
    p.add_argument(
        "--backend",
        default="generic",
        choices=["generic", "v2c", "topofit", "sugar", "pialnn", "cortexode"],
    )
    p.add_argument(
        "--mode",
        default="full",
        choices=["full", "white", "sphere"],
        help="full=white+pial; white=TopoFit; sphere=sphere.reg only",
    )
    p.add_argument("--search-dir", type=Path, action="append", default=[], dest="search_dirs")
    p.add_argument("--white-lh", type=Path, default=None)
    p.add_argument("--white-rh", type=Path, default=None)
    p.add_argument("--pial-lh", type=Path, default=None)
    p.add_argument("--pial-rh", type=Path, default=None)
    p.add_argument("--sphere-lh", type=Path, default=None)
    p.add_argument("--sphere-rh", type=Path, default=None)
    p.add_argument("--no-replace", action="store_true")
    p.add_argument(
        "--allow-partial-sphere",
        action="store_true",
        help="sphere mode: require only hemispheres that were discovered (e.g. lh-only SUGAR)",
    )
    p.add_argument("--check-only", action="store_true")
    args = p.parse_args(argv)

    if args.check_only:
        probs = check_surf_contract(
            args.sd, args.sid, mode=args.mode, allow_partial_sphere=args.allow_partial_sphere
        )
        if probs:
            print("FAIL:")
            for x in probs:
                print(f"  {x}")
            return 1
        print(f"OK: FS surface contract ({args.mode}) under {args.sd / args.sid / 'surf'}")
        return 0

    meshes: dict[str, Path] = {}
    if args.white_lh:
        meshes["lh.white"] = args.white_lh
    if args.white_rh:
        meshes["rh.white"] = args.white_rh
    if args.pial_lh:
        meshes["lh.pial"] = args.pial_lh
    if args.pial_rh:
        meshes["rh.pial"] = args.pial_rh
    if args.sphere_lh:
        meshes["lh.sphere.reg"] = args.sphere_lh
    if args.sphere_rh:
        meshes["rh.sphere.reg"] = args.sphere_rh

    try:
        man = install_surfaces(
            args.sd,
            args.sid,
            backend=args.backend,
            meshes=meshes or None,
            search_dirs=list(args.search_dirs),
            mode=args.mode,
            replace=not args.no_replace,
            allow_partial_sphere=args.allow_partial_sphere,
        )
    except (FileNotFoundError, subprocess.CalledProcessError) as exc:
        print(f"error: {exc}", flush=True)
        return 2

    print(json.dumps(man, indent=2))
    probs = check_surf_contract(
        args.sd, args.sid, mode=args.mode, allow_partial_sphere=args.allow_partial_sphere
    )
    if probs:
        print("WARN after install:", probs)
        return 1
    print(f"[dlsurfer] FS surface contract installed → {args.sd / args.sid / 'surf'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
