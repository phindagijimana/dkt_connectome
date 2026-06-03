# Data Engineering — A Practical Course

*Anchored in the `dwi_pipeline` (QSIPrep → Recon → QSIRecon → DK connectome)*

---

## How to use this document

Read it top-to-bottom once to build a mental map. Then keep it next to your repo as a reference. Every concept is grounded in something your pipeline already does (or should do). The exercises at the end are designed so you finish the course with a portfolio-grade pipeline rather than just notes.

Estimated reading time: ~60 minutes. Estimated time to do every exercise: ~3 weekends.

---

## Table of contents

1. Foundations
2. The DAG mental model
3. The five pillars of any pipeline
4. The DWI pipeline as a DE case study
5. Concepts in depth
6. The industry tooling landscape
7. Reliability and operations
8. Performance and scale
9. Testing pipelines
10. CI/CD for data pipelines
11. From scientific HPC to industry DE — bridging the gap
12. A portfolio progression roadmap
13. Exercises
14. Glossary
15. Further reading

---

## 1. Foundations

### 1.1 What data engineering actually is

A data engineer builds and operates the systems that **move, transform, store and serve data** so that downstream consumers — analysts, scientists, ML systems, products — can rely on it. The output of a data engineer is not insight; it is **infrastructure for insight**.

Three roles, frequently confused:

| Role | Primary output | Typical question they answer |
|---|---|---|
| Data Engineer | Pipelines and storage | "Why is yesterday's `sales` table empty?" |
| Data Analyst / Scientist | Insights, models | "Which channel drove the lift?" |
| ML Engineer | Production models | "Why is the recommender returning 500s?" |

You're currently doing data engineering for neuroimaging. The "data" is DWI volumes, FreeSurfer surfaces and connectome matrices, and the "consumers" are eventually statistical analyses and downstream ML.

### 1.2 What "production-grade" means

A pipeline is production-grade when it satisfies, roughly, these properties:

- **Correct**: outputs match the contract you advertised.
- **Idempotent**: running it twice with the same inputs gives the same outputs and no side effects.
- **Observable**: when something goes wrong you can find out *what*, *where*, *when*, and ideally *why* without re-running the pipeline.
- **Recoverable**: a failed run can be resumed from the point of failure without redoing finished work.
- **Documented**: a new teammate can run it without paging you.
- **Tested**: changes are validated automatically before they hit the cluster/cloud.

Your bash pipeline already satisfies some of these (idempotent recon-all skip, structured logs), and the rest of this document is mostly about closing the remaining gaps.

---

## 2. The DAG mental model

A **DAG** — Directed Acyclic Graph — is the fundamental abstraction of every modern workflow tool. Internalising it is the single highest-leverage move you can make.

### 2.1 Definitions

- **Graph**: a set of *nodes* connected by *edges*.
- **Directed**: each edge has an arrow (A → B is not the same as B → A).
- **Acyclic**: no path that starts at a node returns to it. Cycles would mean a task depends on itself, directly or transitively.

### 2.2 Your DWI pipeline as a DAG

```
                                  ┌─► QSIRecon (HSVS) ──┐
BIDS sub-001 ──► QSIPrep ─────────┤                     ├──► DK connectome ──► dk_connectome.csv
                                  ├─► Recon (recon-all)─┘
```

Each box is a *task*; each arrow declares "this task needs the previous task's output". The graph tells a scheduler four things for free:

1. **Order**: DK cannot start until both Recon and QSIRecon finish.
2. **Parallelism**: QSIPrep and Recon are independent of each other and can run concurrently. Likewise, sub-001 and sub-007 are entirely independent — they're separate DAG instances.
3. **What's safe to skip**: if `dk_connectome.csv` exists and is newer than its inputs, do nothing.
4. **Blast radius**: deleting `aparc+aseg.mgz` invalidates only Recon, DK; QSIPrep is unaffected.

### 2.3 Why DAGs win

Before DAG-thinking, people wrote sequential bash scripts ("step 1 then step 2 then step 3"). Sequential scripts conflate **what** depends on what with **when** to run it. DAGs separate these concerns: you declare dependencies; the engine decides scheduling. The engine can then:

- Re-run only failed branches
- Parallelise independent branches
- Visualise the workflow
- Optimise placement (run heavy nodes on big machines, light nodes on cheap ones)

Every workflow framework you'll encounter — Snakemake, Nextflow, Airflow, Dagster, Prefect, Argo, Kubeflow, Luigi, Make, Bazel — is a DAG engine under the hood. Master the abstraction once and the tools become syntactic variations.

---

## 3. The five pillars of any pipeline

These are the structural properties that distinguish "a working script" from "a piece of infrastructure".

### 3.1 Orchestration

Something has to decide *what runs, where, in what order, with what resources, after what*. That something is the orchestrator. Options range from the trivial (a cron + a bash script) to the heavyweight (Airflow on Kubernetes with a Postgres metadata DB).

In your pipeline today, `submit.sh` + `array.sh` are the orchestrator: they translate "process these subjects" into Slurm array tasks.

### 3.2 Idempotency

**Idempotent** = running the operation twice has the same effect as running it once. In data pipelines, this means: if a step has already produced its output, re-running the pipeline does *not* recompute it, and produces no side effects.

Your `run_recon()` function:

```bash
if [[ -f "${aparc}" ]]; then
  echo "Recon: ${aparc} already exists — skipping"
  return 0
fi
```

…is a hand-written idempotency guard. Industry tools handle this declaratively — Snakemake says "this rule produces `aparc+aseg.mgz`; if it exists and is newer than its inputs, skip", and you never write the `if`.

Idempotency is what makes pipelines safe to re-run. Without it, every retry risks duplicating data or corrupting state.

### 3.3 Isolation (containerisation)

Each task should run in an environment that is reproducible and independent of the others. **Containers** provide this: a frozen filesystem + binaries + libraries that runs identically everywhere. You're already doing this with **Apptainer** SIF files; industry equivalents are **Docker** and **Podman**, almost always orchestrated by **Kubernetes**.

Isolation buys you:

- *Reproducibility* — `qsiprep:0.23.1` produces the same output today and in five years.
- *Dependency hell avoidance* — QSIPrep needs Python 3.10, your other tools need 3.11; both live happily side by side in different containers.
- *Portability* — the same image runs on Slurm, on EC2, on your laptop.

### 3.4 Observability

You cannot fix what you cannot see. A pipeline is observable when, for any failure or oddity, you can quickly answer:

- **What** happened? (the error message, the stack trace)
- **Where**? (which task, which subject, which input)
- **When**? (timestamp, what else was running)
- **Why**? (the contributing cause)

The three observability primitives are:

1. **Logs** — what each task printed; usually a file or a stream in a log aggregator.
2. **Metrics** — numbers over time (CPU, memory, queue depth, success rate, latency).
3. **Traces** — the path of a single request/task across distributed components.

Your pipeline currently produces logs (`logs/dwi_act_*.out`). It does not produce metrics or traces, and that's the main gap.

### 3.5 Configuration

A pipeline that hard-codes paths and parameters is not a pipeline; it's a script. Real pipelines accept configuration through:

- **Environment variables** (what you do today: `RESULTS_ROOT`, `RECON_TOOL`, …)
- **Config files** (YAML/TOML/JSON loaded at startup)
- **Schemas with validation** (Pydantic, JSON Schema, Avro, Protobuf) — reject bad config *before* the cluster spends 10 hours computing on it.

Configuration discipline is what lets the same code base run dev, staging, and production with different inputs.

---

## 4. The DWI pipeline as a DE case study

Let's map your existing pipeline onto data-engineering concepts so the bridge to "industry DE" is concrete.

| DWI stage | What it does (domain) | What it does (DE pattern) |
|---|---|---|
| **QSIPrep** | Denoise / SDC / motion-correct DWI, register to T1w | A *transformation* with multiple inputs (DWI 4-D, optional fmap, T1w) producing a clean, standardised dataset. The "Bronze → Silver" stage in lakehouse parlance. |
| **Recon** (FreeSurfer / FastSurfer) | T1w → cortical surfaces + parcellation | A *derived dataset* with a different fan-out (one input → one fat output tree). Idempotent by `aparc+aseg.mgz` presence. |
| **QSIRecon** | Reconstruct ODFs + tractography in DWI space | A *join* of two upstream datasets (preprocessed DWI + FS surfaces) into a third (tractogram). |
| **DK connectome** | aparc+aseg → DWI grid → graph matrix | An *aggregation* — collapses millions of streamlines into an N×N matrix. The "Silver → Gold" stage. |

Note the recurring shapes — transformation, join, aggregation — these are the same primitives a tabular pipeline uses; only the data type changes.

### 4.1 The "medallion" architecture

A widely-used industry mental model:

- **Bronze**: raw data as received (your BIDS dataset).
- **Silver**: cleaned, validated, conformed (preprocessed DWI, FS subjects dir).
- **Gold**: business-ready / analysis-ready artifacts (connectome CSV).

Your DAG already follows this. Most tabular pipelines do too, even if they don't use the colour names.

---

## 5. Concepts in depth

### 5.1 ETL vs ELT

- **ETL** = Extract, Transform, **then** Load into the destination.
- **ELT** = Extract, **Load** raw into the destination (typically a warehouse), then Transform there using SQL.

Modern warehouses (Snowflake, BigQuery, Redshift, Databricks) made ELT dominant because SQL on huge tables is now cheap and fast. dbt is the industry-standard tool for the "T" in ELT.

In neuroimaging, "transform" usually happens in Python/MRtrix and the final artifacts get loaded into a warehouse for analytics — so you'd typically use a hybrid: ET first (the heavy lifting on the cluster), then L the *summary metrics* into a warehouse, then ELT-style modelling on top of those.

### 5.2 Idempotency — deeper

Idempotency depends on:

1. **Deterministic output paths** — the same inputs always produce the same output path.
2. **Atomic writes** — either the output appears completely or not at all. Half-written files break idempotency. Pattern: write to `output.tmp`, then `mv output.tmp output`.
3. **Content-based skipping** — Snakemake/Make use file mtimes; more robust tools use content hashes (Bazel, Nix). Hash-based skipping survives `touch` and clock skew.

A pipeline that is *non-idempotent* will at some point cause an incident — a partially completed retry will leave inconsistent state.

### 5.3 Determinism and reproducibility

Two distinct properties often conflated:

- **Determinism**: the same code on the same inputs always gives the same outputs *bit-for-bit*. Hard to achieve when ML, randomness, parallel reductions, GPU drivers are involved.
- **Reproducibility**: a colleague (or you in two years) can re-run and get *equivalent* outputs given the same code version, container image, and inputs.

Containers + pinned container tags (never `:latest`) + pinned dataset versions get you most of the way. Bit-for-bit determinism is a research project of its own; usually not worth chasing in DE.

### 5.4 Schemas, contracts, validation

A **schema** declares the shape of data (field names, types, nullability, constraints). A **data contract** is a schema + an agreement between producer and consumer about backwards-compatibility, freshness, and ownership.

| Where | What people use |
|---|---|
| In-memory Python | Pydantic, dataclasses |
| On-disk tabular | Parquet/Avro schemas, Iceberg, Delta |
| Streaming messages | Avro + Schema Registry, Protobuf |
| BI / warehouse | dbt YAML tests, Great Expectations, Soda |
| Neuroimaging | **BIDS** is your schema; `bids-validator` is your validator |

When you pass `--skip-bids-validation` to QSIPrep you are explicitly turning off your schema check. In industry that's equivalent to disabling Pydantic — sometimes pragmatic, often the cause of the next incident.

### 5.5 Data lineage and provenance

**Lineage** = the directed graph of "table X was produced by job Y consuming tables A, B, C". When something is wrong with X you can walk the graph upstream and find the root cause.

Industry tools: **OpenLineage** (open standard), **Marquez** (reference impl), **Atlan / Collibra / DataHub** (catalogs). dbt's `manifest.json` is a lineage artifact too.

Your pipeline's lineage is implicit in the bash dispatch. Snakemake makes it explicit (every output has a rule with declared inputs); a `--report` HTML page renders it.

### 5.6 Partitioning and sharding

**Partitioning** is how you split a big dataset along a natural key so consumers can read only the slice they need. Your "partition key" is `subject_id`. Common industry keys: `date` (`/year=2026/month=05/day=29/...`), `tenant_id`, `region`.

Partitioning enables:

- *Selective reprocessing* — fix one subject without re-running the whole cohort.
- *Parallelism* — each partition is an independent task.
- *Pruning* — query engines skip partitions outside the filter.

Bad partition keys (high cardinality or no skew alignment) destroy these benefits. There are entire blog posts on "small files problem" — too many tiny partitions overwhelm metadata systems.

### 5.7 Backpressure, retries, exponential backoff

When a downstream system is overloaded, you don't keep hammering it — you slow down (**backpressure**), retry after a delay, and increase the delay each time (**exponential backoff**), with a little randomness (**jitter**) so retries don't synchronise. Standard formula:

```
sleep = min(cap, base * 2 ** attempt) * random(0.5, 1.5)
```

In your world this matters for API-bound stages (TemplateFlow downloads, cloud storage). Slurm itself implements backpressure via the queue.

### 5.8 Cost-aware design

Every design choice has a $ price tag at scale:

- Running recon-all sequentially: 10 h × 60 subjects = 600 CPU-hours.
- Running recon-all with 5-way concurrency: same total CPU-hours, but the cohort finishes in ~120 wall hours.
- Switching to FastSurfer: ~60 CPU-hours instead of 600. Maybe 90% cost reduction at the price of slightly different surfaces.

A senior DE always knows the dollar-per-run of their main pipeline and can speak to the cost/benefit of optimisations. In the cloud this is measured in AWS bill lines; in HPC it's CPU-hour quotas.

---

## 6. The industry tooling landscape

You don't need to learn all of these. You do need to recognise them so job posts make sense and you can pick the right tool for the next project.

### 6.1 Workflow orchestrators

| Tool | Strength | Where you see it |
|---|---|---|
| **Snakemake** | Declarative, file-based, idempotent by design | Genomics, neuroimaging, academia |
| **Nextflow** | Same niche as Snakemake but Groovy DSL, nf-core ecosystem | Pharma / biotech genomics |
| **Apache Airflow** | Mature, huge plugin ecosystem, web UI | Default at most tech companies for batch ELT |
| **Dagster** | Asset-centric (vs task-centric), better typing, modern UI | Newer data teams, ML platforms |
| **Prefect** | Pythonic, dynamic DAGs, hybrid execution | Smaller teams, ad-hoc workflows |
| **Argo Workflows** | DAGs on Kubernetes (YAML) | Cloud-native shops, Kubeflow base |
| **Luigi** | Python, simple, predates Airflow | Legacy systems at Spotify et al. |
| **Make / Bazel** | Build tools that double as DAG engines | Software builds, small data jobs |

### 6.2 Compute substrates

| Substrate | Strength | Your equivalent |
|---|---|---|
| **HPC (Slurm, SGE, LSF)** | Big batch jobs, MPI, GPUs | What you use |
| **Kubernetes** | General-purpose container scheduling | Industry default |
| **AWS Batch / Google Batch / Azure Batch** | Cloud batch as a service | Cloud HPC analog |
| **AWS Lambda / Cloud Functions** | Tiny ephemeral tasks, event-driven | Small ETL hops |
| **Spark / Databricks / EMR** | Distributed in-memory data processing | Big-tabular world |

### 6.3 Storage layers

| Layer | Examples | Use case |
|---|---|---|
| Object storage | S3, GCS, Azure Blob | Cheap, durable, the default for big data |
| Network filesystems | NFS, Lustre, GPFS | HPC scratch space; what your NFS home is |
| Lakehouse formats | Parquet, Delta Lake, Iceberg, Hudi | Open table formats on object storage |
| OLTP DBs | Postgres, MySQL | Application state, low latency reads/writes |
| OLAP warehouses | Snowflake, BigQuery, Redshift, Databricks SQL | Analytics queries on huge tables |
| Embedded analytics | DuckDB, SQLite | Local prototyping, single-node analytics |
| Caches | Redis, Memcached | Sub-millisecond reads |
| Vector stores | pgvector, Pinecone, Weaviate, Milvus | LLM retrieval, embeddings |

### 6.4 Transformation tools

- **SQL on a warehouse** — the workhorse.
- **dbt** — SQL with Jinja templating, versioning, tests, lineage. Modern ELT default.
- **Spark / PySpark** — distributed transformations on huge datasets.
- **Pandas / Polars / DuckDB** — single-node Python analytics.

### 6.5 Streaming

- **Apache Kafka** — distributed log; the de-facto event bus.
- **AWS Kinesis / Google Pub-Sub** — managed alternatives.
- **Apache Flink / Spark Structured Streaming / Apache Beam** — stream processors on top.

### 6.6 Observability

- **Logs**: ELK (Elasticsearch + Logstash + Kibana), Splunk, Loki, Datadog Logs.
- **Metrics**: Prometheus + Grafana, Datadog, CloudWatch.
- **Traces**: OpenTelemetry, Jaeger, Tempo.
- **Data-specific**: OpenLineage, Marquez, Monte Carlo, Bigeye.

### 6.7 Data quality

- **Great Expectations** — Python framework for declarative data tests ("expect rows >= 1000", "expect age between 0 and 120").
- **dbt tests** — built-in SQL-based assertions in dbt projects.
- **Soda** — YAML-based data quality DSL.
- **Pandera** — Pydantic for pandas/Polars DataFrames.

---

## 7. Reliability and operations

### 7.1 SLAs, SLOs, SLIs

- **SLI** (Service Level Indicator) — what you measure. e.g., "p95 pipeline runtime", "% subjects with valid DK matrix".
- **SLO** (Service Level Objective) — your internal target. e.g., "99% of subjects finish in <12 h".
- **SLA** (Service Level Agreement) — a contractual target with consequences. Mostly external.

A DE team owns SLOs on its pipelines. Below SLO triggers an investigation; trending toward the boundary triggers prevention.

### 7.2 The failure modes you actually see

| Failure | Likely cause | Mitigation |
|---|---|---|
| Pipeline silently produces wrong data | Schema drift, partial writes | Data tests, atomic writes |
| Pipeline hangs forever | Deadlock, stuck network call | Timeouts on every external call |
| One subject crashes the whole array | No isolation | Per-task error boundary, continue-on-failure flag |
| OOM kill | Underestimated memory | Resource profiling, per-stage tuning |
| Disk full | Workdirs not cleaned, logs not rotated | Cleanup steps, retention policies |
| Auth token expired mid-run | Long pipelines exceed token lifetime | Refresh strategy, short-lived creds + retries |
| Cluster prolog broken on one node | Infrastructure issue | Exclude-list (your `EXCLUDE_NODES`) |

You've already hit two of these (your `/var/spool/slurmd/logs` and the missing FS dir). Each one becomes a runbook.

### 7.3 Runbooks

A runbook is a short markdown file per common alert/failure: "If alert X fires, the cause is usually Y; check Z; remediate with command W; escalate to person P." Cheap, high-leverage, and a great signal in DE interviews ("show me your runbooks" is a real question).

### 7.4 On-call

Production pipelines that other teams depend on need on-call coverage. The DE rotation typically handles:

- Failed pipeline runs (page within minutes if SLO-critical)
- Data quality alerts (page slower)
- Capacity issues (proactive)

In your current setup, you're the entire on-call rotation for the DWI pipeline. That's fine — but it's why discipline matters: every fix should leave the system more resilient than you found it.

### 7.5 Retries — the right way

The naive `for i in 1..3; do something || continue; done` is rarely the right answer. Real retry policy:

1. **Only retry transient errors** (network, 5xx). Never retry on validation errors.
2. **Exponential backoff with jitter** to avoid thundering herds.
3. **Idempotency** is a precondition — never retry a non-idempotent operation without deduplication.
4. **Bounded** — give up eventually and surface the error.

Workflow engines do most of this for you (`retries=3, retry_delay=...`).

---

## 8. Performance and scale

### 8.1 Parallelism — three flavours

- **Data parallelism**: same operation over different shards (your across-subject parallelism).
- **Pipeline parallelism**: different stages on different workers (QSIPrep on node A while Recon on node B for the next subject).
- **Task parallelism**: independent tasks share a worker (multi-threading inside QSIPrep).

Knowing which you're using clarifies bottlenecks. Adding more workers helps data-parallel work but does nothing for sequential-bound work.

### 8.2 Profiling and resource estimation

A senior DE knows, roughly, for each stage:

- CPU time per unit of work
- Peak RSS (memory)
- Disk I/O pattern
- External calls per unit

You get this with `seff <jobid>` on Slurm, with `time -v`, with `cgroups` accounting, or with explicit Python timing. Write down a sentence per stage. Then size the cluster request honestly — overprovisioning costs money; underprovisioning causes OOMs.

### 8.3 Caching and memoization

If a sub-result is expensive and rarely changes, cache it. Patterns:

- Filesystem cache keyed by input hash.
- Memcached/Redis for sub-second values.
- HTTP caching with ETags for external APIs (TemplateFlow, BIDS validators).

Caching is power-and-responsibility: a wrong cache key is the worst bug class in DE because it silently returns stale data. Always include the *content version* in cache keys.

### 8.4 Backfills

When you change a stage, you usually need to re-process all historical data. This is a **backfill**. Industry-grade orchestrators have first-class support (`airflow backfill`, `dagster backfill`, Snakemake `--forceall`). Plan your backfill cost (CPU-hours, $) before you ship a change.

---

## 9. Testing pipelines

### 9.1 The pyramid

```
                  ╱╲
                 ╱  ╲  E2E (1 tiny subject end-to-end)
                ╱────╲
               ╱      ╲ Integration (rule by rule, mocked containers)
              ╱────────╲
             ╱          ╲ Unit (pure-Python helpers, config parsers)
            ╱────────────╲
```

Many fast unit tests at the bottom, a few slow end-to-end tests at the top.

### 9.2 Test types specific to DE

- **Schema tests**: row count > 0, no nulls in primary key, foreign keys resolve, value ranges sane.
- **Volume tests**: today's row count is within ±20% of yesterday's.
- **Freshness tests**: most recent partition's `max(updated_at)` is within N hours.
- **Distribution tests**: mean / stddev of numeric column hasn't drifted.

For neuroimaging analogs:

- *Schema*: every subject has 1 DK matrix; matrix shape is 84×84.
- *Volume*: total streamlines per subject in [N₁, N₂].
- *Distribution*: cohort-mean FA hasn't drifted between releases.
- *Provenance*: every output `.csv` has a sibling `_log.json` recording the container hash.

### 9.3 Test data

Curate one or two **fixture subjects** with very small dimensions (cropped DWI, small T1w) that can run the full pipeline in under 5 minutes on a single node. This is the basis for your integration test and CI.

---

## 10. CI/CD for data pipelines

CI/CD does **not** mean "auto-deploy production data jobs on every commit". For data, it means:

- **Lint**: shellcheck on `*.sh`, `ruff` on `*.py`, `snakemake -n` (dry-run) on every PR.
- **Unit tests**: pytest on PR.
- **Integration tests**: run the pipeline on the tiny fixture subject on PR (a few minutes).
- **Schema diff**: if the pipeline outputs a known schema, diff against the previous release.
- **Container build & scan**: build the SIF/Docker image, scan for vulnerabilities (Trivy, Grype).
- **Promotion gates**: merging to `main` builds production images; deploying to prod still requires a manual click for high-blast-radius pipelines.

GitHub Actions or GitLab CI handles this for free. A `Makefile` with `make lint test integration` targets keeps the same commands runnable locally.

---

## 11. From scientific HPC to industry DE — bridging the gap

### 11.1 What you already have

The mental model is identical. You've built a multi-stage idempotent pipeline orchestrated by a scheduler, with containerised tasks, configurable via env vars, written runbooks-by-example in the form of headers and READMEs, and you can debug logs. That's 60–70% of the day-to-day skillset of an early-career data engineer.

### 11.2 What's different

| Dimension | HPC / scientific | Industry DE |
|---|---|---|
| Storage primitive | Files on POSIX (NFS, Lustre) | Objects in S3/GCS, tables in a warehouse |
| Compute primitive | Slurm jobs in containers | Containers in Kubernetes, or warehouse SQL |
| Transformation language | Python + domain CLIs (MRtrix, FreeSurfer) | SQL + Python (Spark/dbt) |
| Scheduling | Fixed cohort, manual submit | Recurring schedule (hourly/daily/event-driven) |
| Schema enforcement | BIDS (loose, validated separately) | Warehouse types (strict) |
| Observability | `sacct`, logs in files | Web UI, dashboards, alerting |
| SLOs | Implicit ("hopefully runs over the weekend") | Explicit and tracked |
| Failure cost | "Re-run the subject" | "Customer churn / regulatory issue" |

### 11.3 The translation table

| When industry says… | …you've already done it as… |
|---|---|
| "Make this DAG resumable" | Your `aparc+aseg.mgz` skip |
| "Containerise the task" | Apptainer SIF |
| "Run it on the batch service" | Slurm array job |
| "Fan-out per partition" | Per-subject array tasks |
| "Bind-mount the credentials" | `-B FS_LICENSE:...:ro` |
| "Stop scheduling jobs on the bad worker" | `EXCLUDE_NODES=smdodwork05` |
| "Backfill the cohort with the new release" | `PIPELINE_MODE=all` over the full subject list |
| "Promote from dev to prod" | `RESULTS_ROOT=/.../dwi_test` → `RESULTS_ROOT=/.../prod` |

---

## 12. A portfolio progression roadmap

Concrete, ordered steps that turn your current bash pipeline into a strong DE portfolio piece. Each item is sized at "a weekend".

### Milestone 0 — Current state
Bash + Slurm + Apptainer + 4 stages, no tests, manual runbook.

### Milestone 1 — Snakemake port (1 weekend)
- Replace `submit.sh`/`array.sh`/`subject.sh` glue with a `Snakefile`.
- One `rule` per stage; declare `input:`, `output:`, `container:`, `threads:`, `resources:`.
- `snakemake --executor slurm --jobs 50` runs the same workload.
- `snakemake -n` is your dry-run / dependency-diff.
- `snakemake --report report.html` is your provenance artifact.
- Keep the bash scripts in `dwi_pipeline/legacy/` so reviewers can compare.

### Milestone 2 — Tests and CI (1 weekend)
- Pick one cropped subject as fixture (`tests/fixtures/sub-tiny/`).
- Add `pytest` with a single integration test that runs the pipeline locally on the fixture (no Slurm) and asserts the DK CSV exists with shape 84×84.
- Add `tests/test_config.py` with unit tests for any Python helpers (Pydantic config validator if you introduce one).
- Add `.github/workflows/ci.yml`: shellcheck + ruff + `snakemake -n` + pytest.
- Add `Makefile` with `make lint test integration`.

### Milestone 3 — Observability (1 weekend)
- Emit a per-subject `manifest.json` (subject ID, container hashes, git SHA, timings, success/failure).
- Aggregate manifests into a single `cohort_report.parquet`.
- A tiny Grafana dashboard or a static HTML report ("69/76 subjects complete, p95 runtime 8.2 h, failures by stage"). Even a hand-written HTML works.

### Milestone 4 — SQL/warehouse layer (1 weekend)
- DuckDB locally (zero ops) or a small Postgres on-cluster.
- Load every subject's QC metrics, manifest, and a flattened connectome (`subject_id, source_node, target_node, weight`) into three tables.
- Wrap a tiny dbt project around them with two models (`cohort_qc_summary`, `connectome_long_to_wide`) and a few `dbt test`s.
- This is the missing tabular surface area that converts a "scientific pipeline" into "DE portfolio".

### Milestone 5 — Cloud port (stretch, 2 weekends)
- Run the same Snakemake workflow on **AWS Batch** with S3 as the storage layer.
- Push the Apptainer images to a container registry (or convert to Docker).
- The pipeline now demonstrates HPC-and-cloud literacy in one repo.

### Milestone 6 — Airflow / Dagster comparison (stretch)
- Wrap the existing pipeline as a single Airflow or Dagster DAG (each stage = one operator/op).
- Write a short `docs/why-snakemake-vs-airflow.md` documenting the trade-offs you observed. This is exactly the kind of artifact senior engineers and tech leads write — and is gold in interviews.

By Milestone 4 you have a strong portfolio piece. Milestones 5–6 turn it into a senior-level one.

---

## 13. Exercises

Each exercise is a small, contained task in your current repo.

1. **Draw the DAG of the existing pipeline by hand**, including the dotted-line dependency from QSIPrep's LTA into the DK step. Save it as `docs/dag.png` (Mermaid, Graphviz, or paper photo).

2. **Make `run_recon()` content-addressable**: cache key = sha256 of (T1w nifti + container hash + tool flag). Skip if a hash file already exists. Compare with the current mtime/existence check.

3. **Add a `manifest.json` per subject** capturing: subject ID, container SHA, git SHA, start/end timestamps, exit code per stage, host name, peak RSS (from `seff`/`time -v`).

4. **Write three data tests** (any framework you like, or hand-rolled pytest): (a) DK matrix is 84×84 numeric; (b) tractogram count is between 100 k and 100 M; (c) every QSIPrep `*.bval` parses and contains at least one b=0 volume.

5. **Implement atomic writes** for the DK CSV: write `dk_connectome.csv.tmp` then `mv`. Verify by killing the job mid-write and re-running — the output should never be half-written.

6. **Introduce a Pydantic config object** (`dwi_pipeline/config.py`) that mirrors today's env vars. Replace `${RESULTS_ROOT:-…}` with `cfg.results_root`. Run with both a valid and an invalid config; observe the error quality.

7. **Add a `--dry-run` flag** to `submit.sh` that prints the planned `sbatch` command without submitting and a list of subjects that would actually be processed (skipping those already complete).

8. **Port one stage to Snakemake** — `recon` is a good first choice because it has clear inputs/outputs. Get `snakemake --executor slurm -j 2` to run it for sub-001 and sub-007.

9. **Build the cohort-summary DuckDB** (Milestone 4 lite): load `dk_connectome.csv` from every subject into a single table; write a SQL query that returns mean edge weight per (subject, source_region).

10. **Write a one-page runbook**, `docs/runbook_recon_failed.md`: symptoms, common causes, diagnostic commands, remediation, escalation.

---

## 14. Glossary

- **Atomic write** — A write that either completes fully or appears not to have happened. Implemented by writing to a temp path and renaming.
- **Backfill** — Re-processing historical partitions with a new pipeline version.
- **Backpressure** — Mechanism by which a slow consumer signals an upstream producer to slow down.
- **Bronze/Silver/Gold** — Lakehouse layering: raw / cleaned / business-ready.
- **CDC** (Change Data Capture) — Streaming the *changes* to a source table instead of re-reading it whole.
- **Container** — An immutable filesystem + binaries that runs identically on any compatible host.
- **DAG** — Directed Acyclic Graph; the model for every modern workflow engine.
- **Data contract** — A schema + an SLA between producer and consumer.
- **Data mesh** — Organisational pattern: domain teams own their data products.
- **dbt** — Data Build Tool; the dominant SQL transformation framework.
- **Dead-letter queue** — A holding area for messages/tasks that repeatedly fail processing.
- **Determinism** — Same input → same output, bit-for-bit.
- **ELT / ETL** — Extract-Load-Transform vs Extract-Transform-Load.
- **Event-driven** — Pipeline triggered by an event (file arrival, message on a topic) rather than a clock.
- **Fan-out / fan-in** — One task producing many sub-tasks / many tasks merging into one.
- **Idempotency** — Running the same operation twice has the same effect as running it once.
- **Lakehouse** — Architecture combining a data lake (object storage) with warehouse-like ACID tables (Delta, Iceberg, Hudi).
- **Lineage** — Directed graph of which dataset depends on which.
- **Manifest** — Machine-readable record of what a pipeline run produced.
- **Medallion architecture** — The Bronze/Silver/Gold layering pattern.
- **OLAP** — Online Analytical Processing: columnar, wide scans, analytics queries.
- **OLTP** — Online Transactional Processing: row-oriented, fast point lookups, application backends.
- **OpenLineage** — Open standard for emitting lineage events from any tool.
- **Orchestrator** — System that decides what runs, when, with what resources.
- **Partition** — A slice of a dataset along a natural key (date, subject, region).
- **Provenance** — Auditable record of how a dataset was produced.
- **Runbook** — Short ops document: symptoms → diagnostics → fix → escalation.
- **Schema** — Declared shape of data (names, types, constraints).
- **Schema-on-read / schema-on-write** — When the type contract is enforced: at query time vs at write time.
- **Sharding** — Splitting a dataset across multiple physical stores.
- **Slowly Changing Dimension** (SCD) — Strategies for storing history of mutable dimension records (Type 1/2/3).
- **SLA / SLO / SLI** — Contract / objective / indicator for reliability.
- **Snakemake / Nextflow** — File-based DAG workflow tools popular in bioinformatics / neuroimaging.
- **Streaming** — Continuous processing of unbounded data, as opposed to batch.
- **Warehouse** — Columnar OLAP system optimised for analytics (Snowflake, BigQuery, Redshift, Databricks SQL).

---

## 15. Further reading

Books worth owning:

- *Fundamentals of Data Engineering* — Joe Reis & Matt Housley (the modern DE survey textbook).
- *Designing Data-Intensive Applications* — Martin Kleppmann (the systems-level reference; long but essential).
- *The Data Warehouse Toolkit* — Ralph Kimball (dimensional modelling; still relevant).
- *Software Engineering at Google* — Winters, Manshreck & Wright (testing/CI culture).

Free / online:

- Snakemake tutorial: <https://snakemake.readthedocs.io/en/stable/tutorial/tutorial.html>
- nf-core training: <https://nf-co.re/usage/installation>
- dbt fundamentals: <https://courses.getdbt.com>
- Astronomer (Airflow) docs: <https://docs.astronomer.io>
- Dagster university: <https://courses.dagster.io>
- BIDS specification: <https://bids-specification.readthedocs.io>
- The "Modern Data Stack" landscape (blog/diagrams updated yearly).

Communities worth lurking in:

- `r/dataengineering`
- Locally Optimistic Slack (data community)
- The dbt Slack
- The Snakemake / Nextflow user mailing lists

---

*End of Part I. Suggested next step: pick one exercise from §13 and ship it this week.*

---

## 16. Where to go next — Part II (Advanced topics)

Part I is the **map**. To move from beginner → senior, you need **depth** in the areas Part I only names. That depth lives in `data_engineering_part2_advanced.md` (and the matching `.docx`). It covers, with worked examples and per-tool 5-minute pipelines:

1. Data modeling (star/snowflake, SCD types, data vault, OBT)
2. File formats + lakehouse internals (Parquet, Avro, Iceberg, Delta, Hudi)
3. SQL beyond SELECT (query plans, joins, window functions, MVs)
4. Distributed systems fundamentals (CAP, consistency, exactly-once)
5. Distributed compute — Spark (shuffle, AQE, skew, executor sizing)
6. Streaming — Kafka, watermarks, windowing, exactly-once, CDC
7. dbt deeply (models, snapshots, incremental, tests, contracts, semantic layer)
8. Data contracts and schema evolution
9. Security, governance, privacy (IAM, encryption, PII, GDPR/HIPAA)
10. Infrastructure as Code (Terraform, Helm, GitOps)
11. FinOps and cost engineering
12. Performance — queues, percentiles, skew
13. Concurrency, transactions, isolation levels
14. Data quality deeply (six dimensions, drift, circuit breakers)
15. Catalogs, discovery, lineage (DataHub, OpenLineage)
16. Real-time analytics (ClickHouse, Pinot, Materialize)
17. Ingestion patterns (CDC, Airbyte, webhooks)
18. Event-driven (event sourcing, outbox, saga, DLQ)
19. MLOps overlap (feature stores, vector stores)
20. Backup, DR, RTO/RPO
21. Incident management and postmortems
22. Versioning everything (code, data, models)
23. Networking essentials
24. Org-level data engineering (data mesh, RFCs, design docs)
25. Interview preparation (system design template + 5 walkthroughs)

Plus an **Appendix A** with hello-world pipelines for Snakemake / Airflow / Dagster / dbt / Spark / Kafka / Iceberg / DuckDB / Terraform, and an **Appendix B** career rubric (Junior → Principal across 10 dimensions).