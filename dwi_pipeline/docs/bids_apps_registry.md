# BIDS Apps registry — quick checklist

> **Optional** — listing on bids-apps.neuroimaging.io is not required for release.  
> **Full submission guide (if needed):** [BIDS_App.md](BIDS_App.md)  
> **Release, Docker, RTD, Dockstore, WorkflowHub:** [Maintainer one-shot tasks](maintainer/maintainer_tasks.md)

Use this page as a short checklist when submitting **DKT Connectome v0.2.0** to the
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

## Submit *(optional)*

Follow **[BIDS_App.md](BIDS_App.md)** only if you want a public registry listing.

For **release and infrastructure** (GitHub Release, Docker Hub, RTD, Dockstore, WorkflowHub), use **[Maintainer one-shot tasks](maintainer/maintainer_tasks.md)**.

## Smoke test (local)

```bash
export BIDS_APP_CI=1
export FS_LICENSE=/tmp/license.txt && touch /tmp/license.txt
cd dwi_pipeline
python3 tests/fixtures/generate_bids_fixture.py
bash scripts/run_bids_validator.sh tests/fixtures/bids_minimal --ignore-warnings
./run tests/fixtures/bids_minimal /tmp/out participant \
  --participant-label EXAMPLE --session-filter baseline \
  --dry-run --no-sdc --no-dwi-filter --random-seed 42
pytest tests/test_bids_app.py -q
```

See [BIDS_App.md](BIDS_App.md) for Docker smoke test commands.
