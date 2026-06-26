# dwi_py — Snakemake port of the DWI pipeline

This is a 1:1 functional port of `dwi_pipeline/{submit,array,subject}.sh`
into Snakemake. It runs the same four stages, in the same containers, with
the same SDC logic — but as a declarative DAG instead of a shell script that
walks a list of subjects.

The original bash pipeline still lives at `../subject.sh` and continues to
work. **This folder writes to a separate `results_root` (`dwi_test_smk/`) by
default**, so you can develop the Snakemake version while the bash version
runs.

---

## Pipeline (per subject)

```
BIDS sub-XXX/
   ├── dwi/  ── rule qsiprep ─────► qsiprep_single_run_output/sub-XXX/
   │                                       │
   │                                       ▼
   └── anat/ ── rule recon  ─────► freesurfer/sub-XXX/mri/aparc+aseg.mgz
                                          │
                                          ▼
                          rule qsirecon ─► qsirecon_single_run_output/.../*.tck
                                          │
                                          ▼
                          rule dk_connectome ─► dk_connectomes/sub-XXX/dk_connectome.csv
```

Toggles in `config/config.yaml`:

| flag                | default | effect                                                  |
|---------------------|---------|---------------------------------------------------------|
| `run_recon`         | `true`  | gate recon-all / FastSurfer + HSVS in QSIRecon          |
| `run_qsirecon`      | `true`  | run QSIRecon                                            |
| `run_dk_connectome` | `true`  | build DK connectome (requires recon)                    |
| `recon.tool`        | `freesurfer` | `freesurfer` (recon-all) or `fastsurfer`           |
| `qsiprep.use_syn_sdc` | `false` | opt-in SyN SDC when no fmap                           |
| `qsiprep.fmap_retry`  | `false` | `--ignore fieldmaps --use-syn-sdc warn`               |
| `dk.resample_to_dwi`  | `true`  | three-hop warp: mri_label2vol → antsRegistration → antsApplyTransforms (×2) |

---

## Install

Snakemake 8+ and the Slurm executor plugin, into any Python ≥ 3.11
environment:

```bash
pip install 'snakemake>=8' snakemake-executor-plugin-slurm
# or, if you prefer conda/mamba:
# mamba create -n dwi_py -c bioconda -c conda-forge \
#     'snakemake>=8' snakemake-executor-plugin-slurm
```

Verify:

```bash
snakemake --version          # >= 8
python -c "import snakemake_executor_plugin_slurm; print('ok')"
```

Apptainer must be on PATH (we shell out to `apptainer run/exec` inside each
rule rather than using Snakemake's `container:` directive — it gives us the
precise bind-mount layout the BIDS App containers expect).

---

## Configure

Edit `config/config.yaml`:

```yaml
bids_dir:       /…/CIDUR_BIDS/data_bids
results_root:   /…/CIDUR_BIDS/dwi_test_smk        # change me to keep runs apart

containers:
  qsiprep:    /…/others/containers/qsiprep.sif
  qsirecon:   /…/others/containers/qsirecon.sif
  fastsurfer: /…/others/containers/fastsurfer_latest.sif
  # Dedicated full FreeSurfer 7.4.1; pull once via
  #   sbatch ../containers/pull_freesurfer_sif.sbatch
  # Do NOT point this at fastsurfer_latest.sif — that ships a trimmed FreeSurfer
  # that crashes recon-all at the skull-strip step (missing skull-strip atlas).
  freesurfer: /…/others/containers/freesurfer_7.4.1.sif
fs_license:        /…/data_mining/freesurfer/license.txt
templateflow_home: /…/TrackTBI-Sub/templateflow

subjects:      [ "001", "007" ]
# or fill config/subjects.tsv (one ID per line). TSV wins if present.
```

Regenerate the subject list from BIDS:

```bash
make subjects                                                       # uses BIDS_DIR from config
python workflow/scripts/list_subjects.py /path/to/BIDS --require-dwi --require-t1w > config/subjects.tsv
```

---

## Run

### Local (one node, several jobs in parallel)

```bash
make dry                          # snakemake -n -r (no execution, prints DAG)
make run                          # JOBS=8 by default
make run JOBS=2 EXTRA="--forcerun recon"
```

### Slurm cluster

You have three options, in increasing order of "fire and forget":

**(a) Foreground (login node, useful for short stages or debugging).** Stays
attached; if you close the terminal, the orchestrator dies.

```bash
make slurm                            # short for: snakemake --profile profiles/slurm
```

**(b) Detached on the login node** via `tmux` or `nohup`. Good for medium
runs; survives ssh disconnects but dies if the login node reboots.

```bash
tmux new -s dwi_smk
make slurm
# Ctrl-b d  to detach;  tmux attach -t dwi_smk  to resume
```

**(c) As an independent Slurm job (recommended).** The orchestrator runs
inside `sbatch` itself on a tiny 4 GB / 1 CPU node, and fans out child jobs
for every rule instance. Survives ssh disconnects, login node reboots, etc.

```bash
sbatch submit_snakemake.sh                            # default config
sbatch submit_snakemake.sh --config recon='{"tool":"fastsurfer"}'
sbatch submit_snakemake.sh -- --forcerun recon        # extra snakemake flags
squeue -u $USER                                       # 1 driver + N child jobs
tail -f logs/snakemake_driver.<jobid>.out             # driver log
```

In all three modes Snakemake submits **one `sbatch` per rule instance** via
the `slurm` executor plugin (8 jobs for 2 subjects × 4 stages, in your test
config). Threads / mem / runtime / partition come from `config/config.yaml`
(`threads:`, `resources:`) and `profiles/slurm/config.yaml`. The profile
already passes `--exclude=smdodwork05` to every child job.

### Just one stage

```bash
make qsiprep                      # rule qsiprep_all
make recon
make qsirecon
make dk
```

### Just one subject (any stage)

```bash
snakemake --configfile config/config.yaml -j 4 \
    dk_connectomes/sub-014/dk_connectome.csv
```

### Force re-runs

```bash
snakemake -j 4 --forcerun recon                  # rebuild Recon and everything downstream
snakemake -j 4 --forceall                        # rebuild everything
```

---

## Outputs (under `results_root`)

```
qsiprep_single_run_output/        # QSIPrep derivatives
freesurfer/sub-XXX/               # recon-all / FastSurfer subjects dir
qsirecon_single_run_output/       # QSIRecon outputs incl. *.tck tractogram
dk_connectomes/sub-XXX/
    dk_connectome.csv             # square symmetric matrix (Desikan-Killiany)
    dk_assignments.csv            # streamline → (node_i, node_j) map
    dk_nodes.mif                  # MRtrix node label image
    aparc+aseg_in_dwi.nii.gz      # resampled FS parcellation on DWI grid
    aparc+aseg.nii.gz             # FS parcellation in conformed space
    dk_nodes.mrinfo.txt           # space diagnostic (header/transform)
    tracks.tckinfo.txt            # tractogram header
logs/<rule>.sub-XXX.log           # per-task stdout+stderr
.flags/<stage>.sub-XXX.done       # sentinel files for dir-tree stages
intermediate_results_*/           # nipype workdirs (auto-cleaned per stage)
```

---

## Why a port?

* **DAG**: stages depend on real files, so a missing input never silently
  produces a broken downstream output.
* **Idempotency for free**: Snakemake won't redo a job whose output already
  exists and is newer than its inputs. The bash version had to check this
  manually inside each `run_*` function.
* **Per-rule resources**: `threads` and `mem_mb`/`runtime`/`slurm_partition`
  are declared on the rule, and the Slurm executor translates them to
  `sbatch` flags. No more guessing the right `--cpus-per-task`.
* **Selective re-runs**: `--forcerun recon`, or just request one file, and
  only the necessary subset of the DAG runs.
* **Reports**: `snakemake --report report.html` produces a per-rule
  timing + stats HTML.

What we **kept** identical to the bash version:

* the same containers, with the same `apptainer run/exec --cleanenv
  --containall` invocations and bind-mount layout;
* the same SDC decision tree (fmap auto-detected per subject; `--use-syn-sdc`
  opt-in);
* the same Recon tool branching (recon-all by default, FastSurfer via
  `config['recon']['tool']`);
* the same DK space-alignment fix (resample `aparc+aseg.mgz` to the tractography
  grid via `mri_label2vol`, empirical affine BIDS T1w → `desc-preproc_T1w`,
  then `antsApplyTransforms` onto `dwiref`, with `mrinfo`/`tckinfo` diagnostics).

---

## Mapping bash → Snakemake

| bash                                  | Snakemake                                   |
|---------------------------------------|---------------------------------------------|
| `submit.sh` (build subject list, env) | `config/config.yaml` + `config/subjects.tsv`|
| `array.sh` (Slurm array)              | `profiles/slurm/config.yaml`                |
| `subject.sh run_qsiprep`              | `workflow/rules/qsiprep.smk`                |
| `subject.sh run_recon`                | `workflow/rules/recon.smk`                  |
| `subject.sh run_qsirecon`             | `workflow/rules/qsirecon.smk`               |
| `subject.sh run_dk_connectome`        | `workflow/rules/dk_connectome.smk`          |
| `has_fmap()`, paths, sentinels        | `workflow/rules/common.smk`                 |

---

## Troubleshooting

| symptom                                                       | likely fix                                                       |
|---------------------------------------------------------------|------------------------------------------------------------------|
| `WorkflowError: No subjects found`                            | fill `config/subjects.tsv` or `config.subjects`                  |
| `MissingInputException` on recon's aparc+aseg                 | set `run_recon: true` (or point `freesurfer/sub-XXX/` at an existing dir) |
| QSIRecon HSVS aborts with `mount source ... doesn't exist`    | recon must have produced `freesurfer/sub-XXX/`; check that stage |
| DK warning `dwiref/preproc T1w/BIDS T1w not found; falling back to FS conformed` | QSIPrep or BIDS missing `*space-T1w_dwiref.nii.gz`, `desc-preproc_T1w`, and/or session T1w |
| `recon-all not found in CONTAINER_FREESURFER`                 | point `containers.freesurfer` at the dedicated `freesurfer_7.4.1.sif`; pull it with `sbatch ../containers/pull_freesurfer_sif.sbatch` |
| `cannot find /opt/freesurfer/average/RB_all_withskull_2020_01_02.gca` (recon-all dies ~30 min in) | `containers.freesurfer` is pointing at the trimmed FreeSurfer inside `fastsurfer_latest.sif`; switch it to `freesurfer_7.4.1.sif` |
| Job lands on `smdodwork05` and dies                           | already excluded by the profile; check `slurm_extra` is being honoured |
| Need to clean Snakemake metadata only                         | `make clean` (`rm -rf .snakemake`)                               |
