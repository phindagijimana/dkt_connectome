# Maintainer one-shot tasks

!!! note "Repository-local documentation"
    This page is **not** published on [Read the Docs](https://dkt-connectome.readthedocs.io/en/latest/). User-facing docs stay on the public site; maintainer runbooks live in the repo only. Index: [Contributing § Repository-local documentation](../contributing.md#repository-local-documentation).

Runbook for **credential-based, out-of-repo steps** that complete v0.2.0 publishing and registry visibility. These are done once (or per release) by a maintainer with GitHub, Docker Hub, and RTD access.

**Time budget:** about one afternoon if credentials are ready.

**Not in scope here:** BIDS Apps registry listing — optional and documented separately in [BIDS Apps registry submission](bids_apps_registry.md) if you choose to submit later. You do **not** need registry submission to cut a release or use the pipeline.

**Repo-side work** is tracked in [Readiness checklist](readiness_checklist.md) · [What's remaining](remaining.md). **Release + containers + docs** overlap with [Publishing](publishing.md).

---

## Quick checklist

| # | Task | Credentials | Doc section |
|---|------|-------------|-------------|
| 10 | GitHub Release v0.2.0 | `gh auth login` | [§10 GitHub Release](#10-github-release-v020) |
| 11 | Push orchestrator to Docker Hub | Docker Hub token or `podman login` | [§11 Docker Hub](#11-push-orchestrator-to-docker-hub) |
| 12 | Verify `docker pull` | Network | [§12 Verify pull](#12-verify-docker-pull) |
| 13 | BIDS Apps registry | *(optional — skip unless listing)* | [bids_apps_registry.md](bids_apps_registry.md) |
| 14 | RTD auto-rebuild | RTD token or GitHub integration | [§14 Read the Docs](#14-read-the-docs-auto-rebuild) |
| 15 | Dockstore GitHub link | Dockstore account | [§15 Dockstore](#15-dockstore-github-link) |
| 16 | WorkflowHub RO-Crate | WorkflowHub account | [§16 WorkflowHub](#16-workflowhub-ro-crate-upload) |
| 17 | Zenodo archive + DOI | Zenodo + GitHub | [§17 Zenodo](#17-zenodo-archive-doi) |

---

## Before you start

1. **Push code** to `main` (including [`RELEASE_NOTES.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/RELEASE_NOTES.md)).
2. Confirm **CI is green** on GitHub Actions → workflow `dwi_pipeline`.
3. Confirm tag **`v0.2.0`** exists locally and on remote:

   ```bash
   git fetch origin
   git tag -l 'v0.2.*'
   git ls-remote --tags origin v0.2.0
   ```

   If the tag is missing:

   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```

---

## 10. GitHub Release v0.2.0

**Goal:** A formal release on GitHub with notes (used by Dockstore, WorkflowHub, citations).

### Prerequisites

- [GitHub CLI](https://cli.github.com/) installed
- Authenticated: `gh auth login`
- Write access to `phindagijimana/dkt_connectome`

### Steps

```bash
cd /path/to/dkt_connectome

# Confirm tag points at the commit you want
git show v0.2.0 --oneline -1

# Create release (notes file is in-repo)
gh release create v0.2.0 \
  --title "DKT Connectome 0.2.0" \
  --notes-file dwi_pipeline/RELEASE_NOTES.md
```

If the release already exists but notes are empty:

```bash
gh release edit v0.2.0 --notes-file dwi_pipeline/RELEASE_NOTES.md
```

### Verify

```bash
gh release view v0.2.0
```

Open https://github.com/phindagijimana/dkt_connectome/releases/tag/v0.2.0

---

## 11. Push orchestrator to Docker Hub

**Goal:** `docker pull phindagijimana321/dkt-connectome:0.2.0` works for cloud users.

The **orchestrator** image (Snakemake + `./run`) is built in CI to **GHCR** first. Docker Hub is a mirror unless CI secrets are set.

### Option A — GitHub Actions (automatic on tag)

1. GitHub → **Settings → Secrets and variables → Actions**
2. Add secrets:
   - `DOCKERHUB_USERNAME` = `phindagijimana321`
   - `DOCKERHUB_TOKEN` = access token from https://hub.docker.com/settings/security
3. Trigger or re-run workflow **Docker publish** (`.github/workflows/docker_publish.yml`):
   - On push of tag `v0.2.0`, or
   - **Actions → Docker publish → Run workflow** with push enabled

CI pushes to:

- `ghcr.io/phindagijimana/dkt-connectome:0.2.0`
- `phindagijimana321/dkt-connectome:0.2.0` (if secrets set)

### Option B — Skopeo mirror from GHCR (HPC / manual)

After CI has built on GHCR:

```bash
podman login docker.io    # as phindagijimana321
cd dwi_pipeline
bash scripts/mirror_ghcr_to_dockerhub.sh --version 0.2.0
```

Requires `skopeo` and `~/.config/containers/auth.json` from `podman login`.

### Option C — Local build and push

```bash
cd /path/to/dkt_connectome
docker build -f dwi_pipeline/Dockerfile -t phindagijimana321/dkt-connectome:0.2.0 .
docker login
docker push phindagijimana321/dkt-connectome:0.2.0
docker tag phindagijimana321/dkt-connectome:0.2.0 phindagijimana321/dkt-connectome:latest
docker push phindagijimana321/dkt-connectome:latest
```

### Step 4 connectome image (separate)

The **Step 4** structural connectome image is **`phindagijimana321/dkt_connectome`** (underscore), built by `build-dk-connectome.yml`. HPC sites typically use Apptainer `.sif` files instead. See [containers/connectome README](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/connectome/README.md).

---

## 12. Verify Docker pull

**Goal:** Confirm the orchestrator image is public and runnable.

```bash
docker pull phindagijimana321/dkt-connectome:0.2.0
docker run --rm phindagijimana321/dkt-connectome:0.2.0 --version
# expect: 0.2.0

docker run --rm \
  -v "$PWD/dwi_pipeline/tests/fixtures/bids_minimal:/data/bids:ro" \
  -v /tmp/out:/out \
  -e BIDS_APP_CI=1 \
  -e FS_LICENSE=/tmp/license.txt \
  phindagijimana321/dkt-connectome:0.2.0 \
  /data/bids /out participant \
  --participant-label EXAMPLE --session-filter baseline \
  --dry-run --no-sdc --no-dwi-filter
```

If pull fails: check Docker Hub repo visibility (public vs private) and that Option A/B/C in §11 completed.

---

## 13. BIDS Apps registry *(optional)*

**Skip unless you want a listing on https://bids-apps.neuroimaging.io/apps/.**

The app is BIDS-App-compatible without being listed. If you submit later, follow [bids_apps_registry.md](bids_apps_registry.md) (email or PR to `bids-standard/bids-website`).

---

## 14. Read the Docs auto-rebuild

**Goal:** https://dkt-connectome.readthedocs.io/en/latest/ rebuilds when `main` changes.

### One-time project setup

1. Sign in at [readthedocs.org](https://readthedocs.org/) → import `phindagijimana/dkt_connectome`
2. Project slug: **`dkt-connectome`**
3. Config: [`.readthedocs.yaml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.readthedocs.yaml) → `dwi_pipeline/docs/conf.py` (Sphinx)

**Auto-rebuild on push** — pick **Option A** or **Option B** (not both required).

#### Option A — GitHub secret + Actions (already wired)

1. Create token: https://readthedocs.org/accounts/tokens/
2. GitHub repo → **Settings → Secrets → Actions** → `READTHEDOCS_TOKEN`
3. Push to `main` touching `dwi_pipeline/docs/**` or run workflow **Read the Docs** manually

Workflow file: `.github/workflows/readthedocs.yml`

If the secret is missing, CI prints a warning and skips the trigger (docs stay stale until manual rebuild).

#### Option B — RTD GitHub integration (no token in GitHub)

1. [Integrations](https://app.readthedocs.org/dashboard/dkt-connectome/integrations/) → connect GitHub → enable builds on push

### Manual rebuild (anytime)

1. [RTD Builds](https://app.readthedocs.org/projects/dkt-connectome/builds/) → **Build version** for `latest`
2. Or locally verify then trigger:

   ```bash
   pip install -r dwi_pipeline/docs/requirements.txt
   sphinx-build -W --keep-going -b html dwi_pipeline/docs dwi_pipeline/docs/_build/html
   bash dwi_pipeline/scripts/verify_rtd_live.sh
   ```

### Local preview

```bash
pip install -r dwi_pipeline/docs/requirements.txt
sphinx-build -b html dwi_pipeline/docs dwi_pipeline/docs/_build/html
# open dwi_pipeline/docs/_build/html/index.html
```

Strict build (matches CI): `sphinx-build -W --keep-going -b html dwi_pipeline/docs dwi_pipeline/docs/_build/html`

### Doc map (avoid duplicate reading)

| If you need… | Read… |
|--------------|--------|
| Science / theory | [Science overview](../science_overview.md) |
| Per-step methods + citations | [Methods](../methods/index.md) |
| Flags, paths, outputs | [Pipeline steps](../pipeline_steps.md) |
| `./run` reference | [Usage](../usage.md) · [BIDS App spec](../bids_app.md) |
| What's left to ship | [remaining.md](https://github.com/phindagijimana/dkt_connectome/blob/main/remaining.md) |

Publishing checklist: [Publishing](publishing.md).

---

## 15. Dockstore GitHub link

**Goal:** List workflows at https://dockstore.org from [`.dockstore.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.dockstore.yml).

Manifest declares:

| Entry | Path | Notes |
|-------|------|-------|
| `dkt_connectome` | `dwi_pipeline/workflow/Snakefile` | **Canonical** — publish: true |
| `dk_connectome` | root `Snakefile` | Legacy 4-stage — publish: true |
| `dk_connectome-cwl` | CWL | publish: false |

### Steps (one-time, UI)

1. Create account at https://dockstore.org/
2. **My Dockstore → Accounts** → link **GitHub**
3. **My Dockstore → My workflows → Register workflow**
4. Select repository **`phindagijimana/dkt_connectome`**
5. Dockstore reads `.dockstore.yml` at repo root and registers entries with `publish: true`
6. After **GitHub Release** (§10), tagged versions appear automatically on new tags

### Verify

- Search Dockstore for `dkt_connectome`
- Open workflow page → confirm descriptor path `dwi_pipeline/workflow/Snakefile`
- Optional: add ORCID in `.dockstore.yml` under `authors` (requires commit + push)

---

## 16. WorkflowHub RO-Crate upload

**Goal:** Index the workflow at https://workflowhub.eu/

Metadata reference: [`workflowhub.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/workflowhub.yml) (version 0.2.0, canonical Snakefile under `dwi_pipeline/workflow/`).

### Prepare RO-Crate

WorkflowHub expects a **Workflow RO-Crate** (zip). Options:

**A — From a successful pipeline run** (legacy root `./connectome start` path):

- After a run, check `<results_root>/ro-crate-metadata.json` and `ro-crate-preview.html`
- Zip the results directory including those files

**B — Minimal crate from repo** (for registration without a full run):

1. Copy repo metadata into a folder:

   ```bash
   WORK=/tmp/dkt_connectome_crate
   rm -rf "$WORK" && mkdir -p "$WORK"
   cp workflowhub.yml "$WORK/"
   cp CITATION.cff "$WORK/" 2>/dev/null || true
   cp -r dwi_pipeline/workflow "$WORK/dwi_pipeline_workflow"
   cp dwi_pipeline/workflow/Snakefile "$WORK/Snakefile"
   cp dwi_pipeline/README.md "$WORK/README.md"
   ```

2. Add or generate `ro-crate-metadata.json` per [RO-Crate 1.1](https://www.researchobject.org/ro-crate/1.1/) — include `workflowhub.yml` fields as `description`, `version`, `license`, `mainEntity` pointing at the Snakefile.

3. Zip:

   ```bash
   cd "$WORK" && zip -r ../dkt_connectome_0.2.0_crate.zip .
   ```

### Upload

1. Go to https://workflowhub.eu/workflows/new (or **Register workflow** when logged in)
2. Upload the zip or connect Git URL if the UI offers import
3. Fill metadata matching `workflowhub.yml`:
   - **Name:** `dkt_connectome`
   - **Version:** `0.2.0`
   - **Main workflow:** `dwi_pipeline/workflow/Snakefile`
   - **License:** Apache-2.0
4. Save and note the WorkflowHub URL for papers / README

### Verify

- Workflow appears in search
- Container pins in `workflowhub.yml` match current tags (orchestrator `phindagijimana321/dkt-connectome:0.2.0`, connectome `ghcr.io/phindagijimana/dk-connectome:0.2.0`)

---

## 17. Zenodo archive + DOI

**Goal:** Immutable software DOI for citations (P2.2). Required before v1.0 paper claims.

### One-time setup

1. Log in at [zenodo.org](https://zenodo.org) with GitHub.
2. **Account → GitHub** → enable access → toggle **`phindagijimana/dkt_connectome`** ON.
3. Zenodo creates a draft on each **GitHub Release** you publish.

### Per release (v0.2.0 now, v1.0 later)

```bash
# After tag + release exist (§10):
gh release create v1.0.0 --title "DKT Connectome 1.0.0" --notes-file dwi_pipeline/RELEASE_NOTES.md
# Wait for Zenodo webhook → open Zenodo record → Publish → copy DOI
```

### Wire DOI into the repo

1. **`CITATION.cff`** — set `version` and `doi: 10.5281/zenodo.xxxxx`
2. **`dwi_pipeline/app.json`** — `HowToAcknowledge` URL with DOI
3. **`dwi_pipeline/docs/citation.md`** — BibTeX `@software` entry
4. **GitHub Release** — edit notes: “Archived at https://doi.org/10.5281/zenodo.xxxxx”
5. **Manuscript** — replace `[Zenodo DOI]` in `sample_software_paper/manuscript.md`

### Verify

- https://doi.org/10.5281/zenodo.xxxxx resolves
- Zenodo zip matches the git tag commit
- `CITATION.cff` validates: `cffconvert -i CITATION.cff` (optional)

---

## Deferred — not maintainer one-shots

These require compute time, data access, or people — not a single afternoon of admin work.

| Blocked on | Items | Where tracked |
|------------|-------|---------------|
| FS license + GPU/HPC hours | Real `./run` on HPC (each user’s license), URMC n=61 (P4.3) | [Integration CI](integration_ci.md), [Readiness checklist](readiness_checklist.md) P1, P4 |
| Public HCP data + compute | HCP-YA n=10 baseline (P4.4) | [paper plan](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/sample_software_paper/paper_plan.md) §11 |
| Radiologist | Review rubric (P4.5) | paper plan |
| Paper writing | Figures, preprint, Table 1 (P4.6–P4.8) | paper plan |
| Confirm no legacy HPC jobs | Remove bash engine / dual-container (P3.1–P3.2) | [LEGACY.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/workflow/LEGACY.md) |
| Infra decision | Monolithic Docker (P5.1) | Readiness checklist P5 |

Scientific validation status: [Validation](../validation.md).

---

## Suggested order (release afternoon)

```text
1. Push main + confirm CI green
2. §10 GitHub Release
3. §11 Docker Hub (CI secrets or mirror script)
4. §12 docker pull verify
5. §14 RTD token or integration + manual rebuild
6. §15 Dockstore link (after release tag exists)
7. §16 WorkflowHub upload (optional same day)
8. §13 BIDS registry — only if you want public listing
```

---

*Update version strings when cutting v0.3.0+.*
