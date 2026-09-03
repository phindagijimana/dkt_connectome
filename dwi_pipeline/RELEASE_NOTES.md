# DKT Connectome 0.3.0

Tier 1 reproducibility release — baked step scripts, `release_manifest.json`, and
GHCR-published step `.sif` images.

**Documentation:** https://dkt-connectome.readthedocs.io/en/latest/  
**Docker (orchestrator):** `phindagijimana321/dkt-connectome:0.3.0`  
**GHCR:** `ghcr.io/phindagijimana/dkt-connectome:0.3.0`  
**Step SIFs (GHCR):** `dk-connectome`, `dkt-vbt`, `dkt-lesion-act`, `dkt-deep-atropos`, `dkt-deep-atropos-seg` — all tag **`0.3.0`**  
**Entrypoints:** `dwi_pipeline/run` (BIDS App) · `dwi_pipeline/dkt` (install / pull / run / log / check)

---

## Highlights

- **`release_manifest.json`** — single file mapping pipeline version → container URIs and SHA-256 digests
- **`./dkt check --strict`** — verify cached `.sif` digests after install
- **Baked step scripts** — production runs use scripts inside step images (dev bind-mounts opt-in)
- **Connectome SIF rebake** — ACPC-aware `run_disconnectome.py` + DKT LUT in `dkt_connectome.sif`
- **GHCR step SIF release** — GitHub Release `v0.3.0-step-sifs` + workflow `push_release_sifs_to_ghcr.yml`

Includes all [0.2.2](#previous-releases) features: unified `./dkt` CLI, architecture guide, rigid Step 4 registration, factorial experiment arms.

---

## Upgrade from 0.2.2

```bash
git pull origin main
cd dwi_pipeline
chmod +x dkt
./dkt install --missing-only
./dkt check --strict
docker pull phindagijimana321/dkt-connectome:0.3.0
```

No mandatory cohort rerun unless you want updated baked connectome/disconnectome scripts without rebuilding local SIFs — pin git tag + `release_manifest.json` digests for frozen studies.

See [Upgrading](https://dkt-connectome.readthedocs.io/en/latest/upgrading.html).

---

## Full changelog

See [`docs/changelog.md`](docs/changelog.md).

---

## Previous releases

- [0.2.2 release notes](https://github.com/phindagijimana/dkt_connectome/releases/tag/v0.2.2)
- [0.2.1 release notes](https://github.com/phindagijimana/dkt_connectome/releases/tag/v0.2.1)
- [0.2.0 release notes](https://github.com/phindagijimana/dkt_connectome/releases/tag/v0.2.0)
