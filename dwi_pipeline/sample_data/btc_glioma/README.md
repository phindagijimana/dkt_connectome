# BTC_preop glioma sample (OpenNeuro) — **not TBI**

**This is GLIOMA, not traumatic brain injury.** One public subject from
[BTC_preop](https://openneuro.org/datasets/ds001226) (OpenNeuro ds001226) so
you can exercise **lesion-aware BIDS inputs** (T1w sibling mask → Step 1.1
inpaint). It is **not** a TRACK-TBI subject, **not** a TBI lesion, and **must
not be cited as TRACK-TBI validation**.

The OpenNeuro file is a **tumor mask**. This pipeline only discovers a mask
as a sibling of T1w named `*_T1w_label-lesion_roi.nii.gz`. The download
script **copies** (does not move) that tumor mask into that filename. A
sidecar JSON states the provenance: tumor, not trauma.

**Source:** [OpenNeuro ds001226](https://openneuro.org/datasets/ds001226)
([DOI 10.18112/openneuro.ds001226.v5.0.0](https://doi.org/10.18112/openneuro.ds001226.v5.0.0))

Images are **gitignored**. Only this README is tracked.

## Default subject

| BIDS ID | Session | Pathology | Contents |
|---------|---------|-----------|----------|
| `sub-PAT20` | `ses-preop` | anaplastic astrocytoma III (glioma) | T1w, acq-AP HARDI, acq-PA b0, tumor mask copied next to T1w |

**Why PAT20:** smallest complete **glioma** subject (T1w + directional
`acq-AP` HARDI + T1-space tumor mask). BTC_preop also includes meningioma
and control subjects; those are not the default.

**Session layout:** ds001226 already has `ses-preop`. No `ses-1` wrap was
applied. (This pipeline requires T1w and the mask under `sub-*/ses-*/anat/`.
A wrap would have been a layout-only rename, not a change to the images.)

**Skipped:** `func/` and questionnaires (CANTAB / self-report tables).

**DWI shells:** 0 / 700 / 1200 / 2800 s/mm². There is **no** b=1000 shell —
do not use the default `dwi_select_b1000.json`.

## Download

```bash
bash dwi_pipeline/scripts/download_btc_glioma_sample.sh
```

Optional: another glioma ID (`PAT05`, `PAT16`, `PAT22`, `PAT25`, `PAT26`,
`PAT27`, `PAT28`, `PAT29`, `PAT31`) or `-o DIR`. Meningioma IDs are refused
unless you pass `--any-pat`.

Data land in `dwi_pipeline/sample_data/btc_glioma/bids/` (gitignored).

## Example `./run` flags

No `fmap/` folder is shipped (only a short reverse-PE `acq-PA` DWI). Pass
`--syn`. Use the HARDI select JSON or `--no-dwi-filter` — **do not invent
a b=1000 filter**.

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

`--inpaint` is optional: Step 1.1 already auto-runs when the sibling mask
exists. `--session-filter ses-preop` (or `preop`) matches the source session.

**Do not start a full QSIPrep run from this README unless you intend to.**
Use `--dry-run` first.

## Citation

If you use these volumes, cite the BTC papers and the OpenNeuro record.
**Do not present results as TRACK-TBI validation.**

> Aerts H, Schirner M, Jeurissen B, Van Roost D, Achten E, Ritter P, Marinazzo D. Modeling Brain Dynamics in Brain Tumor Patients Using the Virtual Brain. *eNeuro*. 2018;5(3):ENEURO.0083-18.2018. [doi:10.1523/ENEURO.0083-18.2018](https://doi.org/10.1523/ENEURO.0083-18.2018)

> Aerts H, Colenbier N, Almgren H, Marinazzo D. BTC_preop. OpenNeuro. [doi:10.18112/openneuro.ds001226.v5.0.0](https://doi.org/10.18112/openneuro.ds001226.v5.0.0)

Optional dataset descriptor:

> Aerts H, Colenbier N, Almgren H, et al. Pre- and post-surgery brain tumor multimodal magnetic resonance imaging data optimized for large scale computational modelling. *Scientific Data*. 2022;9:676. [doi:10.1038/s41597-022-01806-4](https://doi.org/10.1038/s41597-022-01806-4)

Docs: [datasets/btc_glioma.md](../../docs/datasets/btc_glioma.md) · [Citation](../../docs/citation.md#public-glioma-lesion-demo-not-tbi).
