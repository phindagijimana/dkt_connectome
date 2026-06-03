# Data Engineering — Part II: Advanced Topics

*Companion to `data_engineering.md`. Reading time: ~3 hours.
Each section is self-contained: concept → why it matters → worked example → DWI-pipeline tie-in → next step.*

---

## How to use this volume

Part I gave you a 60-minute map of data engineering using the DWI pipeline as a case study. Part II is the depth that converts "understands the map" into "can be hired as a senior DE". Read top-to-bottom once, then come back per topic when you encounter it at work or in interviews.

Each numbered section in this volume corresponds to one of the gaps identified by the senior-rubric audit. Sections 1–10 are the must-haves for senior; sections 11–20 are strong contributors; sections 21–25 round out the surface area. Appendices A and B give you per-tool pipelines and a self-assessment rubric.

---

## Table of contents

1. Data modeling
2. File formats and lakehouse internals
3. SQL beyond SELECT
4. Distributed systems fundamentals
5. Distributed compute — Spark
6. Streaming systems — Kafka, Flink, Kafka Streams
7. dbt deeply
8. Data contracts and schema evolution
9. Security, governance, privacy
10. Infrastructure as Code
11. FinOps and cost engineering
12. Performance — queues, percentiles, skew
13. Concurrency, transactions, isolation levels
14. Data quality deeply
15. Catalogs, discovery, lineage
16. Real-time analytics
17. Ingestion patterns
18. Event-driven architectures
19. MLOps overlap — feature stores, vector stores
20. Backup, disaster recovery, RTO/RPO
21. Incident management and postmortems
22. Versioning everything — code, data, models
23. Networking essentials
24. Org-level data engineering
25. Interview preparation

- Appendix A — Per-tool 5-minute pipelines
- Appendix B — DE career rubric

---

## 1. Data modeling

### Why it matters

Compute is fungible; schemas are forever. The shape of your tables determines what queries are easy, what queries are slow, what changes are safe, and what migrations cost a quarter. Senior DEs design schemas; mid DEs implement them; juniors write SQL on them.

### Core patterns

**Dimensional modeling (Kimball)** — the dominant pattern for analytics.

- **Fact tables** record events or measurements; each row is one observation; columns are foreign keys to dimensions plus numeric measures.
- **Dimension tables** describe entities (subjects, regions, dates, releases). Each row identifies a "thing"; columns are descriptive attributes.
- **Star schema** — one fact in the middle, dims around it (one-to-many).
- **Snowflake schema** — dims are themselves normalized into sub-dims (one-to-many-to-many). Saves storage; costs joins. Rarely worth it today.
- **Galaxy / fact constellation** — multiple facts sharing conformed dims.

**Grain** — the most important single decision when designing a fact table. "Grain = what does one row mean?" If you can't answer that in one sentence, the model is wrong. Example grains for DWI:

- Grain "one streamline per row" → fact_streamline (billions of rows; rarely correct grain).
- Grain "one (subject, source_node, target_node) edge per run" → fact_dk_edge (millions of rows; correct grain for connectome analytics).
- Grain "one (subject, run) summary" → fact_run_qc (thousands; correct for cohort dashboards).

**Slowly Changing Dimensions (SCD)** — how you store history of a dim that mutates over time.

| Type | Behavior | When |
|---|---|---|
| 0 | Never change | Stable codes |
| 1 | Overwrite | Don't care about history |
| 2 | New row + valid_from/valid_to + is_current | Default for analytics |
| 3 | Add column for previous value | One-step history only |
| 4 | History in separate table | Big histories, keep current small |
| 6 | Hybrid 1+2+3 | Need both current and full history |

**Data Vault 2.0** — alternative to Kimball for the *raw vault* (audit-grade landing zone):
- **Hubs** = unique business keys (`hub_subject` with `subject_bk`, `load_date`, `record_source`)
- **Links** = relationships between hubs (`link_subject_session`)
- **Satellites** = descriptive attributes + history (`sat_subject_demographics`)

Data Vault is hash-key joinable, append-only, easy to load in parallel — good for regulated environments. Then build a Kimball star on top for consumers.

**One Big Table (OBT)** — denormalize everything into a wide table. Trades storage for query simplicity; columnar warehouses (BigQuery, Snowflake) make it cheap. Used by many analytics teams as a "Gold layer".

### Worked example — DWI as a star schema

```sql
-- dim_subject (SCD2)
create table dim_subject (
    subject_sk        bigint primary key,    -- surrogate key
    subject_bk        text   not null,       -- business key, e.g. "001"
    age_at_scan       int,
    sex               text,
    site              text,
    valid_from        timestamp,
    valid_to          timestamp,
    is_current        boolean
);

-- dim_node (Desikan-Killiany regions, stable)
create table dim_node (
    node_sk        smallint primary key,
    node_label     text,                  -- "ctx-lh-precentral"
    hemisphere     char(1),
    lobe           text
);

-- dim_release (which container hashes + git SHA produced a row)
create table dim_release (
    release_sk        bigint primary key,
    qsiprep_sha       text,
    qsirecon_sha      text,
    fastsurfer_sha    text,
    git_sha           text,
    released_at       timestamp
);

-- dim_date
create table dim_date (
    date_sk        int primary key,
    date_actual    date,
    year           int,
    quarter        int,
    month          int,
    day_of_week    int
);

-- fact_dk_edge: one row per (subject, source, target, release)
create table fact_dk_edge (
    subject_sk       bigint references dim_subject,
    source_node_sk   smallint references dim_node,
    target_node_sk   smallint references dim_node,
    release_sk       bigint references dim_release,
    date_sk          int    references dim_date,
    streamline_count bigint,
    mean_fa          double precision,
    primary key (subject_sk, source_node_sk, target_node_sk, release_sk)
);
```

That single model answers: "Show me the cohort-mean connectivity matrix for males age 25–45 scanned in 2026 with QSIPrep 0.23.1" in one star-join query, and it survives the day you re-process the cohort with QSIPrep 0.24 (new `release_sk`).

### DWI tie-in

Your current `dk_connectome.csv` files are a *long-list* representation. Loading them into a star schema (Milestone 4 in Part I) is exactly the senior-level move: it converts a scientific output into a queryable, auditable product.

### Next step

Read *The Data Warehouse Toolkit* (Kimball), chapters 1–3, then rebuild Milestone 4 around the star above. Implement at least one SCD2 dimension (e.g. `dim_subject` with the day a subject's demographics change).

---

## 2. File formats and lakehouse internals

### Row-based vs columnar

Row-based (CSV, JSON, JSONL, Avro): each record is contiguous; great for write-once-read-once and streaming. Bad for analytics — to read one column you read all columns.

Columnar (Parquet, ORC, Arrow): values for one column are stored together; reads only what's projected; compresses better (column values have low entropy together); enables predicate pushdown via min/max statistics per chunk.

### Parquet internals (the format every DE must know cold)

```
File
└── Row Group  (typically 128 MiB)
    ├── Column Chunk: subject_id
    │   ├── Page 1: dictionary
    │   ├── Page 2: data (RLE-encoded indices into dict)
    │   └── stats: min, max, null_count, distinct_count
    ├── Column Chunk: streamline_count
    │   ├── stats: min=0, max=12345678
    │   └── …
    └── …
└── Footer (schema + offsets to row groups + column stats)
```

Why this matters:
- Reader opens **footer first**, finds the columns and row groups it needs, seeks to them. Reads zero bytes from irrelevant columns/rows.
- `WHERE subject_id = '001'` triggers **predicate pushdown**: the reader skips entire row groups whose `[min, max]` for `subject_id` doesn't contain `'001'`.
- **Dictionary encoding** + **RLE** make small-cardinality columns nearly free.

Compression codecs:

| Codec | CPU | Ratio | Use when |
|---|---|---|---|
| none | 0 | 1.0× | Already-compressed source |
| snappy | low | ~2× | Default; balanced |
| zstd | medium | ~3× | Storage-dominated workloads |
| gzip | high | ~3× | Legacy compatibility |
| lz4 | very low | ~1.5× | Latency-critical |

### Lakehouse table formats

A **table format** is a metadata layer on top of Parquet/ORC files that gives you ACID, time-travel, schema evolution, and partition evolution — features that classic "directory of Parquet files" cannot offer.

| Format | Origin | Selling point |
|---|---|---|
| **Apache Iceberg** | Netflix → ASF | Strongest spec; hidden partitioning; safe rename/drop |
| **Delta Lake** | Databricks → Linux Foundation | Mature; great Databricks integration; transaction log on object store |
| **Apache Hudi** | Uber → ASF | Best at upserts; CoW and MoR table types |

Iceberg metadata structure (worth memorising):

```
table_root/
├── data/                          parquet files
└── metadata/
    ├── v1.metadata.json           catalog pointer
    ├── v2.metadata.json
    ├── snap-<id>.avro             snapshot manifest list
    ├── <hash>-m0.avro             manifest of data files (with stats)
    └── …
```

Each commit writes a new metadata.json; old ones are kept (time-travel) until expired. `SELECT * FROM tbl FOR TIMESTAMP AS OF '2026-01-01'` reads through whichever snapshot was current then.

### Worked example — DK matrices in Iceberg

```python
from pyiceberg.catalog import load_catalog
import pyarrow as pa
from pyarrow import parquet as pq

# Catalog (file-based for local dev; AWS Glue or Nessie in prod)
catalog = load_catalog("local", **{
    "type": "sql",
    "uri": "sqlite:////tmp/iceberg.db",
    "warehouse": "/tmp/iceberg-warehouse",
})

schema = pa.schema([
    ("subject_id",       pa.string()),
    ("source_node",      pa.int16()),
    ("target_node",      pa.int16()),
    ("streamline_count", pa.int64()),
    ("release_id",       pa.string()),
    ("ingested_at",      pa.timestamp("us")),
])

catalog.create_namespace_if_not_exists("dwi")
tbl = catalog.create_table_if_not_exists("dwi.fact_dk_edge", schema)

# Append a new subject's edges as one snapshot
arrow_tbl = pq.read_table("/tmp/sub-001_dk_edges.parquet")
tbl.append(arrow_tbl)

# Query later: only reads files touched by this filter (predicate pushdown).
import duckdb
con = duckdb.connect()
con.sql("INSTALL iceberg; LOAD iceberg;")
con.sql("""
    SELECT source_node, AVG(streamline_count) AS mean_sc
    FROM iceberg_scan('/tmp/iceberg-warehouse/dwi/fact_dk_edge')
    WHERE release_id = 'qsiprep-0.23.1'
    GROUP BY source_node
    ORDER BY mean_sc DESC LIMIT 10;
""").show()
```

### DWI tie-in

Replace `dk_connectomes/sub-XXX/dk_connectome.csv` with an Iceberg table you append to per subject. Now any tool (Spark, DuckDB, Trino, ClickHouse) can read it; you get time-travel; you can rename columns safely; you get min/max-based pruning for cohort queries.

### Next step

Convert your existing DK CSVs to an Iceberg table (script above), then point a DuckDB session at it for cohort analytics.

---

## 3. SQL beyond SELECT

### Query plans

```sql
EXPLAIN ANALYZE
SELECT s.site, AVG(e.streamline_count) AS mean_sc
FROM   fact_dk_edge e
JOIN   dim_subject s ON e.subject_sk = s.subject_sk
WHERE  s.is_current
GROUP BY s.site;
```

The optimizer prints (Postgres / Snowflake / BigQuery all do this):

- **Scan node**: which table, which partitions, which columns; rows estimated vs actual.
- **Filter**: predicates pushed down vs evaluated after.
- **Join**: algorithm (Hash / Sort-Merge / Nested-Loop / Broadcast), build vs probe side.
- **Aggregate**: hash vs sort, partial vs final.
- **Sort / Exchange**: implicit data redistribution.

When actual rows ≫ estimated, **statistics are stale** — run `ANALYZE` or the equivalent.

### Join algorithms — when each wins

| Algorithm | Cost | When |
|---|---|---|
| Nested-loop | O(N·M) | Small × tiny, or correlated subquery |
| Hash join | O(N+M), needs RAM for build side | Default for equi-joins |
| Sort-merge | O(N log N + M log M) | When inputs are already sorted (clustered tables) |
| Broadcast | O(N) per executor, M copied | One side is small enough to broadcast (≲100 MB) |

The number-one Spark performance fix is: "make sure that the small side of the join broadcasts."

### Window functions — the senior-DE workhorse

```sql
-- Top 5 most-connected source regions per subject
SELECT *
FROM (
    SELECT subject_id,
           source_node,
           streamline_count,
           ROW_NUMBER() OVER (PARTITION BY subject_id ORDER BY streamline_count DESC) AS rk
    FROM fact_dk_edge
) ranked
WHERE rk <= 5;

-- 7-day rolling cohort-mean per region
SELECT date_sk,
       source_node,
       AVG(mean_sc) OVER (
           PARTITION BY source_node
           ORDER BY date_sk
           ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
       ) AS rolling_sc
FROM cohort_daily;

-- Gaps & islands: contiguous runs of successful pipeline days
SELECT subject_id,
       MIN(date_sk) AS run_start,
       MAX(date_sk) AS run_end,
       COUNT(*)     AS streak
FROM (
    SELECT *,
           date_sk - ROW_NUMBER() OVER (PARTITION BY subject_id ORDER BY date_sk) AS grp
    FROM pipeline_success_days
) t
GROUP BY subject_id, grp;
```

Frame clauses (`ROWS BETWEEN` vs `RANGE BETWEEN`) and `IGNORE NULLS` are common interview hooks.

### CTEs vs subqueries

CTEs (`WITH foo AS (…)`) are usually *materialization hints* (Postgres pre-12) or *optimization-fence* in some engines. Modern Postgres / Snowflake / BigQuery inline them by default; you can force materialization with `WITH foo AS MATERIALIZED (…)`. Use CTEs for readability; profile if perf matters.

### Materialized views

A MV stores the result of a query. The engine refreshes it (manually, on schedule, or incrementally). Trade-offs:

- Read latency ↓↓, storage ↑, write latency ↑ (refresh cost).
- Snowflake auto-refreshes; BigQuery's are smart-refreshed incrementally on the underlying tables.
- Postgres requires manual `REFRESH MATERIALIZED VIEW CONCURRENTLY foo`.

Use MVs for dashboards hitting a slow underlying join; don't use them where the underlying changes faster than the refresh.

### Indexes (row-store) and clustering (columnar)

Row-store (Postgres, MySQL): B-tree, hash, GIN, BRIN, GiST. Pick by query pattern.

Columnar warehouses don't use B-trees; instead:
- **Clustering keys** (Snowflake `CLUSTER BY`, BigQuery `CLUSTER BY`) — physical sort within partitions.
- **Partition pruning** — `PARTITION BY DATE(event_ts)` skips entire days.
- **Z-order / liquid clustering** (Delta) — multidimensional clustering for selective queries on multiple columns.

### DWI tie-in

Your DK cohort dashboard would be a materialized view over `fact_dk_edge` clustered by `(subject_sk, source_node_sk)`. The `EXPLAIN` of "cohort mean per region" should show a partition-pruned scan + a hash join with broadcast on `dim_subject`.

### Next step

Take any 20-line query you've ever written, run `EXPLAIN ANALYZE` on it, and write down two sentences about each stage. Repeat for a week — you will see optimizer patterns that change how you write SQL forever.

---

## 4. Distributed systems fundamentals

### CAP theorem (in 60 seconds)

In a network partition, a distributed system can choose **Consistency** (refuse the write) or **Availability** (accept the write, reconcile later) — not both. Real systems are CP (HBase, MongoDB w/ majority) or AP (Cassandra, DynamoDB w/ eventual) along this knob. When there's no partition, you get both ("PACELC" extends this to "in normal ops, choose Latency or Consistency").

### Consistency models, weakest to strongest

| Model | Guarantee | Example |
|---|---|---|
| Eventual | All replicas converge eventually | DNS, S3 list-after-write (used to be) |
| Read-your-writes | A client reads its own latest write | Sticky sessions |
| Monotonic reads | Successive reads don't go backwards | Same-session reads |
| Causal | If A happens-before B, all readers see A before B | Collaborative editing |
| Sequential | All ops in some global order, agreeing with per-client order | Many DB replicas |
| Linearizable / strong | Looks like there's one node executing ops one at a time | Zookeeper, etcd, single-leader |

### Idempotency keys + exactly-once

True exactly-once is rare. Most systems offer **at-least-once + dedupe**:

1. Producer assigns a UUID per logical operation.
2. Consumer keeps a `seen_ids` table (with TTL).
3. On re-delivery, look up the UUID; if seen, skip.

```python
def handle(msg):
    key = msg.headers["idempotency-key"]
    with db.transaction():
        if db.exists("seen_ids", key):
            return
        process(msg)
        db.insert("seen_ids", key)
```

Kafka has built-in idempotent producer (`enable.idempotence=true`) and transactional producer for exactly-once across topic-partition writes; consumers set `isolation.level=read_committed`.

### Distributed transactions

- **2PC (two-phase commit)** — coordinator asks all participants "can you commit?" then "commit/abort". Blocking on coordinator failure.
- **3PC** — adds a pre-commit phase; non-blocking but complex; rarely used.
- **Sagas** — sequence of local transactions with compensating actions. Orchestrated (central) or choreographed (events).

Sagas are the practical pattern in microservices and pipelines: "if Step 3 fails, run compensating actions for Steps 1 and 2."

### Quorums and consensus

A replicated value with `N` replicas, `W` write quorum, `R` read quorum. If `W + R > N`, every read overlaps with the latest write — strongly consistent. (`N=3, W=2, R=2` is canonical for Cassandra-style systems.)

Consensus algorithms (Paxos, Raft, Zab) elect a leader and replicate a log. You consume them via Zookeeper / etcd / Consul — rarely implement them. Knowing they exist + that they cost a round-trip is enough for most DEs.

### DWI tie-in

Your pipeline today is single-writer per subject, so distribution is implicit. The moment you stream subject status events to multiple consumers (dashboard, alerting, archival), idempotency keys become non-optional.

### Next step

Read Kleppmann's *Designing Data-Intensive Applications* chapters 5 (replication), 7 (transactions), and 9 (consistency). It is the single most leveraged book in DE.

---

## 5. Distributed compute — Spark

### Mental model

Spark is a **lazy** distributed engine. You build a logical plan with **transformations** (`.filter`, `.groupBy`, `.join`) and trigger execution with **actions** (`.count`, `.write`, `.collect`).

- **RDD** — low-level, untyped, rarely used directly.
- **DataFrame** — schemaed, optimized by Catalyst.
- **Dataset** — typed DataFrame, Scala/Java only.

### Narrow vs wide transformations

- **Narrow**: each output partition depends on a single input partition (`map`, `filter`, `withColumn`). Free; runs in place.
- **Wide**: needs data from multiple input partitions (`groupBy`, `join`, `distinct`). Triggers a **shuffle**: serialise, write to local disk, fetch over the network. The expensive part.

### The shuffle and how to minimise it

Symptoms of bad shuffle: huge spill to disk, GC pressure, long "Exchange" stages in the Spark UI.

Fixes:
- **Broadcast join** when one side fits in RAM:
  ```python
  large.join(broadcast(small), "subject_id")
  ```
- **Bucket / pre-partition** both sides by the join key (write once, join cheap forever).
- **Salt** skewed keys: append a random suffix to the hot key so it splits across reducers; aggregate twice (with-suffix, then strip-suffix). AQE does this automatically since Spark 3.

### AQE (Adaptive Query Execution)

Since 3.0, Spark re-plans mid-query using runtime stats: coalesces tiny shuffle partitions, switches sort-merge to broadcast, splits skewed partitions. Enable it:

```python
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
```

### Worked example — cohort summary

```python
from pyspark.sql import SparkSession, functions as F

spark = (SparkSession.builder
         .config("spark.sql.adaptive.enabled", "true")
         .config("spark.sql.shuffle.partitions", "200")
         .getOrCreate())

edges = spark.read.parquet("s3://lake/dwi/fact_dk_edge/")
dim   = spark.read.parquet("s3://lake/dwi/dim_subject/").where("is_current")

cohort = (edges.join(F.broadcast(dim), "subject_sk")
          .groupBy("site", "source_node_sk")
          .agg(F.avg("streamline_count").alias("mean_sc"),
               F.percentile_approx("streamline_count", 0.95).alias("p95_sc")))

(cohort.write
       .mode("overwrite")
       .partitionBy("site")
       .parquet("s3://lake/dwi/gold/cohort_region_summary/"))
```

### Sizing executors (rule of thumb)

- 4–6 cores per executor; more → GC chaos.
- 16–32 GB memory per executor.
- `executor_cores × num_executors ≈ total CPUs`.
- 70 % heap to executor, 30 % to overhead.

### Reading the Spark UI

Open `http://driver:4040`. Look at: stages (where time is spent), tasks per stage (skew = one task hogs), shuffle read/write sizes (high = shuffle is the bottleneck), GC time (>10 % = JVM is choking).

### DWI tie-in

Once you have many cohorts, sub-cohort summary jobs become Spark jobs over your Iceberg fact table. Your DK matrices are tiny per subject (~84² floats) but huge in cohort × release × time.

### Next step

Spin up Spark locally with `pyspark`. Re-do Milestone 4 from Part I using Spark instead of DuckDB. Read the Spark UI for at least one run end-to-end.

---

## 6. Streaming systems — Kafka, Flink, Kafka Streams

### Kafka topology in one paragraph

A **topic** is partitioned into ordered, immutable, append-only **partitions**. Each message has an **offset** within its partition. **Producers** write; **consumers** organised into **consumer groups** share partitions (each partition consumed by exactly one consumer in the group). Brokers replicate partitions across the cluster; the **leader** handles reads/writes, **followers** stay in **ISR** (in-sync replicas) for failover.

### Producers

- **Idempotent producer** (`enable.idempotence=true`) — broker dedups retries within a session.
- **Transactional producer** — atomic write across multiple partitions/topics; consumers set `isolation.level=read_committed`.
- Tune `linger.ms` + `batch.size` for throughput, `compression.type=zstd`.

### Consumers

- **Auto-commit** vs **manual commit** (always manual in production).
- Commit *after* processing; if you commit before, a crash loses data.
- **Rebalance listener**: drain in-flight work before partition reassignment.

### Stream-table duality

A stream of changes IS a table; a table IS the latest value per key from a stream. KSQL, Flink SQL, Materialize all expose this:

```sql
-- A stream of subject-status events from Kafka
CREATE STREAM subject_events (
    subject_id  STRING,
    stage       STRING,
    status      STRING,
    event_time  TIMESTAMP
) WITH (KAFKA_TOPIC='dwi.events', VALUE_FORMAT='AVRO');

-- A table = latest status per (subject, stage)
CREATE TABLE subject_latest AS
SELECT subject_id,
       LATEST_BY_OFFSET(stage)  AS last_stage,
       LATEST_BY_OFFSET(status) AS last_status
FROM   subject_events
GROUP BY subject_id;
```

### Event time vs processing time, watermarks, windows

- **Processing time** — when the system saw the event. Easy; wrong under reprocessing.
- **Event time** — when the event actually happened (timestamp in the message). Correct; needs **watermarks**.

A **watermark** says "I believe I've seen all events with event_time ≤ W". After W, late events are dropped (or sent to a side output).

Windowing types:
- **Tumbling**: fixed, non-overlapping (`5-minute windows`).
- **Hopping / sliding**: overlapping (`5-min window every 1 min`).
- **Session**: gap-based (a user session: events with <30 s gap).
- **Global**: one open window forever; combined with custom triggers.

### Exactly-once across systems

Flink achieves it via **distributed snapshots (Chandy-Lamport)** + transactional sinks. Kafka Streams via **transactional producer + state store + offset commit in one tx**. End-to-end exactly-once is **possible only if the sink supports transactions** (Kafka, Iceberg, JDBC w/ idempotency keys).

### CDC patterns

**Debezium** reads MySQL binlog / Postgres WAL / Mongo oplog → publishes change events to Kafka. The events have `before` and `after` payloads + `op` (`c`/`u`/`d`/`r`). Downstream consumers materialise tables incrementally.

The **outbox pattern** keeps app DB consistent with the stream: write app-row + outbox-row in the same tx; Debezium publishes the outbox; the app never writes Kafka directly. Solves dual-write.

### DWI tie-in

A `dwi.events` Kafka topic (start_qsiprep, finish_recon, dk_complete) feeds a live cohort dashboard and an alert (slack on > N failures/hour). The producer is a tiny script invoked at the end of each `subject.sh` stage.

### Next step

Run Kafka in Docker (`bitnami/kafka` works), write a Python producer + consumer (snippet in Appendix A), then plug ksqlDB on top and produce a live "subjects-per-stage" table.

---

## 7. dbt deeply

### Why dbt eats the world

dbt brings **software-engineering discipline** to SQL: version control, modular reuse, dependency graph, tests, documentation. If your team writes >100 lines of SQL a week, dbt pays for itself in two weeks.

### Project layout

```
my_dbt_project/
├── dbt_project.yml
├── profiles.yml                # connection per target (dev/prod)
├── models/
│   ├── staging/                # 1:1 cleaned views over sources
│   │   └── stg_subjects.sql
│   ├── intermediate/           # multi-step joins
│   │   └── int_subject_qc.sql
│   └── marts/                  # final star schema
│       ├── core/
│       │   ├── dim_subject.sql
│       │   └── fact_dk_edge.sql
│       └── analytics/
│           └── cohort_region_summary.sql
├── snapshots/                  # SCD2 capture
│   └── subjects_snapshot.sql
├── seeds/                      # static CSVs loaded as tables
│   └── dk_node_labels.csv
├── macros/                     # reusable Jinja+SQL
│   └── safe_divide.sql
├── tests/                      # singular tests (one query each)
│   └── assert_dk_matrix_84x84.sql
└── analyses/                   # ad-hoc SQL, not part of DAG
```

### Materializations

| Type | What it builds | When |
|---|---|---|
| `view` | DB view (default for staging) | Cheap to rebuild, source updates often |
| `table` | Full table, drop+recreate each run | Small marts, easiest semantics |
| `incremental` | Append/merge new rows since last run | Big facts |
| `ephemeral` | CTE inlined into consumers | Logic reuse without persisting |

### Incremental strategies

```sql
-- models/marts/fact_dk_edge.sql
{{ config(
    materialized='incremental',
    unique_key=['subject_sk','source_node_sk','target_node_sk','release_sk'],
    incremental_strategy='merge',
    on_schema_change='append_new_columns'
) }}

SELECT *
FROM   {{ ref('int_dk_edges_long') }}
{% if is_incremental() %}
WHERE  ingested_at > (SELECT MAX(ingested_at) FROM {{ this }})
{% endif %}
```

Strategies:
- `merge` (Snowflake/BigQuery/Databricks default): upsert by unique_key.
- `delete+insert`: explicit; needed on Postgres without merge.
- `append`: pure append; OK for immutable facts.
- `insert_overwrite`: replace whole partitions.

### Snapshots = SCD2 for free

```sql
{% snapshot subjects_snapshot %}
{{ config(
    target_schema='snapshots',
    unique_key='subject_id',
    strategy='check',
    check_cols=['age','site']
) }}
select * from {{ source('clinical','subjects') }}
{% endsnapshot %}
```

Run nightly; dbt adds `dbt_valid_from`, `dbt_valid_to`, `dbt_scd_id` automatically.

### Tests

Generic:
```yaml
# models/marts/core/schema.yml
version: 2
models:
  - name: fact_dk_edge
    columns:
      - name: subject_sk
        tests: [not_null, relationships: { to: ref('dim_subject'), field: subject_sk }]
      - name: streamline_count
        tests:
          - dbt_utils.expression_is_true:
              expression: ">= 0"
```

Singular:
```sql
-- tests/assert_dk_matrix_84x84.sql
-- failing if any subject doesn't have exactly 84*84 edges
select subject_sk, count(*) AS n
from   {{ ref('fact_dk_edge') }}
group  by subject_sk
having count(*) <> 84 * 84
```

Unit tests (dbt 1.8+): mock inputs + assert output. Real CI for SQL.

### Contracts (dbt 1.5+)

```yaml
models:
  - name: fact_dk_edge
    config:
      contract: { enforced: true }
    columns:
      - name: subject_sk
        data_type: bigint
        constraints: [{ type: not_null }]
```

Builds fail if a model violates the contract → consumers safe.

### Commands you'll type daily

```
dbt deps              # install packages
dbt seed              # load CSVs
dbt run               # run models
dbt test              # run tests
dbt build             # seed + snapshot + run + test, in DAG order
dbt source freshness  # alert on stale sources
dbt docs generate && dbt docs serve   # interactive lineage site
```

### DWI tie-in

A small dbt project around your Iceberg `fact_dk_edge` + `dim_subject` + `dim_node` gives you: tests for matrix completeness, snapshots of subject demographics, incremental rebuilds when a new release lands, and a free lineage site.

### Next step

`pip install dbt-duckdb`, follow the official dbt-DuckDB quickstart with the synthetic data, then port it to your DK CSVs.

---

## 8. Data contracts and schema evolution

### The producer-consumer problem

You change a column. A downstream dashboard breaks at 9 a.m. on Monday. The on-call DE is paged. This is the failure mode contracts prevent.

### Compatibility modes

A schema change is:
- **Backward compatible** if a *consumer with the new schema* can read *data written with the old schema*. (Default in Confluent Schema Registry.)
- **Forward compatible** if a *consumer with the old schema* can read *data written with the new schema*.
- **Full compatible** if both.
- **None** = anything goes.

| Change | Backward | Forward | Full |
|---|---|---|---|
| Add optional field w/ default | ✅ | ✅ | ✅ |
| Add required field | ❌ | ✅ | ❌ |
| Remove optional field | ✅ | ❌ | ❌ |
| Remove required field | ✅ | ❌ | ❌ |
| Rename field | ❌ | ❌ | ❌ |
| Change type | usually ❌ | usually ❌ | ❌ |

The "rename" row is why **aliases** exist in Avro / Protobuf: rename gracefully by carrying the old name as alias for one release.

### Schema registries

- **Confluent Schema Registry** — Avro/JSON/Protobuf for Kafka; enforces compatibility on register; serializers include the schema id in each message header.
- **AWS Glue Schema Registry** — same idea on AWS.
- **Buf Schema Registry** — Protobuf-focused with great CLI for breaking-change detection.

### dbt contracts (analytics-side enforcement)

Already covered in §7; rejects model builds that violate column-level contracts.

### The deprecation workflow

1. **Announce** in a #data-contracts channel + email; include date + impact.
2. **Dual-emit** — producer keeps writing the old field AND the new field for a release window.
3. **Migrate consumers** — open PRs against each consumer; close out by the deadline.
4. **Stop emitting** the old field.
5. **Postmortem** any consumer that missed the bus, and add a runbook entry.

### DWI tie-in

The **BIDS specification** is your data contract. Your pipeline already asserts it (or skips with `--skip-bids-validation`, which is the same as turning off contract enforcement in production). Treating `sub-XXX_qc.json` outputs as a new contract — versioned and validated — is the path to publishable outputs.

### Next step

Pick one output file (`dk_connectome.csv`) and write a JSON Schema for it. Add a `bin/validate_dk_output.py` to your CI that runs on every release.

---

## 9. Security, governance, privacy

### Identity & Access Management

- **Principle of least privilege** — every identity gets the minimum permissions it needs.
- **Users** (humans) **vs roles** (assumable, short-lived) **vs service accounts** (machines).
- **RBAC** (Role-Based) — assign roles to identities; roles bundle permissions. Most common.
- **ABAC** (Attribute-Based) — policies on attributes (`department=neuro`).
- **ReBAC** (Relationship-Based) — graph of "X has role Y on resource Z" (Google Zanzibar; Authzed).

AWS example (least-privilege read-only to one S3 prefix):

```hcl
data "aws_iam_policy_document" "dwi_read" {
  statement {
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::dwi-lake",
      "arn:aws:s3:::dwi-lake/gold/cohort_region_summary/*"
    ]
  }
}
```

### Encryption

- **At rest**: server-side encryption (SSE-S3, SSE-KMS, customer-managed keys, BYOK).
- **In transit**: TLS 1.2+; verify cert chain; pin in high-security contexts.
- **End-to-end**: encrypt before upload; only client holds keys. Rare but real for clinical data.
- **Key rotation**: KMS does this for you with key aliases.

### Secrets

Never put secrets in repos. Use Vault / AWS Secrets Manager / GCP Secret Manager / K8s Secrets. Mount as envs or files at runtime. Rotate quarterly; revoke instantly on compromise.

### PII / PHI handling

- **Classify data**: Public / Internal / Confidential / Restricted (PHI/PII).
- **Detect**: AWS Macie, GCP DLP, Microsoft Purview, open-source Presidio.
- **De-identify**: hashing (SHA-256 with salt), tokenization (format-preserving), masking (`***`), aggregation (k-anonymity, l-diversity), differential privacy.
- **Access logging** on every PHI table; review monthly.

### Regulations a DE has to know in name

- **GDPR** (EU) — right to access, right to be forgotten, data residency, DPIA.
- **HIPAA** (US health) — PHI, BAAs (Business Associate Agreements with every vendor that touches PHI), audit logs (6-year retention).
- **CCPA / CPRA** (California) — similar to GDPR-lite.
- **SOC 2** — controls audit; required by enterprise customers.
- **PCI-DSS** — payment card; almost certainly out of scope for a DE who doesn't touch payments.

### DWI tie-in

Track TBI subjects ⇒ HIPAA. Practical implications:

- Apptainer images & raw BIDS live on encrypted volumes; FS license already mounted read-only (good).
- Subject IDs ("001", "007") are pseudonyms only if no linkage table is also in the cluster.
- DK matrices and FA scalars are derived stats — discuss with IRB whether they're still PHI for your study (depends on sample size + linkage risk).
- Any cloud port (Milestone 5) needs a BAA with the cloud provider before raw data leaves the building.

### Next step

Read Cloud Security Alliance's HIPAA on AWS / GCP whitepapers (~30 pages each). Then draft a one-page security model for your DWI pipeline: data classification, who can read what, how secrets are stored, audit log location.

---

## 10. Infrastructure as Code

### Why

Click-ops drifts. Three engineers click in three orders, you have three different prod environments, and the one that works in dev doesn't in prod. IaC makes infra **diffable, code-reviewable, reproducible**.

### Terraform in 50 lines

```hcl
terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket         = "dwi-tfstate"
    key            = "dwi/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "dwi-tflocks"
  }
}

provider "aws" { region = "us-east-1" }

# Lakehouse bucket
resource "aws_s3_bucket" "lake" {
  bucket = "dwi-lake"
}

resource "aws_s3_bucket_versioning" "lake" {
  bucket = aws_s3_bucket.lake.id
  versioning_configuration { status = "Enabled" }
}

# Read-only role for analysts
resource "aws_iam_role" "analyst_read" {
  name = "dwi-analyst-read"
  assume_role_policy = jsonencode({
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "analyst_read" {
  role       = aws_iam_role.analyst_read.name
  policy_arn = aws_iam_policy.dwi_read.arn
}

resource "aws_iam_policy" "dwi_read" {
  name   = "dwi-lake-read"
  policy = data.aws_iam_policy_document.dwi_read.json
}
```

Commands:

```
terraform init      # download providers, set up backend
terraform plan      # diff actual vs desired infra
terraform apply     # apply the plan
terraform destroy   # tear it all down (be careful)
```

### State

The **state file** is Terraform's truth. Store it in S3 with versioning + DynamoDB locking (or HCP Terraform Cloud). Never commit `terraform.tfstate` to git.

### Modules

Reusable building blocks: `modules/data-lake/`, `modules/eks-cluster/`. Import with `module "lake" { source = "./modules/data-lake" }`. Version remote modules.

### Kubernetes packaging — Helm

A Helm **chart** is a templated bundle of K8s manifests + a `values.yaml` of inputs:

```bash
helm install airflow apache-airflow/airflow \
    --namespace airflow --create-namespace \
    --values prod-values.yaml
```

### GitOps — Argo CD / Flux

The cluster state is declared in git; an in-cluster operator reconciles. A PR to git = a deploy. Drift between git and cluster is alerted and auto-corrected.

### DWI tie-in

Your repo today has `dwi_pipeline/` and `dwi_py/`. Senior-level repo also has a `terraform/` directory that provisions the S3 lake bucket, an EKS or AWS Batch cluster, and IAM roles — so a new contributor can `terraform apply` and have a working environment.

### Next step

`brew install terraform` (or equivalent), then provision a single S3 bucket + an IAM user with read-only access. Resist the urge to click anything in the AWS console for that resource for a week.

---

## 11. FinOps and cost engineering

### The five FinOps levers

1. **Tagging** — every resource has `owner`, `project`, `env`, `cost-center`. No tag = no spend allowed.
2. **Right-sizing** — utilization < 50 % for two weeks ⇒ smaller instance/warehouse.
3. **Commitments** — Reserved Instances / Savings Plans / Committed Use Discounts (1y/3y) save 30–70 %.
4. **Spot / preemptible** — 60–90 % off; reclaimable within minutes. Fits stateless / checkpointable workloads (Spark, batch jobs).
5. **Lifecycle** — S3 → S3-IA after 30 days → Glacier after 180; auto-suspend Snowflake warehouses after 60 s idle.

### Showbacks vs chargebacks

- **Showback**: report each team's spend; no money changes hands.
- **Chargeback**: actually bill teams.

Showback is the place to start — once teams see "we spent $12k on QSIPrep storage last quarter", they self-tune.

### Worked example — cost of a 1000-subject DK rerun

```
Recon (FastSurfer, ~1 CPU-h/subject):     1000 CPU-h
QSIPrep (~4 CPU-h):                       4000 CPU-h
QSIRecon (~3 CPU-h):                      3000 CPU-h
DK connectome (~0.1 CPU-h):                100 CPU-h
                                          --------
                                          8100 CPU-h

On a 4 vCPU spot instance @ $0.04/h (m5.xlarge spot):
    8100 CPU-h / 4 vCPU * $0.04 = $81

Storage: 60 GB / subject * 1000 = 60 TB; S3 Standard ~$1380/mo, S3-IA ~$760/mo
```

Knowing this number lets you say "we can backfill the cohort with the new release for ~$100 in compute and $1500 first-month storage" in a planning meeting — that is what a senior DE sounds like.

### Tools

AWS Cost Explorer, GCP Cost Reports, Azure Cost Management, Snowflake account usage views, Databricks system tables, Vantage / CloudZero / Cloudability for multi-cloud.

### DWI tie-in

Add a `bin/cost_estimate.py` that takes the subject count and prints the projected compute + storage cost. Run it before every cohort backfill.

### Next step

If you're cloud-curious, sign up for AWS free tier, enable Cost Explorer, run ten dollars through it, and look at the cost-by-tag report.

---

## 12. Performance — queues, percentiles, skew

### Little's law (the queueing identity)

```
L = λ × W
average number in system = arrival rate × average time in system
```

If 100 jobs/hour arrive and each takes 30 minutes, the queue averages 50 jobs in flight. You can use Little's law in reverse: measure two of {L, λ, W}, derive the third.

### Latency percentiles

- **p50** (median) = typical user.
- **p95 / p99** = unhappy minority.
- **p99.9 / p99.99** = tail; dominates user experience at scale because users hit *many* requests per session.

Mean is almost always a lie. Track histograms (Prometheus) and report percentiles.

### Hot partition / hot key detection

Symptom: one Spark task / Kafka partition / DB shard runs orders of magnitude slower. Causes: skewed distribution of join keys (e.g. one site has 50 % of subjects), or a bot/abuser flooding one tenant.

Detection:
```sql
SELECT subject_sk, COUNT(*) AS n
FROM   fact_dk_edge
GROUP  BY subject_sk
ORDER  BY n DESC
LIMIT  20;
```

Fixes:
- **Salt** the key for the aggregate stage (append `% N` salt; aggregate with-salt then collapse).
- **Pre-aggregate** in the producer if possible.
- **Repartition** by a different (lower-cardinality, more uniform) column.
- **Spark AQE** skew join — automatic since 3.0.

### Vertical vs horizontal

- **Vertical**: bigger machine. Simple; eventually hits a wall; expensive at the top.
- **Horizontal**: more machines. Linear cost; needs partitioning that doesn't skew; networking starts to matter.

### Locality

Move compute to data when data is huge ("compute-side filter" in Snowflake, "predicate pushdown" in Parquet/Iceberg, "shuffle hash" vs "broadcast hash" in Spark).

### DWI tie-in

Plot a histogram of `recon-all` wall time across your cohort. Identify p99 outliers — they're almost always (a) subjects with thick T1ws and full session counts, (b) subjects that crashed half-way and retried, or (c) a slow node. Each cause has a different remediation.

### Next step

Add p50/p95/p99 calculations to your cohort dashboard. Watch them across releases. Single best signal of pipeline health.

---

## 13. Concurrency, transactions, isolation levels

### ACID

- **Atomicity** — all or none.
- **Consistency** — invariants hold pre and post tx.
- **Isolation** — concurrent txs don't see each other's partial state.
- **Durability** — committed = on stable storage.

### Isolation levels and the anomalies they prevent

| Level | Dirty read | Non-repeatable | Phantom | Write skew |
|---|---|---|---|---|
| Read Uncommitted | ✅ | ✅ | ✅ | ✅ |
| Read Committed | ❌ | ✅ | ✅ | ✅ |
| Repeatable Read | ❌ | ❌ | ✅ | ✅ |
| Snapshot (MVCC) | ❌ | ❌ | ❌ | ✅ |
| Serializable | ❌ | ❌ | ❌ | ❌ |

Postgres' "Repeatable Read" is actually Snapshot Isolation. Snowflake and BigQuery do snapshot-style. Distributed DBs (Spanner) are Serializable.

### MVCC in one minute

Each row has hidden columns `xmin` (creator tx id), `xmax` (deleter). Each tx sees the snapshot of "rows where `xmin ≤ my_tx_id AND (xmax = 0 OR xmax > my_tx_id)`". No reader blocks a writer. Vacuum collects garbage when no tx can see the dead rows anymore.

### Locks

- **Row locks** — `SELECT ... FOR UPDATE` claims rows.
- **Advisory locks** — Postgres `pg_advisory_lock(123)` — a named lock you implement around your own logic.
- **Optimistic vs pessimistic** — check at commit (CAS) vs lock at read.

### Deadlocks

Two txs each holding a lock the other wants. DB detects (timeout) and aborts one (your client gets a serialization-failure error). Mitigation: take locks in a consistent order; keep transactions short.

### Connection pooling

Direct DB connections are expensive. Pool with PgBouncer / RDS Proxy / Pgpool. App keeps a small pool (size ≈ CPU count, not 1000).

### Python concurrency choices

- **CPU-bound**: `multiprocessing` (sidesteps GIL).
- **I/O-bound**: `asyncio` or threads (GIL releases during I/O).
- **Mixed**: process pool of asyncio workers (Celery, Faust).

### Worked example — worker-pool "claim next subject" pattern

```sql
WITH job AS (
    SELECT subject_id
    FROM   pipeline_queue
    WHERE  status = 'pending'
    ORDER  BY priority DESC, created_at ASC
    LIMIT  1
    FOR    UPDATE SKIP LOCKED          -- Postgres-specific; key trick
)
UPDATE pipeline_queue p
SET    status = 'running',
       worker_id = $1,
       claimed_at = now()
FROM   job
WHERE  p.subject_id = job.subject_id
RETURNING p.subject_id;
```

`FOR UPDATE SKIP LOCKED` means N workers grab N distinct jobs concurrently without blocking on each other.

### DWI tie-in

If you stand up a small Postgres to coordinate "which subjects are queued / running / done", this pattern lets you scale workers up and down without coordination logic.

### Next step

Read Kleppmann ch. 7 (Transactions). Stand up a Postgres locally and reproduce a write-skew with two `psql` shells; then fix it with `SERIALIZABLE`.

---

## 14. Data quality deeply

### Six dimensions

| Dimension | Question | Example check |
|---|---|---|
| Accuracy | Does it match reality? | "Manual reconciliation: 100 sampled rows match source" |
| Completeness | Are required fields populated? | "0 nulls in subject_id" |
| Consistency | Same fact agrees across tables? | "fact_dk_edge subject count = dim_subject is_current count" |
| Timeliness | Is it fresh enough? | "max(ingested_at) within 24 h" |
| Uniqueness | Are duplicates absent? | "unique (subject_id, source_node, target_node, release_id)" |
| Validity | Does it satisfy the rules? | "streamline_count >= 0", "site ∈ {A,B,C}" |

### Where checks live

- **Ingest gate** — block bad data from entering the warehouse (strictest; highest false-positive risk).
- **In-flight** — assert mid-transform; quarantine offenders to `*_bad`.
- **Post-load alert** — let it land, alert on breach. Good for dashboards.

### Circuit breaker pattern

Aggregate failures over a window; if > N%, halt downstream stages and page the on-call. Prevents a corrupt source from poisoning every consumer.

### Drift detection

Compare distribution of today's feed vs the historical baseline.
- **PSI** (Population Stability Index) — > 0.25 = significant drift.
- **Kolmogorov-Smirnov test** — distribution-shape change for continuous features.
- **Chi-squared** — for categorical.

Implement as a daily test; alert when threshold breached.

### Tools

- **Great Expectations** — Python; expectations as code; HTML data docs.
- **dbt tests** — SQL-native, lives with the model.
- **Soda** — YAML DSL; sometimes runs alongside dbt.
- **Pandera** — Pydantic-flavored for pandas/Polars.

### Worked example — Great Expectations on DK CSV

```python
import great_expectations as gx

ctx = gx.get_context()
ds  = ctx.data_sources.add_pandas("dwi_csv")
asset = ds.add_csv_asset("dk_connectome", filepath_or_buffer="dk_connectome.csv")
batch = asset.build_batch_request()

suite = ctx.suites.add(gx.ExpectationSuite(name="dk_matrix"))
suite.add_expectation(gx.expectations.ExpectTableRowCountToEqual(value=84 * 84))
suite.add_expectation(gx.expectations.ExpectColumnValuesToBeBetween(
    column="streamline_count", min_value=0, max_value=1e9))
suite.save()

result = ctx.run_validation(batch_request=batch, expectation_suite=suite)
assert result.success, result.results
```

### DWI tie-in

Adopt one of the four tools. The lowest-friction is `dbt-expectations` once you have a dbt project; the second-lowest is Pandera as a guard in `run_dk_connectome()`.

### Next step

Pick one quality dimension this week (start with Completeness — easy wins) and implement three checks for it across your pipeline outputs.

---

## 15. Catalogs, discovery, lineage

### The problem

"Where is the cohort QC table?" "Who owns `fact_dk_edge`?" "If I delete this column, what breaks?" Without a catalog, these are tribal knowledge. With one, they're searches.

### Catalog feature matrix

| Tool | Open-source | Lineage | Discovery search | Ownership | Notes |
|---|---|---|---|---|---|
| **DataHub** | ✅ | ✅ | ✅ | ✅ | LinkedIn → ASF; rich plugin ecosystem |
| **OpenMetadata** | ✅ | ✅ | ✅ | ✅ | Active community; UI is friendly |
| **Amundsen** | ✅ | ✅ | ✅ | ✅ | Lyft origin; mature |
| **Apache Atlas** | ✅ | ✅ | partial | ✅ | Hadoop heritage; clunky UI |
| **Atlan** | ❌ | ✅ | ✅ | ✅ | Modern UX; enterprise pricing |
| **Collibra** | ❌ | ✅ | ✅ | ✅ | Governance-first; heavy |
| **Unity Catalog** | ✅ (recently) | ✅ | ✅ | ✅ | Databricks-native; multi-engine |

### OpenLineage

An open standard for emitting lineage events. Many tools speak it out of the box:

- **dbt** → openlineage-dbt plugin pushes a manifest after each `dbt run`.
- **Airflow** → openlineage-airflow extracts per-operator lineage.
- **Spark** → openlineage-spark listener emits read/write events.
- **Snakemake** → emerging community plugin.

Reference implementation: **Marquez** (database + UI). Run it in Docker, point your tools at it, get a free lineage graph.

### Why this matters at senior level

- **Impact analysis**: "If I rename this column, which 47 dashboards and 12 reports break?"
- **Compliance**: GDPR Article 30 records of processing — automated from lineage.
- **Onboarding**: a new hire types `recon-all` into search and finds tables, dashboards, owners.

### DWI tie-in

Publish `manifest.json` (Milestone 3) to a small OpenLineage emitter inside Snakemake's `onsuccess:` hook → drop into Marquez running on the cluster. You now have a "data atlas" of your own pipeline.

### Next step

`docker compose up` Marquez locally. Run a tiny dbt project against DuckDB with `openlineage-dbt` installed. Inspect the resulting lineage graph in the Marquez UI.

---

## 16. Real-time analytics

### When you need it

When the dashboard's freshness SLO is < 5 minutes, or when a decision (fraud block, alert, recommendation) has to fire within seconds of an event.

### The serving-tier zoo

| Engine | Niche | Latency target | Notes |
|---|---|---|---|
| **ClickHouse** | OLAP at scale, columnar | 100 ms – 1 s | Single-binary; magical fast; SQL |
| **Apache Pinot** | OLAP-on-streams; LinkedIn-grade | 10 ms – 100 ms | Pre-aggregated index; harder ops |
| **Apache Druid** | Time-series OLAP | 100 ms – 1 s | Older but battle-tested |
| **StarRocks / Doris** | MPP analytics; CN-popular | 100 ms – 1 s | Snowflake-like SQL |
| **Materialize** | Incrementally maintained views | < 100 ms | Postgres-compatible; differential dataflow |
| **RisingWave** | Streaming SQL, Postgres-compatible | < 1 s | Open-source alternative to Materialize |
| **ksqlDB** | Kafka-native streaming SQL | seconds | Confluent ecosystem |

### Lambda vs Kappa

- **Lambda**: batch layer (Spark) + speed layer (Flink) + serving layer (Druid). Two code paths; sync them.
- **Kappa**: stream-only; reprocess history by replaying the topic. Simpler operationally; demands a stream-first mindset.

Kappa is the modern default. Stream-table duality makes batch a special case.

### Worked example — live cohort dashboard

```sql
-- In Materialize, subscribed to a Kafka topic of pipeline events
CREATE SOURCE pipeline_events
FROM   KAFKA BROKER 'kafka:9092' TOPIC 'dwi.events'
FORMAT AVRO USING SCHEMA REGISTRY 'http://schema-registry:8081';

CREATE MATERIALIZED VIEW cohort_status_live AS
SELECT subject_id,
       MAX(CASE WHEN stage = 'qsiprep' AND status = 'done' THEN 1 ELSE 0 END) AS qsiprep_done,
       MAX(CASE WHEN stage = 'recon'    AND status = 'done' THEN 1 ELSE 0 END) AS recon_done,
       MAX(CASE WHEN stage = 'qsirecon' AND status = 'done' THEN 1 ELSE 0 END) AS qsirecon_done,
       MAX(CASE WHEN stage = 'dk'       AND status = 'done' THEN 1 ELSE 0 END) AS dk_done
FROM   pipeline_events
GROUP  BY subject_id;
```

Grafana queries that view via Postgres protocol. Numbers tick live as events arrive.

### DWI tie-in

Mostly aspirational for now — your pipeline is batch. But a cluster-wide live dashboard of "which subjects are at which stage" would be Milestone 7 and is a great showcase for interview portfolios.

### Next step

If interested: stand up Materialize + Kafka + Grafana in Docker Compose, send synthetic events, watch the view update.

---

## 17. Ingestion patterns

### Batch

Scheduled extract every N minutes/hours. Tools: Airbyte, Fivetran, Stitch, Singer/Meltano, Hevo, custom Python.

### CDC — Change Data Capture

Read the database's transaction log instead of full-table extracts.

| Source DB | Mechanism | Reader |
|---|---|---|
| MySQL | binlog | Debezium MySQL connector |
| Postgres | logical replication / WAL | Debezium Postgres connector |
| MongoDB | oplog | Debezium MongoDB connector |
| SQL Server | CDC tables | Debezium SQL Server connector |
| Oracle | LogMiner / GoldenGate | Debezium / GoldenGate |

CDC events have `before` (pre-image), `after` (post-image), `op` (`c`reate / `u`pdate / `d`elete / `r`ead snapshot), and `source` metadata. Materialise downstream:

```sql
-- ksqlDB / Materialize / Flink SQL
CREATE TABLE subject_state AS
SELECT subject_id, LATEST_BY_OFFSET(after.demographics) AS demographics
FROM   cdc_subject_stream
WHERE  op IN ('c','u');
```

### Webhooks vs polling

- **Webhooks**: producer pushes on change. Cheap, real-time. Needs you to expose a publicly-reachable endpoint with HMAC verification.
- **Polling**: you call the API every N seconds. Reliable, simple, lossy of fast changes, hits rate limits.

For polling, always paginate (cursor > offset), retry with exponential backoff, and persist the last cursor durably so you can resume.

### Connector platforms

- **Airbyte** (open) — 350+ connectors, ELT-style, dbt integration. Easy to start.
- **Fivetran** (managed) — connector quality is gold-standard; expensive at scale.
- **Singer / Meltano** (open spec) — taps + targets; great for custom sources.

### DWI tie-in

You don't currently ingest from external sources — your data is BIDS on a filesystem. But if you ever pull subject demographics from REDCap or a clinical-trial portal, that's an Airbyte connector waiting to happen.

### Next step

Read the Airbyte tutorial; spin it up locally; pipe a public REST API (GitHub commits, weather) into DuckDB. End-to-end in an evening.

---

## 18. Event-driven architectures

### Event sourcing

Instead of mutable rows, store the **events** that caused state changes:

```
event_id | aggregate_id | type            | payload                     | created_at
---------+-------------+-----------------+-----------------------------+-----------
1        | sub-001     | SubjectEnrolled | { dob:..., site:'A' }       | 2026-01-01
2        | sub-001     | T1wReceived     | { scan_id:..., path:... }   | 2026-01-05
3        | sub-001     | QSIPrepStarted  | { release:'0.23.1' }        | 2026-01-05
4        | sub-001     | QSIPrepDone     | { duration_s: 13200 }       | 2026-01-05
```

State (a "subject" row) is **derived** by replaying events. Pros: full audit, time travel, replay-as-test. Cons: complex queries; need snapshots for performance.

### CQRS — Command Query Responsibility Segregation

Write model (commands → events) is separate from read model (materialised views from events). Each can be optimised independently. Often paired with event sourcing.

### Outbox pattern (the dual-write fix)

```sql
BEGIN;
INSERT INTO subjects(id, demographics) VALUES (...);
INSERT INTO outbox(aggregate_id, type, payload, created_at) VALUES (...);
COMMIT;
```

A separate process (or Debezium reading `outbox`) publishes to Kafka. The DB write and the event publication are atomic because they're in the same transaction. No "wrote to DB but Kafka was down" ghosts.

### Saga pattern

A distributed transaction modeled as a sequence of local transactions with **compensating** events when a later step fails.

```
Enrol → MR scan → BIDS conversion → QSIPrep → fail
                                         ↓ (compensate in reverse)
                                    delete BIDS, mark MR scan unprocessed,
                                    keep enrollment (compensation is partial by design)
```

Two flavours: **choreographed** (each service listens & decides) vs **orchestrated** (central coordinator).

### Dead-letter queues

Messages that fail processing after N retries go to a DLQ topic. A human (or a smarter process) inspects and decides: re-publish, fix and replay, or drop.

### DWI tie-in

Right now your pipeline state lives in the *filesystem* — Snakemake checks files. An event-sourced version would publish `QSIPrepDone(subject=001, release=0.23.1)` to Kafka; downstream tooling (alerts, dashboards, ML feature pipelines) consume independently.

### Next step

Read *Designing Event-Driven Systems* (Ben Stopford, free PDF from Confluent). Then implement the outbox pattern around your `pipeline_queue` table.

---

## 19. MLOps overlap — feature stores, vector stores

### Why DEs care about MLOps

ML teams produce models that consume your features. If your features are wrong, the model is wrong, and the on-call page goes to *both* teams.

### Feature store (Feast architecture)

A feature store gives you:

- **Offline store** (historical, for training): warehouse / lake.
- **Online store** (low-latency, for serving): Redis / DynamoDB / Cassandra.
- **Feature registry**: metadata, owners, freshness, lineage.
- **Materialisation**: keeps online ↔ offline in sync.
- **Point-in-time correctness**: training uses the feature values as they were on day T (no leakage).

```python
# feature_store/features.py
from feast import Entity, FeatureView, Field, FileSource
from feast.types import Float32, Int64

subject = Entity(name="subject_id", join_keys=["subject_id"])

source = FileSource(
    name="dk_features",
    path="s3://lake/gold/subject_features.parquet",
    timestamp_field="ingested_at",
)

subject_features = FeatureView(
    name="subject_dk",
    entities=[subject],
    schema=[
        Field(name="mean_streamline_count", dtype=Float32),
        Field(name="num_active_edges",     dtype=Int64),
        Field(name="cohort_qc_score",      dtype=Float32),
    ],
    source=source,
)
```

```python
# serving
from feast import FeatureStore
fs = FeatureStore(repo_path="feature_store/")
features = fs.get_online_features(
    features=["subject_dk:mean_streamline_count", "subject_dk:cohort_qc_score"],
    entity_rows=[{"subject_id": "sub-001"}],
).to_dict()
```

### Training-serving skew

The number-one MLOps incident class: the feature value at training time is computed differently from at serving time. Feature stores prevent it by making both call the same transformation code (or the same offline materialisation).

### Vector stores (RAG-era critical)

| Store | Use case |
|---|---|
| **pgvector** | Bolt onto Postgres; easy; up to mid-millions of vectors |
| **Pinecone** | Managed; high-scale; cost: $$ |
| **Weaviate** | Open + managed; built-in hybrid search |
| **Milvus / Zilliz** | Open + managed; high-recall ANN |
| **Qdrant** | Open + Rust; fast; mature filtering |
| **FAISS / Annoy / ScaNN** | Embedded libraries, not services |

A RAG pipeline:

```
[docs] → chunker → embedder (e.g. text-embedding-3) → vector store
                                                          ↑
[query] → embedder ──────────────────────────────────────┘ → top-k → LLM with context
```

### DWI tie-in

Connectome features → ML classifier of TBI severity. A feature store materialises subject-level DK summaries so the model trains on a snapshot and serves online from Redis with point-in-time consistency.

### Next step

`pip install feast`, run the official feast quickstart (5 minutes), then point it at one of your DK Parquet outputs.

---

## 20. Backup, disaster recovery, RTO/RPO

### Define the terms upfront

- **RPO** (Recovery Point Objective): how much data are you willing to lose? "RPO = 1 h" means up to one hour of data may be lost.
- **RTO** (Recovery Time Objective): how long can you be down? "RTO = 4 h" means service must be restored within four hours.

The tighter both numbers, the more expensive the architecture. Set them per-system based on business impact, not engineer comfort.

### Backup types

- **Full**: complete copy. Expensive, slow to take, fastest to restore.
- **Incremental**: changes since last full. Fast to take, slow to restore (need full + chain).
- **Differential**: changes since last full. Middle ground.
- **Continuous / log-shipping**: stream WAL/binlog to a replica. RPO ≈ seconds.

### Object-storage versioning and immutable backups

S3 / GCS / Azure Blob versioning keeps every overwrite. Combined with **Object Lock** (S3) or **Bucket Lock** (GCS) you get **WORM** (write-once-read-many) backups that no one — including the root account — can delete during the lock period. The single best ransomware defence.

### Cross-region replication

- AWS S3 **CRR** / GCS multi-region storage classes / Azure GRS — async replication to a second region.
- For warehouses: Snowflake **database replication**, BigQuery dataset copy, Redshift snapshots cross-region.

### Restore drills

If you've never tested the restore, you don't have a backup. Quarterly drill: pick a table, restore to a sandbox, validate row counts and a few aggregates. Document the steps in a runbook.

### DWI tie-in

Apply object-storage versioning + lifecycle (Glacier-Deep-Archive after 1 year) to the bucket holding your DK matrices. Drill a restore once a quarter — pick a random subject, restore from versioned object, re-compute its connectome, diff against current.

### Next step

For a personal project: enable S3 versioning + Object Lock on a small bucket. For work systems: write your team's RTO/RPO matrix (one row per system) and stress-test the assumptions against finance / legal stakeholders.

---

## 21. Incident management and postmortems

### Severity levels (typical)

- **SEV1** — production data is wrong / outage; revenue or compliance impact; page within minutes.
- **SEV2** — major degradation; partial outage; page within an hour.
- **SEV3** — minor; queue for next business day.
- **SEV4** — cosmetic; backlog ticket.

### Roles during an incident

- **Incident Commander (IC)** — runs the call; never doing the typing.
- **Scribe** — keeps the timeline doc updated.
- **Comms lead** — talks to stakeholders / status page.
- **Subject Matter Experts** — actually fix.

Single most important rule: the IC should *not* be the person debugging.

### The blameless postmortem template

```
1. Summary (one sentence)
2. Impact (who/what/when/duration/financial estimate)
3. Timeline (UTC, every event)
4. Contributing factors (no single root cause; usually 3-5)
5. What went well
6. What didn't go well
7. Action items (owner, due date, link to ticket)
8. Appendix (graphs, logs)
```

Blameless = describe systems, not people. "The runbook for X was out of date" not "Alice didn't update the runbook".

### Root cause analysis techniques

- **Five whys** — ask why five times to walk past symptoms to systemic cause.
- **Fishbone (Ishikawa)** — categories of cause (people, process, tools, environment); brainstorm into each.
- **Fault tree** — top-down boolean breakdown of failure paths.

### On-call hygiene

- Rotation in PagerDuty / Opsgenie / VictorOps with handoffs.
- Pages have runbook links.
- "Toil budget": > X pages/week per oncall = stop feature work, fix the noise.
- Postmortem every SEV1/SEV2; review monthly in a cross-team meeting.

### DWI tie-in

You're already in this — your `/var/spool/slurmd` permission incident and the missing-FS-dir incident in 44504 are textbook SEV2s. Write them up using the template; they'll be the seed of your team's runbook library.

### Next step

Pick the most recent issue you debugged. Write a 1-pager postmortem using the template above. You'll catch contributing factors you didn't notice in the moment.

---

## 22. Versioning everything — code, data, models

### What needs to be versioned

| Thing | Tool | Notes |
|---|---|---|
| Code | git | Sole source of truth |
| Container images | Registry tags (semver) | Never `:latest` in prod |
| Schemas | Schema Registry | Compatibility-checked |
| Pipeline DAGs | git + workflow tool's runbook | Pin tool version in CI |
| Data | DVC / LakeFS / Iceberg snapshots / Delta time-travel | Per dataset |
| Models | MLflow / Vertex AI Model Registry | Per training run |
| Documentation | git (markdown) | Reviewed PRs |
| Infrastructure | Terraform state in versioned backend | One source of truth |

### Data versioning options

- **DVC** — git-based metadata pointing at object-storage blobs. Good for ML datasets; clumsy for tables.
- **LakeFS** — git-style branches over object storage; expose to engines as a virtual prefix.
- **Iceberg / Delta snapshots** — every commit is a snapshot; query `FOR TIMESTAMP AS OF`.
- **Nessie** — git-style for Iceberg catalogs.

### Semver for data products

A dataset has a contract; bumping the major version means breaking change; downstream consumers know what's coming.

```
dwi.fact_dk_edge:v1   →   v1.1  (added optional column)
dwi.fact_dk_edge:v1.1 →   v2    (renamed column; old v1.x kept for 30 days)
```

### DWI tie-in

Tag every pipeline release in git, push the corresponding container image as `dwi-pipeline:1.2.3`, and write the (release, git_sha, container_hash) triple into your `dim_release` dimension. That's full lineage from a row to the code that produced it.

### Next step

Pick one of {DVC, LakeFS, Iceberg snapshots} this quarter and adopt it for the dataset that changes most.

---

## 23. Networking essentials

You will not need to debug TCP for a living, but a DE who doesn't know what a VPC is gets surprised by S3 egress bills.

### The cloud networking stack (AWS-flavoured)

- **VPC** — isolated virtual network in a region.
- **Subnet** — slice of the VPC in one AZ; public (route to IGW) vs private (no direct internet).
- **Route table** — what subnet routes where.
- **Security group** — stateful firewall on the instance.
- **NACL** — stateless firewall at the subnet boundary.
- **NAT Gateway** — private subnet → internet, hides backend IPs.
- **VPC Endpoint / PrivateLink** — private path to AWS services without traversing the public internet (and without egress cost).

### The cost trap

Data **egress** (out of the cloud, or across regions) costs $0.05–$0.12/GB. Replicating 60 TB of DK matrices once across regions = $3000–$7200. Architect to minimise egress: compute in the same region as data, use PrivateLink for S3, batch transfers.

### Latency budgets

Round-trip times matter:
- Same AZ: < 1 ms.
- Same region cross-AZ: 1–2 ms.
- Cross-region same continent: 30–80 ms.
- Cross-continent: 100–300 ms.

A pipeline that joins a US-East lake against an EU-West warehouse is paying 100 ms per network round-trip — kills throughput if not chunked / parallel.

### DNS pitfalls

DNS TTL of 24 h means your failover is 24 h late. Set TTLs accordingly. Use Route53 alias records for AWS services to avoid TTL bloat.

### DWI tie-in

When (if) you go cloud, the cluster, the lake, and any downstream warehouse should live in the same region. Use VPC endpoints for S3 so traffic stays inside AWS. Tag every resource so egress costs can be attributed.

### Next step

Skim AWS' "Networking Fundamentals" digital course (free). For your DWI pipeline, list every cross-region data movement you can imagine — and design around it.

---

## 24. Org-level data engineering

This is the gap between senior and staff/principal.

### Data Mesh

A federated architecture: domain teams (clinical, imaging, ops) own their own data products end-to-end. Central platform team provides the substrate (catalog, pipelines-as-a-service, governance). Trade-off: less duplication of effort vs harder coordination.

Pre-requisites:
1. Domain alignment in the org (Conway's law).
2. Self-serve platform mature enough that domain teams can actually own pipelines.
3. Federated governance (one catalog, common contracts).

A small team rarely needs a data mesh; the pattern shines in 200+ engineer orgs.

### RFC culture

Before any non-trivial change, an engineer writes a 1–3 page RFC:

```
Title: <short>
Authors: <names>
Status: Draft | Reviewing | Accepted | Rejected
Last updated: <date>

## Context
What problem? Why now? What is the business cost?

## Goals / Non-goals

## Proposed solution
With diagrams.

## Alternatives considered
A, B, C — pros, cons, why not.

## Trade-offs
What we give up.

## Rollout plan
Migration, deprecation, comms.

## Open questions
```

Two reviewers + an accepted status before code lands. Sounds heavy; saves quarters of refactor.

### Design docs (DD)

Smaller than an RFC; one feature or pipeline. Same template. Lives in `docs/dd/` in the repo. Lapsed habit kills team velocity.

### Mentoring as a force multiplier

A senior who mentors two mid-levels into senior is worth three seniors. Mechanism: pair-coding 1 hour/week, code-review-as-teaching (explain *why*), one-on-ones with a learning agenda, deliberate scope-stretch.

### OKRs / KRs

Quarterly: 3–5 Objectives, each with 3–5 Key Results that are measurable. KRs are not tasks; they are *outcomes*. "Reduce p99 ingest latency from 45 m to 10 m" is a KR; "Migrate ingest to Kafka" is a task.

### DWI tie-in

Mostly aspirational at solo-PI scale, but the *habits* compound. Write a 2-page RFC before the next major change (e.g. "Adopt Iceberg for DK matrices"). Put it under `dwi_pipeline/docs/rfcs/0001-adopt-iceberg.md`. Hand it to a colleague for review.

### Next step

Read Stripe's open-sourced RFC template and Google's "How to write a design doc" doc. Adopt one of them, write the RFC for your *next* substantive change in advance.

---

## 25. Interview preparation

### The system design template (use literally every time)

1. **Clarify requirements** — functional and non-functional. Ask numbers (QPS, latency target, data volumes, retention).
2. **Estimate scale** — back-of-envelope; rows, bytes, requests/sec.
3. **API / interface** — what the consumer calls; what's read vs written.
4. **High-level architecture** — boxes and arrows; data flow.
5. **Data model** — schemas; partition keys; indexes.
6. **Deep-dive on the bottleneck** — usually the storage layer or the join. Talk through alternatives.
7. **Failure / scale considerations** — what breaks at 10× scale; how you'd handle.
8. **Trade-offs and what you'd improve** — show maturity by naming the limits.

### Five DE system-design walkthroughs

#### 25.1 Spotify-style listening-events pipeline

Scale: 600 M monthly users, ~50 events/user/day = 30 B events/day = 350 K events/sec average, ~3.5 M/sec peak.

Walkthrough:
- Mobile clients batch events, post to an ingest API behind a CDN.
- API writes to **Kafka** (`listening.events.v1`, 1000 partitions for headroom). Producer is idempotent + transactional.
- **Flink** consumer 1: dedupe by event_id over a 1-hour window, write to **Iceberg** raw table (s3, partitioned by hour).
- Flink consumer 2: real-time aggregates (top tracks per region) to **ClickHouse** for the live dashboard.
- Batch dbt over Iceberg for daily artist royalties (millions $; needs the warehouse, not the stream).
- Backup: cross-region S3 replication; Kafka MirrorMaker to DR region.
- Governance: schema registry enforces backward compatibility on `listening.events.v1`.

#### 25.2 E-commerce CDC pipeline

Scale: 10 M products, ~1 K price changes/sec peak (sales).

- Debezium reads MySQL binlog → Kafka topic per source table.
- Iceberg sink (Kafka Connect Iceberg) materialises append-only history.
- dbt build over Iceberg → `dim_product` (SCD2 from CDC), `fact_price_change` (immutable).
- Reverse-ETL (Hightouch) syncs `dim_product` back to Algolia for product search.
- Pipeline DLQ on schema mismatch — quarantine + alert; don't break consumers.

#### 25.3 Fraud-detection feature store

Scale: 50 M transactions/day, online inference < 100 ms.

- Kafka topic per data source (txn, user, device, merchant).
- Flink jobs compute features (rolling sums by user, velocity, geo dispersion) keyed by user_id.
- Sink to **Feast online store** (Redis cluster).
- Offline materialisation: same logic in Spark over Iceberg history; nightly.
- Model trained on offline; served at < 50 ms reading from Feast online; same feature transformations guaranteed by Feast.
- Drift detection on input distributions, daily.

#### 25.4 IoT temperature-sensor dashboards

Scale: 100 K sensors, 1 reading/sec.

- MQTT broker (Mosquitto / EMQX) → Kafka.
- Time-series store: **InfluxDB** or **TimescaleDB** (PG extension) for high-cardinality, long-retention.
- Pre-aggregate to 1-min / 1-hour / 1-day via continuous queries (downsampling).
- Grafana dashboards on top.
- Cold tier: Parquet to S3 after 90 days; Athena for archeology.

#### 25.5 Multi-tenant SaaS warehouse

Scale: 10 K tenants, each owns up to 100 M rows.

- Snowflake account per region; tenant rows tagged with `tenant_id`.
- **Row-Access Policies** keyed off the session's tenant claim.
- Per-tenant materialised views for hot dashboards; warehouse auto-suspend.
- Per-tenant resource monitor with spend cap; alert when 80 %.
- Egress prevention: no per-tenant export API; data exits via a controlled, audited reverse-ETL path.

### SQL whiteboard patterns

Memorise these five — they cover most of what you'll be asked:

1. **Top-N per group** (`ROW_NUMBER()` + WHERE rk <= N).
2. **Gaps & islands** (`row_number - dense_rank` trick; or `LAG` for gaps).
3. **Sessionisation** (`SUM(CASE WHEN new_session THEN 1 ELSE 0 END) OVER (PARTITION BY user ORDER BY ts)`).
4. **Pivot / unpivot** (`CASE WHEN` + `GROUP BY`, or `PIVOT` syntax if supported).
5. **Anti-join** (`WHERE NOT EXISTS` vs `LEFT JOIN ... WHERE other IS NULL` — know the engine's plan for each).

### Behavioural (STAR)

Have three crisp 90-second stories ready:

- **Production incident you led** (Situation, Task, Action, Result) — focus on action and result; downplay heroics, upplay system-level fix.
- **Difficult cross-team negotiation** — show you can de-escalate.
- **Scope cut / disagreement with leadership** — show you can challenge without being a martyr.

### Take-home patterns

If you receive a take-home, the rubric is almost always:
1. Working code with tests.
2. README with assumptions, choices, trade-offs.
3. Diagrams.
4. A "what I'd do next with more time" section.

Most candidates skip #2 and #4. Doing both reliably puts you in the top quartile.

### DWI tie-in

The DWI pipeline itself is a perfect portfolio piece. In an interview, walk through it with the template above: requirements (TBI cohort, ~6-12 h per subject acceptable, on-cluster), data model (BIDS → Bronze, QSIPrep → Silver, DK → Gold), bottleneck (recon-all wall time → FastSurfer fallback), trade-offs (FastSurfer's slightly different surfaces vs 10× speedup), next steps (Iceberg + cohort dbt).

### Next step

Pick one of the five walkthroughs above. Spend 45 minutes drawing it on a whiteboard, talking aloud. Record yourself. Watch back. It will be uncomfortable; do it three times anyway.

---

## Appendix A — Per-tool 5-minute pipelines

Minimal hello-world for each major tool you should be able to stand up cold. Each is intentionally tiny — just enough to feel the shape.

### A.1 Snakemake

Already covered in `dwi_pipeline/dwi_py/`. Minimal:

```python
# Snakefile
SUBJECTS = ["001", "007"]

rule all:
    input: expand("out/{sid}.txt", sid=SUBJECTS)

rule greet:
    output: "out/{sid}.txt"
    shell: "echo 'hello {wildcards.sid}' > {output}"
```

Run: `snakemake -j 2`.

### A.2 Airflow

```python
# dags/dwi_pipeline.py
from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator

with DAG(
    "dwi_pipeline",
    start_date=datetime(2026, 1, 1),
    schedule="@daily",
    catchup=False,
) as dag:
    qsiprep   = BashOperator(task_id="qsiprep",   bash_command="bash run_qsiprep.sh {{ ds }}")
    recon     = BashOperator(task_id="recon",     bash_command="bash run_recon.sh {{ ds }}")
    qsirecon  = BashOperator(task_id="qsirecon",  bash_command="bash run_qsirecon.sh {{ ds }}")
    dk        = BashOperator(task_id="dk",        bash_command="bash run_dk.sh {{ ds }}")

    qsiprep >> [recon, qsirecon]  # parallel branches
    [recon, qsirecon] >> dk
```

### A.3 Dagster (asset-based)

```python
# dwi_assets.py
from dagster import asset

@asset
def qsiprep(context, bids_root: str) -> str:
    context.log.info(f"QSIPrep on {bids_root}")
    return "qsiprep_out/"

@asset(deps=["qsiprep"])
def recon() -> str:
    return "freesurfer_out/"

@asset(deps=["qsiprep", "recon"])
def qsirecon() -> str:
    return "qsirecon_out/"

@asset(deps=["qsirecon", "recon"])
def dk_connectome() -> str:
    return "dk_connectomes/"
```

Run with `dagster dev`.

### A.4 dbt (3 models + tests)

```yaml
# dbt_project.yml
name: dwi_dbt
version: '1.0.0'
profile: dwi_duck
models:
  dwi_dbt:
    +materialized: view
```

```sql
-- models/stg_dk_edges.sql
SELECT subject_id, source_node, target_node, streamline_count
FROM   {{ source('raw','dk_long') }}

-- models/dim_subject.sql
SELECT DISTINCT subject_id
FROM   {{ ref('stg_dk_edges') }}

-- models/fact_dk_edge.sql
{{ config(materialized='table') }}
SELECT e.*, s.subject_id AS subject_sk
FROM   {{ ref('stg_dk_edges') }} e
JOIN   {{ ref('dim_subject') }} s USING (subject_id)
```

```yaml
# models/schema.yml
models:
  - name: fact_dk_edge
    tests:
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns: [subject_sk, source_node, target_node]
```

Run: `dbt build`.

### A.5 Spark (PySpark)

```python
from pyspark.sql import SparkSession, functions as F

spark = SparkSession.builder.appName("dwi_cohort").getOrCreate()
df = spark.read.csv("dk_connectomes/sub-*/dk_connectome.csv", header=False)
df = df.toDF("source", "target", "weight")
agg = df.groupBy("source").agg(F.avg("weight").alias("mean_w"))
agg.write.mode("overwrite").parquet("gold/cohort_source.parquet")
```

### A.6 Kafka (Python producer + consumer)

```python
# producer.py
from kafka import KafkaProducer
import json
p = KafkaProducer(bootstrap_servers="localhost:9092",
                  value_serializer=lambda v: json.dumps(v).encode())
p.send("dwi.events",
       {"subject_id": "sub-001", "stage": "qsiprep", "status": "done"})
p.flush()

# consumer.py
from kafka import KafkaConsumer
import json
c = KafkaConsumer("dwi.events",
                  bootstrap_servers="localhost:9092",
                  value_deserializer=lambda v: json.loads(v.decode()),
                  enable_auto_commit=False,
                  group_id="dwi_dashboard")
for msg in c:
    print(msg.offset, msg.value)
    c.commit()
```

### A.7 Iceberg (PyIceberg)

See §2 worked example. Three lines to read, three lines to append.

### A.8 DuckDB (in-process analytics)

```python
import duckdb
con = duckdb.connect()
con.sql("""
    SELECT source, AVG(weight) AS mean_w
    FROM   read_csv_auto('dk_connectomes/*/dk_connectome.csv', filename=true)
    GROUP  BY source
""").show()
```

### A.9 Terraform (S3 bucket + IAM role)

See §10 worked example. `terraform init && terraform apply` and you have provisioned infrastructure in 30 seconds.

---

## Appendix B — DE career rubric

Use this for self-assessment and 1:1 conversations. Each row is one dimension; each cell is what "good at this level" looks like.

| Dimension | Junior (0–2y) | Mid (2–5y) | Senior (5–8y) | Staff (8–12y) | Principal (12+) |
|---|---|---|---|---|---|
| Scope | one rule / SQL model | one pipeline end-to-end | one platform / domain | cross-domain platforms | cross-org / industry |
| SQL | reads + writes joins | window fns + perf | reads `EXPLAIN`; writes high-throughput | optimises engines; teaches | influences engine roadmaps |
| Modeling | follows star schema | designs star schema | trade-offs across star / vault / OBT | sets modelling standards | publishes patterns |
| Orchestration | runs a DAG | writes a DAG | designs DAG conventions | designs orchestration layer | invents new patterns |
| Quality | runs tests | writes tests | designs test culture | defines org-wide quality SLOs | sets industry expectations |
| Reliability | follows runbooks | writes runbooks | runs on-call rotation | defines reliability program | influences external practices |
| Cost | aware of cost | tracks own cost | drives savings | builds FinOps capability | influences vendor pricing/contracts |
| Mentorship | learns | helps onboard | actively mentors 1–2 | mentors seniors | scales mentorship via writing/talks |
| Communication | clear PR descriptions | docs + design docs | RFCs accepted across teams | strategy memos | thought leadership |
| Influence | own commits | feature acceptance | team direction | tech-strategy quarterly | org strategy annually |

You're currently early-mid, with the scope of one full pipeline and the discipline to write design docs. Snakemake port + Iceberg + dbt + one cross-team RFC clears the senior bar on most rubrics.

---

*End of Part II. Suggested next step: pick one section that scored lowest on your self-assessment and ship the "next step" for it this month.*
