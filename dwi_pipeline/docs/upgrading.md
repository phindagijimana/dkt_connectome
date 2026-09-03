# Upgrading

How to move from an older DKT Connectome install to the current release.

**Current release:** check `./dkt version` or `./run --version` or [GitHub Releases](https://github.com/phindagijimana/dkt_connectome/releases).

---

## Quick upgrade (most users)

```bash
cd /path/to/dkt_connectome
git fetch origin
git checkout main
git pull origin main

cd dwi_pipeline
./dkt install --missing-only
export FS_LICENSE=/path/to/license.txt
./dkt check
```

**Docker / cloud:**

```bash
docker pull phindagijimana321/dkt-connectome:0.3.0
# or GHCR: ghcr.io/phindagijimana/dkt-connectome:0.3.0
```

Step images (QSIPrep, FreeSurfer, QSIRecon, connectome, …) are **not** inside the orchestrator image — `install.sh` refreshes Apptainer `.sif` paths in `workflow/config/config.local.yaml`. After install, run **`./dkt check --strict`** to verify SHA-256 digests against [`release_manifest.json`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/release_manifest.json).

---

## Migrating from legacy entrypoints

| Old | New |
|-----|-----|
| Repo root `./connectome bids` | `dwi_pipeline/run` |
| `PIPELINE_ENGINE=bash` | Snakemake (default in `submit.sh`) |
| MkDocs site (old) | [Read the Docs](https://dkt-connectome.readthedocs.io/en/latest/) |

Legacy paths remain for Dockstore compatibility only — see [Comparisons § Legacy](comparisons.md).

---

## v0.3.0 — what changed

| Area | Change | Rerun needed? |
|------|--------|---------------|
| **Reproducibility** | [`release_manifest.json`](../release_manifest.json) pins step image URIs + SHA-256 | No (verify with `./dkt check --strict`) |
| **Step scripts** | Baked into DKT-owned `.sif` images by default (`run_connectome.sh`, `run_disconnectome.py`, VBT, lesion ACT, …) | No unless you relied on dev bind-mounts |
| **Dev overrides** | `CONNECTOME_BIND_DEV`, `VBT_BIND_DEV`, `DISCONNECTOME_BIND_DEV`, `ACT_BIND_MOUNT_DEV` default **off** | No |
| **GHCR step SIFs** | `dk-connectome`, `dkt-vbt`, `dkt-lesion-act`, `dkt-deep-atropos*` at tag **0.3.0** | Pull/reinstall only |
| **Connectome SIF** | ACPC-aware disconnectome + updated connectome digest | Optional Step 4.1 rerun if disconnectome mattered |

**Upgrade commands:**

```bash
cd dwi_pipeline
./dkt install --missing-only
./dkt check --strict
docker pull phindagijimana321/dkt-connectome:0.3.0
```

Pull step SIFs from GHCR (after `./dkt install` or manually):

```text
ghcr.io/phindagijimana/dk-connectome:0.3.0
ghcr.io/phindagijimana/dkt-vbt:0.3.0
ghcr.io/phindagijimana/dkt-lesion-act:0.3.0
ghcr.io/phindagijimana/dkt-deep-atropos:0.3.0
ghcr.io/phindagijimana/dkt-deep-atropos-seg:0.3.0
```

See [Architecture § Hybrid scripts](architecture.md) and [Containers](containers.md).

---

## v0.2.2 — what changed

| Area | Change | Rerun needed? |
|------|--------|---------------|
| **CLI** | Unified `./dkt` (`install`, `pull`, `run`, `log`, `check`) | No |
| **Docs** | [Architecture guide](architecture.md) — container vs host layout | No |
| **Docker** | Orchestrator republished with `./dkt`; `docker run … dkt check` supported | No (pull new image only) |
| **Verify outputs** | `./dkt check --outputs --subject ID --results-root OUT` | No |

---

## v0.2.1 — what changed

| Area | Change | Rerun needed? |
|------|--------|---------------|
| **Step 4 registration** | Rigid FS T1 → QSIPrep ACPC (`fs_to_preproc_T1w_0GenericAffine.mat`) | **Step 4+ only** if you want updated connectomes |
| **Lesion / factorial** | Dedicated VBT + lesion-act containers; `--experiment-arm` presets | Only if using those features |
| **Tractography** | Default `--tractography-model both` (IFOD2 + SD_STREAM) | Optional |
| **Docs** | TBI experimental arms guide, publication strategy updates | No |

Step 4.1 disconnectome accepts **either** legacy `native_to_preproc_T1w_0GenericAffine.mat` or the new rigid matrix.

**Connectome-only backfill** (reuse tractography `.tck`):

```bash
bash workflow/run_subject.sh connectome SUBJECT [same flags as original]
bash workflow/run_subject.sh nodestrength SUBJECT
bash workflow/run_subject.sh subject_qc SUBJECT
```

Cohort helpers: `scripts/lib/rigid_reg_rerun_helpers.sh`.

---

## v0.2.0 baseline

First public BIDS App release with Snakemake engine, `./run` participant/group levels, RTD docs, and Docker orchestrator. See [RELEASE_NOTES.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/RELEASE_NOTES.md).

---

## Verify after upgrade

```bash
./dkt version
./dkt check --with-dry-run
./dkt run "$BIDS_DIR" "$RESULTS_ROOT" participant \
  --participant-label ID --dry-run
```

Full changelog: [changelog.md](changelog.md).
