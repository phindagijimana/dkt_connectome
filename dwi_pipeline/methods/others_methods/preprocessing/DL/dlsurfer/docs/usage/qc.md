# Quality control

| Check | How |
|-------|-----|
| Plan sanity | Dry-run first (`dlsurfer run` without `--execute`) |
| Doctor | `dlsurfer doctor` → `[READY]` |
| Step timing / exits | `$SD/$SID/scripts/dlsurfer_metrics.tsv` |
| Segmentation / surfaces | `dlsurfer freeview --sd $SD --sid $SID` (upstream FS GUI; needs `DISPLAY`) |
| Gates | `dlsurfer gates` — experimental profiles stay blocked |
| TopoFit machine + Chamfer | `scripts/score_topofit_tbi_lit.py` → `machine_ok` / `qc_ok` |
| TopoFit FreeView | `work/phase3_topofit/freeview_topofit_qc.sh` |
| Metrics vs SLURM | `scripts/compare_metrics_slurm.py --metrics … --jobid …` |

Lesion arms: compare with-LIT vs no-LIT trees carefully; do not Jaccard non-homologous meshes across arms.

DKT Connectome cohort HTML / Step 5 PDFs are **out of scope** here — use that project’s QC pages after handoff.
