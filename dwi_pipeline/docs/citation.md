# Citation

How to acknowledge the DKT Connectome and the upstream tools it orchestrates. Structure follows the [QSIPrep citing page](https://qsiprep.readthedocs.io/en/0.22.1/citing.html).

---

## Citing this pipeline

The DKT Connectome is a **BIDS App orchestrator** — it does not replace QSIPrep, QSIRecon, FreeSurfer, MRtrix3, or neuroLIT. In publications:

1. **Cite every upstream tool** whose methods you report (see [References by step](references.md)).
2. **Name the pipeline** and point readers to this documentation site and the GitHub repository.
3. **Acknowledge cohort-specific data use** (IRB, TrackTBI, institutional agreements) separately.

Suggested prose (Methods or Acknowledgements):

> Structural connectomes were derived with the DKT Connectome (BIDS App v0.2.1; https://dkt-connectome.readthedocs.io/), which orchestrates QSIPrep¹, optional neuroLIT lesion inpainting², FreeSurfer or FastSurfer³, QSIRecon ACT-HSVS tractography⁴, DKT parcellation-based connectome construction⁵, and optional structural disconnectome mapping⁶.

Replace superscripts with numbered references from [References by step](references.md).

---

## Minimum citations (most papers)

If space is limited, include at least:

| When you used… | Cite |
|----------------|------|
| Any preprocessing / SDC | **Cieslak et al. 2021** (QSIPrep) |
| Tractography / reconstruction | **Cieslak et al. 2024** (QSIRecon) + **Tournier et al. 2019** (MRtrix3) |
| Cortical parcellation | **Fischl 2012** (FreeSurfer) or **Henschel et al. 2020** (FastSurfer) |
| DKT connectome nodes | **Klein & Tourville 2012** |
| Lesion inpainting | **Pollak et al. 2025** (neuroLIT) |
| Disconnectome | **Griffis et al. 2019** |
| BIDS data layout | **Gorgolewski et al. 2016** |

Full per-step lists: [References by step](references.md).

---

## BibTeX (common entries)

```bibtex
@article{Cieslak2021,
  author  = {Cieslak, Matthew and Cook, Philip A. and He, Xiaoliu and
             Yeh, Fang-Cheng and Dhollander, Thijs and Mirza, Shreyas and
             Anticevic, Alan and Glahn, David C. and Poldrack, Russell A. and
             C{\'o}rcoran, Catherin and others},
  title   = {{QSIPrep}: an integrative platform for preprocessing and reconstructing diffusion {MRI} data},
  journal = {Nature Methods},
  volume  = {18},
  number  = {7},
  pages   = {775--778},
  year    = {2021},
  doi     = {10.1038/s41592-021-01185-5}
}

@article{Cieslak2024,
  author  = {Cieslak, Matthew and others},
  title   = {{QSIRecon}: A robust workflow for reconstructing diffusion {MRI} data},
  journal = {bioRxiv},
  year    = {2024},
  doi     = {10.1101/2024.05.30.596511}
}

@article{Fischl2012,
  author  = {Fischl, Bruce},
  title   = {{FreeSurfer}},
  journal = {NeuroImage},
  volume  = {62},
  number  = {2},
  pages   = {782--795},
  year    = {2012},
  doi     = {10.1016/j.neuroimage.2012.03.001}
}

@article{Henschel2020,
  author  = {Henschel, Leonie and others},
  title   = {{FastSurfer} -- A fast and accurate deep learning based neuroimaging pipeline},
  journal = {NeuroImage},
  volume  = {219},
  pages   = {117357},
  year    = {2020},
  doi     = {10.1016/j.neuroimage.2020.117357}
}

@article{Tournier2019,
  author  = {Tournier, J-Donald and others},
  title   = {{MRtrix3}: A fast, flexible and open software framework for analysing medical {MR} diffusion imaging data},
  journal = {NeuroImage},
  volume  = {202},
  pages   = {116137},
  year    = {2019},
  doi     = {10.1016/j.neuroimage.2019.01.066}
}

@article{Pollak2025,
  author  = {Pollak, Tobias A. and others},
  title   = {{FastSurfer-LIT}: Lesion inpainting tool for whole brain {MRI} segmentation with tumors, cavities and abnormalities},
  journal = {Imaging Neuroscience},
  year    = {2025},
  doi     = {10.1162/imag_a_00446}
}

@article{Griffis2019,
  author  = {Griffis, Joseph C. and others},
  title   = {Structural disconnectome mapping in patients with brain injury},
  journal = {Cell Reports},
  volume  = {29},
  number  = {9},
  pages   = {2667--2678.e5},
  year    = {2019},
  doi     = {10.1016/j.celrep.2019.10.058}
}

@article{Gorgolewski2016,
  author  = {Gorgolewski, Krzysztof J. and others},
  title   = {The brain imaging data structure, a format for organizing and describing outputs of neuroimaging experiments},
  journal = {Scientific Data},
  volume  = {3},
  pages   = {160044},
  year    = {2016},
  doi     = {10.1038/sdata.2016.44}
}
```

Additional BibTeX for every step: [references.md](references.md).

---

## BIDS App metadata

From [`app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/app.json):

```text
HowToAcknowledge: Cite QSIPrep (Cieslak et al., Nature Methods 2021), QSIRecon,
FastSurfer/FreeSurfer, MRtrix3, Pollak et al. 2025 for neuroLIT inpainting,
and Griffis et al. 2019 for disconnectome methods. See documentation/citation.
```

---

## Repository, Zenodo, and documentation

| Resource | URL |
|----------|-----|
| Documentation | https://dkt-connectome.readthedocs.io/en/latest/ |
| Source code | https://github.com/phindagijimana/dkt_connectome |
| GitHub Releases | https://github.com/phindagijimana/dkt_connectome/releases |
| Zenodo archive | *(enable GitHub integration — see [Maintainer §17 on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/maintainer_tasks.md#17-zenodo-archive-doi))* |
| CITATION.cff | https://github.com/phindagijimana/dkt_connectome/blob/main/CITATION.cff |

After the first Zenodo release, add the software DOI here and in `CITATION.cff`:

```bibtex
@software{Ndagijimana2026DKTConnectome,
  author    = {Ndagijimana, Philbert},
  title     = {{DKT Connectome} — lesion-aware structural connectomics {BIDS App}}},
  year      = {2026},
  version   = {0.2.1},
  url       = {https://github.com/phindagijimana/dkt_connectome},
  doi       = {10.5281/zenodo.xxxxx}
}
```

Replace `10.5281/zenodo.xxxxx` with the DOI from your Zenodo record.

---

## Study cohorts and data use

Validated on the **TRACK-TBI study (~14 centers)** and **URMC clinical MRI cohorts**. Acknowledge institutional data-use agreements and study-specific requirements as required by your IRB.

---

## Sample tutorial data (IDEAS II)

The recommended **public sample** for tutorials and smoke tests is a two-subject subset of **IDEAS II** ([OpenNeuro ds007401](https://openneuro.org/datasets/ds007401)). Download: [`scripts/download_ideas_sample.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/scripts/download_ideas_sample.sh).

If you publish results derived from these volumes (or redistribute derivatives), cite:

1. **IDEAS II paper** — Taylor PN, Hall G, Horsley J, Wang Y, Vos SB, Winston GP, McEvoy AW, Miserocchi A, de Tisi J, Duncan JS. Open diffusion magnetic resonance imaging and connectivity data for epilepsy and surgery: The IDEAS II release. *Epilepsia* 2026;67(6):2912–2923. [doi:10.1002/epi.70186](https://doi.org/10.1002/epi.70186)
2. **OpenNeuro dataset** — [doi:10.18112/openneuro.ds007401.v1.0.0](https://doi.org/10.18112/openneuro.ds007401.v1.0.0)
3. **IDEAS I** (T1w/FLAIR clinical metadata aligned with the same subject IDs) — Taylor PN, et al. *Epilepsia* 2025. [doi:10.1111/epi.18192](https://doi.org/10.1111/epi.18192) (when referencing non-DWI IDEAS fields)

```bibtex
@article{Taylor2026IDEASII,
  author  = {Taylor, Peter N. and Hall, Gerard and Horsley, Jonathan and
             Wang, Yujiang and Vos, Sjoerd B. and Winston, Gavin P. and
             McEvoy, Andrew W. and Miserocchi, Anna and de Tisi, Jane and
             Duncan, John S.},
  title   = {Open diffusion magnetic resonance imaging and connectivity data for epilepsy and surgery: The {IDEAS II} release},
  journal = {Epilepsia},
  volume  = {67},
  number  = {6},
  pages   = {2912--2923},
  year    = {2026},
  doi     = {10.1002/epi.70186}
}

@misc{OpenNeuroIDEASII,
  author       = {Taylor, Peter N. and others},
  title        = {Open diffusion {MRI} and connectivity data for epilepsy and surgery: The {IDEAS II} release},
  year         = {2026},
  publisher    = {OpenNeuro},
  doi          = {10.18112/openneuro.ds007401.v1.0.0},
  url          = {https://openneuro.org/datasets/ds007401}
}
```

Full sample-data guide: [datasets/ideas.md](datasets/ideas.md).

---

## Contact

Questions about citing or software metadata: [phindagiji@gmail.com](mailto:phindagiji@gmail.com) · [GitHub Issues](https://github.com/phindagijimana/dkt_connectome/issues)
