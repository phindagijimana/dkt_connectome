# DLSurfer phases — status

| Phase | Goal | Status in v0.1 |
|-------|------|----------------|
| **0** Spec freeze | Claims, pins, engine choices, XOR engines | **Done** — `docs/CLAIMS.md`, `engines.yaml`, `profiles.yaml` |
| **1** MVP | CLI, doctor, core / core-lesion, dry-run plans, HPC template | **Done** — `dlsurfer` package |
| **2** FS8 + handoff | `fs8`, utilities (EasyReg/SynthMorph/DeepN4), DKT handoff cmd | **Done** — profiles + `dlsurfer handoff-dkt` |
| **3** surf-dl | TopoFit, V2C-Flow, SUGAR, thickness-fast (experimental) | **In progress** — TopoFit ±LIT GPU job; V2C/SUGAR/CTE still open |
| **4** Harden / metrics | metrics TSV on `--execute`, citation boilerplate, publish notes | **Done** — runner summary + `docs/PUBLISH.md` / `LIVE_RUNS.md` |
| **5** Live ops | Cluster bind, EG smoke, specialty gates | **Partial** — container env READY; `core_lesion_eg_smoke` passed; TBI±LIT baseline report; Phase-3 CSR still open |

## Best-ready choices (locked in engines.yaml)

| Stage | Chosen | Why (short) |
|-------|--------|-------------|
| Skull-strip | SynthStrip | Production in FS |
| Bias (optional) | DeepN4 | Best Ready N4 approx |
| Whole-brain seg | FastSurferVINN | Production default; SynthSeg for odd contrast |
| CC / cereb / hypothal | FastSurfer modules | Production parity |
| Lesion | neuroLIT standalone | Production; keeps GPU/CPU split |
| Surfaces (default) | recon-surf | Classical but Production FS contract |
| Surfaces (Phase 3) | TopoFit → V2C-Flow | Production WM / Ready full CSR |
| Volume reg utils | EasyReg + SynthMorph | Production in FS |
| sphere.reg (Phase 3) | SUGAR | Ready dedicated spherical reg |
| Thickness-only | DL-CTE family | Ready; not for connectome |
| Alt engine | FreeSurfer 8 | Production XOR |

## Still required for “live” Phase 5 / science gates

See [`LIVE_RUNS.md`](../lab/LIVE_RUNS.md) and `dlsurfer gates`.

1. Install / bind FastSurfer 2.6 + neuroLIT + FS8 on the cluster → `dlsurfer doctor` READY.  
2. EG smoke: `dlsurfer run --profile core-lesion … --execute` → mark `core_lesion_eg_smoke` passed.  
3. TBI±LIT gate → `tbi_lit_surfaces` passed before promoting `surf-dl-*`.  
4. SynthSeg-PC vs JLF → `synthseg_pc_vs_jlf` passed before IDEAS PC production.  
5. Cohort timing vs legacy multi-job (`dlsurfer_metrics.tsv` + SLURM queue).
