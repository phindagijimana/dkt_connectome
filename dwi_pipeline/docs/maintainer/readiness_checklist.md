# BIDS App readiness checklist

Prioritized remaining work to reach a **listed, production-ready BIDS App** and get as close as practical to **QSIPrep-level** polish.

**Current baseline:** v0.2.0 — `./run`, participant + group levels, Snakemake engine, MkDocs site, CI dry-runs, orchestrator Docker image.

**Architectural note:** This pipeline is a **multi-container orchestrator** (QSIPrep, FreeSurfer, QSIRecon, connectome, LIT, nodestrength). It will not match QSIPrep’s single-image UX unless you publish a monolithic or compose-all-pins stack (optional, P2).

Related docs: [Publishing](publishing.md) · [BIDS App submission](../BIDS_App.md) · [Validation](../validation.md) · [paper plan on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/sample_software_paper/paper_plan.md)

---

## P0 — Listing-ready (do first)

Blockers for appearing on [bids-apps.neuroimaging.io](https://bids-apps.neuroimaging.io/) and giving a first-time user a clear path to run the app.

| # | Task | Status | Notes / path |
|---|------|--------|--------------|
| P0.1 | **Submit BIDS Apps registry entry** | Open | Follow [BIDS_App.md](../BIDS_App.md) — email or PR to `bids-standard/bids-website`. |
| P0.2 | **Create GitHub Release for v0.2.0** | Open | Tag exists; use [`RELEASE_NOTES.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/RELEASE_NOTES.md) with `gh release create`. See [publishing.md](publishing.md). |
| P0.3 | **Verify Docker Hub image is pullable** | Open | `docker pull phindagijimana321/dkt-connectome:0.2.0`. Set `DOCKERHUB_*` secrets or run `scripts/mirror_ghcr_to_dockerhub.sh`. |
| P0.4 | **Fix RTD auto-rebuild** | Open | Confirm webhook or `READTHEDOCS_TOKEN` in `.github/workflows/readthedocs.yml`. [readthedocs_setup.md](../readthedocs_setup.md). |
| P0.5 | **Link Dockstore to GitHub** | Open | One-time profile link for `.dockstore.yml` entries. Root [`REGISTRY.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/REGISTRY.md). |
| P0.6 | **Upload WorkflowHub RO-Crate** | Open | Manual upload; step-4 image ref updated in `workflowhub.yml` (v0.2.0). |
| P0.7 | **Commit legacy doc trim** | **Done** | Bash fallback / dual-container in [`workflow/LEGACY.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/workflow/LEGACY.md); RTD uses `run_subject.sh` only. |

**Exit criterion:** Listed (or submitted) on BIDS Apps site, GitHub Release published, `docker pull` + `./run --version` + RTD build green.

---

## P1 — QSIPrep-level engineering polish

Closes the largest gaps vs mature BIDS Apps: CI confidence, spec completeness, and first-run UX.

| # | Task | Status | Effort | Notes / path |
|---|------|--------|--------|--------------|
| P1.1 | **Add real-container integration test in CI** | Open | High | Today: stub `.sif` + Snakemake `-n` only. Target: QSIPrep (or full DAG) on `tests/fixtures/bids_minimal` with FS license secret. |
| P1.2 | **Run `bids-validator` on minimal fixture in CI** | **Done** | Low | Regenerate fixture + validate in `.github/workflows/dwi_pipeline_ci.yml`. |
| P1.3 | **Schedule `install_smoke.yml`** | **Done** | Low | Weekly cron + `release: published`; default mode `qsiprep`. |
| P1.4 | **Expand `app.json` + Boutiques flag surface** | **Done** | Medium | `app.json` `CommandLineArguments` expanded to match `./run` help. |
| P1.5 | **Implement or remove `--mem-mb`** | **Done** | Low | Exported as `MEM_MB` when set; documented in `run`, `usage.md`, `bids_app.md`. |
| P1.6 | **Docker “quick start” that auto-pulls step images** | Open | Medium | Document and test `DKT_AUTO_INSTALL=1` end-to-end in [cloud_deployment.md](../cloud_deployment.md) + CI smoke. |
| P1.7 | **IDEAS golden run in CI (optional slow job)** | Open | High | OpenNeuro ds007401 via `scripts/download_ideas_sample.sh`. |
| P1.8 | **Deprecate root `./connectome bids` in registry docs** | **Done** | Low | Root [`README.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/README.md), [`REGISTRY.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/REGISTRY.md), [`USER_GUIDE.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/USER_GUIDE.md) point to `dwi_pipeline/run`. |

**Exit criterion:** CI runs at least one real container step; bids-validator green; external reviewer can `docker pull` + run tutorial without reading HPC docs.

---

## P2 — Documentation & discoverability

Most user-facing docs are done (~49 pages). Remaining cleanup is consistency and citation plumbing.

| # | Task | Notes / path |
|---|------|--------------|
| P2.1 | **Align version story (0.2.0 vs 1.0)** | App is 0.2.0; paper plan targets v1.0. Decide when to bump — [paper_plan.md §11](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/sample_software_paper/paper_plan.md). |
| P2.2 | **Zenodo archive + DOI** | Wire into `CITATION.cff`, `app.json` HowToAcknowledge, [citation.md](../citation.md). |
| P2.3 | **Formal BIDS Derivatives output spec page** | Internal layout is custom; export is optional — make policy obvious in [derivatives.md](../derivatives.md) + [outputs.md](../outputs.md). |
| P2.4 | **Refresh root vs `dwi_pipeline/` doc split** | **Done** | Root README / REGISTRY / USER_GUIDE banner + canonical `dwi_pipeline/run` links. |
| P2.5 | **Update manuscript / paper_plan container digests** | Manuscript still references older image names in places — [`manuscript.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/sample_software_paper/manuscript.md). |

**Exit criterion:** One canonical doc hub; DOI citable; no stale entrypoints in top-level README.

---

## P3 — Code cleanup (non-blocking for listing)

Safe to defer until after P0 unless you confirm no site still uses legacy paths.

| # | Task | Notes / path |
|---|------|--------------|
| P3.1 | **Remove bash engine (`PIPELINE_ENGINE=bash`)** | After confirming no active jobs. Plan: [`workflow/LEGACY.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/workflow/LEGACY.md). |
| P3.2 | **Remove dual-container Step 4 path** | `CONNECTOME_LEGACY_DUAL_CONTAINER=1` — `subject.sh` only; Snakemake uses single `dkt_connectome.sif`. |
| P3.3 | **Remove or gate legacy root 4-stage Snakefile** | Documented in [comparisons.md](../comparisons.md); Dockstore legacy entry. |
| P3.4 | **Promote disconnectome from opt-in default** | Still “under validation” in docs; 2-subject integrity PASS in [validation.md](../validation.md). |

---

## P4 — Scientific validation & v1.0 (paper track)

Does **not** block BIDS App listing but required for QSIPrep-level **trust** and a v1.0 release claim.

From [paper_plan.md §11](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/sample_software_paper/paper_plan.md) (all open):

| # | Task |
|---|------|
| P4.1 | Freeze pipeline **v1.0** with release note listing all four SDC modes |
| P4.2 | Container digests pinned + published; digest table in supplement |
| P4.3 | URMC cohort **n=61** end-to-end + per-subject QC summary CSV |
| P4.4 | HCP-YA **n=10** baseline comparison + statistics table |
| P4.5 | Radiological review (James) with rubric per subject |
| P4.6 | Comparison table (Table 1) finalized with citations |
| P4.7 | Figures 1–7 at journal DPI |
| P4.8 | bioRxiv preprint + DOI |
| P4.9 | Update `CITATION.cff` with paper reference (post-acceptance) |

**Exit criterion:** v1.0 tag, Zenodo DOI, cohort QC published, disconnectome validated at scale.

---

## P5 — Optional stretch (QSIPrep parity)

Only if cloud-only / BIDS Apps reviewers demand single-image UX.

| # | Task | Notes |
|---|------|-------|
| P5.1 | **Monolithic or “fat” Docker image** | Bundle orchestrator + pinned step images; large build, FS license still runtime. |
| P5.2 | **Join `bids-apps` GitHub org** | CircleCI → Docker Hub under `bids-apps` namespace. [BIDS_App.md § Optional](../BIDS_App.md). |
| P5.3 | **Public regression dataset on S3/OpenNeuro** | QSIPrep-style CI regression artifacts beyond golden QC outputs in `dwi_test_TBI/`. |

---

## Already done (baseline)

| Area | Status |
|------|--------|
| `./run` BIDS App entrypoint | `dwi_pipeline/run` |
| Participant + group analysis levels | Group = cohort QC + BIDS export |
| Standard + QSIPrep-alias CLI flags | `--participant-label`, `--session-filter`, `--nprocs`, etc. |
| Machine metadata | `app.json`, `dkt_connectome_bids_app.json` |
| Snakemake canonical engine | `workflow/Snakefile`, `run_subject.sh`, `submit.sh` |
| MkDocs / RTD site | [dkt-connectome.readthedocs.io](https://dkt-connectome.readthedocs.io/) |
| CI dry-run + unit tests | `.github/workflows/dwi_pipeline_ci.yml`, `tests/test_bids_app.py` |
| Minimal public test BIDS | `tests/fixtures/bids_minimal/` |
| Docker orchestrator + compose | `Dockerfile`, `docker-compose.yml`, GHCR CI |
| Git tag v0.2.0 | Remote |
| Release notes draft | [`RELEASE_NOTES.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/RELEASE_NOTES.md) |
| bids-validator in CI | `.github/workflows/dwi_pipeline_ci.yml` |
| BIDS fixture validator-clean | `tests/fixtures/bids_minimal/` (`ses-baseline`, regenerate via `generate_bids_fixture.py`) |
| Doc slim-down + legacy trim | `workflow/LEGACY.md`; RTD docs use `run_subject.sh` only |
| Golden QC outputs (docs) | `dwi_test_TBI/` |
| IDEAS sample download script | `scripts/download_ideas_sample.sh`, [datasets/ideas.md](../datasets/ideas.md) |

---

## Suggested sequencing

```text
Week 1 (P0):  registry PR · GitHub Release · Docker verify · RTD webhook · push doc trim
Week 2 (P1):  bids-validator CI · app.json flags · install_smoke schedule
Week 3+ (P1): real-container CI job (start with QSIPrep-only on bids_minimal)
Parallel (P4): URMC 61 + HCP 10 cohort runs (paper track)
Before v1.0:   P3 legacy code removal · P4 checklist · Zenodo · version bump
```

---

*Living document. Update when items close or priorities shift.*
