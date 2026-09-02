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
docker pull phindagijimana321/dkt-connectome:0.2.2
# or pin: phindagijimana321/dkt-connectome:0.2.2
```

Step images (QSIPrep, FreeSurfer, QSIRecon, connectome, …) are **not** inside the orchestrator image — `install.sh` refreshes Apptainer `.sif` paths in `workflow/config/config.local.yaml`.

---

## Migrating from legacy entrypoints

| Old | New |
|-----|-----|
| Repo root `./connectome bids` | `dwi_pipeline/run` |
| `PIPELINE_ENGINE=bash` | Snakemake (default in `submit.sh`) |
| MkDocs site (old) | [Read the Docs](https://dkt-connectome.readthedocs.io/en/latest/) |

Legacy paths remain for Dockstore compatibility only — see [Comparisons § Legacy](comparisons.md).

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
