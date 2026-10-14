# DKT Connectome 0.3.1

Orchestrator rebuild so the published BIDS App image matches host `./run`.
**Do not retag 0.3.0.** Step SIFs stay at **0.3.0**.

**Documentation:** https://dkt-connectome.readthedocs.io/en/latest/  
**Docker (orchestrator):** `phindagijimana321/dkt-connectome:0.3.1`  
**GHCR:** `ghcr.io/phindagijimana/dkt-connectome:0.3.1`  
**Step SIFs (GHCR):** still tag **`0.3.0`** (`dk-connectome`, `dkt-vbt`, `dkt-lesion-act`, `dkt-deep-atropos`, `dkt-deep-atropos-seg`)  
**Entrypoints:** `./run` at repo root (BIDS App; same as `dwi_pipeline/run`) · `./dkt`

---

## Highlights

- **`./run` flag parity** — lesion/ACT/`--force-syn`/`--fastsurfer-device` (same as `run_subject.sh`)
- **Honest `--cache`** — `./dkt list|check --cache DIR` is not masked by site `config.local.yaml`
- **`DKT_AUTO_INSTALL=1`** works when the image config path is read-only
- **`--stop-on-first-crash`** QC covers only subjects that ran
- **Provenance** — derivative `dataset_description.json` reads version and pins from `app.json`

---

## Upgrade from 0.3.0

```bash
git pull origin main
cd dwi_pipeline
./dkt check
docker pull phindagijimana321/dkt-connectome:0.3.1
```

No step-image reinstall unless `./dkt check --strict` reports a missing pin.

See [Upgrading](https://dkt-connectome.readthedocs.io/en/latest/upgrading.html).

---

## Full changelog

See [`docs/changelog.md`](docs/changelog.md).

---

## Previous releases

- [0.3.0 release notes](https://github.com/phindagijimana/dkt_connectome/releases/tag/v0.3.0)
- [0.2.2 release notes](https://github.com/phindagijimana/dkt_connectome/releases/tag/v0.2.2)
