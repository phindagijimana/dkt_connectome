# Step 4.5 — Structural disconnectome

**Theory and methods** for lesion-aware connectome excision and disconnection quantification. Operational details: [Disconnectome](../disconnectome.md) · [Pipeline steps § Step 4.5](../pipeline_steps.md#step-45-disconnectome-optional).

---

## Background

A standard structural connectome describes **intact** white-matter connectivity. After focal brain injury, some pathways are **interrupted** — streamlines that would have passed through lesioned tissue are absent or rerouted. The **structural disconnectome** quantifies how much connectivity is lost relative to the pre-lesion (or contralateral) graph.

This step is inspired by **structural disconnectome mapping** (Griffis et al. 2019) and network-modification / virtual-lesion approaches (Kuceyeski et al. 2013). It runs **after Step 4** and does **not modify** the primary `dkt_connectome.csv`.

**Default:** off — pass `--disconnection` to enable (method under validation).

---

## Prerequisites

Step 4.5 consumes artifacts from Steps 1.5, 3, and 4:

| Input | Source step | Purpose |
|-------|-------------|---------|
| `lesion_mask_prepared.nii.gz` | 1.5 | Binary lesion definition on T1w |
| `*_streamlines.tck.gz` (+ optional SIFT2 weights) | 3 | Tractogram |
| `nodes.mif`, `dkt_connectome.csv` | 4 | Parcellation + primary connectome |
| `native_to_preproc_T1w_0GenericAffine.mat`, `dwiref` | 4 | Warp lesion to tractography grid |

Requires a prepared lesion mask from inpainting (Step 1.5). Subjects without a BIDS lesion mask skip this step entirely.

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
nodes_A_parcexcised.mif  →  tck2connectome (full tractogram)  →  connectome_A.csv
```

Streamlines still pass through the physical lesion region, but no node is assigned there — edges involving excised tissue are redistributed to remaining nodes.

### Option B — Streamline exclusion

Streamlines that **intersect the lesion mask** are removed (`tckedit -exclude lesion`):

```text
streamlines_B_nolesion.tck  →  tck2connectome (original nodes.mif)  →  connectome_B.csv
```

This models **physical pathway interruption** without changing the parcellation.

### Option C — Both A and B

Excised parcellation **and** lesion-excluded tractogram:

```text
streamlines_B_nolesion.tck + nodes_A_parcexcised.mif  →  connectome_C.csv
```

**Default spared connectome for disconnection matrix:** Option C (`--disconnection-spared C`).

---

## Disconnection matrix

The **disconnection matrix D** quantifies fractional connectivity loss:

\[
D_{ij} = 1 - \frac{W^{\mathrm{spared}}_{ij}}{W^{\mathrm{primary}}_{ij}}
\]

where \(W^{\mathrm{primary}}\) is the Step 4 connectome and \(W^{\mathrm{spared}}\) is the chosen Option A, B, or C matrix.

- \(D_{ij} = 0\): no disconnection between nodes *i* and *j*
- \(D_{ij} = 1\): complete loss of connectivity
- Diagonal excluded (no self-connections)

Outputs under `connectomes/sub-<ID>/disconnectome/`:

```text
disconnection_matrix.csv
connectome_{A,B,C}.csv
disconnectome.json          # provenance and parameters
disconnectome_qc.html       # per-subject QC report
```

Weighting default matches Step 4 (**streamline counts**); optional `--connectome-weighting sift2`.

---

## Relationship to inpainting

| Step | What it changes |
|------|-----------------|
| **1.5 Inpaint** | T1w appearance for recon — improves parcellation around lesions |
| **4 Primary connectome** | Counts streamlines on **unmodified** tractogram with warped labels |
| **4.5 Disconnectome** | Post-hoc excision/exclusion — quantifies lesion-specific disconnection |

Inpainting and disconnectome address **different questions**: inpainting improves anatomical label quality; disconnectome measures connectivity loss attributable to the lesion.

---

## Quality control

Per-subject HTML: `connectomes/sub-<ID>/disconnectome/disconnectome_qc.html`

Checks include matrix symmetry, non-negativity, disconnection bounds [0,1], and comparison against validated TBI test subjects. See [Integrity QC](../integrity_qc.md).

Cohort index: `./run BIDS OUT group` → `disconnectome_cohort_qc.html`.

---

## References

| Topic | Citation | Link |
|-------|----------|------|
| **Structural disconnectome (primary)** | Griffis JC, et al. *Cell Reports* 2019 | [10.1016/j.celrep.2019.10.058](https://doi.org/10.1016/j.celrep.2019.10.058) |
| Network modification / virtual lesion | Kuceyeski R, et al. *NeuroImage: Clinical* 2013 | [10.1016/j.nicl.2012.10.003](https://doi.org/10.1016/j.nicl.2012.10.003) |
| TBI connectivity review | Hayes JP, et al. *JINS* 2016 | [10.1017/S1355617715000740](https://doi.org/10.1017/S1355617715000740) |

Full table: [References § Step 4.5](../references.md#step-45-disconnectome-optional) · Implementation spec: [Inpainting/disconnection.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/disconnection.md).

---

## See also

- [Disconnectome](../disconnectome.md) — CLI flags and defaults
- [Lesion segmentation](../lesion_segmentation.md)
- [Step 1.5 — Inpainting](step1_5_inpaint.md)
- [Step 4 — DKT connectome](step4_connectome.md)
