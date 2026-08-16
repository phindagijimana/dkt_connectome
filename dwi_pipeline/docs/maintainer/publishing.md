# Publishing documentation

Checklist for releases, containers, and [dkt-connectome.readthedocs.io](https://dkt-connectome.readthedocs.io/en/latest/).

---

## Release checklist (v0.2.0+)

1. Update [`app.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/app.json) `PipelineVersion` and [changelog.md](../changelog.md).
2. Regenerate config catalog: `python3 dwi_pipeline/scripts/generate_config_catalog.py`
3. Regenerate QC doc figures: `python3 dwi_pipeline/scripts/render_qc_doc_figures.py`
4. `cd dwi_pipeline && mkdocs build --strict`
5. Tag and GitHub Release:

   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   gh release create v0.2.0 --title "DKT Connectome 0.2.0" --notes-file dwi_pipeline/RELEASE_NOTES.md
   ```

6. *(Optional)* [BIDS Apps registry](../BIDS_App.md) — skip unless you want bids-apps.neuroimaging.io listing.

Track remaining work: [Readiness checklist](readiness_checklist.md) · [Maintainer one-shot tasks](maintainer_tasks.md).

---

## Docker orchestrator publish

CI **always** pushes to **GHCR:** `ghcr.io/phindagijimana/dkt-connectome:<version>`

**Docker Hub** (`phindagijimana321/dkt-connectome`):

| Method | When |
|--------|------|
| GitHub secrets `DOCKERHUB_USERNAME` + `DOCKERHUB_TOKEN` | CI pushes on `workflow_dispatch` with push=true or version tags |
| **Skopeo mirror (OOD/HPC)** | After CI build — uses existing `podman login` |

```bash
# After "Docker publish" workflow succeeds on GitHub:
cd dwi_pipeline
bash scripts/mirror_ghcr_to_dockerhub.sh --version 0.2.0
```

Verify:

```bash
docker pull phindagijimana321/dkt-connectome:0.2.0
./run doctor   # inside container or locally after install.sh
```

**Step 4 connectome image (separate):** `phindagijimana321/dkt_connectome` — see [containers/connectome/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/connectome/README.md).

---

## Read the Docs

1. Import `phindagijimana/dkt_connectome` at [readthedocs.org](https://readthedocs.org/).
2. Project slug: **`dkt-connectome`**
3. Config: [`.readthedocs.yaml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.readthedocs.yaml) → `dwi_pipeline/mkdocs.yml`
4. Theme: **Material for MkDocs** (`dwi_pipeline/docs/requirements.txt`)

After docs push:

```bash
cd dwi_pipeline && mkdocs build --strict
bash scripts/verify_rtd_live.sh
```

---

## CI jobs

| Workflow | Role |
|----------|------|
| `dwi_pipeline_ci.yml` | pytest, MkDocs strict, doctor, Snakemake dry-run |
| `integration_qsiprep.yml` | QSIPrep pull + version smoke; optional full run if maintainer adds secret |
| `integration_ideas.yml` | IDEAS OpenNeuro golden (monthly / manual) |
| `docker_auto_install_smoke.yml` | `DKT_AUTO_INSTALL=1` in orchestrator image |
| `docker_publish.yml` | Build orchestrator → GHCR (+ Docker Hub if secrets set) |
| `install_smoke.yml` | Apptainer pull smoke test |
| `build-dk-connectome.yml` | Step-4 connectome image → GHCR/Docker Hub |
| `readthedocs.yml` | Trigger RTD rebuild |

See also: [Read the Docs setup](../readthedocs_setup.md).
