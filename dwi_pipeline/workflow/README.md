# dwi_pipeline as plugins + a workflow (Snakemake)

`subject.sh` is one big imperative script: six stages, wired together by
function calls and if/else branches you have to read line-by-line to
understand the DAG. This directory reimplements the same six stages as
**plugins** (Snakemake rules — one per container, declaring its own
inputs/outputs/params) joined into **one workflow** (the `Snakefile`, which
computes the dependency graph from those declarations instead of a human
tracing bash).

Status: **production-ready via `submit.sh` / `array.sh` (default `PIPELINE_ENGINE=snakemake`)**
for single-subject and cohort array runs. The legacy `subject.sh` path remains
available (`PIPELINE_ENGINE=bash`) for anything not yet ported (legacy
dual-container connectome only).

### Machine setup (required once per host)

Committed `config.yaml` uses `/path/to/...` placeholders (safe for a public
repo). Before the first real run, either:

```bash
cp workflow/config/config.local.yaml.example workflow/config/config.local.yaml
# edit real container + FreeSurfer license paths
```

or export the same paths as env vars (`CONTAINER_QSIPREP`, …, `FS_LICENSE`) —
`run_subject.sh` / `preflight.sh` honour both. `config.local.yaml` is gitignored.

### Single subject

```bash
cd dwi_pipeline
RESULTS_ROOT=/path/to/output BIDS_DIR=/path/to/bids \
  bash workflow/run_subject.sh all SUBJECT001 --fastsurfer --dwi-select config/dwi_select_….json
# or via Slurm (one array task):
SUBJECT_LIST_USE_EXISTING=1 SUBJECT_LIST_FILE=subjects_one.txt \
  bash submit.sh --fastsurfer --dwi-select config/dwi_select_….json
```

### Cohort (Slurm array)

```bash
# subjects.txt: one ID per line, no sub- prefix, on NFS (not /tmp)
RESULTS_ROOT=/path/to/output BIDS_DIR=/path/to/bids \
ARRAY_CONCURRENCY=5 \
bash submit.sh --fastsurfer --dwi-select config/dwi_select_….json
```

One array task = one subject; plugins run sequentially inside the task.
Snakemake skips finished markers/outputs on resume (e.g. after a mid-pipeline
failure, re-submit the same `RESULTS_ROOT` — completed QSIPrep/recon are not redone).

## Layout

```
workflow/
  Snakefile              # top-level: includes rules/*.smk, defines `all` + per-plugin targets
  run_subject.sh          # subject.sh-equivalent CLI (mode, subject, flags)
  config/config.yaml       # defaults (mirrors subject.sh's env-var defaults)
  lib/
    common.sh              # bash helpers shared with subject.sh's own copies (session/mask/atlas logic)
    resolve_session.py      # dwi-select filter -> target session, used at DAG-build time
  rules/
    common.smk              # config loading, path constants, Python helpers
    qsiprep.smk              # Step 1  (plugin: qsiprep.sif)
    inpaint.smk               # Step 1.5 (plugin: lit_0.6.0.sif) -- only in the DAG for subjects with a lesion mask
    recon.smk                  # Step 2  (plugin: freesurfer_7.4.1.sif or fastsurfer_latest.sif)
    qsirecon.smk                # Step 3  (plugin: qsirecon.sif)
    connectome.smk                # Step 4  (plugin: dkt_connectome.sif)
    disconnectome.smk             # Step 4.5 (auto when lesion mask + DKT connectome)
    nodestrength.smk               # Step 5  (plugin: nodestrength_0.1.0.sif)
```

Each `rules/*.smk` is a self-contained plugin: it declares config knobs, an
`output:` pattern (the real artifact — `aparc+aseg.mgz`, `dkt_connectome.csv`,
`sub-X_strength.csv`, ...), and a `shell:` block that runs exactly one
`apptainer` invocation. The `Snakefile` never touches containers directly —
it only wires plugin outputs to plugin inputs, same contract as the
NeuroInsight model this was modeled after.

## Running it

### Slurm array (recommended)

`submit.sh` now defaults to the Snakemake engine. Example for a TrackTBI
subject with lesion inpainting:

```bash
cd dwi_pipeline
RESULTS_ROOT=/path/to/output \
BIDS_DIR=/path/to/TrackTBI \
SUBJECT_LIST_USE_EXISTING=1 \
SUBJECT_LIST_FILE=<(echo SUBJECT001) \
bash submit.sh --syn \
  --dwi-select config/dwi_select_tracktbi_b1300_ses-2WK.json \
  --fast-fs
```

`submit.sh` auto-requests `SBATCH_GRES=gpu:l40s.24g:1` when Step 1.5 inpaint
is enabled. Override with `SBATCH_GRES=` or a different slice if needed.

Use `PIPELINE_ENGINE=bash ./submit.sh ...` to run the legacy `subject.sh`
path instead.

Before re-running subjects that were already processed by `subject.sh`, backfill
Snakemake markers so Steps 1 and 3 are not redone:

```bash
RESULTS_ROOT=/path/to/output bash workflow/backfill_markers.sh
```

Preflight (containers, snakemake, apptainer, config) runs automatically from
`submit.sh`. Run manually:

```bash
bash workflow/preflight.sh --mode all --subject SUBJECT001
```

### Single subject (interactive or inside one array task)

```bash
cd dwi_pipeline
bash workflow/run_subject.sh all 014                    # full pipeline
bash workflow/run_subject.sh all 014 --fastsurfer
bash workflow/run_subject.sh all 014 --fast-fs           # FastSurfer + --fsaparc
bash workflow/run_subject.sh all 014 --no-recon
bash workflow/run_subject.sh all 014 --no-connectome     # (Step 5 with it)
bash workflow/run_subject.sh all 014 --no-inpaint
bash workflow/run_subject.sh all 014 --no-node-strength
bash workflow/run_subject.sh qsiprep 014                 # one plugin at a time...
bash workflow/run_subject.sh inpaint 014                 #   (no-op if no lesion mask, like subject.sh)
bash workflow/run_subject.sh recon 014 --fastsurfer
bash workflow/run_subject.sh qsirecon 014
bash workflow/run_subject.sh connectome 014
bash workflow/run_subject.sh disconnectome 014   # Step 4.5 only (lesion subjects)
bash workflow/run_subject.sh nodestrength 014
bash workflow/run_subject.sh all 014 --dry-run            # show the plan, run nothing (-n)
```

Env vars `RESULTS_ROOT`, `BIDS_DIR`, `NTHREADS`, `RECON_SESSION` work exactly
like they do for `subject.sh`.

Or drive Snakemake directly (what the wrapper does under the hood) — useful
for `--forcerun`, `-j`, `--dag`, or anything else Snakemake exposes that the
wrapper doesn't surface:

```bash
snakemake -s workflow/Snakefile --directory . \
  --configfile workflow/config/config.yaml \
  --config subject=014 \
  --cores 8 -- all              # or: target_recon, target_connectome, ...
```

Running "one plugin of your choice" is just targeting that plugin's `target_*`
rule instead of `all` (see "Why `target_*` rules" below) — no separate
mechanism needed, which was the point of moving to a real DAG.

## Config: subject.sh env var → config.yaml key

`workflow/config/config.yaml` has the same defaults `subject.sh` has built
in. Override via `run_subject.sh`'s flags/env-vars (mirrors `subject.sh`
exactly) or a custom `--configfile`/`--config`.

| subject.sh env var | config.yaml key |
|---|---|
| `RESULTS_ROOT`, `BIDS_DIR` | `results_root`, `bids_dir` |
| `RECON_OUT`, `FS_SUBJECTS_DIR`, `NODESTRENGTH_OUT` | `recon_out`, `fs_subjects_dir`, `nodestrength_out` |
| `QSIPREP_USE_SYN_SDC`, `QSIPREP_FMAP_RETRY`, `QSIPREP_BIDS_FILTER` | `qsiprep.use_syn_sdc`, `qsiprep.fmap_retry`, `qsiprep.bids_filter` |
| `RUN_INPAINT`, `INPAINT_REQUIRE_MASK`, `INPAINT_DILATE`, ... | `inpaint.enabled`, `inpaint.require_mask`, `inpaint.dilate`, ... |
| `RUN_RECON`, `RECON_TOOL`, `RECON_FSAPARC`, `RECON_FASTSURFER_DEVICE`, `RECON_SESSION` | `recon.enabled`, `recon.tool`, `recon.fsaparc`, `recon.fastsurfer_device`, `recon.session` |
| `QSIRECON_SPEC`, `QSIRECON_ATLASES` | `qsirecon.spec`, `qsirecon.atlases` |
| `RUN_CONNECTOME`, `CONNECTOME_PARCELLATION`, `CONNECTOME_DETERMINISTIC`, ... | `connectome.enabled`, `connectome.parcellation`, `connectome.deterministic`, ... |
| `RUN_NODESTRENGTH`, `NODESTRENGTH_STRENGTH_ONLY`, `NODESTRENGTH_NO_REPORT` | `nodestrength.enabled`, `nodestrength.strength_only`, `nodestrength.no_report` |
| `DWI_SHELL_B`, `DWI_SELECT_JSON`, `QSIPREP_NO_DWI_FILTER` | `dwi_select.shell_b`, `dwi_select.json`, `dwi_select.enabled` |

## Why `target_*` rules exist

Snakemake refuses to target a bare rule name if its output contains
wildcards ("Target rules may not contain wildcards"), and every real plugin
rule here is wildcarded on `{subject}` (and `inpaint`/`connectome` also on
`{session}`/`{parc}`). So each plugin gets a thin, wildcard-free phony
wrapper — `target_qsiprep`, `target_recon`, ... — that just points at that
one subject's concrete output path (read from `config["subject"]`, exactly
like `rule all` already does). `run_subject.sh`'s mode dispatch targets these.

## Relationship to `subject.sh`

Both engines are kept in sync deliberately, not by accident:

- `workflow/lib/common.sh` holds the bash helpers extracted verbatim from
  `subject.sh` (`find_lesion_mask`, `_resolve_target_session`'s Python
  counterpart, `_fs_tree_is_dkt`, `_count_empty_nodes`, ...). Every plugin
  rule `source`s it. If you fix a bug in one of these functions, fix it in
  `subject.sh`'s copy too (or better: this file is the natural next step for
  `subject.sh` itself to start sourcing, once this engine is trusted).
- `run_subject.sh` takes the identical `(mode, subject, flags)` CLI as
  `subject.sh`, and reads the same env vars (`submit.sh` exports them).
  `array.sh` selects the engine via `PIPELINE_ENGINE=snakemake|bash`
  (default: `snakemake`).

**Not yet ported** (use `PIPELINE_ENGINE=bash` / `subject.sh` for these):
- The legacy dual-container connectome path (`CONNECTOME_LEGACY_DUAL_CONTAINER=1`).

## SDC (Step 1 / QSIPrep) — four modes

Both engines apply the same SDC decision, in this precedence order (first
match wins):

| Mode | Trigger (any of) | QSIPrep args added | When to use |
|------|------------------|--------------------|-------------|
| **`fmap-retry`** | `--fmap-retry` · `QSIPREP_FMAP_RETRY=1` · `qsiprep.fmap_retry: true` | `--ignore fieldmaps --use-syn-sdc error` | BIDS fmaps exist but are known to be broken; force SyN. |
| **measured fmap** | dwi-select filter includes an `fmap` block | (none — QSIPrep uses the fmap it finds) | Default for subjects with a valid `fmap/` dir + `IntendedFor` → target DWI (all Siemens-with-fmap sessions). |
| **`syn`** | `--syn` / `--use-syn-sdc` · `QSIPREP_USE_SYN_SDC=1` · `qsiprep.use_syn_sdc: true` | `--use-syn-sdc error` | No measured fmap on disk — best available fall-back. Uses ANTs SyN to register b0 → T1w with anatomical priors. |
| **`no-sdc`** | `--no-sdc` · `QSIPREP_NO_SDC=1` · `qsiprep.no_sdc: true` | (none — SDC skipped) | Explicitly skip SDC (reproduces previous CIDUR GE runs, where no fmap was acquired and `--syn` was never passed). Grep-able as `"explicit no_sdc -> NO SDC"` in the QSIPrep log. |

If none of the four fire, QSIPrep exits with a `_pipeline_fail` message
listing all three overrides — the pipeline **never silently runs without
SDC**; you have to say so.

**Why `--use-syn-sdc error` and not `warn`?** QSIPrep's `--use-syn-sdc`
takes an optional argument that controls what happens when SyN SDC cannot
be estimated for a subject: `error` (strict — fail loudly) or `warn`
(permissive — print a warning and proceed *without any SDC*). The name is
misleading: `warn` is not a diagnostic mode, it is a *silent-skip-on-failure*
switch. This pipeline uses `error` on both engines to match the rest of
its fail-fast design. If SyN fails on a subject, you find out immediately
instead of shipping an SDC-less subject that appears to have completed
normally. If you genuinely want that subject to proceed without SDC, add
`--no-sdc` explicitly.

**Cohort split example — CIDUR**:

```bash
# Group 1: Siemens-with-fmap → default (measured SDC)
while read s; do
  bash dwi_pipeline/submit.sh --subject "$s" \
       --dwi-select dwi_pipeline/config/dwi_select_cidur_64dirax.json
done < dwi_pipeline/subject_list_cidur_fmap.txt

# Group 2: GE + Siemens-no-fmap → --no-sdc (reproduces previous behavior)
while read s; do
  bash dwi_pipeline/submit.sh --subject "$s" \
       --dwi-select dwi_pipeline/config/dwi_select_cidur_64dirax.json \
       --no-sdc
done < dwi_pipeline/subject_list_cidur_ge.txt
```

Ready-made lists sit at `dwi_pipeline/subject_list_cidur_{fmap,ge}.txt`.
Both groups run through the default Snakemake engine — no
`PIPELINE_ENGINE=bash` needed.

**Behaviour changes, by design, not oversight:**
- *Recon skip-if-exists is now the default*, not opt-in. `subject.sh` fails
  loudly if `aparc+aseg.mgz` exists unless you pass `RECON_SKIP_IF_EXISTS=1`;
  Snakemake's whole model *is* "skip if the output is already there", so
  that's just what happens now. Force a rerun with
  `snakemake --forcerun recon` or by deleting the subject's FreeSurfer dir.
- QSIPrep/QSIRecon completion is now tracked via a marker file
  (`RESULTS_ROOT/.snakemake_markers/sub-X/{qsiprep,qsirecon}.done`), since
  their real output filenames carry BIDS entities (`acq-`, `dir-`, ...) that
  aren't knowable before the container runs. **This means a subject fully
  processed by `subject.sh` in the past has no marker yet** — the first
  Snakemake run for them will redo Steps 1 and 3 (hours) even though the
  real derivatives are already on disk. Backfill the markers instead:
  ```bash
  RESULTS_ROOT=/path/to/output bash workflow/backfill_markers.sh [sub-ids...]
  ```

## Testing performed (Aug 2026)

- `snakemake ... -n` dry-runs against real subjects (`sub-001`, `sub-007`,
  already fully processed by `subject.sh`) confirmed: correct DAG for
  `target_connectome` and `all` (qsiprep → qsirecon → connectome →
  nodestrength, recon correctly skipped since `aparc+aseg.mgz` already
  existed); `--no-node-strength` correctly dropped Step 5 from `all`'s DAG.
- `run_subject.sh inpaint 001` (no lesion mask for that subject) printed the
  expected no-op message and exited without invoking Snakemake at all, same
  as `subject.sh`'s `run_inpaint()`.
- Real execution: `snakemake --forcerun nodestrength -- target_nodestrength`
  against an existing connectome ran the actual
  `nodestrength_0.1.0.sif` container end-to-end and regenerated
  `<subject>_strength.csv` and `report.pdf` with fresh timestamps (same
  known cosmetic VTK/enigmatoolbox subcortical-render warning as the
  `subject.sh` path — see `pipeline_science.md` §13.5 — everything else
  clean).
- Real execution, real Slurm job, real lesion mask: `sbatch` +
  `run_subject.sh inpaint SUBJECT001 --recon-session 2WK` (`BIDS_DIR` pointed
  at a BIDS tree with an actual `*_T1w_label-lesion_roi.nii.gz` for this
  subject; note `--recon-session` / `RECON_SESSION` takes the bare label,
  e.g. `2WK`, not `ses-2WK`) ran the full Step 1.5 chain for real on a GPU
  node: `prepare_lesion_mask.py` → `lit-inpainting` (neuroLIT, `cuda`) →
  `check_inpainting.py`. Result: `inpainting_qc.json` reports `"ok": true`
  (`outside_lesion_correlation=0.996`, `correlation_drop_vs_control=0.0027`,
  `geometry_matches_original=true`) and `inpainting.json` was written with
  full provenance. This is the first time the mask-present branch of the
  Step 1.5 DAG (as opposed to the no-mask no-op branch, tested earlier) and
  a real `apptainer --nv` GPU container have run through the new engine, and
  the first time the new engine ran under `sbatch` rather than interactively.
  One gotcha found and worth keeping in mind operationally, not a code bug:
  the default `batch_size: 8` OOM'd on a `gpu:l40s.6g` MIG slice (~6 GB);
  it needs a `gpu:l40s.12g` or `gpu:l40s.24g` slice (or a lower
  `inpaint.batch_size`) — same trade-off `subject.sh`'s docs already call
  out for `INPAINT_BATCH_SIZE`. Default `inpaint.batch_size` is now **4**.
- Step 2 (recon) shell body matches `subject.sh`; wiring verified via dry-run.
  Full FastSurfer recon through Snakemake validated on live Slurm subjects
  (Aug 2026).
- **QSIRecon HSVS fix (Aug 2026):** `qsirecon.smk` built `--fs-subjects-dir`
  into `recon_xtra` but never passed it to `apptainer` (unlike `subject.sh`).
  That left `subject_freesurfer_path=None` and crashed HSVS workflow build.
  Fixed: pass `"${recon_xtra[@]}"` and require `FS_SUBJECTS_DIR/sub-<id>`.
