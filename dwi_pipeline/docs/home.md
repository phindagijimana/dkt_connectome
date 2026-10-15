---
orphan: true
---

# DKT Connectome — lesion-aware structural connectomics BIDS App

DKT Connectome turns BIDS DWI + T1w into a **78-node DKT structural connectome**. With a lesion mask and `--disconnection`, the same run can inpaint T1w and estimate which edges the lesion interrupts. It is **study-agnostic**: lesion steps stay off unless a mask and flags are present. One paragraph per step: **[What DKT Connectome does](what_it_does.md)**.

Public software checks: [IDEAS II](datasets/ideas.md) and [BTC glioma](datasets/btc_glioma.md) — [Sample results](sample_results.md). TRACK-TBI DoD Phase 1 was run under a DUA (data not in this repo) and is not a public validation claim.

**Linux + Apptainer** (FreeSurfer license required). Docker is an orchestrator only: [One-pull](installation.md#one-pull-docker--cloud). **Release:** [v0.3.1](https://github.com/phindagijimana/dkt_connectome/releases/tag/v0.3.1).

![DKT Connectome pipeline workflow](img/pipeline_overview.svg)

**Next:** [Installation](installation.md) · [Tutorial](tutorial.md) · [Outputs](outputs.md)

This pipeline **orchestrates** [QSIPrep](https://qsiprep.readthedocs.io/), [QSIRecon](https://qsirecon.readthedocs.io/), FreeSurfer/FastSurfer, MRtrix3, and neuroLIT. Cite those papers — [References by step](references.md).

---

## Quick start

License, cache paths, and `./dkt install` are on [Installation](installation.md). Then the [Tutorial](tutorial.md) (public IDEAS sample + dry-run).

Own BIDS: `./dkt run /path/to/BIDS /path/to/out participant --participant-label 01 --session-filter ses-1 --n-cpus 8 --fastsurfer --syn`. HPC: `bash dwi_pipeline/submit.sh` from the repo root. Flags: [Usage](usage.md). Sidecar errors: [BIDS metadata](bids_metadata.md).

---

## Contact

<a id="contact"></a>

- **GitHub:** [github.com/phindagijimana/dkt_connectome](https://github.com/phindagijimana/dkt_connectome) · [open an issue](https://github.com/phindagijimana/dkt_connectome/issues)
- **Email:** [phindagiji@gmail.com](mailto:phindagiji@gmail.com)
- [FAQ](faq.md) · [Troubleshooting](troubleshooting.md) · [NeuroStars](https://neurostars.org/)
