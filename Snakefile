# =============================================================================
# DWI pipeline — Snakemake port of dwi_pipeline/{submit,array,subject}.sh
# =============================================================================
# 4-stage workflow per subject:
#     qsiprep -> recon -> qsirecon -> dk_connectome
#
# Toggle stages from config.yaml:
#     run_recon         (default true)   gates recon + HSVS
#     run_qsirecon      (default true)
#     run_dk_connectome (default true; only honoured when run_recon=true)
#
# Run locally:                snakemake -j 4 --use-singularity=false
# Run on Slurm:               snakemake --profile profiles/slurm
# Dry-run + DAG inspection:   snakemake -n -r ; snakemake --dag | dot -Tsvg > dag.svg
# =============================================================================

from snakemake.utils import min_version

min_version("8.0")

configfile: "config/config.yaml"


# Helpers, paths, SUBJECTS list, wildcard constraints.
include: "plugins/_common/common.smk"


# -----------------------------------------------------------------------------
# Top-level aggregator. Declared BEFORE the rule files so it is the first rule
# Snakemake sees and therefore the default target when `snakemake` is run
# without an explicit target.
# -----------------------------------------------------------------------------
rule all:
    input:
        all_targets(),


# Optional convenience targets (`snakemake qsiprep_all`, etc.).
rule qsiprep_all:
    input: [qsiprep_flag(s) for s in SUBJECTS]

rule recon_all:
    input: [recon_target(s) for s in SUBJECTS]

rule qsirecon_all:
    input: [qsirecon_flag(s) for s in SUBJECTS]

rule dk_all:
    input: [dk_target(s) for s in SUBJECTS]


include: "plugins/qsiprep/rules.smk"
include: "plugins/recon/rules.smk"
include: "plugins/qsirecon/rules.smk"
include: "plugins/dk_connectome/rules.smk"


onstart:
    print(f"DWI Snakemake pipeline")
    print(f"  results_root : {RESULTS_ROOT}")
    print(f"  bids_dir     : {BIDS_DIR}")
    print(f"  subjects     : {len(SUBJECTS)} ({', '.join(SUBJECTS[:5])}"
          f"{'...' if len(SUBJECTS) > 5 else ''})")
    print(f"  stages       : qsiprep"
          f"{' recon' if RUN_RECON else ''}"
          f"{' qsirecon' if RUN_QSIRECON else ''}"
          f"{' dk' if RUN_DK_CONNECTOME and RUN_RECON else ''}")
    print(f"  recon tool   : {config['recon']['tool']}")
    print(f"  recon spec   : {config['qsirecon']['spec']}")


onsuccess:
    print("Pipeline complete.")
    print(f"  See {RESULTS_ROOT} for outputs.")


onerror:
    print("Pipeline failed; see per-rule logs under:")
    print(f"  {LOGS_DIR}")
