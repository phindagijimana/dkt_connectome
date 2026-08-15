# Read the Docs — one-time setup

The documentation site is built from this repository automatically once connected.

## Connect Read the Docs

1. Sign in at [readthedocs.org](https://readthedocs.org/) with GitHub.
2. **Import a project** → select `phindagijimana/dkt_connectome`.
3. RTD reads [`.readthedocs.yaml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.readthedocs.yaml) at the repo root.
4. Set the **project slug** to `dkt-connectome` (matches URLs in `app.json`).
5. Default version: `latest` from `main` branch.

## Local preview

```bash
pip install mkdocs
cd dwi_pipeline
mkdocs serve
# open http://127.0.0.1:8000
```

Strict build (matches CI):

```bash
mkdocs build --strict
```

## After first publish

Update any bookmark to:

**https://dkt-connectome.readthedocs.io/en/latest/**

The BIDS Apps registry submission should use this URL as `Documentation` in `app.json` (already set).
