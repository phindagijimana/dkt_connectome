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

## Site still shows “TrackTBI Connectome Pipeline”?

The product name is **DKT Connectome Pipeline** (`dwi_pipeline/mkdocs.yml` → `site_name`).

If Read the Docs still shows the old title, the hosted build is stale (webhook missed or failed):

1. Open [RTD dashboard → dkt-connectome → Builds](https://app.readthedocs.org/projects/dkt-connectome/builds/).
2. Click **Build version** → choose `latest` / `main` → **Build**.
3. Confirm the build commit is at or after the rebrand (`25f3740`+).

Local check (should print `DKT Connectome Pipeline`):

```bash
cd dwi_pipeline && mkdocs build && grep -o '<title>.*</title>' site/index.html
```
