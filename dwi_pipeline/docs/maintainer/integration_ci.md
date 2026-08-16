# Integration CI (real containers)

How to run **real** Apptainer/QSIPrep jobs in GitHub Actions and on a self-hosted runner. PR CI (`dwi_pipeline_ci.yml`) stays fast with stub `.sif` files and Snakemake dry-runs.

---

## Workflows

| Workflow | When | What it proves |
|----------|------|----------------|
| [`integration_qsiprep.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.github/workflows/integration_qsiprep.yml) | Weekly, releases, manual | Pull QSIPrep → `./run` on `bids_minimal` → marker + outputs |
| [`integration_ideas.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.github/workflows/integration_ideas.yml) | Monthly, manual | OpenNeuro ds007401 download → dry-run or QSIPrep-only |
| [`install_smoke.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.github/workflows/install_smoke.yml) | Weekly | Apptainer pull pins (no `./run`) |
| [`docker_auto_install_smoke.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.github/workflows/docker_auto_install_smoke.yml) | Weekly, Dockerfile changes | `DKT_AUTO_INSTALL=1` inside orchestrator image |

Local verification script:

```bash
bash dwi_pipeline/scripts/integration_verify_qsiprep.sh /path/to/RESULTS_ROOT EXAMPLE
```

---

## Required GitHub secret: `FS_LICENSE`

1. GitHub → **Settings → Secrets and variables → Actions → New repository secret**
2. Name: `FS_LICENSE`
3. Value: **full text** of your FreeSurfer `license.txt` (same file you use on HPC)

Without this secret, `integration_qsiprep.yml` and `integration_ideas.yml` fail at the first step with an explicit error.

**Never commit** the license file. CI writes it to `/tmp/license.txt` at runtime only.

---

## Manual run (maintainer)

```bash
# GitHub CLI
gh workflow run integration_qsiprep.yml
gh workflow run integration_qsiprep.yml -f skip_pipeline_run=true   # pull + version only
gh workflow run integration_ideas.yml -f analysis=dry-run -f subject=1 -f session=1
```

Watch: **Actions** tab → workflow run → logs.

---

## Self-hosted runner (full DAG / URMC)

GitHub-hosted `ubuntu-latest` is limited (~7 GB disk, 2 vCPU, 6 h max). For **full pipeline** integration (recon + QSIRecon + connectome):

1. Register a [self-hosted runner](https://docs.github.com/en/actions/hosting-your-own-runners) on a URMC login or build node with:
   - Apptainer/Singularity
   - `/scratch` or large cache for `DKT_CONTAINER_CACHE`
   - FreeSurfer license at a fixed path (or inject via secret in workflow)

2. Label the runner, e.g. `urmc-hpc`.

3. Add a job (or duplicate `integration_qsiprep.yml` job):

   ```yaml
   qsiprep-full-local:
     runs-on: [self-hosted, urmc-hpc]
     if: github.event_name == 'workflow_dispatch'
   ```

4. Mount cache between runs:

   ```yaml
   env:
     DKT_CONTAINER_CACHE: /scratch/${{ github.actor }}/dkt-connectome/containers
   ```

5. Run full `./run` without `--dry-run` on IDEAS or URMC test subject.

**Do not** make self-hosted full runs PR-gating until stable and fast enough.

---

## Exit criteria (P1.1)

- [ ] `FS_LICENSE` secret set
- [ ] `integration_qsiprep.yml` green on manual dispatch
- [ ] Weekly schedule stays green (or alerts via GitHub notifications)
- [ ] *(Optional)* Self-hosted job for `--mode all` on one public subject

Track status: [Readiness checklist](readiness_checklist.md) P1.1.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Set repository secret FS_LICENSE` | Add secret (see above) |
| Apptainer pull timeout | Re-run; or use self-hosted runner with warm cache |
| QSIPrep fails on `bids_minimal` | Expected on tiny synthetic volumes — use IDEAS workflow for realistic data; check `logs/sub-*_qsiprep.log` |
| IDEAS download fails | AWS CLI + network; OpenNeuro S3 is public (`aws s3 ls s3://openneuro.org/ds007401/`) |
| Docker auto-install empty cache | Orchestrator image must include Apptainer (see `Dockerfile`); first run pulls qsiprep only when `--mode qsiprep` |
