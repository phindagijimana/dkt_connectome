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

## 2. Mirror container images to Artifact Registry (optional)

Public images work out of the box; for VPC-only / egress-restricted projects,
mirror to Artifact Registry first:

```bash
for img in pennlinc/qsiprep:1.0.0 \
           pennlinc/qsirecon:1.2.1 \
           freesurfer/freesurfer:7.4.1 \
           ghcr.io/phindagijimana/dk-connectome:0.1.0
do
  ./scripts/mirror_to_gar.sh "$img"   # docker pull -> tag -> push to your AR repo
done
```

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
