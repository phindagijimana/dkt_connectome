# BTC_preop glioma public demo run

Public demo of **BTC_preop** `sub-PAT20` (`ses-preop`). This is **GLIOMA, not TBI**. **Do not cite as TRACK-TBI validation.**

**Local output (gitignored):** `sample_data/btc_glioma/results/sub-PAT20_public_demo/`

The run includes `--inpaint` because the tumor mask was renamed to `*_T1w_label-lesion_roi.nii.gz`.

## Reproduce

```bash
bash dwi_pipeline/scripts/download_btc_glioma_sample.sh
```

Then the `./run` command in [docs/datasets/btc_glioma.md](../../docs/datasets/btc_glioma.md) (`--fastsurfer --inpaint --syn`), writing to `sample_data/btc_glioma/results/sub-PAT20_public_demo/`.

## Citation

Cite Aerts et al. 2018 (*eNeuro*) and OpenNeuro ds001226. Optional: Aerts et al. 2022 (*Scientific Data*).

> Aerts H, Schirner M, Jeurissen B, Van Roost D, Achten E, Ritter P, Marinazzo D. Modeling Brain Dynamics in Brain Tumor Patients Using the Virtual Brain. *eNeuro*. 2018;5(3):ENEURO.0083-18.2018. https://doi.org/10.1523/ENEURO.0083-18.2018

> Aerts H, Colenbier N, Almgren H, Marinazzo D. BTC_preop. OpenNeuro. https://doi.org/10.18112/openneuro.ds001226.v5.0.0

Optional: Aerts et al. *Scientific Data* 2022. https://doi.org/10.1038/s41597-022-01806-4
