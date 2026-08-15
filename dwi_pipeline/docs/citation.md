# Citation and acknowledgements

## Pipeline software

When using this BIDS App, please cite the underlying tools:

| Tool | Reference |
|------|-----------|
| **QSIPrep** | Cieslak et al., *Nature Methods* 2021 — [doi:10.1038/s41592-021-01185-5](https://doi.org/10.1038/s41592-021-01185-5) |
| **QSIRecon** | Cieslak et al., 2024 — [doi:10.1101/2024.05.30.596511](https://doi.org/10.1101/2024.05.30.596511) |
| **FreeSurfer** | Fischl, *NeuroImage* 2012 |
| **FastSurfer** | Henschel et al., *NeuroImage* 2020 |
| **MRtrix3** | Tournier et al., *NeuroImage* 2019 |
| **neuroLIT** | DeepMI LIT inpainting — [containers/lit/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/lit/README.md) |

## Disconnectome (Step 4.5)

Adaptation of structural disconnectome methods:

| Paper | Use in this pipeline |
|-------|----------------------|
| **Griffis et al. 2019** — *Cell Reports* | Disconnection matrix framing, Option B |
| **Kuceyeski et al. 2013** — NeMo | Virtual lesioning concept |

Full bibliography: [Inpainting/connectome_excision_literature.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/connectome_excision_literature.md).

## BIDS App metadata

From [`app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/app.json):

```text
HowToAcknowledge: Cite QSIPrep, QSIRecon, FastSurfer/FreeSurfer, and Griffis et al. 2019 for disconnectome methods.
```

## Repository

- **GitHub:** [github.com/phindagijimana/dkt_connectome](https://github.com/phindagijimana/dkt_connectome)
- **BIDS Apps:** [bids-apps.neuroimaging.io](https://bids-apps.neuroimaging.io/)

## Study cohorts and data use

This pipeline is validated on the **TRACK-TBI study (~14 centers)** and **URMC clinical MRI cohorts** (including CIDUR). Acknowledge your institutional data-use agreements and any study-specific requirements separately as required by your IRB and data-sharing policy.
