# Live runs — ops checklist

Cluster validation log for DLSurfer gates and one-off jobs. See also
[TBI ± LIT surface report](TBI_LIT_SURFACES_REPORT.md).

## 1. Bind tools

```bash
cd …/preprocessing/DL/dlsurfer
source env/cluster_containers.sh
PYTHONPATH=. python -m dlsurfer doctor   # [READY]
```

Exports SIFs, `SCHAEFER_ANNOT_{LH,RH}`, `V2C_ROOT`, `SUGAR_ROOT`, `SUGAR_FSD`, `SYNTHSEG_PC_*`.
Optional meta-image: `containers/dlsurfer.def` + `entrypoint_bids.sh`.

## 2. EG smoke — **passed** (incl. GPU confirmatory)

| Arm | Status |
|-----|--------|
| Standalone FS2.6+LIT science | Done (prior) |
| GPU job **191960** | **COMPLETED** — `work/eg_gpu_core_lesion/sub-EG/scripts/recon-surf.done` |
| Metrics vs sacct | `work/eg_gpu_core_lesion/metrics_vs_slurm.json` (~6991s compute / 01:56:33 wall) |

Gate: `core_lesion_eg_smoke` → **passed** ([EG_SMOKE_EVIDENCE.md](EG_SMOKE_EVIDENCE.md)).

## 3. Gates

| Gate | Choice (literature) | Status |
|------|---------------------|--------|
| `tbi_lit_topofit` | TopoFit (FS-shipped WM) | **passed** — job + Chamfer QC |
| `tbi_lit_surfaces` | **V2C-Flow** (best Ready full CSR) | **passed** — job **192088** ±LIT |
| `tbi_lit_sphere_sugar` | SUGAR | **passed** — job **192095** (lh-only pretrained) |
| `tbi_lit_v2c_long` | V2C-Long longitudinal | **passed** — job **192111** TrackTBI 2WK+6MO |
| `tbi_lit_thickness` | DL-CTE family | **passed** — job 191968 |
| `synthseg_pc_vs_jlf` | **JLF production** until PC ≥ JLF | **open** — env wired |
| `core_lesion_eg_smoke` | — | **passed** |

```bash
PYTHONPATH=. python -m dlsurfer gates
sbatch hpc/sbatch_phase3_v2c_tbi_lit.sh      # cross-sectional (gate passed)
sbatch hpc/sbatch_phase3_sugar_tbi_lit.sh    # SUGAR (gate passed)
bash scripts/eval_synthseg_pc_vs_jlf.sh      # when SSP_GT_DIR / SSP_IMG_DIR set
```

Scores: `work/phase3_v2c/v2c_tbi_lit_score.json`, `work/phase3_sugar/sugar_tbi_lit_score.json`.

## 4. Schaefer — **executed**

Annots bundled under `resources/schaefer2018/…`. FS wrapper propagates `SUBJECTS_DIR`.

Wrote `lh/rh.schaefer.annot` on:

- standalone FS2.6 EG subjects
- `work/eg_gpu_core_lesion/sub-EG`

```bash
export SUBJECTS_DIR=…/subjects   # must contain fsaverage + sid
python -m dlsurfer run --profile atlas-schaefer --t1 /dev/null --sd "$SUBJECTS_DIR" --sid sub-EG --execute
```

## 5. BIDS App

Derivatives + Boutiques + CI fixture — see [bids_app.md](../bids_app.md).

## 6. Metrics vs legacy SLURM

```bash
python scripts/compare_metrics_slurm.py \
  --metrics work/eg_gpu_core_lesion/sub-EG/scripts/dlsurfer_metrics.tsv \
  --jobid 191960 --out work/eg_gpu_core_lesion/metrics_vs_slurm.json
```
