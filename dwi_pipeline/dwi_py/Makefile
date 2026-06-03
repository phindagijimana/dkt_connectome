# =============================================================================
# Convenience targets for the Snakemake DWI pipeline. Run from dwi_py/.
# =============================================================================
SHELL := /bin/bash

CONFIG     ?= config/config.yaml
JOBS       ?= 8
PROFILE    ?= profiles/slurm
SUBJECT    ?=
EXTRA      ?=

.PHONY: help install subjects lint dry dag report run slurm clean qsiprep recon qsirecon dk

help:
	@echo "Targets:"
	@echo "  make install      Install snakemake + slurm executor plugin into the current env"
	@echo "  make subjects     Regenerate config/subjects.tsv from BIDS"
	@echo "  make lint         Snakemake static lint"
	@echo "  make dry          Dry-run, show jobs (uses CONFIG=$(CONFIG))"
	@echo "  make dag          Render DAG to dag.svg (requires graphviz)"
	@echo "  make report       Produce report.html after a run"
	@echo "  make run          Local run, JOBS=$(JOBS)"
	@echo "  make slurm        Submit via Slurm profile ($(PROFILE))"
	@echo "  make qsiprep      Only run QSIPrep stage (all subjects)"
	@echo "  make recon        Only run Recon stage (all subjects)"
	@echo "  make qsirecon     Only run QSIRecon stage"
	@echo "  make dk           Only run DK connectome stage"
	@echo "  make clean        Remove .snakemake/ metadata (keeps outputs)"
	@echo ""
	@echo "Vars: CONFIG=$(CONFIG) JOBS=$(JOBS) PROFILE=$(PROFILE) SUBJECT=$(SUBJECT)"

install:
	pip install --upgrade snakemake snakemake-executor-plugin-slurm

subjects:
	@python workflow/scripts/list_subjects.py \
	    $$(yq -r .bids_dir $(CONFIG) 2>/dev/null || grep '^bids_dir:' $(CONFIG) | awk '{print $$2}') \
	    --require-dwi --require-t1w > config/subjects.tsv
	@echo "Wrote $$(grep -cv '^#' config/subjects.tsv) subjects to config/subjects.tsv"

lint:
	snakemake --configfile $(CONFIG) --lint

dry:
	snakemake --configfile $(CONFIG) -n -r --printshellcmds $(EXTRA)

dag:
	snakemake --configfile $(CONFIG) --dag $(EXTRA) | dot -Tsvg > dag.svg
	@echo "Wrote dag.svg"

report:
	snakemake --configfile $(CONFIG) --report report.html

run:
	snakemake --configfile $(CONFIG) -j $(JOBS) --rerun-incomplete --printshellcmds $(EXTRA)

slurm:
	snakemake --configfile $(CONFIG) --profile $(PROFILE) $(EXTRA)

qsiprep:
	snakemake --configfile $(CONFIG) -j $(JOBS) qsiprep_all $(EXTRA)

recon:
	snakemake --configfile $(CONFIG) -j $(JOBS) recon_all $(EXTRA)

qsirecon:
	snakemake --configfile $(CONFIG) -j $(JOBS) qsirecon_all $(EXTRA)

dk:
	snakemake --configfile $(CONFIG) -j $(JOBS) dk_all $(EXTRA)

clean:
	rm -rf .snakemake
