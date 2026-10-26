---
orphan: true
---

# DLSurfer — deep-learning FreeSurfer-suite methods

DLSurfer is the **deep-learning counterpart to FreeSurfer’s method suite**:
T1 **morphometry** (FastSurferVINN → FreeSurfer-shaped `SUBJECTS_DIR`) plus
**specialty DL** for structure *and* FreeSurfer’s non-morphometry streams where
credible tools exist — **TractSeg** (↔ TRACULA), **PET-DL** (↔ FS PET parc/SUVR),
**DeepPrep** (↔ fMRI helpers), **BrainQCNet** (↔ FreeView-only QC triage).
Call modules alone like FS utilities. **Not** TBI-only; lesion fill is optional.

Credibility tiers **A/B/C** (specialty allowed) · **D** classical gated — see
[Credibility](reference/CREDIBILITY.md) or `dlsurfer credibility`.

One paragraph per stage: **[What DLSurfer does](what_it_does.md)**. Sibling
connectomics: **[DKT Connectome](https://dkt-connectome.readthedocs.io/)**.
DLSurfer is **isolated** — no DKT imports; handoff is optional print-only notes.

**Linux + Apptainer** (FreeSurfer license required). **Release:** [v0.2.0](https://github.com/phindagijimana/dlsurfer/releases).

```{note} Recommended setup
Use **Linux + Apptainer**. After `source env/cluster_containers.sh`, run
**`dlsurfer doctor`** until `[READY]`.
```

**Next:** [Installation](installation.md) · [Tutorial](tutorial.md) · [Credibility](reference/CREDIBILITY.md)

Orchestrates FastSurfer / Synth* / specialty DL — cite the engines you run
([Methods / engines](methods/engines.md)).

---

## Start here

| If you want… | Read… |
|--------------|--------|
| **Install & first run** | [Installation](installation.md) → [Tutorial](tutorial.md) |
| **What each stage does** | [What DLSurfer does](what_it_does.md) |
| **What to trust (A/B/C/D)** | [Credibility](reference/CREDIBILITY.md) · `dlsurfer credibility` |
| **All CLI flags** | [Usage](usage.md) · [Command-line reference](cli.md) |
| **Specialty modules** | [Structure modules](reference/STRUCTURE_MODULES.md) · `dlsurfer tools` |
| **Methods & citations** | [Methods overview](methods/index.md) · [Engines](methods/engines.md) |
| **Problems** | [FAQ](faq.md) · [Troubleshooting](troubleshooting.md) |
| **And DKT Connectome** | [And DKT Connectome](and_dkt.md) |

---

## Quick start

```bash
source env/cluster_containers.sh
dlsurfer doctor
dlsurfer credibility
# Full morphometry tree (FS-shaped orchestrator → FastSurferVINN core)
dlsurfer recon-all -i T1.nii.gz -sd ./subjects -s sub-01 --fs-license $FS_LICENSE
# Specialty (allowed): dlsurfer tools | dlsurfer tool hippunfold --t1 … --sd … --sid …
# Optional lesion fill: add --lesion-mask MASK  (profile core-lesion)
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
