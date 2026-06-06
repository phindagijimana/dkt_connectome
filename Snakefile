# =============================================================================
# dk_connectome — Snakemake entry point
# =============================================================================
# 4-stage workflow per subject:
#     qsiprep -> recon -> qsirecon -> dk_connectome
#
# Toggle stages from config.yaml:
#     run_recon         (default true)   gates recon + HSVS
#     run_qsirecon      (default true)
#     run_dk_connectome (default true; only honoured when run_recon=true)
#
# Run locally:                snakemake -j 4
# Run on Slurm:               snakemake --profile profiles/slurm
# Dry-run + DAG inspection:   snakemake -n -r ; snakemake --dag | dot -Tsvg > dag.svg
#
# Architecture
# ------------
# Each stage is a "plugin" — a directory under plugins/<name>/ with two files:
#     plugin.yaml   machine-readable manifest (name, version, requires, options)
#     rules.smk     Snakemake rules that produce this stage's outputs
#
# plugins/loader.smk discovers manifests, honours per-stage toggles, validates
# dependencies (lenient on container paths during parse — see DK_STRICT_VALIDATION),
# and exposes plugin_rule_files() that this Snakefile then `include:`s in order.
# =============================================================================

from snakemake.utils import min_version

min_version("8.0")

configfile: "config/config.yaml"


# Helpers, paths, SUBJECTS list, wildcard constraints. The `_common` plugin is
# loaded first because every other plugin's rules.smk reads its symbols
# (BIDS_DIR, RESULTS_ROOT, SUBJECTS, qsiprep_flag, recon_target, ...).
include: "plugins/_common/common.smk"

# Plugin discovery + manifest validation. Populates ENABLED_PLUGINS based on
# `run_recon` / `run_qsirecon` / `run_dk_connectome` config toggles, and
# exposes plugin_rule_files() for the include loop below.
include: "plugins/loader.smk"


# -----------------------------------------------------------------------------
# Top-level aggregator. Declared BEFORE the per-plugin rule files so it is the
# first rule Snakemake sees and therefore the default target when `snakemake`
# is run without an explicit target.
# -----------------------------------------------------------------------------
rule all:
    input:
        all_targets(),


# Optional convenience targets (`snakemake qsiprep_all`, etc.). These reference
# helpers from _common/common.smk and survive whether or not the corresponding
# plugin is enabled (they just expand to an empty input list in that case).
rule qsiprep_all:
    input: [qsiprep_flag(s) for s in SUBJECTS]

rule recon_all:
    input: [recon_target(s) for s in SUBJECTS]

rule qsirecon_all:
    input: [qsirecon_flag(s) for s in SUBJECTS]

rule dk_all:
    input: [dk_target(s) for s in SUBJECTS]


# Dynamically include every enabled plugin's rules.smk, in load order. Snakemake
# permits `include:` inside a top-level for loop; this is the documented pattern
# for config-driven workflow composition.
for _rules_file in plugin_rule_files():
    include: _rules_file


onstart:
    print("dk_connectome pipeline")
    print(f"  results_root : {RESULTS_ROOT}")
    print(f"  bids_dir     : {BIDS_DIR}")
    print(f"  subjects     : {len(SUBJECTS)} ({', '.join(SUBJECTS[:5])}"
          f"{'...' if len(SUBJECTS) > 5 else ''})")
    print_plugin_banner()
    print(f"  recon tool   : {config['recon']['tool']}")
    print(f"  qsirecon spec: {QSIRECON_SPEC}"
          f"{'  (multi-shell)' if cfg_bool_from(config.get('qsirecon', {}).get('multi_shell')) else '  (single-shell)'}")


onsuccess:
    print("Pipeline complete.")
    print(f"  See {RESULTS_ROOT} for outputs.")

    # FAIR provenance: emit an RO-Crate 1.1 manifest describing this run
    # (workflow source, container digests, config snapshot, per-rule
    # benchmarks, per-subject outputs). Best-effort — a failure here must
    # not mask a successful pipeline run, so we wrap in try/except.
    try:
        import subprocess, sys as _sys
        from pathlib import Path as _Path
        _script = _Path(workflow.basedir) / "workflow" / "scripts" / "write_ro_crate.py"
        if _script.is_file():
            subprocess.run(
                [_sys.executable, str(_script),
                 "--results-root", str(RESULTS_ROOT),
                 "--repo-root",    workflow.basedir,
                 "--config",       str(_Path(workflow.basedir) / "config" / "config.yaml"),
                 "--subjects",     ",".join(SUBJECTS)],
                check=False,
            )
        else:
            print(f"  (skipped RO-Crate export: {_script} missing)")
    except Exception as _e:
        print(f"  WARN: RO-Crate export failed: {_e}")


onerror:
    print("Pipeline failed; see per-rule logs under:")
    print(f"  {LOGS_DIR}")
