# Report visualization scripts

All the code that turns dwi_pipeline outputs into report-ready figures lives
here, in one place, so it's easy to find and re-run. Each script is
standalone (`python3 build_X.py`, no CLI args) and writes its PNGs straight
into `dwi_pipeline/reports/<subject>/<category>/`. `common.py` holds the
paths and FreeSurfer/DKT lookup helpers every script shares -- edit the
constants at the top of `common.py` to point everything at a different
subject or a different `RESULTS_ROOT`.

| Script | Panels it writes | Category folder | Needs |
|---|---|---|---|
| `build_panels.py` | `A_matrix`, `B_connectogram`, `C_surface_strength`, `D_summary` | `connectome/` | system python3 |
| `build_morphometry_panels.py` | `E_thickness`, `E_surface_area`, `F_subcortical_summary` | `morphometry/` | system python3 |
| `build_imaging_panels.py` | `G_segmentation_overlay`, `H_lesion_overlay_montage`, `I_inpainting_fullbrain_montage`, `J_dwi_qc` | `imaging/` (+ writes native DKT segmentation into `data/`) | system python3 |
| `build_imaging_stat_overlays.py` | `K_node_strength_on_imaging`, `L_volume_map_DK`, `M_volume_map_DKT` | `imaging_stat_overlays/` | system python3 (run after `build_imaging_panels.py`, needs its `data/` output) |
| `build_subcortical_3d.py` | `N_subcortical_volumes_raw`, `N_subcortical_asymmetry` | `subcortical_3d/` | **`venv_enigma_vtk/bin/python3`** (enigmatoolbox + pinned VTK, see below) |
| `build_seed_connectivity.py` | `O_seed_fingerprint_<ABBREV>` per seed | `seed_connectivity/` | system python3 |

Run them all, in order, from the repo root:

```bash
python3 dwi_pipeline/reports/scripts/build_panels.py
python3 dwi_pipeline/reports/scripts/build_morphometry_panels.py
python3 dwi_pipeline/reports/scripts/build_imaging_panels.py
python3 dwi_pipeline/reports/scripts/build_imaging_stat_overlays.py
dwi_pipeline/reports/scripts/venv_enigma_vtk/bin/python3 dwi_pipeline/reports/scripts/build_subcortical_3d.py
python3 dwi_pipeline/reports/scripts/build_seed_connectivity.py
```

## Rebuilding venv_enigma_vtk

`venv_enigma_vtk/` is ~1.7GB and gitignored -- it is not distributed with
the repo. To rebuild it:

```bash
python3 -m venv dwi_pipeline/reports/scripts/venv_enigma_vtk
source dwi_pipeline/reports/scripts/venv_enigma_vtk/bin/activate
pip install numpy pandas matplotlib nibabel
pip install vtk==9.3.1 vtk-osmesa
pip install enigmatoolbox
```

## Why one script needs a separate venv

`enigmatoolbox.plotting.plot_subcortical` renders through VTK. The VTK
version pip installs by default raises `AttributeError: type object
'PointSet' has no attribute '__vtkname__'` inside enigmatoolbox's wrapper,
and this HPC environment has no X server for interactive VTK anyway.
`venv_enigma_vtk` pins `vtk==9.3.1` and installs `vtk-osmesa` (a headless,
software-rendered VTK build) so `build_subcortical_3d.py` can render without
a display. Every other script only needs nibabel/nilearn/networkx/pandas/
matplotlib, which the system python3 already has -- keep it that way rather
than growing one shared environment, since enigmatoolbox's VTK pin is fragile
and specific to that one script.

## What these are, and are not

These scripts render one demo subject's (`sub-PLACEHOLDER`, set via
`REPORT_SUBJECT`) *own* pipeline outputs -- no normative/reference cohort is
used anywhere here. See `dwi_pipeline/ENIGMA.md` for when a real ENIGMA-style
group comparison would require external reference data this pipeline does not
ship, and `dwi_pipeline/reports/sub-PLACEHOLDER/sample_report*.md` for which
of these panels were judged essential enough to put in front of a clinician
versus which are exploratory/engineering-facing.
