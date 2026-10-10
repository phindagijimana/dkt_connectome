# IDEAS II sample data (OpenNeuro)

BIDS data from the **IDEAS II** diffusion MRI release. The download script fetches either a two-subject sample (for pipeline demos and smoke tests) or the full dataset.

**Source:** [OpenNeuro ds007401](https://openneuro.org/datasets/ds007401) ([DOI 10.18112/openneuro.ds007401.v1.0.0](https://doi.org/10.18112/openneuro.ds007401.v1.0.0))

Also listed on the [CNNP Lab IDEAS page](https://sites.google.com/view/cnnp-lab//ideas-data).

## Subjects included

| BIDS ID | Sessions used | Contents |
|---------|---------------|----------|
| `sub-1` | `ses-1` | T1w, FLAIR, DWI (+ sidecars) |
| `sub-6` | `ses-1` | T1w, FLAIR, DWI (+ sidecars) |

See [SUBJECTS.md](SUBJECTS.md) for download provenance.

## Download / refresh

The script is a single self-contained file. It needs only `bash` and `curl`, which are standard on Linux, macOS and Git Bash on Windows. It works without the rest of this repository.

The data come from OpenNeuro's public storage and are read anonymously, so **no AWS account or credentials are needed**.

### Standalone use (without cloning the repository)

```bash
curl -fsSLO https://raw.githubusercontent.com/phindagijimana/dkt_connectome/main/dwi_pipeline/scripts/download_ideas_sample.sh
bash download_ideas_sample.sh            # menu; saves to ./ideas_bids/
bash download_ideas_sample.sh -o ~/ideas # or choose the folder
bash download_ideas_sample.sh -h         # help
```

### 1. Optional: install the AWS command-line tool (faster)

If `aws` is installed the script uses it, because it downloads files in parallel. Otherwise it uses `curl` automatically. To force one, set `IDEAS_DOWNLOADER=aws` or `IDEAS_DOWNLOADER=curl`. Either install option works:

| Option | Command | Notes |
|--------|---------|-------|
| pip (AWS CLI v1) | `pip install --user awscli` | Simplest if Python/pip is available |
| Official installer (AWS CLI v2) | see below | No admin rights needed; bundles its own Python |

```bash
# AWS CLI v2, user-level install (no sudo).
# Run from your home folder, not /tmp: many clusters mount /tmp "noexec",
# which makes ./aws/install fail with "Permission denied".
cd ~
curl -sSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
unzip -q awscliv2.zip
./aws/install -i ~/.local/aws-cli -b ~/.local/bin
```

Both put `aws` in `~/.local/bin`. Make sure that folder is on your `PATH`, then check:

```bash
aws --version
```

### 2. Run the script

From `dwi_pipeline/`:

```bash
bash scripts/download_ideas_sample.sh
```

A menu appears:

```text
  1) Download all data (542 subjects, ~40 GB)
  2) Download a sample (sub-1 sub-6, ~150 MB)
Choose [1/2] (default 2):
```

- Type `2` (or press Enter) for the two-subject sample.
- Type `1` for the full dataset, then `y` to confirm.

Other ways to run it:

```bash
bash scripts/download_ideas_sample.sh sample        # sample, no menu
bash scripts/download_ideas_sample.sh all           # everything, no menu
bash scripts/download_ideas_sample.sh 3 sub-10      # specific subjects
bash scripts/download_ideas_sample.sh -o /scratch/ideas          # other folder
IDEAS_OUT=/scratch/ideas bash scripts/download_ideas_sample.sh   # same, via env var
```

Run from `dwi_pipeline/`, data land in `sample_data/ideas/bids/` (gitignored, so downloaded imaging data is never committed). Run as a standalone file, they land in `./ideas_bids/` unless you pass `-o`. When run without a terminal (SLURM job, CI, another script), the menu is skipped and the sample is downloaded.

### Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `ERROR: need curl or aws installed` | Neither tool found | Install `curl` (system package manager), or `aws` (step 1) |
| `curl: (6) Could not resolve host` | No internet access (common on cluster compute nodes) | Run on a login node or a machine with internet |
| `./aws/install: Permission denied` | Installer unzipped in `/tmp`, which is mounted `noexec` on many clusters | Unzip and install from your home folder (`cd ~` first) |
| `Unable to locate credentials` | Older copy of the script without anonymous access | Update the script; current version uses `--no-sign-request` |
| `ERROR: sub-999 not found in ds007401` | Subject ID does not exist (typo) | Check IDs on [OpenNeuro ds007401](https://openneuro.org/datasets/ds007401) |
| `aws` crashes on start with `MemoryError` | Restricted environment (memory-limited sandbox or container) | Use `IDEAS_DOWNLOADER=curl`, or run from a normal login shell |
| Download stopped partway (Ctrl-C, lost connection, job time limit) | Interrupted transfer | Run the same command again; only missing files are fetched |
| Full download takes too long | ~40 GB total | Use a compute node or `screen`/`tmux`; or download only the subjects you need |

Typing `1` or `2` **as a command-line argument** means subject `sub-1` / `sub-2`, not a menu choice. The 1/2 choice applies only inside the menu.

## Run DKT Connectome

From `dwi_pipeline/` (`./dkt run` is the same as `./run`):

```bash
export FS_LICENSE=/path/to/license.txt

./dkt run "$(pwd)/sample_data/ideas/bids" "$(pwd)/sample_data/ideas/results/sub-1_tutorial" participant \
  --participant-label 1 \
  --session-filter ses-1 \
  --fastsurfer \
  --syn \
  --dwi-select config/dwi_select_ideas_b2500.json \
  --dry-run
```

Use `--syn` if no fieldmaps are present in the dwi-select filter (typical for these subjects).

Full guide: [docs/datasets/ideas.md](../../docs/datasets/ideas.md).

## Citation

If you use these data in publications, tutorials, or redistributed derivatives, cite **both** the IDEAS II paper and the OpenNeuro dataset record.

### IDEAS II (diffusion MRI release)

> Taylor PN, Hall G, Horsley J, Wang Y, Vos SB, Winston GP, McEvoy AW, Miserocchi A, de Tisi J, Duncan JS. Open diffusion magnetic resonance imaging and connectivity data for epilepsy and surgery: The IDEAS II release. *Epilepsia* 2026;67(6):2912–2923. https://doi.org/10.1002/epi.70186

### OpenNeuro dataset (ds007401)

> OpenNeuro dataset ds007401 (IDEAS II BIDS release). https://doi.org/10.18112/openneuro.ds007401.v1.0.0

### IDEAS I (structural MRI + clinical metadata, same subject IDs)

> Taylor PN, et al. Open MRI data for epilepsy and surgery: The IDEAS release. *Epilepsia* 2025. https://doi.org/10.1111/epi.18192

### BibTeX

```bibtex
@article{Taylor2026IDEASII,
  author  = {Taylor, Peter N. and Hall, Gerard and Horsley, Jonathan and
             Wang, Yujiang and Vos, Sjoerd B. and Winston, Gavin P. and
             McEvoy, Andrew W. and Miserocchi, Anna and de Tisi, Jane and
             Duncan, John S.},
  title   = {Open diffusion magnetic resonance imaging and connectivity data for epilepsy and surgery: The {IDEAS II} release},
  journal = {Epilepsia},
  volume  = {67},
  number  = {6},
  pages   = {2912--2923},
  year    = {2026},
  doi     = {10.1002/epi.70186}
}

@misc{OpenNeuroIDEASII,
  author       = {Taylor, Peter N. and others},
  title        = {Open diffusion {MRI} and connectivity data for epilepsy and surgery: The {IDEAS II} release},
  year         = {2026},
  publisher    = {OpenNeuro},
  doi          = {10.18112/openneuro.ds007401.v1.0.0},
  url          = {https://openneuro.org/datasets/ds007401}
}
```

Copy-paste acknowledgements: [Citation](../../docs/citation.md#sample-tutorial-data-ideas-ii).
