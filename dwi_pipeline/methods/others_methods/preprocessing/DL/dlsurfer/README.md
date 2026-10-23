# DLSurfer

**Curated deep-learning morphometry orchestrator** — FreeSurfer-shaped outputs, lesion + device policy, every engine cited.

> DLSurfer does **not** replace FreeSurfer or FastSurfer science. It calls published tools and keeps a `SUBJECTS_DIR` contract for DKT / QSIRecon.

Plan / literature siblings: [`../DLSURFER_PLAN.md`](../DLSURFER_PLAN.md) · [`../CLASSICAL_TO_DL_TABLE.md`](../CLASSICAL_TO_DL_TABLE.md) · [`docs/PHASES.md`](docs/PHASES.md) · [`docs/CLAIMS.md`](docs/CLAIMS.md)

---

## Install

```bash
cd dlsurfer
pip install -e .
dlsurfer doctor
dlsurfer engines
dlsurfer profiles
```

---

## Quick start (dry-run by default)

```bash
dlsurfer run \
  --profile core-lesion \
  --t1 /path/T1.nii.gz \
  --lesion-mask /path/lesion.nii.gz \
  --sd /path/subjects \
  --sid sub-EG \
  --fs-license /path/license.txt \
  --device auto
```

Add `--execute` only after `doctor` is green and the printed plan looks right.

```bash
dlsurfer cite --profile core-lesion
dlsurfer handoff-dkt --sd /path/subjects --sid sub-EG
```

---

## Why each chosen engine is here

Full text lives in `dlsurfer/engines.yaml` (also `dlsurfer engines`). Summary:

| Engine | Replaces (classical) | Why chosen |
|--------|----------------------|------------|
| **SynthStrip** | Watershed skull-strip | Best Production strip in FreeSurfer |
| **DeepN4** | N3/N4 bias | Best Ready portable N4 approx (optional util) |
| **FastSurferVINN** | CA aseg / DKT labels | Primary Production morphometry engine |
| **SynthSeg** | CA aseg (odd contrast) | Production alt for clinical/odd data |
| **FastSurfer-CC / CerebNet / HypVINN** | Limited classical substructure | Production FastSurfer defaults |
| **neuroLIT** | No native FS lesion fill | Production lesion fill; **standalone** default keeps GPU/CPU split |
| **recon-surf** | FS surface stages | Default surfaces — classical but Production FS contract |
| **TopoFit** | Topology + white surface | Best Production DL WM (Phase 3 experimental) |
| **V2C-Flow** | White+pial (+ template IDs) | Best Ready full CSR (Phase 3 experimental) |
| **SUGAR** | sphere.reg | Best Ready spherical reg util (Phase 3) |
| **EasyReg / SynthMorph** | CA volume registration | Production FS registration utils |
| **DL-CTE family** | Surface thickness | Ready fast thickness — **not** for connectome |
| **FreeSurfer 8** | FS≤7 early classical | Alt XOR engine (`fs8`) |

Deferred (documented, not default): HD-BET, VBG, LeAPP VBT, CortexODE, PialNN — see `engines.yaml` `deferred:`.

---

## Profiles

| Profile | Phase | Notes |
|---------|-------|-------|
| `core` | 1 | FastSurfer full morphometry |
| `core-lesion` | 1 | **Recommended lesion path** |
| `core-lesion-native` | 1 | Native `--lesion_mask` (no seg/surf split) |
| `seg-quick` / `seg-quick-synthseg` / `strip` | 1 | Utilities |
| `fs8` / `fs8-lesion` | 2 | FreeSurfer 8 XOR engine |
| `register-*` / `bias-deepn4` | 2 | Utils |
| `surf-dl-topofit` / `surf-dl-v2c` / `sphere-sugar` / `thickness-fast` | 3 | Experimental — TBI±LIT gate |

---

## Phases

See [`docs/PHASES.md`](docs/PHASES.md). v0.1 implements Phase 0–4 as **spec + CLI + adapters + metrics hooks**; live cluster execution still needs FastSurfer/neuroLIT/FS installed (`dlsurfer doctor`).

---

## Citation

```bash
dlsurfer cite --profile <profile>
```

Always cite the **engines you ran**. DLSurfer is orchestration only.
