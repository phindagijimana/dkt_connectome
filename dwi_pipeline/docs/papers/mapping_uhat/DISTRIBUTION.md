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
| `CITATION.cff` **v0.2.0** | Done; add Zenodo DOI after public GH Release |
| GitHub `phindagijimana/edgeuq` | `main` + tag **`v0.2.0` pushed** 2026-10-22 |
| GitHub Release + Zenodo | **Blocked on `gh auth`** — re-login, make public if needed, *Create release* from `v0.2.0` |
| GHCR image | Optional follow-on from release workflow |

Cite in manuscripts as: *edgeuq v0.2.0 (DOI pending)* implementing Paper 1/2 protocols.

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
