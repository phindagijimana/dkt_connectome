"""CLI adapters — build commands; do not reimplement engines."""

from dlsurfer.adapters.plan import build_plan
from dlsurfer.adapters.surfaces_fs import check_surf_contract, install_surfaces

__all__ = ["build_plan", "check_surf_contract", "install_surfaces"]