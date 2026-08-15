# License information

The DKT Connectome Pipeline orchestrator is released under the **Apache License 2.0**; the full license may be found in the [LICENSE](https://github.com/phindagijimana/dkt_connectome/blob/main/LICENSE) file in the repository root.

All trademarks referenced herein are property of their respective holders.

Copyright © 2026 Phind Ndagijimana and contributors. All rights reserved.

SPDX identifier: `Apache-2.0`

---

## Upstream software licenses

This pipeline **orchestrates** separate containerized tools. Each component retains its own license; you are responsible for complying with all upstream terms when running the pipeline.

| Component | Typical license | Notes |
|-----------|-----------------|-------|
| QSIPrep / QSIRecon | [3-clause BSD](https://github.com/PennLINC/qsiprep/blob/master/LICENSE) | PennLINC |
| FreeSurfer | [FreeSurfer license](https://surfer.nmr.mgh.harvard.edu/fswiki/FreeSurferSoftwareLicense) | Registration required |
| FastSurfer | Apache 2.0 | [Deep-MI/FastSurfer](https://github.com/Deep-MI/FastSurfer) |
| MRtrix3 | [MRtrix3 license](https://www.mrtrix.org/download/) | See upstream distribution |
| neuroLIT | See upstream | [Deep-MI/lit](https://github.com/Deep-MI/lit) |
| ANTs, FSL (via QSIPrep) | Upstream terms | Bundled inside QSIPrep/QSIRecon images |

Product names such as **QSIPrep**, **QSIRecon**, **FreeSurfer**, **FastSurfer**, and **MRtrix3** are trademarks or registered marks of their respective owners. This documentation uses them only to identify the upstream tools the pipeline calls.

---

## Data and test fixtures

Example BIDS data under `tests/fixtures/bids_minimal/` is synthetic (CC0).  
Do not commit participant data to the public repository.

---

## Related pages

- [Citation](citation.md) — how to acknowledge this pipeline and upstream methods
- [References by step](references.md) — papers for each processing step
- [Installation](installation.md) — FreeSurfer license and container requirements
