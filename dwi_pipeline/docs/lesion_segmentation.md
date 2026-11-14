# Lesion segmentation

How lesion masks enter the pipeline — from BIDS annotation through inpainting (Step 1.1) to optional disconnectome (Step 4.1).

---

## BIDS lesion mask

Place a multi-label ROI next to the session T1w:

```text
sub-<ID>/ses-<Y>/anat/
  sub-<ID>_ses-<Y>_T1w.nii.gz
  sub-<ID>_ses-<Y>_T1w_label-lesion_roi.nii.gz
```

Default labels (Step 1.1 / 4.1):

| Value | Meaning |
|-------|---------|
| 0 | Background |
| 1 | Core |
| 2 | Oedema / FLAIR hyperintensity |

The mask is a NIfTI on the T1w grid. Values above are the labels Steps 1.1 and 4.1 read.

---

## Pipeline stages that use the mask

| Step | When | What happens |
|------|------|--------------|
| **1 — QSIPrep** | Always if mask present | Cost-function masking during registration |
| **1.1 — Inpaint** | Auto when mask found | neuroLIT fills lesion on T1w before recon |
| **4.1 — Disconnectome** | Manual post-hoc | Binary union excision + disconnection matrix |

Subjects **without** a mask skip Steps 1.1 and 4.1. Step 4.1 additionally requires **`--disconnection`**.

---

## Step 1.1 (inpainting)

- **Trigger:** sibling `*_label-lesion_roi.nii.gz` in BIDS
- **Tool:** [neuroLIT](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/lit/README.md) (`lit_0.6.0.sif`)
- **Output:** `inpainted/.../inpainting_result.nii.gz` used by Steps 2 and 4

```bash
bash workflow/run_subject.sh inpaint 009
bash workflow/run_subject.sh all 009 --no-inpaint   # force skip
```

QC: `scripts/check_inpainting.py`. Method: [Step 1.1](methods/step1_1_inpaint.md).

---

## Step 4.1 (disconnectome)

**Opt-in:** pass `--disconnection` on a full pipeline run, or use `--mode disconnectome` / `run_subject.sh disconnectome`.

**Primary lesion definition:** binary union of core + oedema, **no erosion**.

```bash
python3 dwi_pipeline/scripts/run_disconnectome.py \
  --results-root /path/to/derivatives \
  --subject 009
```

Method: [Disconnectome](disconnectome.md) · [Step 4.1](methods/step4_1_disconnectome.md).

---

## See also

- [Step 1.1 — Inpaint](methods/step1_1_inpaint.md)
- [Step 4.1 — Disconnectome](methods/step4_1_disconnectome.md)
- [Disconnectome](disconnectome.md) — outputs and QC

---

## Automated segmentation (future / external)

This pipeline expects **manual** BIDS ROI masks today. For automated alternatives (LINDA, AutoDDPM, etc.), generate a compatible `*_label-lesion_roi.nii.gz` on the T1w grid before running Step 1.1.
