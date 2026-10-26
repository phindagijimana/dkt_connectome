---
orphan: true
---

# DLSurfer — curated deep-learning morphometry orchestrator

DLSurfer turns a **T1w** (± lesion mask) into a **FreeSurfer-shaped `SUBJECTS_DIR`** using validated FastSurfer / FreeSurfer DL tools. With a lesion mask and profile `core-lesion`, the same plan can **inpaint T1w** (neuroLIT) then run ordinary FastSurfer so surfaces and labels are estimated on a filled anatomy. It is **study-agnostic**: lesion steps stay off unless you choose a lesion profile and pass a mask.

One paragraph per stage: **[What DLSurfer does](what_it_does.md)**. Sibling connectomics pipeline: **[DKT Connectome](https://dkt-connectome.readthedocs.io/)** (BIDS DWI → DKT connectome). DLSurfer is **isolated** morphometry orchestration — it does not import or modify the DKT workflow; handoff is optional print-only notes.

**Linux + Apptainer** (FreeSurfer license required). **Release:** [v0.1.1](https://github.com/phindagijimana/dlsurfer/releases).

```{note} Recommended setup
Use **Linux + Apptainer** on a workstation or HPC. After `source env/cluster_containers.sh`, run **`dlsurfer doctor`** until it prints `[READY]`.
```

**Next:** [Installation](installation.md) · [Tutorial](tutorial.md) · [Outputs](outputs.md)

This package **orchestrates** FastSurfer, FreeSurfer, and neuroLIT (and optional specialty tools). Cite those papers — [Methods / engines](methods/engines.md).

---

## Start here

| If you want… | Read… |
|--------------|--------|
| **Install & first run** | [Installation](installation.md) → [Tutorial](tutorial.md) |
| **What each stage does** | [What DLSurfer does](what_it_does.md) |
| **All CLI flags** | [Usage](usage.md) · [Command-line reference](cli.md) |
| **Prepare inputs** | [Preparing your data](preparing_data.md) |
| **Methods & citations** | [Methods overview](methods/index.md) · [Engines](methods/engines.md) |
| **Problems** | [FAQ](faq.md) · [Troubleshooting](troubleshooting.md) |
| **And DKT Connectome** | [And DKT Connectome](and_dkt.md) |

---

## Quick start

License, SIFs, and `dlsurfer doctor` are on [Installation](installation.md). Then the [Tutorial](tutorial.md) (dry-run + EG evidence).

```bash
source env/cluster_containers.sh
dlsurfer doctor
dlsurfer run --profile core-lesion \
  --t1 T1.nii.gz --lesion-mask lesion.nii.gz \
  --sd ./subjects --sid sub-01 --fs-license $FS_LICENSE
# add --execute when the plan looks right
```

HPC examples: `hpc/sbatch_*.sh`. Flags: [Usage](usage.md).

```{warning} Short of a full BIDS App
Unlike [DKT Connectome](https://dkt-connectome.readthedocs.io/) (`./run bids out participant`), DLSurfer’s production API is still explicit paths. A stub exists — [BIDS App status](bids_app.md).
```

---

## Contact

<a id="contact"></a>

- **GitHub:** [github.com/phindagijimana/dlsurfer](https://github.com/phindagijimana/dlsurfer) · [open an issue](https://github.com/phindagijimana/dlsurfer/issues)
- **Related:** [DKT Connectome docs](https://dkt-connectome.readthedocs.io/) · [repo](https://github.com/phindagijimana/dkt_connectome)
- [FAQ](faq.md) · [Troubleshooting](troubleshooting.md) · [Citation](citation.md)
