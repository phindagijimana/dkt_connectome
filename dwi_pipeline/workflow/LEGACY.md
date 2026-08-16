# Legacy execution paths (maintainer / local only)

**Not documented on [Read the Docs](https://dkt-connectome.readthedocs.io/)** — kept for sites still on older invocations. New cohort work should use Snakemake via `./run`, `workflow/run_subject.sh`, or `submit.sh` (default).

---

## Bash engine (`PIPELINE_ENGINE=bash`)

`submit.sh` and `array.sh` default to **`PIPELINE_ENGINE=snakemake`**. The bash engine runs the imperative [`subject.sh`](../subject.sh) script instead of Snakemake:

```bash
PIPELINE_ENGINE=bash bash submit.sh --participant-label 001
```

Use only when a feature below is not yet available under Snakemake.

---

## Dual-container Step 4 (`CONNECTOME_LEGACY_DUAL_CONTAINER=1`)

The current Step 4 rule uses a single **`dkt_connectome.sif`** image (`CONTAINER_CONNECTOME`).

The legacy path runs connectome tooling split across **FreeSurfer + QSIRecon** containers at runtime (pre-unified image). It is **Snakemake-only via bash fallback**:

```bash
CONNECTOME_LEGACY_DUAL_CONTAINER=1 PIPELINE_ENGINE=bash \
  bash subject.sh connectome 001
```

Snakemake [`rules/connectome.smk`](rules/connectome.smk) documents that only the single-container path is ported; dual-container remains `subject.sh`-only.

See [`containers/connectome/README.md`](../containers/connectome/README.md) for the unified image build.

---

## Marker backfill (bash → Snakemake migration)

If subjects were processed with `subject.sh` before switching to Snakemake, backfill completion markers so QSIPrep/QSIRecon are not rerun:

```bash
RESULTS_ROOT=/path/to/output bash workflow/backfill_markers.sh
```

---

## Deprecation plan

1. Confirm no active jobs use `PIPELINE_ENGINE=bash` or `CONNECTOME_LEGACY_DUAL_CONTAINER=1`.
2. Remove bash engine branch from `submit.sh` / `array.sh`.
3. Remove or gate `subject.sh` connectome dual-container block.
4. Drop `PIPELINE_ENGINE` from public config docs (already omitted from RTD).
