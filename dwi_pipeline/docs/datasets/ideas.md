# IDEAS II sample dataset

Public BIDS subset for tutorials and smoke tests — **two subjects** from the IDEAS II epilepsy diffusion release.

**Download script:** [`scripts/download_ideas_sample.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/scripts/download_ideas_sample.sh)

**Local path after download:** `dwi_pipeline/sample_data/ideas/bids/` (gitignored NIfTI; README tracked)

---

## Source

| Resource | Link |
|----------|------|
| **OpenNeuro** | [openneuro.org/datasets/ds007401](https://openneuro.org/datasets/ds007401) |
| **DOI** | [10.18112/openneuro.ds007401.v1.0.0](https://doi.org/10.18112/openneuro.ds007401.v1.0.0) |
| **CNNP Lab index** | [IDEAS data page](https://sites.google.com/view/cnnp-lab//ideas-data) |
| **Paper** | [Taylor et al. 2026, *Epilepsia*](https://doi.org/10.1002/epi.70186) |

We pull from **OpenNeuro S3** (`s3://openneuro.org/ds007401/`) rather than Figshare bundles — same IDEAS II BIDS release, easier partial subject download.

---

## Included subjects

| ID | Session | Modalities |
|----|---------|------------|
| `sub-1` | `ses-1` | T1w, FLAIR, DWI |
| `sub-6` | `ses-1` | T1w, FLAIR, DWI |

No resection masks are bundled in this two-subject sample. For RAMPS resection masks, see the [Figshare resection bundle](https://figshare.com/s/476b37fd883c14f50324) on the CNNP Lab page.

---

## Download

```bash
bash dwi_pipeline/scripts/download_ideas_sample.sh
```

Requires AWS CLI (public read-only S3 — no credentials needed).

---

## Example run

```bash
export BIDS_DIR="$(pwd)/dwi_pipeline/sample_data/ideas/bids"
export FS_LICENSE=/path/to/license.txt

cd dwi_pipeline
./run "${BIDS_DIR}" sample_data/ideas/results/sub-1_golden participant \
  --participant-label 1 \
  --session-filter ses-1 \
  --fastsurfer \
  --syn \
  --dwi-select config/dwi_select_ideas_b2500.json \
  --n-cpus 8
```

**Notes:**

- IDEAS DWI shells are **0, 300, 700, 2500 s/mm²** — use **`config/dwi_select_ideas_b2500.json`** (not the default b=1000 filter).
- Pass **`--syn`** — no fieldmaps in this sample.
- Participant label is **`1`** or **`6`** (with or without `sub-` prefix).
- Full pipeline takes hours on CPU; use **`--dry-run`** first.
- Golden output path (when complete): `sample_data/ideas/results/sub-1_golden/`

See also: [Tutorial](../tutorial.md).

---

## Citation

If you use these data, cite **IDEAS II** and the **OpenNeuro dataset**:

> Taylor PN, Hall G, Horsley J, Wang Y, Vos SB, Winston GP, McEvoy AW, Miserocchi A, de Tisi J, Duncan JS. Open diffusion magnetic resonance imaging and connectivity data for epilepsy and surgery: The IDEAS II release. *Epilepsia* 2026;67(6):2912–2923. https://doi.org/10.1002/epi.70186

> OpenNeuro dataset ds007401. https://doi.org/10.18112/openneuro.ds007401.v1.0.0

**IDEAS I** (T1w/FLAIR + clinical metadata, same subject IDs): Taylor PN, et al. *Epilepsia* 2025. https://doi.org/10.1111/epi.18192

BibTeX and acknowledgment templates: [Citation](../citation.md#sample-tutorial-data-ideas-ii) · [References](../references.md#sample-tutorial-data-ideas-ii-openneuro).

---

## See also

- [sample_data/ideas/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/sample_data/ideas/README.md)
- [Validation](../validation.md)
- [Preparing your data](../preparing_data.md)
