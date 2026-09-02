# DKT Connectome 0.2.2

Lesion-aware structural connectomics BIDS App — unified `./dkt` CLI, architecture
documentation, and republished orchestrator image.

**Documentation:** https://dkt-connectome.readthedocs.io/en/latest/  
**Docker (orchestrator):** `phindagijimana321/dkt-connectome:0.2.2`  
**GHCR:** `ghcr.io/phindagijimana/dkt-connectome:0.2.2`  
**Entrypoints:** `dwi_pipeline/run` (BIDS App) · `dwi_pipeline/dkt` (install / pull / run / log / check)

---

## Highlights

- **Unified CLI `./dkt`** — `install`, `pull`, `run`, `log`, `check`, `version`
- **Architecture guide** — [which steps run in containers vs host](docs/architecture.md)
- **Subject output checker** — `./dkt check --outputs --subject ID --results-root OUT`
- **Docker orchestrator republished** with `./dkt` included; entrypoint supports `dkt install|check|…`
- **CI** validates `./dkt` and version string

Includes all [0.2.1](#previous-releases) features: rigid Step 4 registration, factorial experiment arms, dedicated ACT/VBT containers, upgrading guide.

---

## Upgrade from 0.2.1

```bash
git pull origin main
cd dwi_pipeline
chmod +x dkt
./dkt install --missing-only
./dkt check
docker pull phindagijimana321/dkt-connectome:0.2.2
```

No mandatory rerun unless you want updated bind-mounted scripts without rebuilding `.sif` files — pin git tag + container digests for frozen studies.

See [Upgrading](https://dkt-connectome.readthedocs.io/en/latest/upgrading.html).

---

## Full changelog

See [`docs/changelog.md`](docs/changelog.md).

---

## Previous releases

- [0.2.1 release notes](https://github.com/phindagijimana/dkt_connectome/releases/tag/v0.2.1)
- [0.2.0 release notes](https://github.com/phindagijimana/dkt_connectome/releases/tag/v0.2.0)
