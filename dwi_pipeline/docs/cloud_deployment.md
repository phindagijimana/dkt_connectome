# Cloud and group deployment

Patterns for running DKT Connectome outside URMC HPC: Docker orchestrator, cached step containers, and cohort post-processing.

---

## Docker orchestrator (recommended for cloud)

Pull the published image:

```bash
docker pull phindagijimana321/dkt-connectome:0.2.1
```

Minimal run (bind-mount BIDS, output, FreeSurfer license):

```bash
docker run --rm \
  -v /path/to/BIDS:/data/bids:ro \
  -v /path/to/out:/out \
  -v /path/to/license.txt:/opt/freesurfer/license.txt:ro \
  -e FS_LICENSE=/opt/freesurfer/license.txt \
  -e DKT_AUTO_INSTALL=1 \
  phindagijimana321/dkt-connectome:0.2.1 \
  /data/bids /out participant \
  --participant-label 001 --session-filter ses-1 --syn
```

`DKT_AUTO_INSTALL=1` pulls pinned Apptainer `.sif` step images into `DKT_CONTAINER_CACHE` on first container start. The orchestrator **Docker image includes Apptainer** for cloud use; on HPC, use `bash scripts/install.sh` directly instead.

**Requirements:** network egress to container registries; FreeSurfer license at `FS_LICENSE`; sufficient disk (~20 GB for full stack, ~4 GB for QSIPrep-only).

**Verify auto-install in CI:** workflow `docker_auto_install_smoke.yml` (weekly + on Dockerfile changes).

For air-gapped sites, pre-populate `CONTAINER_*` paths instead — see [Containers](containers.md).

**Compose:** [`docker-compose.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docker-compose.yml) wraps the same image with volume mounts for local smoke tests.

---

## AWS / GCP / Azure (batch)

Typical layout:

| Component | Suggestion |
|-----------|------------|
| Orchestrator | One task per subject using `phindagijimana321/dkt-connectome` |
| Storage | BIDS input + `RESULTS_ROOT` on shared FS (EFS, Filestore, Azure Files) |
| License | Secret → mount as `FS_LICENSE` |
| CPUs | Match `--n-cpus` to vCPU count (8+ recommended for recon) |
| Step containers | `DKT_AUTO_INSTALL=1` or bake SIFs into AMI / custom image |

Example AWS Batch job definition env:

```text
FS_LICENSE=/secrets/license.txt
DKT_AUTO_INSTALL=1
TEMPLATEFLOW_HOME=/cache/templateflow
```

After all subject jobs finish, run **one** group job:

```bash
./run /data/bids /out group
```

This builds `cohort_qc.html` and optional BIDS Derivatives export — no reprocessing.

---

## Slurm array (HPC)

Production path at URMC and similar sites:

```bash
export BIDS_DIR=/path/to/BIDS
export RESULTS_ROOT=/path/to/results
export SUBJECT_LIST_FILE=dwi_pipeline/subjects.txt
bash dwi_pipeline/submit.sh
```

Post-array cohort step:

```bash
bash dwi_pipeline/scripts/batch_postprocess.sh
```

See [Usage § Slurm array](usage.md#slurm-array-hpc).

---

## Group-level analysis only

When imaging is already processed under `RESULTS_ROOT`:

```bash
./run /path/to/BIDS /path/to/out group
```

Rebuilds cohort QC indexes and subject report links. Does **not** re-run QSIPrep, recon, or connectome steps.

---

## See also

- [Installation](installation.md) · [Containers](containers.md)
- [BIDS App specification](bids_app.md) · [Usage](usage.md)
- [Release checklist on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/publishing.md)
