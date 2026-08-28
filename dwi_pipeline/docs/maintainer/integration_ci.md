# Integration CI (real containers)

How GitHub Actions exercises **real** Apptainer pulls and (optionally) `./run`. PR CI (`dwi_pipeline_ci.yml`) stays fast with stub `.sif` files and Snakemake dry-runs.

---

## FreeSurfer license — per user, not per repo

Each site and user must obtain their own FreeSurfer license (free registration). **Public user instructions:** [Installation → FreeSurfer license](../installation.md#freesurfer-license-you-must-obtain-this) · [FAQ](../faq.md#do-i-need-a-freesurfer-license-who-provides-it).

At runtime:

```bash
export FS_LICENSE=/path/to/your/license.txt
```

**The project does not ship or centralize licenses.** Do not commit `license.txt` to git.

---

## What CI runs without any license

| Workflow | Default behavior | License needed? |
|----------|------------------|-----------------|
| `dwi_pipeline_ci.yml` | Stubs + dry-run | No (`BIDS_APP_CI=1`) |
| `install_smoke.yml` | Apptainer pull (qsiprep; **act** on schedule/release) | No |
| `act_containers_publish.yml` | Build/push Step 3.5 ACT images to GHCR | No |
| `integration_qsiprep.yml` | Pull QSIPrep + `qsiprep --version` | No |
| `integration_ideas.yml` | OpenNeuro download + **dry-run** | No (`BIDS_APP_CI=1` + stub file) |
| `docker_auto_install_smoke.yml` | Docker dry-run | No (stub file) |

These prove registry pins, install paths, and Snakemake wiring — without anyone's personal license.

---

## Optional: full QSIPrep run in GitHub Actions

If **you** (a maintainer) want CI to execute real QSIPrep on `bids_minimal`, you may add an **optional** repository secret:

1. GitHub → **Settings → Secrets → Actions → New secret**
2. Name: `FS_LICENSE`
3. Value: your own license text

Then `integration_qsiprep.yml` will also run `./run` (not just pull + version). **This is optional** — the repo is healthy without it.

For IDEAS **real** runs (`workflow_dispatch` → `qsiprep-only`), the same optional secret is required; scheduled monthly jobs stay dry-run only.

**Prefer local/HPC validation** with your own license:

```bash
export FS_LICENSE=/path/to/license.txt
bash dwi_pipeline/scripts/install.sh --mode qsiprep
cd dwi_pipeline
./run tests/fixtures/bids_minimal /tmp/out participant \
  --participant-label EXAMPLE --session-filter baseline \
  --mode qsiprep --no-sdc --no-dwi-filter
bash scripts/integration_verify_qsiprep.sh /tmp/out EXAMPLE
```

---

## Workflows reference

| Workflow | When | What it proves |
|----------|------|----------------|
| [`integration_qsiprep.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.github/workflows/integration_qsiprep.yml) | Weekly, releases, manual | Pull + version; optional full run |
| [`integration_ideas.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.github/workflows/integration_ideas.yml) | Monthly, manual | IDEAS download + dry-run (or real if secret set) |
| [`install_smoke.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.github/workflows/install_smoke.yml) | Weekly | Apptainer pull pins |
| [`docker_auto_install_smoke.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.github/workflows/docker_auto_install_smoke.yml) | Weekly | `DKT_AUTO_INSTALL=1` smoke |

Local verification after a real local run:

```bash
bash dwi_pipeline/scripts/integration_verify_qsiprep.sh /path/to/RESULTS_ROOT EXAMPLE
```

---

## Self-hosted runner (full DAG / URMC)

GitHub-hosted runners are small (~7 GB disk). For **full pipeline** integration on your cluster:

1. Register a [self-hosted runner](https://docs.github.com/en/actions/hosting-your-own-runners) with Apptainer + `/scratch` cache.
2. Use **your** `FS_LICENSE` on that machine (env or mounted path — not necessarily a GitHub secret).
3. Run `./run` without `--dry-run` on IDEAS or a test subject.

See [v1 science track](v1_science_track.md) for cohort-scale runs.

---

## Exit criteria (P1.1)

- [ ] `integration_qsiprep.yml` green weekly (pull + version — **no license required**)
- [ ] `install_smoke.yml` green weekly
- [ ] *(Optional)* Real `./run` in CI or on HPC with **your** license
- [ ] *(Optional)* Self-hosted full DAG job

Track status: [Readiness checklist](readiness_checklist.md) P1.1.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Missing FreeSurfer license` locally | Register and `export FS_LICENSE=...` — [installation.md](../installation.md) |
| Integration skips full `./run` | Expected without optional `FS_LICENSE` secret — run locally instead |
| Apptainer pull timeout | Re-run workflow; use self-hosted runner with warm cache |
| QSIPrep fails on `bids_minimal` | Tiny synthetic data — use IDEAS locally with real license |
| IDEAS `qsiprep-only` fails in Actions | Add optional secret or run on HPC |
