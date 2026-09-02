# Step 4.1 — Structural disconnectome

**Theory and methods** for lesion-aware connectome excision and disconnection quantification. Operational details: [Disconnectome](../disconnectome.md) · [Pipeline steps § Step 4.1](../pipeline_steps.md#step-41-disconnectome-optional).

---

## Background

A standard structural connectome describes **intact** white-matter connectivity. After focal brain injury, some pathways are **interrupted** — streamlines that would have passed through lesioned tissue are absent or rerouted. The **structural disconnectome** quantifies how much connectivity is lost relative to the pre-lesion (or contralateral) graph.

This step is inspired by **structural disconnectome mapping** (Griffis et al. 2019) and network-modification / virtual-lesion approaches (Kuceyeski et al. 2013). It runs **after Step 4** and does **not modify** the primary `dkt_connectome.csv`.

**Default:** off — pass `--disconnection` to enable (method under validation).

---

## Prerequisites

Step 4.1 consumes artifacts from Steps 1.1, 3, and 4:

| Input | Source step | Purpose |
|-------|-------------|---------|
| `lesion_mask_prepared.nii.gz` | 1.1 | Binary lesion definition on T1w |
| `*_streamlines.tck.gz` (+ optional SIFT2 weights) | 3 | Tractogram |
| `nodes.mif`, `dkt_connectome.csv` | 4 | Parcellation + primary connectome |
| `fs_to_preproc_T1w_0GenericAffine.mat` (or legacy `native_to_preproc_T1w_0GenericAffine.mat`), `dwiref` | 4 | Warp lesion to tractography grid |

Requires a prepared lesion mask from inpainting (Step 1.1). Subjects without a BIDS lesion mask skip this step entirely.

---

## Lesion definition

The **primary lesion** is the **binary union** of selected labels from `lesion_mask_prepared.json`:

| Label | Default meaning |
|-------|-----------------|
| 1 | Core |
| 2 | Oedema / FLAIR hyperintensity |

Default: core + oedema, **no erosion** (`--lesion-erode-voxels 0`) — definition-faithful to the traced mask.

Sensitivities: `--lesion-erode-voxels 1` (border robustness); `--core-only` (exclude oedema).

The lesion is warped to the DWI/`nodes.mif` grid using the same affine chain as Step 4 (ANTs: T1w → preproc T1w → `dwiref` resample).

---

## Options A, B, and C

Three complementary strategies estimate **spared connectivity** after injury:

### Option A — Parcellation excision

Voxels overlapping the lesion are **removed from the parcellation** (`nodes × ¬lesion`):

```text
nodes_A_parcexcised.mif  →  tck2connectome (full tractogram)  →  dkt_connectome_A_parcexcised.csv
```

Streamlines still pass through the physical lesion region, but no node is assigned there — edges involving excised tissue are redistributed to remaining nodes.

### Option B — Streamline exclusion

Streamlines that **intersect the lesion mask** are removed (`tckedit -exclude lesion`):

```text
streamlines_B_nolesion.tck  →  tck2connectome (original nodes.mif)  →  dkt_connectome_B_streamexcluded.csv
```

This models **physical pathway interruption** without changing the parcellation.

### Option C — Both A and B

Excised parcellation **and** lesion-excluded tractogram:

```text
streamlines_B_nolesion.tck + nodes_A_parcexcised.mif  →  dkt_connectome_C_both.csv
```

**Default spared connectome for disconnection matrix:** Option C (`--disconnection-spared C`).

---

## Disconnection matrix

The **disconnection matrix** `D` compares the Step 4 **primary** connectome to a **spared**
connectome built under Option A, B, or C. For each off-diagonal edge between DKT nodes
*i* and *j*:

```{math}
D_{ij} = 1 - \frac{W^{\mathrm{spared}}_{ij}}{W^{\mathrm{primary}}_{ij}}
```

| Symbol | Source file | Meaning |
|--------|-------------|---------|
| {math}`W^{\mathrm{primary}}_{ij}` | `connectomes/sub-<ID>/dkt_connectome.csv` | Step 4 edge weight (default: streamline **count**) |
| {math}`W^{\mathrm{spared}}_{ij}` | Option **A**, **B**, or **C** CSV under `disconnectome/` | Spared connectivity after parc excision, streamline exclusion, or both |
| {math}`D_{ij}` | `disconnection_matrix.csv` (and `_A`, `_B`, `_C` variants) | Fractional connectivity **loss** on that edge |

**Which spared matrix is used?** By default, `disconnection_matrix.csv` uses **Option C**
(`--disconnection-spared C`). Options A and B are always written when enabled; each has
its own `disconnection_matrix_{A,B,C}.csv`.

### How edges are evaluated

The implementation (`run_disconnectome.py`) applies the formula only where the primary
edge exists:

- If {math}`W^{\mathrm{primary}}_{ij} = 0`, then {math}`D_{ij} = 0` (undefined ratio → treated as no
  primary connection to compare).
- If {math}`W^{\mathrm{primary}}_{ij} > 0`, compute the ratio and **clip** {math}`D_{ij}` to {math}`[0, 1]`.
  Values above 1 can occur when {math}`W^{\mathrm{spared}}_{ij} > W^{\mathrm{primary}}_{ij}`
  (most often under Option A parc excision); clipping keeps the exported matrix in range.
- The diagonal is zero (no self-connections).

### Interpretation

| Value | Meaning |
|-------|---------|
| {math}`D_{ij} = 0` | No loss on edge *i*–*j* relative to primary (spared equals primary, or primary was zero) |
| {math}`0 < D_{ij} < 1` | Partial loss — some but not all primary connectivity remains in the spared graph |
| {math}`D_{ij} = 1` | Complete loss on that edge (spared weight is zero, or ratio clipped to 1) |

Step 4 **`dkt_connectome.csv` is never modified**; disconnectome is a post-hoc comparison.

### Output files

Under `connectomes/sub-<ID>/disconnectome/`:

```text
dkt_connectome_A_parcexcised.csv      # Option A spared matrix
dkt_connectome_B_streamexcluded.csv     # Option B spared matrix
dkt_connectome_C_both.csv               # Option C spared matrix (default for D)
disconnection_matrix.csv                # D using --disconnection-spared (default C)
disconnection_matrix_{A,B,C}.csv        # D for each option
disconnectome.json                      # provenance, weighting, spared choice
disconnectome_qc.html                   # per-subject QC report
```

**Weighting:** Step 4 and Step 4.1 must use the same edge definition. Default is
**streamline counts** (`count`); optional `--connectome-weighting sift2` applies to both
steps. Mismatched weighting invalidates $D$ — see [Integrity QC](../disconnectome.md#integrity-qc).

---

## Relationship to inpainting

| Step | What it changes |
|------|-----------------|
| **1.1 Inpaint** | T1w appearance for recon — improves parcellation around lesions |
| **4 Primary connectome** | Counts streamlines on **unmodified** tractogram with warped labels |
| **4.1 Disconnectome** | Post-hoc excision/exclusion — quantifies lesion-specific disconnection |

Inpainting and disconnectome address **different questions**: inpainting improves anatomical label quality; disconnectome measures connectivity loss attributable to the lesion.

---

## Quality control

Per-subject HTML: `connectomes/sub-<ID>/disconnectome/disconnectome_qc.html`

Checks include matrix symmetry, non-negativity, disconnection bounds [0,1], and comparison against validated TBI test subjects. See [Disconnectome § Integrity QC](../disconnectome.md#integrity-qc).

Cohort index: `./run BIDS OUT group` → `disconnectome_cohort_qc.html`.

---

## Implementation substeps

Full specification: [Inpainting/disconnection.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/disconnection.md) · Developer notes: [pipeline_science.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/pipeline_science.md).

| Substep | Action | Output |
|---------|--------|--------|
| **4.1a** | Binary union of lesion labels on T1w | `lesion_binary.nii.gz` |
| **4.1b** | Warp lesion → `dwiref` / `nodes.mif` grid | `lesion_in_dwi.mif` |
| **4.1c** | ROI overlap metrics | `lesion_roi_metrics.csv` |
| **4.1d** | Option A: parc excision + tck2connectome | `connectome_A.csv` |
| **4.1e** | Option B: tckedit exclude + tck2connectome | `connectome_B.csv` |
| **4.1f** | Option C: B tractogram + A parcellation | `connectome_C.csv` |
| **4.1g** | D = 1 − spared/primary | `disconnection_matrix.csv` |

The primary `dkt_connectome.csv` from Step 4 is **never modified**.

---

## References

| Topic | Citation | Link |
|-------|----------|------|
| **Structural disconnectome (primary)** | Griffis JC, et al. *Cell Reports* 2019 | [10.1016/j.celrep.2019.10.058](https://doi.org/10.1016/j.celrep.2019.10.058) |
| Network modification / virtual lesion | Kuceyeski R, et al. *NeuroImage: Clinical* 2013 | [10.1016/j.nicl.2012.10.003](https://doi.org/10.1016/j.nicl.2012.10.003) |
| TBI connectivity review | Hayes JP, et al. *JINS* 2016 | [10.1017/S1355617715000740](https://doi.org/10.1017/S1355617715000740) |

Full table: [References § Step 4.1](../references.md#step-41-disconnectome-optional) · Implementation spec: [Inpainting/disconnection.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/disconnection.md).

---

## See also

- [Disconnectome](../disconnectome.md) — CLI flags and defaults
- [Lesion segmentation](../lesion_segmentation.md)
- [Step 1.1 — Inpainting](step1_1_inpaint.md)
- [Step 4 — DKT connectome](step4_connectome.md)
