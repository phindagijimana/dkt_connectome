# dwi_pipeline/reports/

Generated, per-subject report figures and drafts. Nothing under this folder
is tracked in git except this README and `scripts/` (see `.gitignore` at the
repo root) -- everything else here is derived from a real subject's pipeline
output and must not be committed.

```
reports/
  scripts/                    <- all visualization code (tracked in git)
    common.py
    build_panels.py
    build_morphometry_panels.py
    build_imaging_panels.py
    build_imaging_stat_overlays.py
    build_subcortical_3d.py
    build_seed_connectivity.py
    venv_enigma_vtk/          <- dedicated venv for the one VTK-dependent script
    README.md                 <- what each script does and how to run it

  sub-<ID>/                   <- one folder per subject (gitignored)
    connectome/                A_matrix, B_connectogram, C_surface_strength, D_summary
    morphometry/                E_thickness, E_surface_area, F_subcortical_summary
    imaging/                    G_segmentation_overlay .. J_dwi_qc
    imaging_stat_overlays/      K_node_strength_on_imaging .. M_volume_map_DKT
    subcortical_3d/             N_subcortical_volumes_raw, N_subcortical_asymmetry
    seed_connectivity/           O_seed_fingerprint_<ABBREV>
    data/                        intermediate volumes shared across scripts
    sample_report.md / .docx              full draft report (all panels, annotated
                                            with engineer + radiologist read)
    sample_report_clinical.md / .docx     trimmed, clinician-facing version
```

See `dwi_pipeline/reports/scripts/README.md` for how to (re)generate every
panel, and `dwi_pipeline/ENIGMA.md` for what is and is not a valid
ENIGMA-style claim about a single subject's data.
