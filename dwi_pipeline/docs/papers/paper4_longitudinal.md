# Paper 4 — Longitudinal connectome resource

**Status:** Active parallel — runs alongside Paper 1 without blocking it.
**Target:** *Scientific Data* / *GigaScience* (resource framing, default);
*Human Brain Mapping* stretch as trajectory science paper.

**Cross-refs:** [publication_strategy.md § Paper 4](publication_strategy.md#paper-4--longitudinal-connectomics--resource-parallel)

---

## One-paragraph summary

A multisite, longitudinal structural connectome resource built from ~600
TrackTBI subjects × 2 sessions (~1200 diffusion scans) processed through
a single standard pipeline arm (e.g. `orig-std`), with session-aware
output layout, harmonized derivatives (ComBat / site-effect handled), and
BIDS-Derivatives-compliant packaging. The primary framing is a reusable
resource for the community — subject/session-level connectomes, QC
tables, and provenance JSON — with optional trajectory analyses
(session-paired Δ, ICC / test–retest) as secondary content.

## Candidate titles

- *A multisite structural connectome resource for traumatic brain injury: ~1200 diffusion sessions with harmonized derivatives*
- *Longitudinal trajectories of structural connectivity after traumatic brain injury: a multisite TRACK-TBI cohort* (HBM stretch)
- *TrackTBI-Connectome: reproducible, containerized structural connectome derivatives for a longitudinal TBI cohort*
- *Multisite longitudinal DKT-parcellated structural connectomes in traumatic brain injury (TrackTBI-Sub, N ≈ 600 × 2 sessions)*
- *Harmonized structural connectomes across sites and scanners in a longitudinal TBI cohort: pipeline, QC, and reusable derivatives*

## Research questions

| ID | Question |
|----|----------|
| RQ1 | Do connectome metrics change systematically from timepoint 1 to 2? |
| RQ2 | Are trajectories associated with injury severity or recovery (if outcomes linked)? |
| RQ3 | How much variance is site/scanner vs biology (harmonization)? |

## Design choices to lock

- [ ] Fixed processing arm (default `orig-std`)
- [ ] Session-aware `RESULTS_ROOT` layout with per-session subdirs
- [ ] Harmonization method (ComBat default; site regressors as sensitivity)
- [ ] QC pass thresholds per session
- [ ] Data-release format (BIDS-Derivatives + provenance JSON)

## Deliverables

- ~1200 session-level connectome CSVs (SIFT2 + count + FA)
- Session-paired Δ metrics per subject
- Cross-site QC report
- Data descriptor / methods paper
- Optional: Zenodo DOI for the derivatives package
- Optional: Snakemake config for one-command re-processing

## Prior-work analogs

- **Palacios et al. 2022 TRACK-TBI** (J Neurotrauma, N≈391 multisite DTI + GOSE)
- **Kuceyeski et al. 2020 HBM** (longitudinal connectome + cognition; mTBI N=26)

## Novelty

TRACK-TBI DTI/outcome papers exist at scale; a formal **multisite
structural connectome resource** at ~1200 sessions with harmonized
derivatives + reusable containerized pipeline is the documented gap.

## Related pipeline docs

- Snakemake workflow: [../snakemake_workflow.md](../snakemake_workflow.md)
- Outputs / BIDS-Derivatives: [../outputs.md](../outputs.md)
- Validation: [../validation.md](../validation.md)
- References: [../references.md](../references.md)
