# BIDS Apps registry submission checklist

Use this checklist when submitting **DKT Connectome v0.2.0** to the
[BIDS Apps registry](https://bids-apps.neuroimaging.io/apps/).

Full prioritized backlog: [Readiness checklist](maintainer/readiness_checklist.md).

## Repository requirements (done in this repo)

| Item | Location |
|------|----------|
| BIDS App entrypoint `./run` | `dwi_pipeline/run` |
| Machine-readable metadata | `dwi_pipeline/app.json` |
| Boutiques descriptor | `dwi_pipeline/dkt_connectome_bids_app.json` |
| Human documentation | https://dkt-connectome.readthedocs.io/en/latest/ |
| Minimal public test dataset | `dwi_pipeline/tests/fixtures/bids_minimal/` |
| CI smoke test | `.github/workflows/dwi_pipeline_ci.yml` |
| Docker orchestrator image | `dwi_pipeline/Dockerfile` → `phindagijimana321/dkt-connectome:0.2.0` |

## One-time maintainer steps

### 1. Read the Docs

1. Sign in at https://readthedocs.org/ with GitHub.
2. Import `phindagijimana/dkt_connectome`.
3. Project slug: **`dkt-connectome`**.
4. Confirm build succeeds (uses `.readthedocs.yaml`).

### 2. Docker Hub

**Status (v0.2.0):** Published at `docker.io/phindagijimana321/dkt-connectome:0.2.0` and `:latest`.

CI pushes to **GHCR** on every build; mirror to Docker Hub with:

```bash
cd dwi_pipeline
bash scripts/mirror_ghcr_to_dockerhub.sh --version 0.2.0
```

Or build/push locally:

```bash
docker build -f dwi_pipeline/Dockerfile -t phindagijimana321/dkt-connectome:0.2.0 .
docker push phindagijimana321/dkt-connectome:0.2.0
docker tag phindagijimana321/dkt-connectome:0.2.0 phindagijimana321/dkt-connectome:latest
docker push phindagijimana321/dkt-connectome:latest
```

Set GitHub secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` to enable automatic
push on version tags (`.github/workflows/docker_publish.yml`).

> **Note:** The Docker image is an **orchestrator** only. Step containers (QSIPrep,
> FreeSurfer, etc.) must be provided at runtime via `CONTAINER_*` env vars or
> bind-mounts — same as HPC Apptainer deployments.

### 3. Git release

```bash
git tag v0.2.0
git push origin main
git push origin v0.2.0
```

### 4. Registry listing

**Option A — Email BIDS maintainers**

```
To: bids.maintenance+apps@gmail.com
Subject: BIDS App submission — DKT Connectome v0.2.0

Name: DKT Connectome
Version: 0.2.0
GitHub: https://github.com/phindagijimana/dkt_connectome
Documentation: https://dkt-connectome.readthedocs.io/en/latest/
Docker Hub: docker.io/phindagijimana321/dkt-connectome:0.2.0
Test dataset: dwi_pipeline/tests/fixtures/bids_minimal/
```

**Option B — PR to [bids-standard/bids-website](https://github.com/bids-standard/bids-website)**

Fork and add an entry to `data/tools/apps.yml`:

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
  description: Lesion-aware Desikan-Killiany structural connectomics (QSIPrep → recon → QSIRecon → connectome → disconnectome).
```

### 5. Optional: bids-apps GitHub org

For automatic CircleCI → Docker Hub under the `bids-apps` namespace, request a repo
from the maintainers and mirror this pipeline layout.

## Smoke test (local)

```bash
export BIDS_APP_CI=1
export FS_LICENSE=/tmp/license.txt && touch /tmp/license.txt
cd dwi_pipeline
./run tests/fixtures/bids_minimal /tmp/out participant \
  --participant-label EXAMPLE --session-filter baseline \
  --dry-run --no-sdc --no-dwi-filter --random-seed 42
pytest tests/test_bids_app.py -q
```

## Docker smoke test (local)

```bash
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
