# Google Batch profile

`dk_connectome` on Google Cloud Batch + Cloud Storage. Equivalent to the
AWS Batch profile but using GCP-native services.

## 1. Project setup (one-time)

```bash
gcloud auth login
gcloud config set project MY-PROJECT

gcloud services enable batch.googleapis.com storage.googleapis.com \
                      artifactregistry.googleapis.com

gsutil mb -p MY-PROJECT -l us-central1 gs://dk-connectome-workdir
gcloud artifacts repositories create dk-connectome \
       --repository-format=docker --location=us-central1
```

Reference: the
[Snakemake Google Batch tutorial](https://snakemake.readthedocs.io/en/stable/executor_tutorial/googlebatch.html).

## 2. Pull container images from GHCR

Images are published to GHCR (see [docs/maintainer/publishing.md](../../dwi_pipeline/docs/maintainer/publishing.md));
pull from there. Public images work out of the box when the project has egress.

## 3. Override config to use GCS URIs

```yaml
bids_dir:          gs://my-bids-bucket/cohort-A/
results_root:      gs://dk-connectome-workdir/cohort-A-out/
templateflow_home: gs://dk-connectome-workdir/templateflow/
```

The Google Batch executor downloads inputs to the VM's boot disk before each
rule executes (size with `disk_mb`).

## 4. Run

```bash
snakemake --profile profiles/google-batch --configfile config/config.yaml
```

Or via the CLI shim:

```bash
./connectome start --mode local -- --profile profiles/google-batch
```

## 5. Cost guardrails

* Set `--googlebatch-spot true` (via the plugin's CLI) for ~75% discount;
  `restart-times: 2` recovers from preemption.
* Bound spend per run via the Batch parent job's `taskCount` limit.
* GCS lifecycle rules can auto-delete intermediate files after the run —
  Snakemake won't clean the bucket on success.
