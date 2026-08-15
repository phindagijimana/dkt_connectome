# Read the Docs — one-time setup

**Maintainer checklist:** see [Publishing](maintainer/publishing.md) for the full deploy workflow and live-site verification.

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

## Site still shows “TrackTBI Connectome” (or old “Pipeline” name)?

The product name is **DKT Connectome** (`dwi_pipeline/mkdocs.yml` → `site_name`). The GitHub source is already correct; the hosted site is **stale** because Read the Docs has not rebuilt since the rebrand (no GitHub webhook is configured on the repo).

Also check the RTD **project display name** (separate from `site_name`):

1. [Admin → Settings → Project name](https://app.readthedocs.org/dashboard/dkt-connectome/edit/) → set to **DKT Connectome** (not TrackTBI Connectome Pipeline).
2. Save and rebuild **latest**.

After a successful rebuild, the browser tab title, sidebar header, and search box area should all read **DKT Connectome**.

### Fix now (manual, ~1 minute)

1. Open [RTD → dkt-connectome → Versions](https://app.readthedocs.org/projects/dkt-connectome/versions/).
2. Click **latest** → open the build link (or use **Integrations** to connect GitHub for automatic builds).
3. On the version row, use the menu (⋮) → **Build version** if available, or go to [Settings → Integrations](https://app.readthedocs.org/dashboard/dkt-connectome/integrations/) → **Add integration** → **GitHub incoming webhook** / connect repository.
4. Alternatively: [Builds](https://app.readthedocs.org/projects/dkt-connectome/builds/) → trigger a new build for `latest`.

Confirm the new build uses commit **`9c52d48`** or later (must include `site_name: DKT Connectome` in `dwi_pipeline/mkdocs.yml`).

### Browser favicon (QSIPrep-style)

QSIPrep uses the default **sphinx-rtd-theme** favicon (Read the Docs book icon). MkDocs `readthedocs` theme ships the same icon at build time (`img/favicon.ico` in the built site).

If the tab icon looks wrong:

1. Rebuild **latest** on RTD (stale builds cache old assets).
2. In [RTD Admin → Settings](https://app.readthedocs.org/dashboard/dkt-connectome/edit/), clear any custom **Project image / favicon** override if set.
3. Hard-refresh the browser (Ctrl+Shift+R).

Optional: copy the theme favicon into the repo for a pinned asset:

```bash
python3 dwi_pipeline/scripts/fetch_docs_favicon.py
# then set site_favicon: img/favicon.ico in mkdocs.yml
```

### Fix permanently (automatic rebuilds on push)

**Option A — GitHub Actions (recommended)**

1. Create a token at https://readthedocs.org/accounts/tokens/
2. Add GitHub secret **`READTHEDOCS_TOKEN`** on `phindagijimana/dkt_connectome`
3. Workflow `.github/workflows/readthedocs.yml` triggers RTD on every docs push

**Option B — RTD GitHub integration**

Connect the repo under [Integrations](https://app.readthedocs.org/dashboard/dkt-connectome/integrations/) so pushes to `main` rebuild automatically (no token in GitHub required).
