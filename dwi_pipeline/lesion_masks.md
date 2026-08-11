# Lesion masks in the DWI pipeline

How manually-traced lesion masks flow through this pipeline and, in particular,
how QSIPrep consumes them. Includes the reason we do **not** pre-binarize the
BIDS mask before Step 1 (QSIPrep).

## Mask file on disk

- Name (BEP-003, what QSIPrep looks for and what `find_lesion_mask` globs):
  `sub-<ID>[_ses-YY][_acq-ZZ]_T1w_label-lesion_roi.nii.gz`
- Location: `sub-*/[ses-*/]anat/`, sibling to the T1w.
- Values in the TrackTBI dataset: multi-label `{0, 1, 2}` with
  `1 = core`, `2 = oedema` (see `KNOWN_LABEL_NAMES` in
  `scripts/prepare_lesion_mask.py`). Dtype is `uint16`.
- The pipeline never rewrites this file. Both QSIPrep (Step 1) and the
  inpainting step (Step 1.5) read the same raw file.

## Where the mask is used

| Step | Consumer | What the mask does |
|------|----------|--------------------|
| 1 — QSIPrep | ANTs cost-function mask in T1w → MNI SyN | Downweights lesion voxels so healthy tissue is not warped into the damaged area (or vice-versa). Auto-detected; no CLI flag. Anat-only — DWI/eddy/SDC/QSIRecon are untouched. |
| 1.5 — Inpaint | neuroLIT (`lit_0.6.0.sif`) via `prepare_lesion_mask.py` | Fills the lesion region on the T1w before Step 2, so recon-all/FastSurfer's atlas priors don't get pulled off by the lesion. Uses the multi-label values (`INPAINT_LABELS` can select core, oedema, or all). |

Both consumers glob the same BIDS filename. They do not conflict — Step 1
writes only into its own output tree, and Step 1.5 writes only into
`inpainted/` and `Inpainting/`.

## How QSIPrep picks it up (auto — no flag, no filter entry)

QSIPrep's PyBIDS layer discovers `_T1w_label-lesion_roi.nii.gz` in the anat
directory alongside the T1w. It does **not** need a `--bids-filter-file`
`anat` entry, and our `dwi-select` filter is only allowed to emit `dwi` and
`fmap` blocks — so `dwi-select` neither includes nor excludes anat files, and
does not affect lesion-mask discovery either way.

Inside `qsiprep/workflows/anatomical/volume.py::init_anat_preproc_wf` the
mask enters through `inputnode.roi` and, when `has_rois` is true, two nodes
are added under `anat_preproc_wf.anat_normalization_wf`:

1. `rigid_acpc_resample_roi` — `ants.ApplyTransforms(interpolation='MultiLabel')`
   resamples the raw BIDS ROI into ACPC-aligned T1w space.
2. `anat_nlin_normalization` — `RobustMNINormalizationRPT` runs the T1w → MNI
   SyN warp with the resampled ROI wired in as `lesion_mask`
   (`(rigid_acpc_resample_roi → anat_nlin_normalization, [('output_image', 'lesion_mask')])`),
   which becomes ANTs' fixed-image cost-function mask.

When no mask is found, `has_rois` is false, both nodes are omitted, and
QSIPrep runs a normal T1w → MNI SyN. No error, no warning.

## Why we do NOT pre-binarize the BIDS mask

QSIPrep's documentation asks for a binary mask (damaged = 1, else = 0). Our
BIDS masks are multi-label `{0, 1, 2}`. We deliberately leave them as-is,
for four reasons:

1. **QSIPrep already accepts multi-label ROIs in practice.** ANTs treats a
   cost-function mask as "any nonzero voxel = in-mask." `{0, 1, 2}` is
   effectively unioned into one lesion region. QSIPrep's own resampling node
   uses `interpolation='MultiLabel'` and passes the file through without a
   binarize step, so no thresholding is required upstream.

2. **Our two completed runs confirm it works end-to-end.** For
   `sub-TBI011204` and `sub-TBI011011`, the QSIPrep log shows
   `rigid_acpc_resample_roi` finished (~97 s) and `anat_nlin_normalization`
   finished (~61 min) with the multi-label mask on disk. QSIPrep's
   auto-generated `qsiprep_single_run_output/logs/CITATION.md` records
   "*ROI masks of abnormal tissue were incorporated into the registration.*"
   That sentence is only emitted when the mask was actually used.

3. **Binarizing in place would break Step 1.5.**
   `scripts/prepare_lesion_mask.py`, `INPAINT_LABELS`, and
   `KNOWN_LABEL_NAMES = {1: "core", 2: "oedema"}` all depend on the
   multi-label input to let inpainting target `core`, `oedema`, or `all`.
   Overwriting the BIDS file with a `{0, 1}` version would collapse those
   labels and remove that control.

4. **The pipeline never modifies BIDS.** Keeping the raw file as the single
   source of truth means Step 1 and Step 1.5 always see the same input,
   provenance is trivial to reason about, and re-running with a different
   `INPAINT_LABELS` selection stays a purely local decision.

If a future QSIPrep release ever tightens the mask contract and rejects
non-binary input, the least-disruptive fix is to write a **binarized sibling**
under the newer BIDS name (`sub-<ID>[…]_desc-lesion_mask.nii.gz`) — QSIPrep
picks that up, `find_lesion_mask` still matches the multi-label
`_T1w_label-lesion_roi.nii.gz`, and neither side has to change behavior.

## Behavior when no mask is present

Most subjects have no lesion mask; that is the normal case.

- QSIPrep: `has_rois=False`, ROI nodes are skipped, standard T1w → MNI SyN
  runs. No error.
- Step 1.5: `find_lesion_mask` returns nothing, `run_inpaint` logs
  `"Inpaint: no lesion mask for sub-… — skipping Step 1.5"`, and Step 2 uses
  the raw BIDS T1w. Set `INPAINT_REQUIRE_MASK=1` to hard-fail instead of
  silently skipping.

## Excising the lesion from the connectome (post-hoc, single-subject)

Inpainting (Step 1.5) is the pipeline's **default** answer for producing DKT
connectomes on lesioned subjects: it lets FS/FastSurfer see a healthy brain
so the parcellation is well-defined near the injury, and the resulting
connectome is comparable across subjects. But it is a **counterfactual** near
the lesion — it reports "what connectivity would look like if that cortex
were intact," not "what tissue-verified connectivity exists post-injury."

For single-subject clinical inference, or as a sensitivity view alongside
the inpainted cohort connectome, it is often useful to also produce a
**lesion-excised** connectome where the lesion region is explicitly removed
from the graph. This section describes three flavors — A, B, and C — all
built from artifacts a completed run already produces.

### Inputs (in the results tree of a completed subject)

- Lesion mask (T1w space, dilated per `INPAINT_DILATE`):
  `${INPAINT_OUT}/sub-<ID>/ses-<Y>/lesion_mask_prepared.nii.gz`
- Parcellation used by the connectome (labelconverted, on the
  DWI/preproc-T1w grid): `${CONN_OUT}/sub-<ID>/nodes.mif`
  (or `aparc+aseg_in_dwi.nii.gz`).
- Streamlines + SIFT2 weights (`space-T1w`), under
  `${QSIRECON_OUT}/derivatives/qsirecon-*/sub-<ID>/ses-<Y>/dwi/`:
  `*_space-T1w_model-ifod2_streamlines.tck.gz` and
  `*_space-T1w_model-sift2_streamlineweights.csv`.

All excision commands re-use tools the pipeline already invokes at Step 4
(`labelconvert`, `tck2connectome`, `mrtransform`, `mrcalc`, `tckedit`).
Nothing new needs to be installed.

### Option A — Parcellation excision

**What it does.** Zero out the lesion region in the labelled parcellation,
so every voxel inside the lesion becomes background (label 0) that
`tck2connectome` cannot assign a streamline endpoint to. Streamlines whose
endpoints fall inside the lesion contribute nothing to any edge. Nodes only
partially overlapping the lesion still exist, but the voxels they cover are
only their non-lesion territory. In graph terms: the node set is unchanged
(still 78 DKT nodes) — only the *definition* of some peri-lesional nodes
shrinks.

Recipe:

```bash
# 1. Bring the lesion mask onto the same grid as nodes.mif (nearest-neighbour, stays binary).
mrtransform "${INPAINT_OUT}/sub-${SUBJ}/ses-${SES}/lesion_mask_prepared.nii.gz" \
  -template "${CONN_OUT}/sub-${SUBJ}/nodes.mif" -interp nearest \
  "${CONN_OUT}/sub-${SUBJ}/lesion_in_dwi.mif"

# 2. Carve the lesion out of the parcellation:  nodes_A = nodes * (1 - lesion).
mrcalc "${CONN_OUT}/sub-${SUBJ}/nodes.mif" "${CONN_OUT}/sub-${SUBJ}/lesion_in_dwi.mif" -not -mult \
  "${CONN_OUT}/sub-${SUBJ}/nodes_A_parcexcised.mif"

# 3. Re-run tck2connectome with the same streamlines + SIFT2 weights and the excised nodes.
tck2connectome -force \
  -tck_weights_in "${TCKD}/sub-${SUBJ}_..._space-T1w_model-sift2_streamlineweights.csv" \
  "${TCKD}/sub-${SUBJ}_..._space-T1w_model-ifod2_streamlines.tck.gz" \
  "${CONN_OUT}/sub-${SUBJ}/nodes_A_parcexcised.mif" \
  "${CONN_OUT}/sub-${SUBJ}/dkt_connectome_A_parcexcised.csv"
```

**What changes vs. the original connectome.** Only edges whose endpoints
previously fell in lesion voxels are affected — those endpoints either move
to a neighbouring node (if the assigner searches for the nearest labelled
voxel) or drop out of the count entirely (strict endpoint-in-label matching).
Peri-lesional edge weights typically *decrease* because the target territory
shrank. Non-peri-lesional edges are essentially unchanged.

**Per-node excision provenance.** Always compute and report
`excised_fraction = (lesion voxels dropped in node N) / (original voxels of node N)`
for every node. Nodes with `excised_fraction ≥ 0.5` become unstable and
should be flagged or dropped. This lets a reviewer see how much of each
node was carved off, per subject.

### Option B — Streamline exclusion

**What it does.** Drop every streamline that passes through the lesion mask,
then re-run `tck2connectome` with the *original, un-excised* parcellation.
All 78 DKT nodes stay defined as they were. Edges lose only those streamlines
that traversed the lesion at any point — including streamlines that started
and ended in intact cortex but happened to route through damaged white
matter.

Recipe:

```bash
# 1. Same as Option A step 1 — bring the lesion mask onto the DWI/preproc-T1w grid.
mrtransform "${INPAINT_OUT}/sub-${SUBJ}/ses-${SES}/lesion_mask_prepared.nii.gz" \
  -template "${CONN_OUT}/sub-${SUBJ}/nodes.mif" -interp nearest \
  "${CONN_OUT}/sub-${SUBJ}/lesion_in_dwi.mif"

# 2. Drop lesion-crossing streamlines; filter SIFT2 weights in lockstep so they stay aligned.
tckedit -force \
  "${TCKD}/sub-${SUBJ}_..._space-T1w_model-ifod2_streamlines.tck.gz" \
  -exclude "${CONN_OUT}/sub-${SUBJ}/lesion_in_dwi.mif" \
  -tck_weights_in  "${TCKD}/sub-${SUBJ}_..._space-T1w_model-sift2_streamlineweights.csv" \
  -tck_weights_out "${CONN_OUT}/sub-${SUBJ}/sift2_B_nolesion.csv" \
  "${CONN_OUT}/sub-${SUBJ}/streamlines_B_nolesion.tck"

# 3. Re-run tck2connectome with the ORIGINAL nodes.mif and the filtered tracks.
tck2connectome -force \
  -tck_weights_in "${CONN_OUT}/sub-${SUBJ}/sift2_B_nolesion.csv" \
  "${CONN_OUT}/sub-${SUBJ}/streamlines_B_nolesion.tck" \
  "${CONN_OUT}/sub-${SUBJ}/nodes.mif" \
  "${CONN_OUT}/sub-${SUBJ}/dkt_connectome_B_streamexcluded.csv"
```

**What changes vs. the original.** Any edge whose weight depended on
lesion-traversing streamlines drops. Peri-lesional nodes retain their full
territory but usually lose most of their connectivity to distant regions
(long-range streamlines are more likely to skim the lesion). Non-peri-lesional
edges lose only the fraction of their streamlines that happened to route
through damaged white matter — often small in absolute terms but can
concentrate in specific long tracts (e.g., corticospinal, callosal fibres
crossing a hemispheric lesion).

**How aggressive is `tckedit -exclude`?** It removes any streamline with even
*one* voxel inside the mask — a conservative (over-excluding) choice. If you
want a stricter "≥ N voxels in the lesion" rule, post-process the
`assignments.csv` or count per-streamline mask intersections manually. In
practice, the one-voxel rule is what NeMo-style tools use.

### Option C — Both A and B

**What it does.** Apply A and B together — carve the lesion out of the
parcellation, drop streamlines that traverse the lesion, then run
`tck2connectome`. Reports only "connectivity we can verify is between intact
ROI territory and via intact white matter." Strictest of the three;
smallest edge weights; safest interpretation.

Recipe:

```bash
# Prereq: lesion_in_dwi.mif, nodes_A_parcexcised.mif, streamlines_B_nolesion.tck,
#         sift2_B_nolesion.csv  — all produced by A and B above.

tck2connectome -force \
  -tck_weights_in "${CONN_OUT}/sub-${SUBJ}/sift2_B_nolesion.csv" \
  "${CONN_OUT}/sub-${SUBJ}/streamlines_B_nolesion.tck" \
  "${CONN_OUT}/sub-${SUBJ}/nodes_A_parcexcised.mif" \
  "${CONN_OUT}/sub-${SUBJ}/dkt_connectome_C_both.csv"
```

**What changes vs. A or B alone.** C is at most as large as A or B on any
given edge (never more) and typically smaller than either. Non-peri-lesional
edges are near the original; peri-lesional edges are strictly reduced
compared to A alone (streamlines dropped) and B alone (target territory
shrunk). Use C when the single-subject narrative rests on the strongest
possible "we are sure this tract survived" statement.

### Comparison at a glance

| Version | Peri-lesional nodes | Peri-lesional edges | Non-peri-lesional edges | Node count |
|---------|---------------------|---------------------|-------------------------|------------|
| Original (inpainted) | full territory | counterfactual, "as if intact" | ≈ unchanged | 78 |
| A — parc excision | shrunk territory | endpoints in lesion drop | ≈ unchanged | 78 |
| B — streamline exclusion | full territory | lesion-crossing tracts drop | slightly lower | 78 |
| C — both | shrunk territory | strictest reduction | slightly lower | 78 |
| Raw `--no-inpaint` | often mislabeled/missing | driven by FS failure modes | ≈ unchanged | 78 (but degenerate near lesion) |

### Common practice — where each version is used

- **Option A (parcellation masking)** is the most common lesion-connectome
  variant in stroke and TBI DWI studies. Griffis et al. 2019
  (*Cell Reports*), the LINDA pipeline (Pustina et al. 2016, *Human Brain
  Mapping*), and much MS DWI work use this pattern. Preserves the node set;
  peri-lesional damage shows up as reduced edge weights on nodes whose
  territory has been reduced.
- **Option B (streamline exclusion)** is standard in tract-of-interest
  studies (e.g. corticospinal integrity before/after stroke) and often
  applied as a filter step in whole-brain connectome analyses when the
  question is "connectivity independent of the lesion." Rare on its own in
  whole-brain work without A.
- **Option C (both)** is the most conservative reading and typical in
  single-subject clinical case reports where the narrative rests on
  "connectivity that provably does not depend on the injury."
- **Virtual lesioning** on a normative template (Kuceyeski's NeMo tool,
  *Brain Connectivity* 2013 and follow-ups) is a parallel paradigm — not
  covered here, since it does not use the subject's own tractography.

### Key papers cited (paper summaries)

**Griffis, Metcalf, Corbetta & Shulman (2019).** *Structural Disconnections
Explain Brain Network Dysfunction after Stroke.* Cell Reports, 28(10),
2527–2540.e9. DOI: 10.1016/j.celrep.2019.07.100.
[Link](https://www.cell.com/cell-reports/fulltext/S2211-1247(19)31016-2)

Studied 114 stroke patients with diffusion MRI and resting-state fMRI.
Rather than reading stroke effects off lesion voxel counts, they built
subject-level *structural disconnectomes* (which edges of a normative
white-matter atlas the lesion disrupts) and showed those disconnectome
patterns explain resting-state functional connectivity abnormalities
better than either the lesion itself or gray-matter damage alone. Their
result is the main empirical argument for lesion-aware connectome methods
in general (Options A/B/C in this document) — the point is that the
lesion's effect on the *graph* is a more sensitive readout of stroke than
the lesion's location. Uses parcellation-masking-style handling in the
subject connectome pipeline.

**Kuceyeski, Maruta, Relkin & Raj (2013).** *The Network Modification
(NeMo) Tool: Elucidating the Effect of White Matter Integrity Changes on
Cortical and Subcortical Structural Connectivity.* Brain Connectivity,
3(5), 451–463.
[Link](https://www.liebertpub.com/doi/abs/10.1089/brain.2013.0147)

Introduced the NeMo tool. Rather than reconstruct each subject's own
connectome, take a large reference set of healthy tractograms, and mark
every edge whose supporting streamlines pass through the subject's lesion
mask as "disconnected." The output is a predicted per-edge / per-region
change map, computed *without* using the subject's DWI at all. That is a
parallel paradigm to the A/B/C excision methods here — useful when
subject tractography is unreliable (very large lesions, degraded DWI, or
pediatric acquisitions where template-based inference is preferred).
NeMo has follow-up applications in stroke motor prognosis, TBI, and MCI;
the 2013 paper is the founding reference.

**Pustina, Coslett, Turkeltaub, Tustison, Schwartz & Avants (2016).*
*Automated segmentation of chronic stroke lesions using LINDA: Lesion
identification with neighborhood data analysis.* Human Brain Mapping.
[Link](https://pubmed.ncbi.nlm.nih.gov/26756101/) ·
[Software](https://github.com/dorianps/LINDA)

Automated lesion segmentation for chronic stroke on a single T1w image,
trained on 60 left-hemispheric chronic stroke patients. Uses hierarchical
random-forest predictions from low → high resolution to converge on a
final lesion mask (Dice ≈ 0.70 vs. manual tracings; volume correlation
r ≈ 0.96). Distributed as an R package. LINDA's output is exactly the
kind of file that feeds Options A/B/C — replacing the manual
`_T1w_label-lesion_roi.nii.gz` this dataset currently uses, whenever
manual tracings are unavailable. Note the training scope (chronic
left-hemispheric stroke) is narrower than TBI oedema/core lesions, so
LINDA is not a drop-in for TrackTBI without validation on TBI data.

### Risks

1. **Loss of legitimate peri-lesional connectivity.** Not every voxel inside
   a hand-drawn lesion mask is dead — oedema resolves, some fibres survive.
   Options B and C drop them all. Interpret those numbers as **lower bounds**
   on connectivity, not accurate estimates.
2. **Graph metric non-comparability.** Global efficiency, path length, and
   clustering depend on node count *and* edge density. A subject with heavy
   excision has a graph that is not directly comparable to a subject with
   light excision. Mitigation: for cross-subject work, drop any node with
   `excised_fraction ≥ 0.5` on *any* subject from *every* subject's matrix
   so all matrices share one node set.
3. **Mask precision is inherited.** Manual lesion masks are noisy — usually
   over-inclusive at the boundary. Excision inherits every mask error 1:1,
   with no QC. Mitigation: sanity-check the mask visually before excising;
   optionally run excision with an eroded copy of the mask as a second
   sensitivity check so you have "generous" and "conservative" excisions to
   compare.
4. **Tractography–excision assumption mismatch.** In this pipeline, Step 3
   streamlines are computed using the *inpainted* HSVS 5tt — streamlines
   were seeded and terminated as if the peri-lesional cortex were healthy.
   Excising after the fact removes some of them, but the survivors are still
   "computed under inpainting." For a fully coherent damaged-brain reading,
   do the excision on top of a `--no-inpaint` re-run (Step 2 → Step 3 →
   Step 4 on the raw T1w), then apply A/B/C.
5. **Boundary artifacts.** ROIs partially clipped by the lesion can end up
   as thin strips or small islands. `tck2connectome` still assigns endpoints
   there, but the density-per-mm³ is non-uniform. Report absolute streamline
   counts alongside volume-normalised versions to make this visible.
6. **Interpretation risk.** "Connectivity with the lesion removed" is *not*
   "connectivity of the healthy portion of the brain." It is "connectivity
   we can verify without relying on the damaged region." State this
   explicitly in methods.
7. **Multiple-view inflation.** If you present three matrices
   (inpainted / raw / excised) and run tests on each, control for it or
   pre-specify which is primary.

### Recommendation

**Single subject** — present three views of the same subject, one designated
primary:

- Primary: original inpainted whole-parcellation connectome
  (`dkt_connectome.csv` from Step 4). Cohort-comparable, counterfactual
  near the lesion.
- Sensitivity 1: Option C connectome (`dkt_connectome_C_both.csv`).
  Strict, tissue-verified.
- Sensitivity 2 (optional): a `--no-inpaint` re-run's `dkt_connectome.csv`.
  Raw damaged reading, for auditability.

The clinical narrative should show: whole-brain graph metrics stable across
all three views; peri-lesional edges systematically move in the expected
direction (inpainted highest → raw next → Option C lowest); the
interpretation is anchored on findings that agree across all three.

**Cohort** — Option A is usually the right complement to the primary
inpainted connectome, paired with a fixed cross-subject node-drop policy so
graph metrics remain comparable.

**Audit trail.** Every excision-derived CSV should sit next to a small JSON
recording: which option (A/B/C), the source lesion mask, the number of
streamlines dropped (from `tckstats` before/after), and the per-node
`excised_fraction`. That is what reviewers will ask for.

## References

- QSIPrep docs — Preprocessing → *Handling Lesions and Abnormalities*:
  https://qsiprep.readthedocs.io/en/latest/preprocessing.html#handling-lesions-and-abnormalities
- QSIPrep source — `qsiprep/workflows/anatomical/volume.py`
  (`init_anat_preproc_wf`, `rigid_acpc_resample_roi`,
  `anat_nlin_normalization`)
- Pipeline — `subject.sh::find_lesion_mask`,
  `workflow/lib/common.sh::find_lesion_mask`,
  `workflow/rules/common.smk::find_lesion_mask` / `subject_has_lesion_mask`,
  `scripts/prepare_lesion_mask.py`
- Run evidence — `dwi_test_TBI/sub-TBI011204_fastsurfer_inpaint/logs/sub-TBI011204_qsiprep.log`
  and `.../qsiprep_single_run_output/logs/CITATION.md`
- Griffis, Metcalf, Corbetta & Shulman (2019), *Structural Disconnections
  Explain Brain Network Dysfunction after Stroke.* Cell Reports 28(10),
  2527–2540.e9. https://doi.org/10.1016/j.celrep.2019.07.100
- Kuceyeski, Maruta, Relkin & Raj (2013), *The Network Modification (NeMo)
  Tool: Elucidating the Effect of White Matter Integrity Changes on
  Cortical and Subcortical Structural Connectivity.* Brain Connectivity
  3(5), 451–463. https://doi.org/10.1089/brain.2013.0147
- Pustina, Coslett, Turkeltaub, Tustison, Schwartz & Avants (2016),
  *Automated segmentation of chronic stroke lesions using LINDA: Lesion
  identification with neighborhood data analysis.* Human Brain Mapping.
  https://pubmed.ncbi.nlm.nih.gov/26756101/
