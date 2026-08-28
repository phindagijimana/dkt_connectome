# Deep Atropos native-T1 5TT (maintainer reference)

Reference for optional **native-T1 Deep Atropos** as the Step 3.5 ACT five-tissue-type
(5TT) source, alongside the default **QSIRecon ACPC HSVS** path.

**Public doc:** [Deep Atropos native-T1 5TT](../deep_atropos_5tt.md) (Read the Docs).

**Status:** **Implemented** (Aug 2026). Pilot on `sub-TBI011011` with `--deep-atropos-seg-mode generate`.  
**Related:** [Step 3.5 methods](../methods/step3_5_lesion_act.md) · [Publication strategy § Paper 3](../publication_strategy.md).

---

## Problem solved

| Current default (`hsvs`) | Pain point |
|--------------------------|------------|
| QSIRecon **ACPC HSVS** 5TT from inpainted recon | Lesion mask on **native BIDS T1w**; 5TT in **ACPC** → extra warp chain |
| ACPC-first HSVS workflow (`5ttedit` on ACPC grid) | Works; production default for factorial arms |
| MRtrix 3.0.4 in `qsirecon.sif` | **No `5ttgen deep_atropos`** |

Native-T1 branch: segment on **native T1w** with **ANTsPyNet Deep Atropos**, build ACT 5TT,
assign pathology from the **original lesion ROI on the same grid**, then resample to `dwiref`
for `tckgen`. Cohort segs can be imported when available.

---

## Three-container architecture

```text
dkt_deep_atropos_seg.sif   Step 3.5a-seg — ANTsPyNet deep_atropos → integer seg (0–6)
        ↓
dkt_deep_atropos.sif       Step 3.5a     — seg → base_5tt_native.mif (Python mapper)
        ↓
dkt_lesion_act.sif         Step 3.5      — 5ttedit -path, QA, dwiref resample, tckgen + SIFT2
```

Default path unchanged: `act.five_tt_source: hsvs` uses only `dkt_lesion_act.sif` with QSIRecon HSVS.

---

## CLI / config

```bash
bash workflow/run_subject.sh act TBI011011 \
  --recon-session 2WK \
  --act-mode lesion-aware \
  --act-5tt-source deep-atropos-native \
  --deep-atropos-seg-mode auto    # auto | import | generate
```

| Key | Env | Default | Values |
|-----|-----|---------|--------|
| `act.five_tt_source` | `ACT_FIVE_TT_SOURCE` | `hsvs` | `hsvs` \| `deep-atropos-native` |
| `act.deep_atropos.segmentation` | `DEEP_ATROPOS_SEG` | *(unset)* | Path to seg (supports `{subject}` `{session}`) |
| `act.deep_atropos.segmentation_mode` | `DEEP_ATROPOS_SEG_MODE` | `auto` | `auto` \| `import` \| `generate` |
| `act.deep_atropos.antsxnet_cache` | `DEEP_ATROPOS_ANTSXNET_CACHE` | *(unset)* | Persistent ANTsXNet weight cache (HPC) |

**Rules:**

- `--act-5tt-source deep-atropos-native` requires `--act-mode lesion-aware` and a lesion mask.
- Ignored when `act.mode=standard`.
- Does **not** replace Step 2 recon or QSIRecon FOD — only the **base 5TT** for Step 3.5.

Slurm: same flags via `submit.sh` (`--act-5tt-source`, `--deep-atropos-seg`, `--deep-atropos-seg-mode`).

---

## Segmentation discovery (`segmentation_mode`)

| Mode | Behavior |
|------|----------|
| `auto` | Config/`DEEP_ATROPOS_SEG` → `derivatives/deep-atropos/` → run ANTsPyNet |
| `import` | External seg required; fail if missing |
| `generate` | Always run ANTsPyNet (ignore external files) |

Canonical pipeline output: `<results>/deep_atropos_seg/sub-<ID>/desc-deepatropos_seg.nii.gz`.

Optional BIDS derivative layout:

```text
derivatives/deep-atropos/sub-<ID>/ses-<SES>/anat/
  sub-<ID>_ses-<SES>_desc-deepatropos_seg.nii.gz
```

Implemented in `workflow/rules/common.smk` (`find_deep_atropos_segmentation`).

---

## Spatial workflow (native path)

```text
Deep Atropos seg (native T1w grid)
        │
        ├─► convert_deep_atropos_to_5tt.py → base_5tt_native.mif
        │
BIDS lesion ROI (native T1w) ──► prepare_lesion_mask.py
        │
        └─► 5ttedit -path on NATIVE grid  ◄── same grid, no ACPC warp
                 │
                 ├─ pathology QA (mrstats numeric)
                 │
                 └─► resample edited 5TT → dwiref
                        via desc-preproc_T1w + mrtransform -template dwiref
                        clip + renormalize (sum to 1 along axis 4)
                 │
WM FOD (dwiref) ──► tckgen -act + tcksift2
```

**Difference from `hsvs`:** skip ACPC HSVS and `from-T1wNative_to-T1wACPC` for the
`5ttedit` step; lesion and base 5TT already share native T1w.

The shared pathology recipe (resample contusion → inject 5TT channel 5 → renormalize) is identical; only the segmentation grid differs.

---

## Snakemake rules

| Rule file | Target | Container |
|-----------|--------|-----------|
| `deep_atropos_seg.smk` | `deep_atropos_seg/sub-<ID>/desc-deepatropos_seg.nii.gz` | `dkt_deep_atropos_seg.sif` |
| `deep_atropos_5tt.smk` | `deep_atropos/sub-<ID>/base_5tt_native.mif` | `dkt_deep_atropos.sif` |
| `lesion_aware_act.smk` | `lesion_aware_act/sub-<ID>/…` | `dkt_lesion_act.sif` |

Included in `workflow/Snakefile` before `lesion_aware_act.smk`. Rules activate only when `act.five_tt_source=deep-atropos-native`.

**Note:** QSIRecon outputs may be symlinked into experiment arms; `find -L` is used when discovering WM FOD under `qsirecon_single_run_output`.

---

## Conversion utility

`scripts/convert_deep_atropos_to_5tt.py`:

- Input: Deep Atropos integer seg (labels 0–6) + BIDS T1w reference
- Output: 4D NIfTI → `base_5tt_native.mif` (MRtrix ACT channel order)
- Skips scipy resample when seg and T1w share grid/affine; otherwise uses `nibabel.processing`
- Label map matches MRtrix `5ttgen deep_atropos` convention

Tests: `tests/test_convert_deep_atropos_to_5tt.py`.

---

## HPC / ANTsXNet cache

First ANTsPyNet run downloads model weights (~few GB). On compute nodes, Figshare WAF may block
`figshare.com/ndownloader` URLs. Mitigations implemented in `scripts/run_deep_atropos_seg.py`:

- Rewrite URLs to `ndownloader.figshare.com`
- Call `antspynet.set_antsxnet_cache_directory()`
- Prefetch required weights into bind-mounted cache
- **`--prefetch-only`** CLI for login-node warmup before batch submit

**Dev override:** set `ACT_BIND_MOUNT_DEV=1` to bind-mount repo Python scripts over
in-container copies (pilot iteration only; default off for published runs).

Set persistent cache:

```yaml
act:
  deep_atropos:
    antsxnet_cache: /path/to/shared/.cache/antsxnet
```

Or `DEEP_ATROPOS_ANTSXNET_CACHE` in Slurm.

---

## Provenance (`lesion_aware_act.json`)

When `deep-atropos-native`:

```json
{
  "five_tt_source": "deep-atropos-native",
  "deep_atropos_segmentation": ".../desc-deepatropos_seg.nii.gz",
  "spatial_workflow": "native_5tt_edit_then_dwiref_resample",
  "lesion_warp_method": "native_t1w_direct"
}
```

Plus existing factorial fields (`cross_source_factorial_intentional`, etc.).

---

## Pilot example (isolated arm)

```bash
# Reuse qsiprep/qsirecon from neurolit-lesion via symlinks; fresh deep-atropos outputs
RESULTS_ROOT=.../arms/deep-atropos-pilot \
DEEP_ATROPOS_ANTSXNET_CACHE=.../.cache/antsxnet \
  bash workflow/run_subject.sh act TBI011011 \
    --recon-session 2WK \
    --act-mode lesion-aware \
    --act-5tt-source deep-atropos-native \
    --deep-atropos-seg-mode generate
```

---

## Explicit non-goals

- Replacing QSIRecon HSVS for **`act.mode=standard`** or non-lesion runs
- New experiment arm names — use `--act-5tt-source` on existing `*-lesion` arms
- Changing Step 4 parcellation (still FastSurfer DKT from inpainted recon on factorial arms)

---

## Open questions (cohort segmentation contract)

1. Exact filename pattern and root directory for external Deep Atropos outputs?
2. Confirm Deep Atropos was run on **original BIDS T1w** (pipeline assumes yes).
3. Prefer `import` mode once cohort paths are on NFS?

---

## See also

- [containers/deep_atropos/README.md](../../containers/deep_atropos/README.md)
- [containers/deep_atropos_seg/README.md](../../containers/deep_atropos_seg/README.md)
- [containers/lesion_act/run_lesion_aware_act.sh](../../containers/lesion_act/run_lesion_aware_act.sh)
- ANTsPyNet Deep Atropos: [ANTsPyNet repo](https://github.com/ANTsX/ANTsPyNet/)
