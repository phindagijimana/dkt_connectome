---
title: Distribution before authorship / journal
date: 2026-10-21
status: active
---

# DISTRIBUTION

Authorship and journal choice can wait. **Versioned, licensed artifacts** should not.

## Software — `edgeuq`

| Step | Status / action |
|------|-----------------|
| License Apache-2.0 | Done in repo |
| `CITATION.cff` v0.1.0 | Done; add Zenodo DOI after first public release |
| GitHub `phindagijimana/edgeuq` | Exists; follow [edgeuq `docs/release.md`](https://github.com/phindagijimana/edgeuq/blob/main/docs/release.md) |
| Tag `v0.1.0` + GHCR image | When ready to cite from drafts |
| Keep private until preprint if coauthors require | OK; still tag internally |

Cite in manuscripts as: *edgeuq vX.Y.Z (DOI…)* implementing Paper 1/2 protocols.

## Software — `dkt-connectome`

| Step | Action |
|------|--------|
| Optional trust-band hook | See [EDGEUQ_TRUST_BANDS_HOOK.md](EDGEUQ_TRUST_BANDS_HOOK.md); default **off** |
| JOSS / software note | After hook ships; cite P1/P2; do not re-litigate ECE |
| Containers | Keep pinned digests; do not bundle HCP/private BIDS |

## Pipelines (TrackTBI-Sub / mapping_uhat)

- Public: recipes, locks, subject-list **formats**, container pins.
- Private / gated: HCP derivatives, institutional BIDS, raw identifiers.
- Reproduce path: Kirby/Boekel public subsets → `edgeuq` demo + `docs/reproduce.md`.

## Papers

- Keep drafts under `docs/papers/mapping_uhat/` until author list agreed.
- Then preprint (bioRxiv/medRxiv) **before or with** submission.
- Preprint cites software DOI; software note cites preprint/journal.

## Do not block on

Final author order · camera-ready figures · full scale tables (P1 can submit with awaiting-scale appendix).
