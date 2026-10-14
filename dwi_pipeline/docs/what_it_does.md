# What DKT Connectome does

DKT Connectome is a [BIDS App](bids_app.md) that takes a subject's diffusion MRI and T1-weighted anatomy and builds a **structural connectome**: a region-to-region map of reconstructed white-matter pathways. When you also supply a lesion mask, the same run can estimate **what that lesion disconnects**.

The default graph uses the **Desikan–Killiany–Tourville (DKT)** atlas — 78 cortical and subcortical nodes that both FreeSurfer and FastSurfer can produce. The same streamlines can also be counted on other atlases (below) so you can compare scales without running a second pipeline.

The workflow is **study-agnostic**. Any BIDS DWI + T1w cohort can run. Lesion-specific steps (inpainting, lesion-aware tractography, disconnectome) stay off unless a mask and the matching flags are present. It orchestrates [QSIPrep](https://qsiprep.readthedocs.io/), [QSIRecon](https://qsirecon.readthedocs.io/), FreeSurfer or FastSurfer, MRtrix3, and optional neuroLIT — it does not replace those tools; it pins them and carries a lesion mask through to the graph.

Public software checks use [IDEAS II](datasets/ideas.md) and [BTC glioma](datasets/btc_glioma.md) — reportlets on [Sample results](sample_results.md). TRACK-TBI DoD Phase 1 was run under a data-use agreement and is **not** in this repository.

---

## Each step in a paragraph

**Step 1 — Preprocess (QSIPrep).** Motion, eddy currents, and susceptibility distortion are corrected, then T1w is aligned to the diffusion grid. Every subject gets an explicit distortion-correction choice (fieldmap TOPUP, SyN, or a documented skip) so mixed-vendor cohorts stay comparable.

**Step 1.1 — Inpaint the lesion on T1w (optional).** If a BIDS `*_label-lesion_roi` mask is present, neuroLIT (or optional virtual brain transplant) fills that region on T1w *before* cortical reconstruction. Diffusion signal is not rewritten. Skip with `--no-inpaint` or omit the mask.

**Step 2 — Reconstruct cortex and assign nodes.** FreeSurfer `recon-all` or FastSurfer builds surfaces and a DKT parcellation. Those labels become the default connectome nodes. FastSurfer is the usual HPC default; `recon-all` is available when you need a Desikan–Killiany (DK) tree as well.

**Step 3 — Tractography (QSIRecon).** Constrained spherical deconvolution estimates fiber orientations; anatomically constrained tractography (ACT-HSVS) grows streamlines that terminate at gray-matter boundaries. This tractogram is the white-matter evidence later steps count.

**Step 3.1 — Lesion-aware ACT (optional).** The lesion is inserted into the five-tissue-type (5TT) image and tractography is rebuilt so streamlines respect pathology. An optional Deep Atropos branch can supply that 5TT from native T1w instead of the QSIRecon HSVS map.

**Step 4 — Structural connectome.** DKT labels are warped onto the tractography grid. MRtrix3 writes 78×78 matrices from the same streamlines: count (default), mean length, mean FA, and mean MD, plus optional SIFT2 weights. Output: `dkt_connectome.csv`.

**Step 4.1 — Disconnectome (optional).** With `--disconnection` and a lesion mask, the pipeline asks which DKT edges the lesion interrupts: remove lesioned parcels (A), drop streamlines that hit the mask (B), or both (C), then compare the spared graph to the intact Step 4 connectome. Off by default.

**Step 5 — Node strength.** Each region's total connectivity is summarized and written as an ENIGMA-style cortical and subcortical report so you can inspect hubs without opening the matrix in a script first.

---

## Other atlases

DKT (78 nodes) is the **primary** product — the name of the app and the default `dkt_connectome.csv`. The same subject can also emit other graphs:

| Atlas | Nodes | How to request | Notes |
|-------|------:|----------------|-------|
| **DKT** (default) | 78 | (none) | Cortical + subcortical; FreeSurfer or FastSurfer |
| **Desikan–Killiany (DK)** | 84 | `CONNECTOME_PARCELLATION=dk` | `recon-all` only — FastSurfer does not write DK |
| **Lausanne-60** | 60 | `--connectome-atlases dkt,lausanne60` | Extra robustness matrix beside DKT |
| **4S156** (Schaefer-100 + subcortex) | 156 | QSIRecon default atlas | Written by Step 3; not a replacement for DKT |

Do not pool DKT and DK matrices in one analysis — node sets differ. Lausanne-60 and 4S156 are additional views of the same tractogram, not a second preprocessing path.

---

## What this is not

It is not a lesion-segmentation tool (you bring the mask). It is not a functional (BOLD) connectome. The Docker image is an **orchestrator** only — QSIPrep, FreeSurfer, and the other step containers still mount at runtime.

---

## Next

| If you want… | Read… |
|--------------|--------|
| Install and a first dry-run | [Installation](installation.md) · [Tutorial](tutorial.md) |
| Flags for lesions, SDC, atlases | [Usage](usage.md) · [Decision tables](decision_tables.md) |
| Why each scientific choice exists | [Science overview](science_overview.md) |
| Commands, paths, and outputs | [Pipeline steps](pipeline_steps.md) · [Outputs](outputs.md) |
| Citations | [Methods](methods/index.md) · [References](references.md) |
