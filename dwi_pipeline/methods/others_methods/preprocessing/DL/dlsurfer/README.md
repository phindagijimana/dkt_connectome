# DLSurfer

**Curated deep-learning morphometry orchestrator** — FreeSurfer-shaped outputs, lesion + device policy, every engine cited.

> Does **not** replace FreeSurfer / FastSurfer science.  
> **Isolated** under `others_methods/preprocessing/DL/dlsurfer/` — does **not** couple to or modify the DKT connectome pipeline.  
> **Atlases:** DKT is the default labeling scheme; DK / Destrieux / others are in-scope (see `dlsurfer atlases`).

Docs: [`docs/ISOLATION.md`](docs/ISOLATION.md) · [`docs/ATLASES.md`](docs/ATLASES.md) · [`docs/COMPARE_FS_FASTSURFER.md`](docs/COMPARE_FS_FASTSURFER.md) · [`docs/GAPS_WITHOUT_ALTERNATIVES.md`](docs/GAPS_WITHOUT_ALTERNATIVES.md) · [`docs/STRUCTURE_MODULES.md`](docs/STRUCTURE_MODULES.md) · [`docs/ALTERNATIVES.md`](docs/ALTERNATIVES.md) · [`docs/CLAIMS.md`](docs/CLAIMS.md) · [`docs/PHASES.md`](docs/PHASES.md)

Parent notes: [`../DLSURFER_PLAN.md`](../DLSURFER_PLAN.md) · [`../CLASSICAL_TO_DL_TABLE.md`](../CLASSICAL_TO_DL_TABLE.md)

---

## Install / run

```bash
cd dlsurfer
PYTHONPATH=. python -m dlsurfer doctor
PYTHONPATH=. python -m dlsurfer atlases
PYTHONPATH=. python -m dlsurfer compare          # vs FreeSurfer & FastSurfer
PYTHONPATH=. python -m dlsurfer gaps-remaining   # no credible alternative
PYTHONPATH=. python -m dlsurfer engines --alternatives
```

```bash
PYTHONPATH=. python -m dlsurfer run \
  --profile core-lesion \
  --atlas dkt \
  --t1 /path/T1.nii.gz \
  --lesion-mask /path/lesion.nii.gz \
  --sd /path/dlsurfer_subjects \
  --sid sub-EG \
  --fs-license /path/license.txt \
  --device auto
```

Gap-fill examples (dry-run plans):

```bash
# DK via FastSurfer --fsaparc
python -m dlsurfer run --profile core --atlas dk --t1 T1.nii.gz --sd SD --sid S --fs-license LIC

# Module off + hires + HPC launcher
python -m dlsurfer run --profile core --t1 T1.nii.gz --sd SD --sid S \
  --no-hypothal --vox-size 0.8 --hpc srun --fs-license LIC

# Former FS-suite gaps
python -m dlsurfer run --profile fs-long --t1 T1.nii.gz --sd SD --sid S
python -m dlsurfer run --profile subfields-ha --t1 T1.nii.gz --sd SD --sid S
python -m dlsurfer run --profile nuclei-bs-thal --t1 T1.nii.gz --sd SD --sid S
python -m dlsurfer run --profile atlas-destrieux --t1 T1.nii.gz --sd SD --sid S

# Specialty (clau_seg / piriform / HippUnfold) — see docs/STRUCTURE_MODULES.md
python -m dlsurfer run --profile preprocess-synthsr --t1 T1.nii.gz --sd SD --sid S
python -m dlsurfer run --profile structure-claustrum --t1 T1.nii.gz --sd SD --sid S
python -m dlsurfer run --profile structure-piriform-synthseg --t1 T1.nii.gz --sd SD --sid S
python -m dlsurfer run --profile clinical-claustrum --t1 T1.nii.gz --sd SD --sid S
python -m dlsurfer run --profile structure-hippunfold --t1 T1.nii.gz --sd SD --sid S
```

Use a **dedicated `--sd`** (not the DKT pipeline work tree) unless you intentionally share a SUBJECTS_DIR.

Optional consumer notes only (print-only):

```bash
python -m dlsurfer handoff --consumer generic --sd ... --sid ...
python -m dlsurfer handoff --consumer dkt --sd ... --sid ...   # does not run DKT
```

---

## Chosen engines (defaults)

| Engine | Why chosen |
|--------|------------|
| SynthStrip | Best Production strip in FS |
| DeepN4 | Best Ready N4 approx (optional) |
| FastSurferVINN + CC/CerebNet/HypVINN | Production morphometry core |
| SynthSeg | Odd-contrast Production alt |
| neuroLIT standalone | Lesion fill without breaking GPU/CPU split |
| recon-surf | Production FS-shaped surfaces (classical) |
| TopoFit / V2C-Flow / SUGAR / DL-CTE | Phase 3 experimental Ready/Production alts |
| EasyReg / SynthMorph | Production registration utils |
| FreeSurfer 8 | XOR alt engine |

**All other credible alternatives** (HD-BET, QuickNAT, DeepSCAN, VBG, CortexODE, PialNN, S3Reg, …) are documented for future reference:

- `dlsurfer engines --alternatives`
- [`docs/ALTERNATIVES.md`](docs/ALTERNATIVES.md)
- `engines.yaml` → `alternatives:` + `deferred:`

---

## What’s missing vs FreeSurfer / FastSurfer

- Full matrix: `dlsurfer compare` → [`docs/COMPARE_FS_FASTSURFER.md`](docs/COMPARE_FS_FASTSURFER.md)
- **No credible alternative** (intentionally): `dlsurfer gaps-remaining` → [`docs/GAPS_WITHOUT_ALTERNATIVES.md`](docs/GAPS_WITHOUT_ALTERNATIVES.md)

Best alternatives for former gaps are wired as profiles/flags (`fs-long`, `subfields-ha`, `nuclei-bs-thal`, `fs-clinical`, `atlas-*`, `--atlas dk`, `--hpc srun`, `--vox-size`, `--no-*`).

---

## Citation

```bash
python -m dlsurfer cite --profile core-lesion
```
