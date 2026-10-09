# AWS Batch profile

`dk_connectome` on Spot instances + S3 storage. Designed for one-shot
cohort-scale runs (think: 200-subject UK Biobank slice) where you don't
want a dedicated cluster idling between submissions.

## 1. Account setup (one-time)

```bash
aws configure                       # region, access keys
aws iam create-role ...             # see Batch quickstart
aws batch create-compute-environment ...
aws batch create-job-queue --name dk-connectome-queue ...
aws s3 mb s3://dk-connectome-workdir
```

Reference the full procedure in the
[AWS Batch + Snakemake quickstart](https://snakemake.readthedocs.io/en/stable/executor_tutorial/aws-batch.html).

## 2. Pull container images from GHCR

Images are published to GHCR (see [docs/maintainer/publishing.md](../../dwi_pipeline/docs/maintainer/publishing.md));
pull from there. AWS Batch can use them directly if the compute environment
has internet egress.

## 3. Override config to use S3 URIs

```yaml
# config/config.yaml or pass via --config
bids_dir:      s3://my-bids-bucket/cohort-A/
results_root:  s3://dk-connectome-workdir/cohort-A-out/
templateflow_home: s3://dk-connectome-workdir/templateflow/
```

The plugin streams S3 paths to/from each Batch job's ephemeral storage
(set `disk_mb` per rule accordingly — see this profile's defaults).

## 4. Run

```bash
snakemake --profile profiles/aws-batch --configfile config/config.yaml
```

Or via the CLI shim:

```bash
./connectome start --mode local -- --profile profiles/aws-batch
```

## 5. Cost guardrails

* Use Spot pricing in the compute environment; `restart-times: 2` in the
  profile recovers from Spot interruptions automatically.
* Bound spend per run via the Batch compute environment's
  `desiredvCpus`/`maxvCpus`. A 50-subject cohort runs comfortably at
  100-200 vCPUs.
* Push the working bucket lifecycle to delete intermediates after the run
  completes (`./connectome stop` does not delete S3 objects — Snakemake's
  `--cleanup-shadow` doesn't extend to remote storage).
