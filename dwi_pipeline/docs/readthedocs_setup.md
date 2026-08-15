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

The product name is **DKT Connectome Pipeline** (`dwi_pipeline/mkdocs.yml` → `site_name`). The GitHub source is already correct; the hosted site is **stale** because Read the Docs has not rebuilt since the rebrand (no GitHub webhook is configured on the repo).

### Fix now (manual, ~1 minute)

1. Open [RTD → dkt-connectome → Versions](https://app.readthedocs.org/projects/dkt-connectome/versions/).
2. Click **latest** → open the build link (or use **Integrations** to connect GitHub for automatic builds).
3. On the version row, use the menu (⋮) → **Build version** if available, or go to [Settings → Integrations](https://app.readthedocs.org/dashboard/dkt-connectome/integrations/) → **Add integration** → **GitHub incoming webhook** / connect repository.
4. Alternatively: [Builds](https://app.readthedocs.org/projects/dkt-connectome/builds/) → trigger a new build for `latest`.

Confirm the new build uses commit **`42c10ec`** or later.

### Fix permanently (automatic rebuilds on push)

**Option A — GitHub Actions (recommended)**

1. Create a token at https://readthedocs.org/accounts/tokens/
2. Add GitHub secret **`READTHEDOCS_TOKEN`** on `phindagijimana/dkt_connectome`
3. Workflow `.github/workflows/readthedocs.yml` triggers RTD on every docs push

**Option B — RTD GitHub integration**

Connect the repo under [Integrations](https://app.readthedocs.org/dashboard/dkt-connectome/integrations/) so pushes to `main` rebuild automatically (no token in GitHub required).
