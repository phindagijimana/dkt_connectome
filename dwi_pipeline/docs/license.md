# License

TrackTBI Connectome Pipeline is released under the **Apache License 2.0**.

- Full text: [LICENSE](https://github.com/phindagijimana/dkt_connectome/blob/main/LICENSE) in the repository root
- SPDX identifier: `Apache-2.0`

---

## Third-party software

This pipeline orchestrates separate containerized tools, each with its own license:

| Component | License |
|-----------|---------|
| QSIPrep / QSIRecon | BSD-style (see upstream) |
| FreeSurfer | FreeSurfer license (registration required) |
| FastSurfer | Apache 2.0 |
| MRtrix3 | MRtrix3 license |
| neuroLIT | See [DeepMI/lit](https://github.com/Deep-MI/lit) |

You are responsible for complying with each tool's license when running the pipeline.

---

## Data

Example BIDS fixture under `tests/fixtures/bids_minimal/` is synthetic (CC0).  
Do not commit participant data to the public repository.
