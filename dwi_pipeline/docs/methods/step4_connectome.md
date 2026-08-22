# Step 4 — DKT structural connectome

**Theory and methods** for region-to-region connectivity matrix generation. Operational details: [Pipeline steps § Step 4](../pipeline_steps.md#step-4-connectome) · [Outputs](../outputs.md).

---

## Background

A **structural connectome** is a graph where **nodes** are brain regions and **edges** are structural connections (typically white-matter pathways). In streamline tractography, edge weight is the number of streamlines (or SIFT2-weighted sum) connecting each node pair.

Step 4 builds a **subject-native anatomical connectome**: FreeSurfer DKT labels from Step 2 are warped onto the tractography grid from Step 3, then MRtrix3 `tck2connectome` counts streamlines between every pair of regions.

**Default output:** symmetric **78×78** matrix (`dkt_connectome.csv`) using **streamline counts**.

---

## Spatial alignment

FreeSurfer parcellations live in **conformed 256³ space**. Streamlines from QSIRecon live on the **`dwiref` grid** (~2 mm, QSIPrep T1w-derived). Step 4 aligns labels through three stages:

```text
aparc.DKTatlas+aseg.mgz  (FreeSurfer conformed)
        │  mri_label2vol --temp rawavg.mgz
        ▼
Parcellation on native T1w grid (rawavg)
        │  ANTs affine: BIDS/inpainted T1w → desc-preproc_T1w
        ▼
Parcellation in QSIPrep T1w space
        │  ANTs GenericLabel resample → dwiref
        ▼
nodes.mif on tractography grid
        │  labelconvert (FS LUT → fs_dkt.txt)
        ▼
tck2connectome → dkt_connectome.csv
```

**Why not QSIPrep's packaged FS transform alone?** QSIPrep's FreeSurfer-native transform may target a reoriented frame that does not match `rawavg.mgz`. Step 4 uses an **empirical affine** between the T1w used for registration (inpainted or BIDS) and `desc-preproc_T1w` after `mri_label2vol`, which aligns labels with tractography on real data (Avants et al. 2011).

---

## Label conversion

`labelconvert` maps FreeSurfer integer labels to MRtrix compact indices using **region names** (via `FreeSurferColorLUT.txt`), not raw integers.

| LUT | Nodes | Segmentation required |
|-----|-------|----------------------|
| `fs_dkt.txt` (default) | 78 | `aparc.DKTatlas+aseg.mgz` (or FastSurfer DKT `aparc+aseg.mgz`) |
| `fs_default.txt` | 84 | `aparc+aseg.mgz` from `recon-all` only |

Names absent from the target table become 0 and are excluded from the graph. Step 4 records the segmentation file read, node count, and empty-node warnings in **`parcellation.json`**.

---

## Connectome construction

**`tck2connectome`** options in this pipeline:

- **`-symmetric`** — undirected graph (edge (i,j) = edge (j,i))
- **`-zero_diagonal`** — no self-connections
- **Default assignment** — streamline **counts** per node pair
- **Optional** — SIFT2-weighted sums (`--connectome-weighting sift2`)

Primary output:

```text
connectomes/sub-<ID>/
  dkt_connectome.csv       # 78×78 symmetric matrix (default)
  nodes.mif                # parcellation on dwiref grid
  parcellation.json        # provenance: atlas, LUT, empty nodes
  native_to_preproc_T1w_0GenericAffine.mat   # reused by Step 4.5
```

---

## DKT vs. DK matrices

| Matrix | Nodes | When available |
|--------|-------|----------------|
| `dkt_connectome.csv` | 78 | Default for all subjects |
| `dk_connectome.csv` | 84 | `CONNECTOME_PARCELLATION=dk` on `recon-all` trees only |

**Do not pool DK and DKT connectomes** in one analysis — node sets and dimensions differ. DKT is not simply DK with six rows removed; DKT merges bankssts and pole regions into neighbouring gyri.

Measured impact of using the wrong segmentation+LUT combination: ~3.4% of streamlines mis-assigned and 91% of matrix cells differ from true DKT on test subjects. See [Step 2 § DKT vs. DK](step2_recon.md#dkt-vs-dk-parcellation).

---

## Multi-measure connectomes (one tractogram)

From the **same** iFOD2 tractogram and DKT node image, Step 4 writes five edge definitions (IDEAS II and connectomics literature use multiple strength measures because no single metric is universally accepted; Jones et al. 2013):

| Output file | Measure | Interpretation |
|-------------|---------|----------------|
| `dkt_connectome_count.csv` | Streamline **count** | Raw connectivity density; default primary (`dkt_connectome.csv`) |
| `dkt_connectome_sift2.csv` | **SIFT2** weight sum | Global density-corrected connectivity (Smith et al. 2015) |
| `dkt_connectome_meanlength.csv` | Mean streamline **length** (mm) | Path length between regions |
| `dkt_connectome_meanfa.csv` | Mean **FA** along streamlines | Microstructure sampled on reconstructed paths |
| `dkt_connectome_meanmd.csv` | Mean **MD** along streamlines | Microstructure sampled on reconstructed paths |

**Important:** MeanFA and MeanMD describe diffusion properties **along tractography paths**, not independent histological ground truth. They must not be interpreted as interchangeable with Count or SIFT2 “strength” (Jones et al. 2013).

Voxelwise **`dkt_desc-FA_dwi.nii.gz`** and **`dkt_desc-MD_dwi.nii.gz`** are derived from QSIPrep preprocessed DWI via `dwi2tensor` / `tensor2metric` for tract sampling.

### Optional deterministic tractography (`--tractography-model both`)

**SD_STREAM** (Tournier et al. 2019) provides a deterministic complement to probabilistic iFOD2. The pipeline writes parallel `dkt_model-SDSTREAM_connectome_*.csv` files using the same atlas and measure definitions. Agreement between iFOD2 and SD_STREAM can support robustness claims; disagreement in crossing-fibre regions is expected and is not proof of anatomical absence.

---

## What DKT Connectome runs

| Item | Value |
|------|-------|
| Container | `dkt_connectome.sif` (FreeSurfer + ANTs + MRtrix3) |
| Tractogram | QSIRecon `*_streamlines.tck.gz` |
| Parcellation | DKT from Step 2 (78 nodes default) |
| Registration T1w | Inpainted T1w when Step 1.5 ran; else BIDS T1w |

---

## References

| Topic | Citation | Link |
|-------|----------|------|
| Connectome tools | Tournier JD, et al. MRtrix3. *NeuroImage* 2019 | [10.1016/j.neuroimage.2019.01.066](https://doi.org/10.1016/j.neuroimage.2019.01.066) |
| SIFT2 weighting | Smith RE, et al. *NeuroImage* 2015 | [10.1016/j.neuroimage.2015.02.069](https://doi.org/10.1016/j.neuroimage.2015.02.069) |
| **DKT parcellation** | Klein A, Tourville J. *Frontiers in Neuroscience* 2012 | [10.3389/fnins.2012.00171](https://doi.org/10.3389/fnins.2012.00171) |
| Registration | Avants BB, et al. ANTs. *NeuroImage* 2011 | [10.1016/j.neuroimage.2010.09.025](https://doi.org/10.1016/j.neuroimage.2010.09.025) |
| FS parcellation | Fischl B, et al. *Cerebral Cortex* 2004 | [10.1093/cercor/bhg087](https://doi.org/10.1093/cercor/bhg087) |
| Diffusion metric interpretation | Jones DK, et al. *NeuroImage* 2013;73:239–254. | [10.1016/j.neuroimage.2013.06.018](https://doi.org/10.1016/j.neuroimage.2013.06.018) |

Full table: [References § Step 4](../references.md#step-4-dkt-structural-connectome).

---

## See also

- [Step 3 — Tractography](step3_qsirecon.md)
- [Step 4.5 — Disconnectome](step4_5_disconnectome.md)
- [Disconnectome § Integrity QC](../disconnectome.md#integrity-qc)
- [Container README](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/connectome/README.md)
