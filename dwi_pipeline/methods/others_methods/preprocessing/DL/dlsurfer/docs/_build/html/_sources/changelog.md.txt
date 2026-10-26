# Changelog

## 0.1.1

- Literature-best Phase-3 wiring: **V2C-Flow** CSR (`dlsurfer-v2c`), SUGAR / DL-CTE separate gates  
- TopoFit Chamfer/Hausdorff scoring + FreeView QC script  
- EG GPU confirmatory job 191960 completed (`recon-surf.done`)  
- Schaefer 400/17 annots bundled; `SUBJECTS_DIR` propagated in FS Apptainer wrapper; executed on EG  
- SynthSeg-PC env wired; production PC remains **JLF** until Hammers eval  
- BIDS App: derivatives layout, Boutiques descriptor, container entrypoint, CI fixture  
- Ops: `compare_metrics_slurm.py`, meta-SIF `containers/dlsurfer.def`

## 0.1.0

- Initial public release of DLSurfer orchestrator  
- Profiles: `core`, `core-lesion`, seg-quick, specialty, Phase-3 TopoFit  
- Apptainer cluster wrappers + `dlsurfer doctor` READY path  
- Production gates (`tbi_lit_topofit` passed machine check on EG)  
- MkDocs documentation site (DKT Connectome IA + QSIPrep depth)  
- Methods page: per-engine resources + paper citations (from `engines.yaml`)  
- `dlsurfer bids-app` stub toward BIDS App standard  
