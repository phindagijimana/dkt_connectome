# Sample datasets

Public BIDS subsets for tutorials, smoke tests, and documentation examples.

| Dataset | Subjects | Download | Docs |
|---------|----------|----------|------|
| **IDEAS II** (OpenNeuro) | `sub-1`, `sub-6` | [`scripts/download_ideas_sample.sh`](../scripts/download_ideas_sample.sh) | [docs/datasets/ideas.md](../docs/datasets/ideas.md) |
| **BTC_preop glioma** (OpenNeuro) — **not TBI** | `sub-PAT20` (`ses-preop`) | [`scripts/download_btc_glioma_sample.sh`](../scripts/download_btc_glioma_sample.sh) | [docs/datasets/btc_glioma.md](../docs/datasets/btc_glioma.md) |

NIfTI volumes land in gitignored paths under each dataset folder (e.g. `ideas/bids/`, `btc_glioma/bids/`). README and provenance files are tracked in git.

**Citation:** If you use IDEAS II data, cite Taylor et al. 2026 (*Epilepsia*) and the OpenNeuro dataset DOI — see [IDEAS sample README](ideas/README.md#citation). If you use the BTC glioma sample, cite Aerts et al. 2018 (*eNeuro*) and OpenNeuro ds001226 — see [BTC glioma README](btc_glioma/README.md). **BTC is glioma, not TBI. Do not cite it as TRACK-TBI validation.**
