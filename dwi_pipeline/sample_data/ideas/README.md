# IDEAS II sample data (OpenNeuro)

Two-subject BIDS subset from the **IDEAS II** diffusion MRI release for pipeline demos and CI-adjacent smoke tests.

**Source:** [OpenNeuro ds007401](https://openneuro.org/datasets/ds007401) ([DOI 10.18112/openneuro.ds007401.v1.0.0](https://doi.org/10.18112/openneuro.ds007401.v1.0.0))

Also listed on the [CNNP Lab IDEAS page](https://sites.google.com/view/cnnp-lab//ideas-data).

## Subjects included

| BIDS ID | Sessions used | Contents |
|---------|---------------|----------|
| `sub-1` | `ses-1` | T1w, FLAIR, DWI (+ sidecars) |
| `sub-6` | `ses-1` | T1w, FLAIR, DWI (+ sidecars) |

See [SUBJECTS.md](SUBJECTS.md) for download provenance.

## Download / refresh

```bash
bash dwi_pipeline/scripts/download_ideas_sample.sh
```

Data land in `dwi_pipeline/sample_data/ideas/bids/` (gitignored).

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

Full guide: [docs/datasets/ideas.md](../docs/datasets/ideas.md).

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

Copy-paste acknowledgements: [Citation](../docs/citation.md#sample-tutorial-data-ideas-ii).
