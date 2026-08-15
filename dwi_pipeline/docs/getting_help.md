# Getting help

---

## Documentation

- **Hosted site:** https://dkt-connectome.readthedocs.io/en/latest/
- [FAQ](faq.md)
- [Troubleshooting](troubleshooting.md)
- [Usage](usage.md) — full CLI reference

---

## GitHub

- **Repository:** https://github.com/phindagijimana/dkt_connectome
- **Issues:** https://github.com/phindagijimana/dkt_connectome/issues

When opening an issue, include:

1. `./run --version` output
2. Full command line (redact paths if needed)
3. Relevant log excerpt from `RESULTS_ROOT/logs/`
4. Whether a lesion mask is present

---

## Community forums

For general BIDS / diffusion questions, search or post on [NeuroStars](https://neurostars.org/):

- Tag **`qsiprep`** or **`qsirecon`** for preprocessing and tractography questions (Steps 1 and 3)
- Tag **`freesurfer`** or **`mrtrix`** for recon and connectome questions (Steps 2 and 4)
- Include **`dkt-connectome`** or a link to this repo when the question is specific to this orchestrator

Also: [BIDS Slack](https://bids-standard.github.io/bids-starter-kit/)

This pipeline builds on QSIPrep and QSIRecon; many preprocessing questions are answered in their docs:

- https://qsiprep.readthedocs.io/
- https://qsirecon.readthedocs.io/

---

## Upstream tools

| Tool | Support |
|------|---------|
| QSIPrep | https://github.com/pennlinc/qsiprep/issues |
| QSIRecon | https://github.com/pennlinc/qsirecon/issues |
| FreeSurfer | https://surfer.nmr.mgh.harvard.edu/fswiki/FreeSurferSupport |
| MRtrix3 | https://community.mrtrix.org/ |

---

## BIDS Apps registry

Submission checklist: [BIDS Apps registry](bids_apps_registry.md).

Maintainers: bids.maintenance+apps@gmail.com

---

## Citation

If you use this pipeline in a publication, cite the underlying tools — see [Citation](citation.md).
