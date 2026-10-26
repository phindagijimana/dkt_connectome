# Live runs — ops checklist

## 1. Bind tools

```bash
cd …/preprocessing/DL/dlsurfer
source env/cluster_containers.sh
PYTHONPATH=. python -m dlsurfer doctor   # [READY]
```

Exports SIFs, `SCHAEFER_ANNOT_{LH,RH}`, `V2C_ROOT`, `SYNTHSEG_PC_*`.  
Optional meta-image: `containers/dlsurfer.def` + `entrypoint_bids.sh`.

## 2. EG smoke — **passed** (incl. GPU confirmatory)

| Arm | Status |
|-----|--------|
| Standalone FS2.6+LIT science | Done (prior) |
| GPU job **191960** | **COMPLETED** — `work/eg_gpu_core_lesion/sub-EG/scripts/recon-surf.done` |
| Metrics vs sacct | `work/eg_gpu_core_lesion/metrics_vs_slurm.json` (~6991s compute / 01:56:33 wall) |

## 3. Gates

| Gate | Choice (literature) | Status |
|------|---------------------|--------|
| `tbi_lit_topofit` | TopoFit (FS-shipped WM) | **passed** + Chamfer QC / FreeView script |
| `tbi_lit_surfaces` | **V2C-Flow** (best Ready full CSR) | **open** — clone + `dlsurfer-v2c`; need `vox2organ` env |
| `tbi_lit_sphere_sugar` | SUGAR | open — set `SUGAR_ROOT` |
| `tbi_lit_thickness` | DL-CTE family | open — set `DL_CTE_ROOT` |
| `synthseg_pc_vs_jlf` | **JLF production** until PC ≥ JLF | open — env wired; Hammers val dirs |
| `core_lesion_eg_smoke` | — | **passed** |

```bash
sbatch hpc/sbatch_phase3_v2c_tbi_lit.sh   # after conda env vox2organ
bash scripts/eval_synthseg_pc_vs_jlf.sh     # when SSP_GT_DIR / SSP_IMG_DIR set
```

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
