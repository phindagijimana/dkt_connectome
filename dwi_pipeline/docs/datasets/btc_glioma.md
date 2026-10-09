# BTC_preop glioma sample — **not TBI**

**This is glioma, not traumatic brain injury.** One public subject from
OpenNeuro **BTC_preop** (ds001226) is a **demo of lesion-aware BIDS inputs
only**. It is **not** TRACK-TBI data. **Do not cite it as TRACK-TBI
validation.**

The mask on disk is a **tumor** mask from OpenNeuro
`derivatives/tumor_masks/`, copied next to T1w and renamed
`*_T1w_label-lesion_roi.nii.gz` because `find_lesion_mask` only looks for
that sibling filename under `sub-<id>/ses-<ses>/anat/`. The voxels are
unchanged; only the BIDS name is adapted. A sidecar JSON states this is a
**tumor mask, not a traumatic lesion**.

**Download script:** [`scripts/download_btc_glioma_sample.sh`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/scripts/download_btc_glioma_sample.sh)

**Local path after download:** `dwi_pipeline/sample_data/btc_glioma/bids/`
(gitignored NIfTI; README tracked)

---

## Source

| Resource | Link |
|----------|------|
| **OpenNeuro** | [openneuro.org/datasets/ds001226](https://openneuro.org/datasets/ds001226) |
| **DOI** | [10.18112/openneuro.ds001226.v5.0.0](https://doi.org/10.18112/openneuro.ds001226.v5.0.0) |
| **Primary paper** | [Aerts et al. 2018, *eNeuro*](https://doi.org/10.1523/ENEURO.0083-18.2018) |
| **Dataset descriptor (optional)** | [Aerts et al. 2022, *Scientific Data*](https://doi.org/10.1038/s41597-022-01806-4) |

BTC_preop includes glioma patients, meningioma patients, and controls. The
sample script defaults to a **glioma** subject and refuses meningioma IDs
unless you pass `--any-pat`.

---

## Included subject

| ID | Session | Pathology | Modalities |
|----|---------|-----------|------------|
| `sub-PAT20` | `ses-preop` | anaplastic astrocytoma III (**glioma**) | T1w, `acq-AP` HARDI, `acq-PA` b0, tumor mask copied as T1w sibling |

**Session wrap:** not needed. ds001226 already uses `ses-preop`. A `ses-1`
wrap would have been layout-only (images unchanged).

**Skipped:** `func/` and questionnaires.

**HARDI shells:** 0 / 700 / 1200 / 2800 s/mm². There is **no b=1000**
shell. Use `config/dwi_select_btc_hardi.json` or `--no-dwi-filter`. Do not
invent a b=1000 filter.

---

## Download

```bash
bash dwi_pipeline/scripts/download_btc_glioma_sample.sh
```

Requires `aws` (anonymous `--no-sign-request`) or `curl`. No credentials.

---

## Example run

```bash
export BIDS_DIR="$(pwd)/dwi_pipeline/sample_data/btc_glioma/bids"
export FS_LICENSE=/path/to/license.txt

cd dwi_pipeline
./run "${BIDS_DIR}" /tmp/btc_glioma_derivatives participant \
  --participant-label PAT20 \
  --session-filter ses-preop \
  --fastsurfer \
  --inpaint \
  --syn \
  --dwi-select config/dwi_select_btc_hardi.json \
  --dry-run
```

**Notes:**

- Pass **`--syn`** — no `fmap/` folder in this sample (only a short
  reverse-PE `acq-PA` DWI series).
- **`--inpaint`** is explicit; Step 1.1 also auto-runs when the sibling
  mask exists.
- Participant label is **`PAT20`** (with or without `sub-`).
- This is a **layout / CLI demo**, not a validation cohort.

---

## Citation

Cite BTC (glioma / tumor modelling). **Do not cite as TRACK-TBI.**

> Aerts H, Schirner M, Jeurissen B, Van Roost D, Achten E, Ritter P, Marinazzo D. Modeling Brain Dynamics in Brain Tumor Patients Using the Virtual Brain. *eNeuro*. 2018;5(3):ENEURO.0083-18.2018. https://doi.org/10.1523/ENEURO.0083-18.2018

> Aerts H, Colenbier N, Almgren H, Marinazzo D. BTC_preop. OpenNeuro. https://doi.org/10.18112/openneuro.ds001226.v5.0.0

Optional: Aerts et al. *Scientific Data* 2022. https://doi.org/10.1038/s41597-022-01806-4

BibTeX: [Citation](../citation.md#public-glioma-lesion-demo-not-tbi).

---

## See also

- [sample_data/btc_glioma/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/sample_data/btc_glioma/README.md)
- [IDEAS II sample](ideas.md) (epilepsy DWI smoke test — also not TBI)
- [Preparing your data](../preparing_data.md)
