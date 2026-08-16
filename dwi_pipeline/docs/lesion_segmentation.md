# Lesion segmentation

How lesion masks enter the pipeline — from BIDS annotation through inpainting (Step 1.5) to optional disconnectome (Step 4.5).

---

## BIDS lesion mask

Place a multi-label ROI next to the session T1w:

```text
sub-<ID>/ses-<Y>/anat/
  sub-<ID>_ses-<Y>_T1w.nii.gz
  sub-<ID>_ses-<Y>_T1w_label-lesion_roi.nii.gz
```

Default labels (Step 1.5 / 4.5):

| Value | Meaning |
|-------|---------|
| 0 | Background |
| 1 | Core |
| 2 | Oedema / FLAIR hyperintensity |

Format details: [Inpainting/bids_mask_format.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/bids_mask_format.md).

---

## Pipeline stages that use the mask

| Step | When | What happens |
|------|------|--------------|
| **1 — QSIPrep** | Always if mask present | Cost-function masking during registration |
| **1.5 — Inpaint** | Auto when mask found | neuroLIT fills lesion on T1w before recon |
| **4.5 — Disconnectome** | Manual post-hoc | Binary union excision + disconnection matrix |

Subjects **without** a mask skip Steps 1.5 and 4.5. Step 4.5 additionally requires **`--disconnection`**. See [Inpainting/no_mask_behavior.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/no_mask_behavior.md).

---

## Step 1.5 (inpainting)

- **Trigger:** sibling `*_label-lesion_roi.nii.gz` in BIDS
- **Tool:** [neuroLIT](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/lit/README.md) (`lit_0.6.0.sif`)
- **Output:** `inpainted/.../inpainting_result.nii.gz` used by Steps 2 and 4

```bash
bash workflow/run_subject.sh inpaint 009
bash workflow/run_subject.sh all 009 --no-inpaint   # force skip
```

QC: `scripts/check_inpainting.py` — see [Inpainting/pipeline_usage.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/pipeline_usage.md).

---

## Step 4.5 (disconnectome)

**Opt-in:** pass `--disconnection` on a full pipeline run, or use `--mode disconnectome` / `run_subject.sh disconnectome`.

**Primary lesion definition:** binary union of core + oedema, **no erosion**.

```bash
python3 dwi_pipeline/scripts/run_disconnectome.py \
  --results-root /path/to/derivatives \
  --subject 009
```

Method: [Disconnectome](disconnectome.md) · Full spec: [Inpainting/disconnection.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/disconnection.md).

---

## Documentation index

All lesion / excision docs live under [`Inpainting/`](https://github.com/phindagijimana/dkt_connectome/tree/main/dwi_pipeline/Inpainting):

| Doc | Topic |
|-----|--------|
| [lesion_masks.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/lesion_masks.md) | Master index |
| [connectome_excision_overview.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/connectome_excision_overview.md) | Why excise after connectome |
| [connectome_excision_option_a.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/connectome_excision_option_a.md) | Parc excision |
| [connectome_excision_option_b.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/connectome_excision_option_b.md) | Streamline exclusion |
| [connectome_excision_option_c.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/connectome_excision_option_c.md) | Both A and B |
| [connectome_excision_recommendations.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/connectome_excision_recommendations.md) | Reporting guidance |

---

## Automated segmentation (future / external)

This pipeline expects **manual** BIDS ROI masks today. For automated alternatives (LINDA, AutoDDPM, etc.), generate a compatible `*_label-lesion_roi.nii.gz` on the T1w grid before running Step 1.5. Literature: [Inpainting/connectome_excision_literature.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/connectome_excision_literature.md).
