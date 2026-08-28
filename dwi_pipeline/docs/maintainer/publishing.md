# Release checklist

Use this page as a **pre-flight checklist** before tagging. Step-by-step runbooks live in **[Maintainer one-shot tasks](maintainer_tasks.md)**.

---

## Before you tag

1. Bump [`app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/app.json) `PipelineVersion` and [changelog.md](../changelog.md).
2. Regenerate generated docs:
   ```bash
   python3 dwi_pipeline/scripts/generate_config_catalog.py
   python3 dwi_pipeline/scripts/render_qc_doc_figures.py
   ```
3. Verify docs build: `cd dwi_pipeline && mkdocs build --strict`
4. Create tag and GitHub Release — **[§10 GitHub Release](maintainer_tasks.md#10-github-release-v020)**

---

## After you tag

| Task | Runbook |
|------|---------|
| Push orchestrator to Docker Hub | [§11 Push orchestrator](maintainer_tasks.md#11-push-orchestrator-to-docker-hub) |
| Verify `docker pull` | [§12 Verify Docker pull](maintainer_tasks.md#12-verify-docker-pull) |
| Rebuild Read the Docs | [§14 Read the Docs auto-rebuild](maintainer_tasks.md#14-read-the-docs-auto-rebuild) |
| Dockstore / WorkflowHub / Zenodo | [§15–17](maintainer_tasks.md) |

---

## Optional

- **[BIDS Apps registry submission](bids_apps_registry.md)** — only if you want a listing on bids-apps.neuroimaging.io
- Open work tracker: [Readiness checklist](readiness_checklist.md) · [remaining.md](https://github.com/phindagijimana/dkt_connectome/blob/main/remaining.md)

---

## CI overview

| Workflow | Role |
|----------|------|
| `dwi_pipeline_ci.yml` | pytest, MkDocs strict, doctor, Snakemake dry-run |
| `integration_qsiprep.yml` | QSIPrep pull + version smoke |
| `integration_ideas.yml` | IDEAS OpenNeuro golden (monthly / manual) |
| `docker_auto_install_smoke.yml` | `DKT_AUTO_INSTALL=1` in orchestrator image |
| `docker_publish.yml` | Build orchestrator → GHCR (+ Docker Hub if secrets set) |
| `act_containers_publish.yml` | Build Step 3.1 ACT images → GHCR (+ Docker Hub if secrets set) |
| `readthedocs.yml` | Trigger RTD rebuild |

Details: [Integration CI](integration_ci.md) · [Maintainer one-shot tasks](maintainer_tasks.md).
