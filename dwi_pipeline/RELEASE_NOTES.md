# DKT Connectome 0.2.1

Lesion-aware structural connectomics BIDS App — rigid Step 4 registration, factorial
experiment arms, dedicated ACT/VBT containers, and external-user upgrade guide.

**Documentation:** https://dkt-connectome.readthedocs.io/en/latest/  
**Docker (orchestrator):** `phindagijimana321/dkt-connectome:0.2.1`  
**GHCR:** `ghcr.io/phindagijimana/dkt-connectome:0.2.1`  
**Entrypoint:** `dwi_pipeline/run`

---

## Highlights

- **Rigid FS T1 → ACPC registration** for Step 4 connectome parcellation (`fs_to_preproc_T1w_0GenericAffine.mat`)
- **Factorial experiment arms** (`--experiment-arm orig-std`, `vbt-lesion`, …) with isolated `arms/<arm>/` trees
- **Dedicated Step 3.1 / 1.1 containers** — `dkt_lesion_act.sif`, `dkt_vbt.sif`, optional Deep Atropos branch
- **SD_STREAM + iFOD2** connectomes (`--tractography-model both`, default)
- **TBI experimental arms doc** + **upgrading guide** for external users
- **Docker / GHCR orchestrator** rebuilt from current `main`

---

## Upgrade from 0.2.0

```bash
git pull origin main
cd dwi_pipeline && bash install.sh --missing-only && ./run doctor
docker pull phindagijimana321/dkt-connectome:0.2.1
```

See [Upgrading](https://dkt-connectome.readthedocs.io/en/latest/upgrading.html). **Step 4+ rerun** recommended if you need the new rigid registration; Steps 1–3 tractography can be reused.

---

## Full changelog

See [`docs/changelog.md`](docs/changelog.md).

---

## Previous release

[0.2.0 release notes](https://github.com/phindagijimana/dkt_connectome/releases/tag/v0.2.0)
