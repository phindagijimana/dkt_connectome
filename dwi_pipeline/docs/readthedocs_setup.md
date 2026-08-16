# Read the Docs — setup

**Full runbook:** [Maintainer tasks §14](maintainer/maintainer_tasks.md#14-read-the-docs-auto-rebuild) · [Publishing](maintainer/publishing.md)

---

## One-time

1. Sign in at [readthedocs.org](https://readthedocs.org/) → import `phindagijimana/dkt_connectome`
2. Project slug: **`dkt-connectome`**
3. Config: [`.readthedocs.yaml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.readthedocs.yaml) → `dwi_pipeline/mkdocs.yml`

**Auto-rebuild on push (pick one):**

| Option | Setup |
|--------|--------|
| **A — GitHub secret** | RTD token → repo secret `READTHEDOCS_TOKEN` → workflow [`.github/workflows/readthedocs.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.github/workflows/readthedocs.yml) |
| **B — RTD GitHub integration** | [RTD Integrations](https://app.readthedocs.org/dashboard/dkt-connectome/integrations/) → connect GitHub |

**Manual rebuild:** [RTD Builds](https://app.readthedocs.org/projects/dkt-connectome/builds/) → Build version `latest`

---

## Local preview

```bash
pip install -r dwi_pipeline/docs/requirements.txt
cd dwi_pipeline && mkdocs serve
# http://127.0.0.1:8000
```

Strict (matches CI): `mkdocs build --strict`

Verify live site after rebuild: `bash dwi_pipeline/scripts/verify_rtd_live.sh`

---

## Doc map (avoid duplicate reading)

| If you need… | Read… |
|--------------|--------|
| Science / theory | [Science overview](../science_overview.md) |
| Per-step methods + citations | [Methods](../methods/index.md) |
| Flags, paths, outputs | [Pipeline steps](../pipeline_steps.md) |
| `./run` reference | [Usage](../usage.md) or [BIDS App](../bids_app.md) |
| What's left to ship | [remaining.md](https://github.com/phindagijimana/dkt_connectome/blob/main/remaining.md) |
