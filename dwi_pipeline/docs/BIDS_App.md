# BIDS App registry submission

Optional guide to list **DKT Connectome v0.2.0** on the official [BIDS Apps registry](https://bids-apps.neuroimaging.io/apps/).

**You do not need this listing** to release, cite, or run the pipeline. For release, Docker, RTD, Dockstore, and WorkflowHub steps, see [Maintainer one-shot tasks](maintainer/maintainer_tasks.md).

**Related:** [BIDS App usage](bids_app.md) (how to run `./run`) · [Readiness checklist](maintainer/readiness_checklist.md) · [`app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/app.json)

---

## What you are submitting

The registry lists apps that follow the [BIDS Apps specification](https://bids-apps.neuroimaging.io/):

```text
./run <bids_dir> <output_dir> <analysis_level> [options]
```

| Field | DKT Connectome value |
|-------|----------------------|
| **Name** | DKT Connectome |
| **Version** | `0.2.0` (`./run --version`) |
| **GitHub** | https://github.com/phindagijimana/dkt_connectome |
| **Entrypoint** | `dwi_pipeline/run` (working directory: `dwi_pipeline/`) |
| **Documentation** | https://dkt-connectome.readthedocs.io/en/latest/ |
| **Docker Hub** | `phindagijimana321/dkt-connectome:0.2.0` |
| **Test dataset** | `dwi_pipeline/tests/fixtures/bids_minimal/` (public, synthetic) |
| **CI workflow** | `.github/workflows/dwi_pipeline_ci.yml` (`name: dwi_pipeline`) |
| **License** | Apache-2.0 |

!!! note "Multi-container orchestrator"
    Unlike QSIPrep’s single monolithic image, this BIDS App **orchestrates** pinned step containers (QSIPrep, FreeSurfer, QSIRecon, connectome, LIT, nodestrength). The Docker Hub image is an **orchestrator only**; step images mount at runtime (same as HPC Apptainer). Say this explicitly in your submission so reviewers do not expect one `docker pull` to include FreeSurfer.

---

## Prerequisites (complete before submitting)

Check each item. Most repo work is already done; remaining steps are maintainer one-shots.

| # | Requirement | Status | How to verify |
|---|-------------|--------|---------------|
| 1 | Public GitHub repo with `./run` | Done | [`dwi_pipeline/run`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/run) |
| 2 | `app.json` metadata | Done | [`dwi_pipeline/app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/app.json) |
| 3 | Human-readable docs (URL) | Done | https://dkt-connectome.readthedocs.io/en/latest/ |
| 4 | Minimal public test BIDS dataset | Done | `dwi_pipeline/tests/fixtures/bids_minimal/` |
| 5 | CI tests the app interface | Done | `.github/workflows/dwi_pipeline_ci.yml` |
| 6 | Docker image on Docker Hub | Verify | `docker pull phindagijimana321/dkt-connectome:0.2.0` |
| 7 | Git tag + GitHub Release | Open | Tag `v0.2.0` exists; create release with [`RELEASE_NOTES.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/RELEASE_NOTES.md) |
| 8 | RTD builds on push | Verify | https://readthedocs.org/projects/dkt-connectome/ |

---

## Pre-submission verification (run locally)

From the repository root:

### 1. BIDS App pytest + validator

```bash
cd dwi_pipeline

# Regenerate validator-clean fixture
python3 tests/fixtures/generate_bids_fixture.py

# BIDS validation
bash scripts/run_bids_validator.sh tests/fixtures/bids_minimal --ignore-warnings

# Unit / smoke tests
export BIDS_APP_CI=1
export FS_LICENSE=/tmp/license.txt && touch /tmp/license.txt
pytest tests/test_bids_app.py -q

# Dry-run participant invocation
./run tests/fixtures/bids_minimal /tmp/out participant \
  --participant-label EXAMPLE --session-filter baseline \
  --dry-run --no-sdc --no-dwi-filter --random-seed 42
```

### 2. Docker orchestrator smoke test

```bash
# From repo root
docker build -f dwi_pipeline/Dockerfile -t dkt-connectome:local .
docker run --rm dkt-connectome:local --version

docker run --rm \
  -v "$PWD/dwi_pipeline/tests/fixtures/bids_minimal:/data/bids:ro" \
  -v /tmp/out:/out \
  -e BIDS_APP_CI=1 \
  -e FS_LICENSE=/tmp/license.txt \
  dkt-connectome:local \
  /data/bids /out participant \
  --participant-label EXAMPLE --session-filter baseline \
  --dry-run --no-sdc --no-dwi-filter
```

### 3. GitHub Release (recommended before listing)

```bash
git push origin main
git push origin v0.2.0   # if not already on remote

gh release create v0.2.0 \
  --title "DKT Connectome 0.2.0" \
  --notes-file dwi_pipeline/RELEASE_NOTES.md
```

### 4. Docker Hub (if pull fails)

```bash
cd dwi_pipeline
bash scripts/mirror_ghcr_to_dockerhub.sh --version 0.2.0
```

Or set GitHub secrets `DOCKERHUB_USERNAME` + `DOCKERHUB_TOKEN` and re-run the Docker publish workflow.

---

## Submit — Option A: Email (fastest)

Send to **bids.maintenance+apps@gmail.com**.

**Subject:** `BIDS App submission — DKT Connectome v0.2.0`

**Body (copy-paste and adjust if needed):**

```text
Name: DKT Connectome
Version: 0.2.0

GitHub: https://github.com/phindagijimana/dkt_connectome
Entrypoint: dwi_pipeline/run (BIDS App CLI; run from dwi_pipeline/ or use Docker image)
Documentation: https://dkt-connectome.readthedocs.io/en/latest/
Docker Hub: docker.io/phindagijimana321/dkt-connectome:0.2.0
License: Apache-2.0

Analysis levels: participant, group
Inputs: dwi, T1w, fmap (optional)
Outputs: structural connectome CSV/JSON, optional disconnectome, QC HTML

Test dataset (public, synthetic):
  dwi_pipeline/tests/fixtures/bids_minimal/
  Subject: sub-EXAMPLE, session: ses-baseline

CI: GitHub Actions workflow "dwi_pipeline" (.github/workflows/dwi_pipeline_ci.yml)
  — pytest, bids-validator, Snakemake dry-run, Docker smoke dry-run

Container model:
  The Docker image is an orchestrator (Snakemake + ./run). Step containers
  (QSIPrep, FreeSurfer, QSIRecon, etc.) are pinned Apptainer/Docker images
  mounted at runtime — documented at:
  https://dkt-connectome.readthedocs.io/en/latest/containers/

Machine-readable metadata: dwi_pipeline/app.json
Boutiques descriptor: dwi_pipeline/dkt_connectome_bids_app.json

Maintainer: [your name / lab contact]
```

Expect a reply asking for clarification or confirmation; link to the full submission doc on RTD if helpful:

`https://dkt-connectome.readthedocs.io/en/latest/BIDS_App/`

---

## Submit — Option B: Pull request (persistent listing)

The live registry is driven by [`data/tools/apps.yml`](https://github.com/bids-standard/bids-website/blob/main/data/tools/apps.yml) on the BIDS website repo.

### Step 1 — Fork and clone

```bash
# On GitHub: fork https://github.com/bids-standard/bids-website
git clone https://github.com/YOUR_USER/bids-website.git
cd bids-website
git remote add upstream https://github.com/bids-standard/bids-website.git
git checkout -b add-dkt-connectome-app
```

### Step 2 — Add the app entry

Edit `data/tools/apps.yml`. Add under the **“apps hosted somewhere else”** section (alphabetically by Docker Hub name `phindagijimana321/dkt-connectome` → near `p` entries, or at end of external apps):

```yaml
- gh: phindagijimana/dkt_connectome
  status: active
  dh: phindagijimana321/dkt-connectome
  ci: gh
  branch: main
  workflow: dwi_pipeline
  ds_type:
    - raw
    - derivative
  datatype:
    - anat
    - dwi
    - fmap
  description: |
    Lesion-aware structural connectomics BIDS App (QSIPrep → optional neuroLIT
    inpainting → FreeSurfer/FastSurfer → QSIRecon ACT-HSVS → DKT connectome →
    optional disconnectome → node-strength report). Multi-container orchestrator;
    see documentation for runtime container mounts.
```

**Field reference:**

| Key | Value | Notes |
|-----|-------|-------|
| `gh` | `phindagijimana/dkt_connectome` | GitHub `owner/repo` |
| `dh` | `phindagijimana321/dkt-connectome` | Docker Hub `user/repo` (no tag) |
| `ci` | `gh` | GitHub Actions (not CircleCI) |
| `branch` | `main` | Default branch |
| `workflow` | `dwi_pipeline` | Matches `name:` in `dwi_pipeline_ci.yml` |
| `ds_type` | `raw`, `derivative` | Accepts BIDS raw; can write derivatives |
| `datatype` | `anat`, `dwi`, `fmap` | Primary modalities |

### Step 3 — Open the PR

```bash
git add data/tools/apps.yml
git commit -m "Add DKT Connectome BIDS App"
git push origin add-dkt-connectome-app
gh pr create --repo bids-standard/bids-website \
  --title "Add DKT Connectome BIDS App" \
  --body "$(cat <<'EOF'
## Summary
Adds **DKT Connectome v0.2.0** — lesion-aware structural connectomics BIDS App.

- GitHub: https://github.com/phindagijimana/dkt_connectome
- Docs: https://dkt-connectome.readthedocs.io/en/latest/
- Docker Hub: phindagijimana321/dkt-connectome
- CI: GitHub Actions workflow `dwi_pipeline` (pytest, bids-validator, Snakemake dry-run)
- Test data: public synthetic fixture in-repo (`dwi_pipeline/tests/fixtures/bids_minimal/`)

**Note:** Docker image is a multi-container **orchestrator** (Snakemake + ./run); step images are mounted at runtime, as documented in the app README.

EOF
)"
```

### Step 4 — Respond to review

Maintainers may ask for:

- CI badge / green workflow on `main`
- Confirmation Docker image pulls
- Clarification of entrypoint path (`dwi_pipeline/run` vs repo root)
- Link to BIDS App usage documentation

Point reviewers to this page and [bids_app.md](bids_app.md).

---

## After listing

1. **Confirm** the app appears at https://bids-apps.neuroimaging.io/apps/
2. **Update** [citation.md](citation.md) if the registry URL was “TBD”
3. **Tick** P0.1 on [readiness checklist](maintainer/readiness_checklist.md)
4. **Optional:** request membership in the [`bids-apps` GitHub org](https://github.com/bids-apps) for CircleCI → `bids/` Docker Hub namespace (not required for listing)

---

## Optional: join the bids-apps organization

Some legacy apps live under `bids-apps/` on GitHub and publish to `docker.io/bids/<name>` via CircleCI. DKT Connectome currently uses:

- GitHub: `phindagijimana/dkt_connectome`
- Docker Hub: `phindagijimana321/dkt-connectome`

To migrate:

1. Email bids.maintenance+apps@gmail.com requesting a `bids-apps/dkt_connectome` repo (or similar).
2. Mirror the pipeline layout (`run`, `Dockerfile`, `.circleci/config.yml` if required).
3. Update `apps.yml` `gh` and `dh` fields after migration.

This is **optional** — external listing (Option A or B above) is sufficient.

---

## Registry metadata quick reference

For copy-paste into forms, emails, or grant data-management plans:

```json
{
  "name": "DKT Connectome",
  "version": "0.2.0",
  "bids_app_spec": "https://bids-apps.neuroimaging.io/",
  "github": "https://github.com/phindagijimana/dkt_connectome",
  "documentation": "https://dkt-connectome.readthedocs.io/en/latest/",
  "docker_hub": "docker.io/phindagijimana321/dkt-connectome:0.2.0",
  "entrypoint": "dwi_pipeline/run",
  "test_dataset": "dwi_pipeline/tests/fixtures/bids_minimal",
  "analysis_levels": ["participant", "group"],
  "license": "Apache-2.0"
}
```

Full machine-readable descriptor: [`dwi_pipeline/app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/app.json).

---

## FAQ

### Is the app “fully tested” for listing?

CI runs **dry-run** smoke tests, `bids-validator`, and pytest — not full QSIPrep/FreeSurfer execution. That matches many orchestrator-style apps; disclose the multi-container model in the submission. See [validation.md](validation.md) for scientific validation status.

### Why is `./run` under `dwi_pipeline/`?

The repository root retains a legacy 4-stage Snakemake workflow. The **canonical** BIDS App is `dwi_pipeline/run`. The Docker image sets `WORKDIR` to `dwi_pipeline/` so the entrypoint behaves like a standard BIDS App.

### What if CI workflow name does not match?

The `workflow:` field in `apps.yml` must match the **`name:`** key in `.github/workflows/dwi_pipeline_ci.yml` (`dwi_pipeline`), not the filename.

### Who do I contact for registry issues?

- BIDS Apps maintenance: bids.maintenance+apps@gmail.com  
- DKT Connectome issues: https://github.com/phindagijimana/dkt_connectome/issues

---

*Last updated for v0.2.0 — update version strings when releasing v0.3.0+.*
