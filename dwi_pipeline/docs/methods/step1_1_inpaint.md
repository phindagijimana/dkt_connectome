# Step 1.1 — Lesion inpainting (neuroLIT)

**Theory and methods** for optional T1w lesion inpainting before cortical reconstruction. Operational details: [Pipeline steps § Step 1.1](../pipeline_steps.md#step-11-inpaint-optional) · [Lesion segmentation](../lesion_segmentation.md).

---

## Background

FreeSurfer and FastSurfer are trained on **healthy anatomy**. Large lesions (hemorrhage, encephalomalacia, resection cavities) violate the tissue intensity relationships these tools expect, which can cause:

- Local segmentation errors inside and around the lesion
- Global registration drift (Talairach / template steps optimize over the whole brain)
- Downstream connectome errors when parcellation labels are wrong

Rather than excluding lesioned subjects or masking out tissue, the pipeline **synthesizes plausible anatomy inside the lesion** so reconstruction sees an image closer to its training distribution. The original lesion mask is preserved as metadata for disconnectome analysis (Step 4.1).

---

## Denoising diffusion probabilistic models (DDPM)

[neuroLIT](https://github.com/Deep-MI/lit) (FastSurfer-LIT) frames lesion filling as **conditional image inpainting** with a DDPM (Ho et al. 2020):

```text
Forward  (fixed):   x₀ → x₁ → … → x_T   (add Gaussian noise)
Reverse  (learned): x_T → … → x₀         (denoise one step at a time)
```

At inference, the model starts from noise **inside the lesion mask** and iteratively denoises. At each step, **known healthy voxels outside the mask are re-inserted unchanged** (RePaint-style resampling; Lugmayr et al. 2022), so surrounding anatomy guides what is synthesized inside the lesion.

Default **`--dilate 2`** expands the mask slightly before inpainting, covering partial-volume margins and imperfect manual traces.

---

## VINN layers and `--keepgeom`

Classical CNN segmenters require inputs conformed to a fixed 256³ grid. neuroLIT uses **Voxel-size Independent Neural Network (VINN)** layers (Henschel et al. 2022) parameterized in millimeters rather than voxels, so inference works across clinical voxel sizes without mandatory resampling.

**`--keepgeom`** returns the inpainted volume on the **exact input T1w grid** (same shape, affine, voxel size as BIDS T1w). This makes the result a drop-in replacement for raw T1w in Steps 2 and 4.

---

## What DKT Connectome runs

| Item | Value |
|------|-------|
| Container | `deepmi/lit:0.6.0` (`lit_0.6.0.sif`) |
| Trigger | Sibling `*_T1w_label-lesion_roi.nii.gz` in BIDS (exactly one match) |
| Skip | No mask (silent no-op), or `--no-inpaint` |
| Device | GPU by default (`INPAINT_DEVICE=cpu` for debugging only) |

### Processing sequence

1. **`prepare_lesion_mask.py`** — resample mask to T1w grid, select labels (default: core + oedema), write `lesion_mask_prepared.nii.gz` + JSON provenance.
2. **`lit-inpainting`** — DDPM fill with dilation and `--keepgeom`.
3. **`check_inpainting.py`** — QC metrics (see below).
4. **`inpainting.json`** — merged provenance and pass/fail status.

### Inpainted T1w routing

When Step 1.1 runs, **`INPAINTED_T1W`** replaces the raw BIDS T1w for:

- Step 2 (FreeSurfer / FastSurfer input)
- Step 4 (BIDS-side of the registration affine)

**The DWI is never modified** — diffusion data processed in Steps 1 and 3 are unaffected by inpainting.

---

## Quality control

`check_inpainting.py` verifies inpainting **only changed voxels inside (or near) the lesion**:

| Metric | Meaning | Default gate |
|--------|---------|--------------|
| Outside-lesion correlation | Pearson *r* between original and inpainted outside mask | ≥ 0.995 |
| Resampling control | Same correlation after conform/resample round-trip without inpainting | baseline |
| Correlation drop | Control − outside correlation; large values mean network altered healthy tissue | ≤ 0.01 |
| Regenerated voxels | Count of outside-lesion voxels changed beyond adaptive threshold | reported only |

Set `INPAINT_FAIL_ON_QC=1` to fail the run on QC violation (default: warn and continue).

---

## Virtual brain transplant (`--anat-mitigation vbt`)

**Alternative to neuroLIT:** a deterministic **virtual brain transplant (VBT)** ported from the public [BrainModes/LeAPP](https://github.com/BrainModes/LeAPP) code (Bey et al. 2024). LeAPP adapted enantiomorphic lesion mitigation strategies used in stroke neuroimaging; the pipeline implementation follows LeAPP's released shell/Python sequence rather than running the LeAPP container itself.

### Theory

VBT assumes a **largely unilateral lesion** with an intact **contralateral homologue**:

1. Mirror the T1w across the midline.
2. Rigidly register the original brain to the mirror using **healthy voxels only** (lesion excluded from the cost function).
3. Apply **half-transform** midline alignment (`midtrans`) so both hemispheres share a common midline frame.
4. **Blend** mirrored contralesional signal into the lesion through a **Gaussian-smoothed mask** (default σ = 2 voxels, matching LeAPP defaults).
5. Inverse-transform the transplant back to native T1w space (`--keepgeom`-equivalent).

Unlike neuroLIT's learned synthesis, VBT is **deterministic**, requires **no GPU**, and does not train on healthy statistics — it explicitly copies contralesional anatomy. It is appropriate as a **sensitivity backend**, not as a claim of biological recovery inside the lesion.

### When to use VBT vs neuroLIT

| | neuroLIT (default) | VBT |
|--|---------------------|-----|
| Mechanism | DDPM inpainting (Pollak et al. 2025) | Enantiomorphic mirror + FLIRT (LeAPP port) |
| GPU | Recommended | CPU only |
| Assumptions | Learned healthy appearance | Unilateral lesion + usable homologue |
| Output dir | `inpainted/` | `vbt/` |

### Citation guidance

- Cite **Pollak et al. 2025** when using `--anat-mitigation neurolit`.
- Cite **Bey et al. 2024 (LeAPP)** when using `--anat-mitigation vbt`, and state that VBT is a **port of LeAPP's released virtual brain transplant code**, not a full LeAPP pipeline run.
- Do **not** claim equivalence between neuroLIT and VBT — they answer similar anatomical questions with different models.

---

## References

| Topic | Citation | Link |
|-------|----------|------|
| **neuroLIT (required when inpainting)** | Pollak TA, et al. FastSurfer-LIT. *Imaging Neuroscience* 2025 | [10.1162/imag_a_00446](https://doi.org/10.1162/imag_a_00446) |
| DDPM foundation | Ho J, et al. *NeurIPS* 2020 | [arXiv:2006.11239](https://arxiv.org/abs/2006.11239) |
| VINN layers | Henschel L, et al. *Medical Image Analysis* 2022 | [10.1016/j.media.2022.102313](https://doi.org/10.1016/j.media.2022.102313) |
| Inpainting strategy | Lugmayr A, et al. RePaint. *CVPR* 2022 | [10.1109/CVPR52688.2022.01175](https://doi.org/10.1109/CVPR52688.2022.01175) |
| **VBT / LeAPP (when `--anat-mitigation vbt`)** | Bey P, et al. LeAPP. *Human Brain Mapping* 2024;45(9):e26701. | [10.1002/hbm.26701](https://doi.org/10.1002/hbm.26701) |

Full table: [References § Step 1.1](../references.md#step-11-anatomical-lesion-mitigation-optional).

---

## See also

- [Lesion segmentation](../lesion_segmentation.md)
- [Step 2 — Cortical reconstruction](step2_recon.md)
- [Step 4.1 — Disconnectome](step4_1_disconnectome.md)
- [neuroLIT container README](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/lit/README.md)
- [VBT container README](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/vbt/README.md)
