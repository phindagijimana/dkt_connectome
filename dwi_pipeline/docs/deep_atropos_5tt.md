# Deep Atropos native-T1 5TT (optional Step 3.1 branch)

Optional **base five-tissue-type (5TT) source** for lesion-aware ACT when you want tissue
priors built on **native BIDS T1w** instead of the default QSIRecon ACPC HSVS grid.

**Default:** `--act-5tt-source hsvs` (QSIRecon ACT-HSVS on ACPC).  
**This branch:** `--act-5tt-source deep-atropos-native`.

Operational reference: [Pipeline steps § Step 3.1](pipeline_steps.md#step-31-lesion-aware-act-optional) ·
[Step 3.1 methods](methods/step3_1_lesion_act.md) · [Lesion-aware tractography](lesion_aware.md) ·
[Containers](containers.md).

---

## When to use it

| Goal | Recommended flag |
|------|------------------|
| Production factorial arms (TrackTBI, LeAPP-style) | `hsvs` (default) |
| Sensitivity analysis: native-T1 tissue priors vs HSVS ACPC | `deep-atropos-native` |
| Cohort with precomputed Deep Atropos segmentations | `deep-atropos-native` + `--deep-atropos-seg-mode import` |
| Pilot without external segs | `deep-atropos-native` + `--deep-atropos-seg-mode generate` |

Both paths share the same **pathology edit** after the base 5TT is loaded: resample the
**original BIDS lesion mask** → `5ttedit -path` → clip and renormalize tissue fractions →
matched iFOD2 + SIFT2 in `dkt_lesion_act.sif` (LeAPP-style; Bey et al. 2024).

---

## Workflow sketch (Step 3.1 branch)

```text
                    ┌── default: QSIRecon HSVS 5TT (ACPC)
                    │
Step 3 QSIRecon ────┼── optional Deep Atropos branch:
                    │       Step 3.2 (segmentation)  ANTsPyNet deep_atropos on native T1w
                    │            ↓
                    │       Step 3.2    seg → base_5tt_native.mif
                    │            ↓
                    └──► Step 3.1  lesion-aware ACT (5ttedit + tckgen + SIFT2)
                              ↓
                         Step 4 connectome (uses rebuilt tractogram)
```

| Sub-step | Snakemake rule | Container | Output |
|----------|----------------|-----------|--------|
| **3.2-seg** | `deep_atropos_seg` | `dkt_deep_atropos_seg.sif` | `deep_atropos_seg/sub-<ID>/desc-deepatropos_seg.nii.gz` |
| **3.2** | `deep_atropos_5tt` | `dkt_deep_atropos.sif` | `deep_atropos/sub-<ID>/base_5tt_native.mif` |
| **3.1** | `lesion_aware_act` | `dkt_lesion_act.sif` | `lesion_aware_act/sub-<ID>/model-ifod2_streamlines.tck`, SIFT2 weights, JSON |

Rules activate only when `act.mode=lesion-aware` and `act.five_tt_source=deep-atropos-native`.

---

## Segmentation modes

| Mode | Config / flag | Behavior |
|------|---------------|----------|
| `auto` (default) | `--deep-atropos-seg-mode auto` | Use external seg if found; else run ANTsPyNet |
| `import` | `--deep-atropos-seg-mode import` | Require external seg; skip ANTsPyNet |
| `generate` | `--deep-atropos-seg-mode generate` | Always run ANTsPyNet on native BIDS T1w |

**Discovery order:** `--deep-atropos-seg` / `act.deep_atropos.segmentation` →
`derivatives/deep-atropos/` → `<results>/deep_atropos_seg/sub-<ID>/`.

---

## Configuration

```yaml
# workflow/config/config.local.yaml
act:
  mode: lesion-aware
  five_tt_source: deep-atropos-native   # hsvs | deep-atropos-native
  deep_atropos:
    segmentation_mode: auto             # auto | import | generate
    antsxnet_cache: /path/to/shared/.cache/antsxnet   # required for auto/generate on HPC
```

Environment overrides: `ACT_FIVE_TT_SOURCE`, `DEEP_ATROPOS_SEG`, `DEEP_ATROPOS_SEG_MODE`,
`DEEP_ATROPOS_ANTSXNET_CACHE` — see [Configuration](configuration.md).

---

## HPC — ANTsXNet weight cache

First ANTsPyNet run downloads model weights (~few GB). On some compute nodes, Figshare WAF
blocks direct downloads. **Set a persistent cache** and prefetch once from a login node:

```bash
python3 dwi_pipeline/scripts/run_deep_atropos_seg.py \
  --prefetch-only \
  --cache-dir /path/to/shared/.cache/antsxnet
```

Preflight **requires** `act.deep_atropos.antsxnet_cache` when seg mode is `auto` or `generate`.

Details: [Troubleshooting § Step 3.1](troubleshooting.md#step-31-lesion-aware-act) ·
[containers/deep_atropos_seg README on GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/deep_atropos_seg/README.md).

---

## CLI examples

```bash
# Deep Atropos native path (auto-discover or generate seg)
bash workflow/run_subject.sh act SUBJECT \
  --recon-session ses-1 \
  --act-mode lesion-aware \
  --act-5tt-source deep-atropos-native \
  --deep-atropos-seg-mode auto

# Import precomputed segmentation
bash workflow/run_subject.sh act SUBJECT \
  --act-mode lesion-aware \
  --act-5tt-source deep-atropos-native \
  --deep-atropos-seg-mode import \
  --deep-atropos-seg /path/to/derivatives/deep-atropos/sub-SUBJECT/ses-1/anat/seg.nii.gz
```

Slurm: pass the same flags via `submit.sh` — [Usage](usage.md).

---

## Containers and registry pins

| Image | Tag (default pin) |
|-------|-------------------|
| `ghcr.io/phindagijimana/dkt-lesion-act` | `0.1.0` |
| `ghcr.io/phindagijimana/dkt-deep-atropos` | `0.1.0` |
| `ghcr.io/phindagijimana/dkt-deep-atropos-seg` | `0.1.0` |

Install: `bash install.sh --mode act` — [Containers](containers.md).

---

## Cross-source factorial design

On inpainted experiment arms (`neurolit-lesion`, `vbt-lesion`), Deep Atropos seg and base 5TT
use **original BIDS T1w**, while the lesion ROI for `5ttedit` remains the **original BIDS
mask**. This is intentional: anatomical mitigation (Step 1.1) and pathology ACT (Step 3.1) are
orthogonal factors. Provenance is recorded in `lesion_aware_act.json`.

See [Lesion-aware § Intentional cross-source design](lesion_aware.md#intentional-cross-source-design-on--lesion-inpainted-arms).

---

## See also

- [Step 3.1 — Lesion-aware ACT (methods)](methods/step3_1_lesion_act.md)
- [Publication strategy](publication_strategy.md) — when to report HSVS vs Deep Atropos as a sensitivity analysis
- [Snakemake workflow](snakemake_workflow.md) — `target_act` and plugin rules
