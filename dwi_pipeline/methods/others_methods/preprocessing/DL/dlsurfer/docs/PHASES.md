# DLSurfer phases — status

| Phase | Goal | Status in v0.1 |
|-------|------|----------------|
| **0** Spec freeze | Claims, pins, engine choices, XOR engines | **Done** — `docs/CLAIMS.md`, `engines.yaml`, `profiles.yaml` |
| **1** MVP | CLI, doctor, core / core-lesion, dry-run plans, HPC template | **Done** — `dlsurfer` package |
| **2** FS8 + handoff | `fs8`, utilities (EasyReg/SynthMorph/DeepN4), DKT handoff cmd | **Done** — profiles + `dlsurfer handoff-dkt` |
| **3** surf-dl | TopoFit, V2C-Flow, SUGAR, thickness-fast (experimental) | **Scaffolded** — adapters + gates; live weights not bundled |
| **4** Harden / metrics | metrics TSV on `--execute`, citation boilerplate, publish notes | **Done** — runner metrics + `docs/PUBLISH.md` |

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

## Still required for “live” Phase 3–4 science

1. Install / bind FastSurfer 2.6 + neuroLIT + FS8 on the cluster.  
2. Run EG smoke: `dlsurfer run --profile core-lesion ... --execute`.  
3. TBI±LIT gate before promoting `surf-dl-*` out of experimental.  
4. Cohort timing vs legacy multi-job bounce (metrics TSV).
