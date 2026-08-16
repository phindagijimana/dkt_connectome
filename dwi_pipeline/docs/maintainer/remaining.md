# Remaining work

Canonical copy: [`remaining.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/remaining.md) at the repository root (edit there; this page is included in the docs site).

---

<!-- Content synced from repo root remaining.md -->

**Last updated:** 2026-08-16 · **Current release:** v0.2.0

Living tracker of **open** work. Detailed IDs: [Readiness checklist](readiness_checklist.md).

---

## Status in one paragraph

The BIDS App is **ready for use** at v0.2.0: `./run`, participant + group levels, `app.json`, docs, GitHub Release, Docker Hub orchestrator, CI dry-run + bids-validator, [science/theory pages](../science_overview.md). **Not done:** optional registry listings, Dockstore + WorkflowHub one-shots, Zenodo DOI, confirming integration CI green weekly, v1.0 cohort science, legacy code removal.

| Level | Verdict |
|-------|---------|
| **Spec-compliant BIDS App (run in production)** | ✅ Yes |
| **Listed on bids-apps.neuroimaging.io** | ⏸ Optional (deferred) |
| **QSIPrep-style single-image + full E2E CI** | ❌ Not targeted for v0.2 |
| **v1.0 + paper + cohort validation** | ❌ Open (P4) |

---

## Open — maintainer one-shots (P0)

| Task | Doc |
|------|-----|
| Link **Dockstore** to GitHub | [maintainer_tasks §15](maintainer_tasks.md#15-dockstore-github-link) |
| Upload **WorkflowHub** RO-Crate (optional) | [maintainer_tasks §16](maintainer_tasks.md#16-workflowhub-ro-crate-upload) |
| **BIDS Apps registry** PR (optional) | [BIDS_App.md](../BIDS_App.md) |

**Done:** GitHub Release v0.2.0 · Docker Hub · RTD · legacy doc trim.

---

## Open — engineering (P1)

| Task | Status | Notes |
|------|--------|-------|
| Integration CI weekly green | Scaffolded | [integration_ci.md](integration_ci.md) — pull + version, no license |
| Docker auto-install smoke | Scaffolded | `docker_auto_install_smoke.yml` |
| IDEAS golden CI | Scaffolded | Monthly dry-run |
| Real E2E `./run` in CI | Optional | Users’ own `FS_LICENSE`; HPC/local |

**Done:** bids-validator · install_smoke · app.json · `--mem-mb` · doc deprecation · Dockerfile Apptainer.

---

## Open — docs & citation (P2)

| Task | Notes |
|------|-------|
| **Zenodo + DOI** | [§17](maintainer_tasks.md#17-zenodo-archive-doi) |
| Version 0.2 vs 1.0 policy | After P4 |
| BIDS Derivatives policy | [derivatives.md](../derivatives.md) |
| Manuscript digests | [manuscript.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/sample_software_paper/manuscript.md) |

**Done:** RTD hub · [science overview](../science_overview.md) · FreeSurfer license docs.

---

## Open — code cleanup (P3)

Defer until no legacy HPC jobs: bash engine · dual-container Step 4 · root `./connectome` · disconnectome default promotion. [LEGACY.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/workflow/LEGACY.md)

---

## Open — v1.0 science (P4)

[v1_science_track.md](v1_science_track.md) — URMC n=61 · HCP n=10 · radiology · figures · bioRxiv · v1.0 tag · digest table. **Does not block v0.2 use.**

---

## Optional stretch (P5)

Monolithic Docker · `bids-apps` org · public regression dataset.

---

## Suggested order

```text
1. Integration + auto-install workflows green
2. Dockstore link
3. Zenodo DOI (v0.2.0)
4. URMC 61 + HCP 10 (parallel)
5. v1.0 + preprint
6. Optional registry · legacy removal
```

---

## Already shipped

See [readiness checklist → Already done](readiness_checklist.md#already-done-baseline).

*Update [remaining.md](https://github.com/phindagijimana/dkt_connectome/blob/main/remaining.md) at repo root when closing items.*
