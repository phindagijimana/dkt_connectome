# BIDS Apps registry — quick checklist

> **Full submission guide:** [BIDS_App.md](BIDS_App.md) — email template, PR steps, verification commands, FAQ.

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

## Submit

Follow **[BIDS_App.md](BIDS_App.md)** for:

1. Pre-submission verification commands  
2. **Option A** — email to `bids.maintenance+apps@gmail.com`  
3. **Option B** — PR to `bids-standard/bids-website` → `data/tools/apps.yml`  

## One-time maintainer steps (before listing)

| Step | Doc section |
|------|-------------|
| Read the Docs live | [BIDS_App.md § Prerequisites](BIDS_App.md#prerequisites-complete-before-submitting) |
| Docker Hub pull works | [BIDS_App.md § Pre-submission](BIDS_App.md#pre-submission-verification-run-locally) |
| GitHub Release | [Publishing](maintainer/publishing.md) |
| Registry PR or email | [BIDS_App.md](BIDS_App.md) |

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
