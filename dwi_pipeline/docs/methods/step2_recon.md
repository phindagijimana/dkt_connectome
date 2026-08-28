# Step 2 — Cortical reconstruction

**Theory and methods** for anatomical reconstruction and parcellation. Operational details: [Pipeline steps § Step 2](../pipeline_steps.md#step-2-recon).

---

## Background

Structural connectomics requires knowing **where cortical and subcortical regions are** in each subject's brain. Surface-based reconstruction:

1. Skull-strips and registers the T1w to a template
2. Models the **cortical sheet** (white and pial surfaces)
3. Parcellates cortex and deep nuclei into labeled regions

These labels become **connectome nodes** in Step 4. Tractography in Step 3 also consumes FreeSurfer surfaces for **hybrid surface/volume segmentation (HSVS)** when building the five-tissue-type (5TT) image for ACT.

---

## FreeSurfer vs. FastSurfer

| Tool | Method | Runtime | DKT output |
|------|--------|---------|------------|
| **FreeSurfer** `recon-all` | Classical surface reconstruction + atlas labeling | Hours | `aparc.DKTatlas+aseg.mgz` + DK `aparc+aseg.mgz` |
| **FastSurfer** | Deep-learning segmentation + optional surface recon | ~10× faster | DKT only (`aparc.DKTatlas+aseg.mgz`; symlinked as `aparc+aseg.mgz`) |

Both write a FreeSurfer-compatible subject directory under `freesurfer/sub-<ID>/`.

**Pipeline default:** DKT parcellation (78 nodes) regardless of recon tool — see [DKT vs. DK](#dkt-vs-dk-parcellation) below.

Pass `--fastsurfer` on `./run` or set `RECON_TOOL=fastsurfer` before `run_subject.sh`.

---

## DKT vs. DK parcellation

The **Desikan–Killiany (DK)** atlas defines 34 cortical regions per hemisphere (68 cortical + subcortical labels → **84 connectome nodes**).

The **Desikan–Killiany–Tourville (DKT)** protocol refines DK boundaries for reproducibility and **removes three regions**: banks of the superior temporal sulcus, frontal pole, and temporal pole → **31 cortical regions per hemisphere → 78 nodes** (Klein & Tourville 2012).

| Recon tool | Default parcellation | Segmentation file | Matrix |
|------------|---------------------|-------------------|--------|
| `recon-all` | DKT | `aparc.DKTatlas+aseg.mgz` | 78×78 |
| FastSurfer | DKT | `aparc+aseg.mgz` (is DKT) | 78×78 |
| `recon-all` + `CONNECTOME_PARCELLATION=dk` | DK | `aparc+aseg.mgz` | 84×84 |

**Why DKT is the default:** FastSurfer produces DKT only. Using DKT for all subjects lets mixed cohorts share one node set without branching analyses by recon tool.

> **Warning:** Do not apply the DKT lookup table to a DK segmentation image. `labelconvert` matches by **region name**. Applying `fs_dkt.txt` to a DK image silently drops voxels in bankssts and the poles (~12k cortical voxels on typical subjects) without empty-node warnings. Step 4 selects the correct **segmentation file**, not just the LUT.

---

## T1w input: raw vs. inpainted

| Condition | T1w fed to Step 2 |
|-----------|-------------------|
| BIDS lesion mask present, Step 1.1 ran | Inpainted T1w (`inpainting_result.nii.gz`) |
| No mask or `--no-inpaint` | QSIPrep `desc-preproc_T1w` or BIDS T1w per config |

Inpainting improves segmentation **around lesions** without altering DWI (see [Step 1.1](step1_1_inpaint.md)).

---

## Key FreeSurfer outputs

| File | Space | Used by |
|------|-------|---------|
| `mri/aparc.DKTatlas+aseg.mgz` | Conformed 256³ | Step 4 parcellation (default) |
| `mri/aparc+aseg.mgz` | Conformed 256³ | Step 4 when `CONNECTOME_PARCELLATION=dk` |
| `mri/rawavg.mgz` | Native T1w grid | `mri_label2vol` warp target |
| `surf/*.white`, `surf/*.pial` | Surface mesh | Step 3 HSVS 5TT construction |
| `mri/aseg.mgz` | Conformed | HSVS subcortical component |

FastSurfer runs **`recon-surf`** (not `--seg_only` alone) so cortical surfaces exist for ACT-HSVS tractography.

---

## Tissue roles in downstream steps

| Tissue | Role in ACT (Step 3) | Role in connectome (Step 4) |
|--------|---------------------|----------------------------|
| Cortical GM | Streamline **termination** at cortex | Parcellation **nodes** |
| Subcortical GM | Streamline **termination** | Parcellation **nodes** (thalamus, hippocampus, …) |
| White matter | Streamline **propagation** | Edges between nodes |
| CSF | Streamline **discarded** | — |

---

## References

| Topic | Citation | Link |
|-------|----------|------|
| **FreeSurfer** | Fischl B. *NeuroImage* 2012 | [10.1016/j.neuroimage.2012.03.001](https://doi.org/10.1016/j.neuroimage.2012.03.001) |
| Cortical surfaces | Dale AM, et al. *NeuroImage* 1999 | [10.1006/nimg.1998.0395](https://doi.org/10.1006/nimg.1998.0395) |
| **FastSurfer** | Henschel L, et al. *NeuroImage* 2020 | [10.1016/j.neuroimage.2020.117357](https://doi.org/10.1016/j.neuroimage.2020.117357) |
| **DKT atlas** | Klein A, Tourville J. *Frontiers in Neuroscience* 2012 | [10.3389/fnins.2012.00171](https://doi.org/10.3389/fnins.2012.00171) |
| DK atlas (84 nodes) | Desikan RS, et al. *NeuroImage* 2006 | [10.1016/j.neuroimage.2006.01.021](https://doi.org/10.1016/j.neuroimage.2006.01.021) |

Full table: [References § Step 2](../references.md#step-2-cortical-reconstruction-freesurfer-fastsurfer).

---

## See also

- [Step 3 — Tractography](step3_qsirecon.md) (HSVS uses Step 2 surfaces)
- [Step 4 — DKT connectome](step4_connectome.md)
- [Comparisons § recon-all vs FastSurfer](../comparisons.md)
