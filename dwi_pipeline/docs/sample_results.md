# Sample results (public demos)

QSIPrep / QSIRecon-style **reportlets** from the two public software demos.
These show that the pipeline ran. They are **not** TRACK-TBI validation and
**not** a clinical glioma or epilepsy study.

Full derivatives (NIfTI, tractograms, HTML reports, connectome CSVs) stay
**local** and are gitignored. Reproduce with the download scripts on
[IDEAS II](datasets/ideas.md) and [BTC glioma](datasets/btc_glioma.md).

---

## Subject QC summary

| Subject | Dataset | Path | QSIPrep | Inpaint | Recon | QSIRecon | Connectome | Disconnectome | Node strength |
|---------|---------|------|---------|---------|-------|----------|------------|---------------|---------------|
| `sub-1` | IDEAS II [ds007401](https://openneuro.org/datasets/ds007401) | No lesion | PASS | SKIP | PASS | PASS | PASS (78 nodes, 0 empty) | SKIP | PASS |
| `sub-6` | IDEAS II | No lesion | PASS | SKIP | PASS | PASS | PASS (78 nodes, 0 empty) | SKIP | PASS |
| `sub-PAT20` | BTC glioma [ds001226](https://openneuro.org/datasets/ds001226) | Tumor mask as `*_T1w_label-lesion_roi` | PASS | PASS | PASS | PASS | PASS (78 nodes, 0 empty) | PASS (736 edges disrupted; option C) | PASS |

Inpaint on PAT20 **wrote a T1w**. Outside-mask Pearson *r* = **0.986897**,
resample-only control = **0.996625**, drop = **0.009728**. Those numbers are
printed as IQMs. **0.995 / 0.01 are optional pipeline defaults, not a
published cutoff.** Judge the before/after PNGs
([Pollak et al. 2025](https://doi.org/10.1162/imag_a_00446);
[MRIQC](https://doi.org/10.1371/journal.pone.0184661) visual QC).

---

## IDEAS II `sub-1` (no lesion)

Epilepsy DWI, `ses-1`. Inpaint skipped (no mask). Cite Taylor et al. 2026
(*Epilepsia*) and OpenNeuro ds007401.

```{figure} img/demos/ideas-sub-1-carpet.svg
:alt: QSIPrep carpet plot for IDEAS II sub-1
:width: 90%

QSIPrep DWI carpet plot (`sub-1`, `ses-1`). Check for motion spikes and
odd slices — same panel as in the QSIPrep HTML report.
```

```{figure} img/demos/ideas-sub-1-coreg.svg
:alt: QSIPrep DWI–T1w coregistration for IDEAS II sub-1
:width: 90%

QSIPrep DWI–T1w coregistration. Brain boundaries should line up.
```

```{figure} img/demos/ideas-sub-1-connectome.svg
:alt: QSIRecon connectivity matrices for IDEAS II sub-1
:width: 90%

QSIRecon connectivity-matrix reportlet. The pipeline then writes the 78-node
DKT connectome from this tractography (0 empty nodes on this run).
```

`sub-6` completed the same Steps 1–5 with overall PASS. Reportlets are
omitted to keep this page small; they look like `sub-1`.

---

## BTC glioma `sub-PAT20` (lesion-aware)

**Glioma, not TBI.** The OpenNeuro tumor mask was renamed to
`*_T1w_label-lesion_roi.nii.gz` so Step 1.1 and `--disconnection` could run.
Cite Aerts et al. 2018 (*eNeuro*) and OpenNeuro ds001226. Do **not** cite as
TRACK-TBI.

```{figure} img/demos/pat20-carpet.svg
:alt: QSIPrep carpet plot for BTC glioma PAT20
:width: 90%

QSIPrep carpet plot (`ses-preop`, `acq-AP` HARDI).
```

```{figure} img/demos/pat20-coreg.svg
:alt: QSIPrep DWI–T1w coregistration for BTC glioma PAT20
:width: 90%

QSIPrep DWI–T1w coregistration.
```

```{figure} img/demos/pat20-inpaint-mask.png
:alt: PAT20 tumor mask used for inpainting
:width: 55%

Tumor mask used as the pipeline lesion ROI (T1w sibling).
```

```{figure} img/demos/pat20-inpaint-result.png
:alt: PAT20 inpainted T1w
:width: 55%

neuroLIT result on the original T1w grid. Inspect tissue next to the mask;
do not treat Pearson *r* as a disease grade.
```

```{figure} img/demos/pat20-connectome.svg
:alt: QSIRecon connectivity matrices for BTC glioma PAT20
:width: 90%

QSIRecon connectivity-matrix reportlet. Disconnectome option C reported 736
edges with disruption > 0.
```

---

## What is not on this page

NIfTI, `.tck`, full QSIPrep/QSIRecon HTML, DKT CSVs, and TRACK-TBI outputs
are **not** in the repository. After you run the [tutorial](tutorial.md)
locally, open `RESULTS_ROOT/qc/sub-<ID>/subject_qc.html`.

---

## Citation

- IDEAS II: Taylor et al. 2026, *Epilepsia*. [10.1002/epi.70186](https://doi.org/10.1002/epi.70186) · [ds007401](https://doi.org/10.18112/openneuro.ds007401.v1.0.0)
- BTC glioma: Aerts et al. 2018, *eNeuro*. [10.1523/ENEURO.0083-18.2018](https://doi.org/10.1523/ENEURO.0083-18.2018) · [ds001226](https://doi.org/10.18112/openneuro.ds001226.v5.0.0)
- QSIPrep / QSIRecon reportlets: Cieslak et al. 2021, *Nature Methods*. [10.1038/s41592-021-01185-5](https://doi.org/10.1038/s41592-021-01185-5)

See [Citation](citation.md).
