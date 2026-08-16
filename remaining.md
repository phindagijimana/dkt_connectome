# Remaining work — DKT Connectome BIDS App

**Last updated:** 2026-08-16 · **Current release:** v0.2.0

Living tracker of **open** work. Detailed IDs and history: [`dwi_pipeline/docs/maintainer/readiness_checklist.md`](dwi_pipeline/docs/maintainer/readiness_checklist.md) (also on [Read the Docs](https://dkt-connectome.readthedocs.io/en/latest/maintainer/readiness_checklist/)).

---

## Status in one paragraph

The BIDS App is **ready for use** at v0.2.0: `./run`, participant + group levels, `app.json`, docs ([RTD](https://dkt-connectome.readthedocs.io/en/latest/)), GitHub Release, Docker Hub orchestrator, CI dry-run + bids-validator, science/theory pages. **Not done:** optional registry listings, two maintainer registry one-shots, Zenodo DOI, confirming integration CI green weekly, v1.0 cohort science, and legacy code removal.

| Level | Verdict |
|-------|---------|
| **Spec-compliant BIDS App (run in production)** | ✅ Yes |
| **Listed on bids-apps.neuroimaging.io** | ⏸ Optional (deferred) |
| **QSIPrep-style single-image + full E2E CI** | ❌ Not targeted for v0.2 |
| **v1.0 + paper + cohort validation** | ❌ Open (P4) |

---

## Open — maintainer one-shots (P0)

| Task | Owner | Doc |
|------|-------|-----|
| Link **Dockstore** to GitHub | Maintainer | [maintainer_tasks §15](dwi_pipeline/docs/maintainer/maintainer_tasks.md#15-dockstore-github-link) |
| Upload **WorkflowHub** RO-Crate | Maintainer (optional) | [maintainer_tasks §16](dwi_pipeline/docs/maintainer/maintainer_tasks.md#16-workflowhub-ro-crate-upload) |
| **BIDS Apps registry** PR | Optional | [BIDS_App.md](dwi_pipeline/docs/BIDS_App.md) |
| **RTD rebuild (science pages live)** | Maintainer | Stale site — add `READTHEDOCS_TOKEN` or manual build · [§14](dwi_pipeline/docs/maintainer/maintainer_tasks.md#14-read-the-docs-auto-rebuild) |

**Done (P0):** GitHub Release v0.2.0 · Docker Hub pull · RTD project exists · legacy doc trim.

---

## Open — engineering (P1)

| Task | Status | Notes |
|------|--------|-------|
| **Integration CI weekly green** | Scaffolded | `integration_qsiprep.yml` — pull + `qsiprep --version` (no license). Confirm Actions schedule. [integration_ci.md](dwi_pipeline/docs/maintainer/integration_ci.md) |
| **Docker auto-install smoke green** | Scaffolded | `docker_auto_install_smoke.yml` after Dockerfile changes |
| **IDEAS golden CI** | Scaffolded | `integration_ideas.yml` — monthly dry-run; real runs on HPC with user license |
| **Real E2E `./run` in CI** | Optional | Per-user `FS_LICENSE`; validate locally/HPC, not a repo requirement |

**Done (P1):** bids-validator CI · install_smoke schedule · app.json flags · `--mem-mb` · root README/REGISTRY deprecation · Apptainer in orchestrator Dockerfile.

---

## Open — docs & citation (P2)

| Task | Notes |
|------|-------|
| **Zenodo archive + DOI** | Enable GitHub integration → release → wire `CITATION.cff` · [§17](dwi_pipeline/docs/maintainer/maintainer_tasks.md#17-zenodo-archive-doi) |
| **Version story (0.2 vs 1.0)** | Bump to v1.0 only after P4 cohort work |
| **BIDS Derivatives policy** | Clarify custom layout vs export in [derivatives.md](dwi_pipeline/docs/derivatives.md) / [outputs.md](dwi_pipeline/docs/outputs.md) |
| **Manuscript container digests** | Update pins in [manuscript.md](dwi_pipeline/sample_software_paper/manuscript.md) |

**Done (P2):** RTD doc hub · science overview · FreeSurfer license user docs · root vs `dwi_pipeline/` split.

---

## Open — code cleanup (P3, defer)

| Task | Blocker |
|------|---------|
| Remove `PIPELINE_ENGINE=bash` | Confirm no active HPC jobs |
| Remove dual-container Step 4 | Same |
| Remove/gate root 4-stage `./connectome` | Dockstore legacy entry |
| Promote disconnectome default | Scale validation (P4) |

Plan: [`workflow/LEGACY.md`](dwi_pipeline/workflow/LEGACY.md)

---

## Open — v1.0 science & paper (P4)

Does **not** block using the BIDS App today. Runbook: [v1_science_track.md](dwi_pipeline/docs/maintainer/v1_science_track.md)

| Task | Owner |
|------|-------|
| Freeze **v1.0** tag + SDC release notes | Philbert |
| **Container digest table** (S4) | Philbert — `generate_container_digests_md.py` after full `install.sh` |
| URMC **n=61** end-to-end + QC CSV | Daniel + HPC |
| HCP-YA **n=10** baseline stats | Daniel |
| Radiological review rubric | James |
| Table 1 + Figures 1–7 | Team |
| **bioRxiv** preprint | Philbert |
| `CITATION.cff` paper DOI | Post-acceptance |

---

## Optional stretch (P5)

Only if single-image or official `bids-apps` namespace is required:

- Monolithic / fat Docker image (P5.1)
- Join `bids-apps` GitHub org (P5.2)
- Public regression dataset on OpenNeuro/S3 (P5.3)

---

## Suggested order

```text
1. Confirm integration + auto-install workflows green on GitHub Actions
2. Dockstore link (P0.5)
3. Zenodo DOI for v0.2.0 (P2.2)
4. Parallel: URMC n=61 + HCP n=10 (P4)
5. Digest table + v1.0 tag + preprint
6. Optional: BIDS Apps registry · WorkflowHub · legacy code removal
```

---

## Already shipped (v0.2.0 baseline)

- BIDS App `./run` · participant + group · Snakemake · `submit.sh`
- `app.json` · Boutiques JSON · `tests/fixtures/bids_minimal`
- MkDocs / RTD · [science_overview.md](dwi_pipeline/docs/science_overview.md) · Methods per step
- CI: pytest · MkDocs strict · Snakemake dry-run · bids-validator
- Workflows: `install_smoke` · `integration_qsiprep` · `integration_ideas` · `docker_auto_install_smoke`
- Release: GitHub v0.2.0 · `phindagijimana321/dkt-connectome:0.2.0`
- User docs: FreeSurfer license (per-user) · tutorial · IDEAS sample script

---

*Update this file when items close. Mirror major changes in [readiness_checklist.md](dwi_pipeline/docs/maintainer/readiness_checklist.md).*
