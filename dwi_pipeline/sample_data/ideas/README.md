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

### 1. Install the AWS command-line tool (once)

The data come from OpenNeuro's public storage. The script reads it anonymously, so **no AWS account or credentials are needed**, only the `aws` program. Either option works:

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

From the repository root:

```bash
bash dwi_pipeline/scripts/download_ideas_sample.sh
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
bash dwi_pipeline/scripts/download_ideas_sample.sh sample        # sample, no menu
bash dwi_pipeline/scripts/download_ideas_sample.sh all           # everything, no menu
bash dwi_pipeline/scripts/download_ideas_sample.sh 3 sub-10      # specific subjects
IDEAS_OUT=/scratch/ideas bash dwi_pipeline/scripts/download_ideas_sample.sh   # other folder
```

Data land in `dwi_pipeline/sample_data/ideas/bids/` (gitignored, so downloaded imaging data is never committed). When run without a terminal (SLURM job, CI, another script), the menu is skipped and the sample is downloaded.

### Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `ERROR: aws CLI required` | `aws` not installed or not on `PATH` | Install (step 1); add `~/.local/bin` to `PATH` |
| `./aws/install: Permission denied` | Installer unzipped in `/tmp`, which is mounted `noexec` on many clusters | Unzip and install from your home folder (`cd ~` first) |
| `Unable to locate credentials` | Older copy of the script without anonymous access | Update the script; current version uses `--no-sign-request` |
| `ERROR: sub-999 not found in ds007401` | Subject ID does not exist (typo) | Check IDs on [OpenNeuro ds007401](https://openneuro.org/datasets/ds007401) |
| `aws` crashes on start with `MemoryError` | Restricted environment (memory-limited sandbox or container) | Run from a normal login shell or a compute node with more memory |
| Download stopped partway (Ctrl-C, lost connection, job time limit) | Interrupted transfer | Run the same command again; only missing files are fetched |
| Full download takes too long | ~40 GB total | Use a compute node or `screen`/`tmux`; or download only the subjects you need |

Typing `1` or `2` **as a command-line argument** means subject `sub-1` / `sub-2`, not a menu choice. The 1/2 choice applies only inside the menu.

## Run DKT Connectome

```bash
export BIDS_DIR="$(pwd)/dwi_pipeline/sample_data/ideas/bids"
export FS_LICENSE=/path/to/license.txt

cd dwi_pipeline
./run "${BIDS_DIR}" /tmp/ideas_derivatives participant \
  --participant-label 1 \
  --session-filter ses-1 \
  --fastsurfer \
  --syn \
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
