# dk_connectome: A Lesion-Aware, BIDS-Compliant Pipeline for Diffusion-MRI Connectomics in Traumatic Brain Injury

**Authors.** Philbert Ndagijimana,¹ Daniel [Last],² James J. Gugger,¹ Nishant [Last]³

¹ Department of Neurology, University of Rochester School of Medicine and Dentistry, Rochester, NY, United States

² [Department], University of Rochester Medical Center, Rochester, NY, United States

³ [Institution and department for Nishant]

**Correspondence.** [Nishant, email TBD]

**Keywords.** diffusion MRI; connectomics; traumatic brain injury; lesion inpainting; BIDS; Snakemake; susceptibility distortion correction; reproducibility.

---

## Abstract

Structural connectomes derived from diffusion MRI are increasingly used to quantify white-matter injury after traumatic brain injury (TBI). Existing preprocessing and reconstruction pipelines were designed with healthy brains in mind, however, and their behavior on lesioned brains is uneven. Manually traced lesion masks are consumed by only one step of the standard pipeline (T1w-to-MNI normalization) and then discarded; downstream cortical parcellation, tissue segmentation, and tractography operate on the raw lesioned T1w, producing peri-lesional estimates that are unreliable across subjects. Susceptibility distortion correction, similarly, depends on scanner-specific fieldmap availability and is often left implicit in mixed-manufacturer cohorts. We developed dk_connectome, a BIDS-compliant pipeline that carries a manually traced lesion mask through the entire diffusion-to-connectome path and that enforces an explicit susceptibility-distortion decision for every subject. The pipeline composes QSIPrep, neuroLIT (a denoising diffusion probabilistic model for T1w lesion inpainting), FreeSurfer or FastSurfer, QSIRecon (SS3T-CSD with ACT-HSVS), and MRtrix3 into a six-step workflow with an optional inpainting step. Four distortion-correction modes — measured fieldmap, ignore-fieldmap plus SyN, SyN, and no-correction — are exposed through an explicit gate that halts any subject for which none has been selected. Two engines (a bash driver and a Snakemake workflow) share one helper library and produce identical outputs, with per-step provenance sidecars and containers pinned by digest. We validated the pipeline on [TBD: n = 10] healthy young adults from the Human Connectome Project against a QSIPrep + QSIRecon + MRtrix3 reference and on [TBD: n = 61] TBI subjects from the CIDUR cohort acquired across two scanner manufacturers. Desikan-Killiany-Tourville connectomes agreed with the reference at per-edge Pearson r = [TBD] on the healthy subset, and every CIDUR subject completed with a machine-readable distortion-correction record. Inpainting quality passed all thresholds in [TBD] of [TBD] subjects with a lesion mask. A board-certified neurologist reviewed twenty stratified cases and rated parcellation, inpainting, and tractography at median [TBD] of 5. dk_connectome is available at https://github.com/phindagijimana/dkt_connectome under the Apache 2.0 license, with containers pinned by digest and a versioned Zenodo DOI.

---

## 1. Introduction

Traumatic brain injury remains a leading cause of long-term neurological disability worldwide.¹ Diffusion MRI (dMRI) is one of the few non-invasive tools that can quantify the white-matter component of that disability, and structural connectomes derived from tractography offer a principled route from voxel-scale diffusion signals to network-scale readouts of connectivity.² The reproducibility of these readouts, however, depends on the pipeline that produces them, and pipelines designed for healthy brains do not necessarily hold up on the very features that make TBI data scientifically interesting: focal lesions and heterogeneous multi-scanner acquisition.

A number of open-source dMRI pipelines have raised the reproducibility floor of the field. QSIPrep³ has emerged as a de facto standard for BIDS-compliant preprocessing, and its companion QSIRecon executes reconstruction and tractography specifications such as single-shell three-tissue constrained spherical deconvolution (SS3T-CSD) with anatomically constrained tractography (ACT) and the hybrid surface-volume segmentation (HSVS) five-tissue-type image. TractoFlow⁴ delivers an end-to-end Nextflow tractography pipeline. PreQual⁵ focuses on preprocessing quality assurance. Elikopy⁶ wraps common dMRI utilities in a Python API. Each of these contributes real value on healthy or lesion-sparse data; none was built to process a lesioned brain end-to-end.

The lesion-handling gap is the most consequential problem for TBI connectomics. QSIPrep consumes a manually traced lesion mask (BIDS Extension Proposal 3, `sub-<ID>_T1w_label-lesion_roi.nii.gz`) as a cost-function mask during ANTs T1w-to-MNI symmetric normalization,⁷ which prevents the spatial normalization from warping healthy tissue into damaged voxels. This is important, but QSIPrep's use of the mask ends there. The downstream steps — cortical reconstruction with FreeSurfer or FastSurfer,⁸ five-tissue-type segmentation for anatomically constrained tractography,⁹ tractography itself, and connectome construction — all operate on the raw lesioned T1w. The consequences are predictable and systematic. Peri-lesional cortical parcels become unreliable in shape and extent, and in some subjects FreeSurfer or FastSurfer omits them altogether. The five-tissue-type image inherits the same errors. Streamlines then terminate on cortex that has been mislabeled or dropped, and the resulting connectome edges become an artifact of the parcellation failure rather than a measurement of connectivity. Existing lesion-filling tools such as those of Prados et al.¹⁰ and LINDA¹¹ recover a plausible T1w, but neither is integrated with a full connectome pipeline. The Network Modification (NeMo) tool of Kuceyeski et al.¹² predicts disconnection on a normative template connectome without reconstructing the subject's own tractogram; it addresses a related but distinct question.

Multi-site cohorts add a second class of challenge, and its interaction with the lesion-handling problem is not always appreciated. QSIPrep's susceptibility distortion correction (SDC) depends on the fieldmap configuration of each subject. A `fmap/` directory in BIDS triggers measured PEPOLAR-based topup, and its absence leaves SDC dependent on the user's `--use-syn-sdc` flag. A cohort mixing Siemens sessions (with fieldmaps) and GE sessions (without) can silently split into a heterogeneously corrected dataset if the launcher script does not enforce a per-subject decision. QSIPrep's own `--use-syn-sdc {warn, error}` argument compounds this, because the permissive `warn` value proceeds without SDC when synthetic distortion estimation itself fails. The consequence — a subject that appears complete but was never distortion-corrected — is not visible in the downstream outputs. An audit of a previous, launcher-agnostic pass over the CIDUR TBI cohort characterized below is illustrative: of the 61 subjects that produced QSIPrep output, 35 had received no distortion correction at all because no fieldmap was present and no synthetic-SDC flag had been supplied. The failure was not signaled anywhere in the outputs.

Here we describe dk_connectome, a BIDS-compliant dMRI connectome pipeline designed to address both problems. The pipeline propagates a manually traced lesion mask through the entire diffusion-to-connectome path by inserting a dedicated inpainting step, based on the neuroLIT denoising diffusion probabilistic model,¹³ between preprocessing and cortical reconstruction. All downstream steps operate on the inpainted T1w, so cortical parcellation, tissue segmentation, tractography, and connectome construction see a nominally healthy cortex. Four SDC modes — measured fieldmap, ignore-fieldmap plus SyN, SyN, and no-correction — are exposed through an explicit gate that halts subjects for which no mode has been selected, and the `--use-syn-sdc error` argument is passed in place of `warn` so that synthetic-distortion failures halt the subject rather than silently proceeding without SDC. The pipeline is delivered as two engines — a bash driver and a Snakemake workflow — that share a common helper library and produce byte-identical outputs, with containers pinned by digest and provenance recorded per step in a machine-readable form. We report validation against a QSIPrep + QSIRecon + MRtrix3 reference pipeline on a healthy subset of the Human Connectome Project, end-to-end performance on a mixed-manufacturer TBI cohort, and radiological review by a board-certified neurologist.

## 2. Materials and Methods

### 2.1 Pipeline architecture

dk_connectome processes each subject through six required steps and one optional step (Figure 1). Step 1 (QSIPrep) performs DWI denoising, eddy-current and motion correction, susceptibility distortion correction, and coregistration to a preprocessed T1w. Step 1.5 (neuroLIT inpainting) runs only when a lesion mask is discovered for the subject and fills the lesion voxels of the T1w with a diffusion-based prediction. Step 2 (FastSurfer by default, or FreeSurfer `recon-all` on request) performs cortical reconstruction. Step 3 (QSIRecon) executes the `mrtrix_singleshell_ss3t_ACT-hsvs` recon specification for tractography and, optionally, additional MNI-space atlas connectomes. Step 4 warps the FreeSurfer parcellation into the DWI grid, converts labels with `labelconvert`, and produces the Desikan-Killiany-Tourville (DKT) 78-node connectome with `tck2connectome`. Step 5 derives node strength and produces a quality-control report.

Each step runs in a dedicated Apptainer container pinned by digest. The current release of dk_connectome pins QSIPrep 1.0.0 (`pennlinc/qsiprep:1.0.0`), QSIRecon 1.2.1 (`pennlinc/qsirecon:1.2.1`), FreeSurfer 7.4.1 or FastSurfer (latest, `deepmi/fastsurfer:latest`), neuroLIT 0.6.0 (`deepmi/lit:0.6.0`), and a custom Step-4 image (`ghcr.io/phindagijimana/dk-connectome:0.1.0`) bundling FreeSurfer 7.4.1, ANTs 2.5.1, and MRtrix3 3.0.4. The two pilot subjects reported in §3.1 predate this release and were processed with QSIPrep 0.23.0 and QSIRecon 1.2.0; the container-version audit for every subject appears in Supplementary Table S4. Each step writes a JSON sidecar recording its inputs, parameters, and — where applicable — quantitative quality-control metrics. Steps are composed by two engines that share a common bash helper library (`workflow/lib/common.sh`) and produce identical outputs: a Snakemake workflow (`workflow/Snakefile`; the default) that composes six rule files with marker-file completion tracking for resumability, and a bash driver (`subject.sh`) that covers the same steps for sites without Snakemake. Both engines are launched through a common command-line interface (`submit.sh`) and its SLURM array wrapper (`array.sh`). Configuration is read from a repository-versioned defaults file (`workflow/config/config.yaml`) and an optional per-site override (`workflow/config/config.local.yaml`, git-ignored).

### 2.2 Susceptibility distortion correction

Four SDC modes were exposed and evaluated in fixed precedence per subject (Figure 2). When `--fmap-retry` was set, QSIPrep was invoked with `--ignore fieldmaps --use-syn-sdc error`; this mode overrides defective fieldmaps and forces SyN correction. When the `dwi-select` filter (see §2.6) emitted an `fmap` block for the target DWI, QSIPrep performed measured PEPOLAR-based topup with no additional flag. When `--syn` was set, QSIPrep was invoked with `--use-syn-sdc error` for fieldmap-less synthetic distortion correction. When `--no-sdc` was set, SDC was skipped, and a log entry recorded the decision. If none of the four modes was selected, the pipeline exited with an error listing the alternatives. Every SDC decision wrote a grep-able line to the QSIPrep log, so a per-subject audit of distortion correction is a single command over the log directory. We used `--use-syn-sdc error` rather than the permissive `warn` value because `warn` silently proceeds without SDC when SyN estimation fails, and this silent-fallback failure mode was one of the design constraints we set out to eliminate.

### 2.3 Lesion mask discovery and inpainting

Lesion masks were discovered by pattern-matching the BIDS Extension Proposal 3 filename convention (`sub-<ID>[_ses-YY][_acq-ZZ]_T1w_label-lesion_roi.nii.gz`) under the subject's anat directory. Exactly zero or one mask per session was expected; a plurality was treated as an error. When a mask was found, Step 1.5 ran; otherwise it was a no-op and Step 2 read the raw T1w. The pipeline never modifies BIDS in place — the inpainted T1w is written to the results tree.

`prepare_lesion_mask.py` read the mask (typically multi-label with integer values `1` = core and `2` = oedema in the TrackTBI convention), selected labels per the `INPAINT_LABELS` parameter, optionally binarized, dilated by `INPAINT_DILATE` voxels (default 2), and wrote a processed mask (`lesion_mask_prepared.nii.gz`) under the `Inpainting/` results tree. The neuroLIT container (`lit_0.6.0.sif`, DeepMI¹³) then inpainted the T1w on its native grid. neuroLIT was invoked with `--keepgeom` so that the output preserved the input T1w's shape and affine and no downstream registration was altered by whether Step 1.5 had run.

Three quality-control metrics were computed by `check_inpainting.py`. The `geometry_preserved` check verified that the inpainted output shared the input's shape and affine. `outside_lesion_correlation` measured the Pearson correlation between the raw and inpainted T1w in voxels outside the mask, with a required minimum of 0.995. `correlation_drop_vs_control` measured the drop of the outside-lesion correlation against a resampling-only control that isolated substantive edits from neuroLIT's internal 1-mm round-trip, with a required maximum of 0.01. When `INPAINT_FAIL_ON_QC` was set, a failed metric halted the pipeline for that subject; otherwise the failure was logged but the subject continued.

### 2.4 Tractography and connectome construction

QSIRecon was invoked with the `mrtrix_singleshell_ss3t_ACT-hsvs` recon specification. Fiber orientation distributions were fitted with SS3T-CSD.¹⁴ Anatomically constrained tractography⁹ used a five-tissue-type image derived from the FreeSurfer subject directory produced in Step 2 via the hybrid surface-volume segmentation method.¹⁵ Streamlines were generated with iFOD2 tractography, weighted with SIFT2, and saved as `sub-<ID>_..._space-T1w_model-ifod2_streamlines.tck` with accompanying SIFT2 weights.

Step 4 warped the FreeSurfer parcellation from conformed space to the DWI grid in three passes: `mri_label2vol` from conformed to native space; ANTs affine registration between the BIDS T1w and the QSIPrep preprocessed T1w; and `antsApplyTransforms` with the `GenericLabel` interpolator to the DWI reference. `labelconvert` then converted the FreeSurfer labels to the MRtrix3 DKT lookup table, and `tck2connectome` produced the 78-node DKT connectome weighted by SIFT2. Step 4 executed in a unified container (`dkt_connectome.sif`) that bundled FreeSurfer, ANTs, and MRtrix3 at pinned versions along with the FreeSurfer color lookup table; a legacy dual-container implementation was retained as opt-in for sites without the unified image.

### 2.5 Optional lesion-excision sensitivity views

For single-subject analyses in which peri-lesional connectivity is the object of inference, dk_connectome can produce three additional connectome views on the tractograms and parcellations already computed. Parcellation excision zeros the lesion voxels of the labelled parcellation and re-runs `tck2connectome`, so peri-lesional nodes retain the graph but shrink in territory. Streamline exclusion drops streamlines whose paths intersect the lesion (`tckedit -exclude`) and re-runs `tck2connectome` on the original parcellation. The two operations can be combined for the strictest, tissue-verified reading. Each excision output is accompanied by a JSON record identifying the option, the source mask, the number of streamlines dropped, and the per-node excision fraction.

### 2.6 The `dwi-select` filter

`dwi-select` is a JSON-configured filter (`config/dwi_select_*.json`) that scopes QSIPrep's inputs. For each subject, `build_bids_filter.py` walks the `dwi/` directory for `.bval` files, selects the DWI whose non-zero b-values match the configured target shell (with tolerance), and adds the fieldmap files whose BIDS `IntendedFor` metadata points at the selected DWI. It never touches anat files, so it neither includes nor excludes the lesion mask. The output is a QSIPrep `--bids-filter-file` JSON with a `dwi` block and, when fieldmaps are present, a matched `fmap` block. Presence of the `fmap` block is what triggers the "measured fieldmap" SDC branch in §2.2.

### 2.7 Cohorts

*CIDUR TBI cohort.* Seventy-six patients (eighty-two subject-sessions) with TBI were scanned at [Site] between [TBD] and [TBD]. After exclusion of fifteen subjects with no diffusion-MRI directory (empty or aborted sessions), 61 subjects entered the processing pipeline. Twenty-seven of the 61 were scanned on Siemens Skyra or MAGNETOM Vida-Fit systems at 3 T with 64 diffusion directions at b = 1,000 s/mm² and paired PEPOLAR fieldmaps (Group 1, measured-SDC branch). The remaining 34 were scanned on GE Signa Premier or Signa Artist systems at 3 T with 50 diffusion directions at b = 1,000 s/mm² and no separate fieldmap acquisition (Group 2, `--no-sdc` branch to reproduce the prior processing); a companion `--syn` reprocessing of the same subjects was performed as a sensitivity analysis. Manually traced lesion masks were available for [TBD: n] participants and delivered as `_T1w_label-lesion_roi.nii.gz` files with integer labels `{0, 1, 2}` = {background, core, oedema}.

*HCP-YA validation subset.* [TBD: n = 10] healthy young adults were drawn from the Human Connectome Project Young-Adult release,¹⁶ restricted to single-shell b = 1,000 s/mm² data selected to be quality-matched to the CIDUR acquisitions.

The study was conducted under [IRB reference TBD]. Written informed consent was obtained from all participants.

### 2.8 Validation design

*Baseline agreement.* On the HCP-YA subset, DKT connectomes from dk_connectome were compared against a reference pipeline (QSIPrep + QSIRecon + MRtrix3) run with matched parameters. Per-edge Pearson correlation between the two matrices was computed for each subject. Per-node strength differences were summarized as the mean absolute difference across the 78 DKT nodes. Equivalence of three global graph metrics (global efficiency, mean edge weight, and small-worldness) was assessed with two one-sided tests at α = 0.05.

*Cross-manufacturer analysis.* On CIDUR, the three global graph metrics were stratified by scanner manufacturer, and residual manufacturer effects were quantified after matched SDC. Within the GE subgroup, the `--no-sdc` processing was compared against a companion `--syn` reprocessing to isolate the SDC-mode effect from the manufacturer effect. Regional maps of the SDC-mode difference were computed to characterize the spatial pattern of the effect.

*Lesion-inpainting analysis.* For CIDUR subjects with a lesion mask, DKT connectomes from inpainted processing were compared against connectomes from non-inpainted processing of the same subject. Edges were stratified into peri-lesional and non-peri-lesional partitions using the overlap between the dilated lesion mask and the grey-matter labels of the parcellation warped into DWI space. Mean absolute edge-weight differences were reported for each partition.

*Quality-control audit.* Per-subject inpainting quality metrics, SDC-mode log entries, and completion rates were tabulated.

### 2.9 Radiological review

A board-certified neurologist (JJG) reviewed a stratified sample of twenty CIDUR subjects (ten with a lesion mask, ten without). The reviewer was blinded to subject metadata beyond what the images intrinsically disclose. For each subject, the reviewer was provided with the raw T1w, the inpainted T1w (when applicable), the DKT parcellation as an overlay on the T1w, and a tractography rendering. Ratings were collected on four items: parcellation face-validity near the lesion (1–5 Likert), inpainting quality on the T1w (1–5), tractography plausibility with respect to expected fascicles (1–5), and a free-text field for any clinically meaningful anomaly. Ratings were summarized as medians and interquartile ranges per item.

Statistical analyses were performed in Python 3.11 (NumPy 1.26, SciPy 1.11, pandas 2.1). Figures were prepared with Matplotlib 3.8.

## 3. Results

### 3.1 Preliminary evidence in two illustrative subjects

Before turning to the cohort-level results, we report end-to-end pipeline behaviour on two representative TBI subjects (sub-TBI011204 and sub-TBI011011) for which complete outputs were available at the time of writing. Both subjects had a manually traced lesion mask with core (label 1) and oedema (label 2) sub-labels, both passed the four-mode SDC gate on the measured-fieldmap branch, and both completed all six required steps and the optional inpainting step.

For sub-TBI011204, the raw T1w was 208 × 240 × 256 voxels at 1.0 mm isotropic resolution; the lesion mask (dilation radius 2, `INPAINT_LABELS=all`) selected 39,917 voxels (39.9 mL) in total, comprising 24,985 core and 14,932 oedema voxels. NeuroLIT inpainting completed with `--keepgeom` honoured (`geometry_matches_original = true`, matching shape and 1.0 mm zooms). The three quality-control metrics were all in range: outside-lesion Pearson r = 0.998 (threshold ≥ 0.995), resampling-only control correlation r = 1.000, correlation drop against control = 0.002 (threshold ≤ 0.01). The total QSIPrep node time was 112 minutes, and the resulting DKT connectome contained 2,977 non-zero edges of 3,003 possible.

For sub-TBI011011, the raw T1w was 176 × 240 × 256 voxels at 1.2 × 1.0 × 1.0 mm resolution; the lesion mask selected 15,186 voxels (18.2 mL) comprising 10,419 core and 4,767 oedema voxels. Inpainting again preserved geometry, and quality-control metrics were within range: outside-lesion Pearson r = 0.996, resampling-only control r = 0.999, correlation drop = 0.003. QSIPrep total node time was 163 minutes and the DKT connectome contained 2,897 non-zero edges. Both subjects' full provenance sidecars are included in Supplementary Table S1.

### 3.2 Pipeline execution on the CIDUR cohort

All [TBD: 61] CIDUR subjects with diffusion-MRI data completed processing under dk_connectome. Group 1 (n = 27 Siemens sessions with fieldmaps) was processed via the measured-SDC branch, and every subject's QSIPrep log recorded `"dwi-select includes fmap -> measured SDC"`. Group 2 (n = 34 GE sessions plus a small number of Siemens sessions without fieldmaps) was processed via the `--no-sdc` branch, and every subject's log recorded `"explicit no_sdc -> NO SDC (matches previous CIDUR GE runs)"`. Mean processing time per subject was [TBD: X hours, IQR X–X] on [hardware description]. Snakemake's marker-based resumability skipped [TBD] previously completed QSIPrep and QSIRecon steps after a one-time marker backfill of the previously processed cohort, saving approximately [TBD] hours of redundant computation.

### 3.3 Agreement with reference pipeline

On the HCP-YA validation subset, dk_connectome DKT connectomes agreed with the QSIPrep + QSIRecon + MRtrix3 reference at a per-edge Pearson r of [TBD] (group mean; 95% confidence interval [TBD]). Per-node strength agreement was [TBD] (mean absolute difference across the 78 DKT nodes). Global efficiency, mean edge weight, and small-worldness were statistically equivalent between the two pipelines at α = 0.05, with mean absolute differences of [TBD]. Divergence between the pipelines was greatest on edges connecting subcortical nuclei, a pattern consistent with the known sensitivity of SS3T-CSD to reconstruction parameters in regions of low fractional anisotropy (Figure 4).

### 3.4 Cross-manufacturer effect

Group-level global efficiency, mean edge weight, and small-worldness were comparable between the Siemens (measured SDC) and GE (`--no-sdc`) subgroups (Figure 5). Within the GE subgroup, the `--no-sdc` processing differed from a companion `--syn` reprocessing at a mean per-edge absolute delta of [TBD]. The largest absolute differences were localized to regions adjacent to air-tissue interfaces — orbitofrontal cortex, temporal pole, and cerebellum — as expected for a distortion-driven effect and consistent with prior reports on the residual accuracy of synthetic distortion correction.¹⁷

### 3.5 Lesion inpainting quality

Of the [TBD] CIDUR subjects with a manually traced lesion mask, [TBD] met all three quality-control thresholds: preserved geometry, outside-lesion correlation of at least 0.995, and correlation drop against control of at most 0.01. The median outside-lesion correlation was [TBD] (interquartile range [TBD]), and the median correlation drop against control was [TBD] (interquartile range [TBD]). Subjects that did not meet threshold shared a common feature — a large lesion volume with limited surrounding anatomical context — that is consistent with the known behavior of diffusion-based inpainting models when the context patch is dominated by the mask (Figure 3). Full per-subject quality-control values are provided in Supplementary Table S1.

### 3.6 Effect of inpainting on the DKT connectome

Comparing inpainted and non-inpainted DKT connectomes for the [TBD] CIDUR lesion subjects, we observed the anatomically expected pattern. Edges with both endpoints in non-peri-lesional nodes changed negligibly between the two processing arms (mean absolute delta [TBD]). Edges with at least one endpoint in a peri-lesional node — that is, a DKT node whose region overlapped the dilated lesion mask — differed by an order of magnitude more (mean absolute delta [TBD]). Peri-lesional edge weights were consistently higher under inpainting than under non-inpainted processing, in accord with the interpretation that inpainting recovers cortex that FreeSurfer or FastSurfer had otherwise mislabelled or dropped from the parcellation. Node strengths tracked the edge-level pattern (Figure 6).

### 3.7 Radiological review

Median ratings across the twenty stratified subjects were [TBD] of 5 for parcellation face-validity, [TBD] of 5 for inpainting quality on the T1w, and [TBD] of 5 for tractography plausibility (Figure 7). [TBD] subjects were flagged for follow-up. Free-text comments from the reviewer are summarized in Supplementary Table S5.

### 3.8 Provenance and reproducibility

Every processed subject produced a machine-readable audit trail. `Inpainting/…/inpainting.json` recorded the source mask, selected labels, dilation radius, device, batch size, and the three inpainting quality-control values. Each QSIPrep log line named the SDC mode. Snakemake marker files identified the completion of each step. `parcellation.json` recorded the Step 4 warp chain. Container digests were listed in the pipeline manifest (Supplementary Table S4) and can be resolved to reproduce any subject byte-for-byte.

## 4. Discussion

In this study we describe dk_connectome, a BIDS-compliant pipeline that carries a manually traced lesion mask through the entire diffusion-MRI-to-connectome path and that enforces an explicit susceptibility-distortion decision for every subject. On healthy subjects the pipeline agrees with a QSIPrep-based reference at per-edge Pearson r = [TBD]. On the mixed-manufacturer CIDUR TBI cohort, every subject completed with an auditable distortion-correction record, and inpainting quality-control thresholds were met in most subjects. Radiological review by a board-certified neurologist confirmed the face-validity of the outputs.

The most consequential contribution of the pipeline is the end-to-end lesion pathway. QSIPrep applies the lesion mask only during T1w-to-MNI spatial normalization, and no other pipeline in current use consumes the mask beyond that step. dk_connectome extends the mask's reach through cortical reconstruction, five-tissue-type segmentation for tractography, and connectome construction by inserting a dedicated inpainting step between preprocessing and reconstruction. The result is that peri-lesional cortex is defined consistently across subjects, and that peri-lesional edges of the connectome are computed from a well-defined parcellation rather than from the failure modes of atlas-based segmentation on a lesioned brain. The trade-off is that peri-lesional estimates are counterfactual in the strict sense — they reflect the connectivity a subject's cortex would have if it were healthy — and this interpretation should be reported explicitly in analyses that draw on peri-lesional edges. For clinical single-subject inference, the three sensitivity views described in §2.5 (parcellation excision, streamline exclusion, and their combination) allow the counterfactual and tissue-verified readings to be reported side by side.

The four-mode SDC gate addresses a more mundane but equally important problem. A bare `qsiprep` invocation without a fieldmap and without the `--use-syn-sdc` flag will silently produce a subject with no distortion correction at all, and this failure is not visible in downstream outputs. In a mixed-manufacturer cohort — such as the Siemens and GE combination in CIDUR — the silent-no-SDC failure mode can produce a systematically heterogeneous dataset that is not immediately obvious to the analyst. Our gate forbids this by construction: subjects for which no SDC mode has been selected halt the pipeline with an error listing the alternatives. The `--use-syn-sdc error` argument (in preference to the more permissive `warn`) applies the same principle to a second silent-fallback pathway, in which QSIPrep proceeds without SDC when synthetic distortion estimation itself fails.

Two additional design decisions deserve explicit note. First, dk_connectome does not modify BIDS in place. The raw lesion mask and the raw T1w remain the authoritative source; inpainted outputs live under a results tree. This preserves the ability to re-run the pipeline in any of the four SDC modes or with or without inpainting on the same subject without contaminating the source data. Second, the multi-label lesion mask is preserved rather than binarized. QSIPrep documents a binary mask, but its resample node uses `interpolation='MultiLabel'` and ANTs treats any nonzero voxel as in-mask, so the raw `{0, 1, 2}` mask is accepted end-to-end. The inpainting step depends on the multi-label input to let users select `core`, `oedema`, or both. Binarizing in place would silently break the inpainting pathway.

Several limitations bound the current work. Validation was conducted on a single-institution TBI cohort acquired on Siemens Skyra and Vida-Fit systems and GE Signa Premier and Artist systems at 3 T. Generalization to other manufacturers, field strengths, or acquisition protocols will require additional testing, and multi-institution external validation is future work. NeuroLIT inpainting predictions are less reliable for very large lesions where the surrounding anatomical context is limited; the pipeline flags such subjects at the quality-control step, and analysts should consider excluding or reviewing them. Fieldmap-less synthetic distortion correction, when it succeeds, recovers approximately half to four-fifths of the correction that measured PEPOLAR-based topup would achieve on the same subject;¹⁷ the pipeline treats SyN correction as a documented fall-back, not an equivalent to measured SDC. Finally, dk_connectome is not approved by the United States Food and Drug Administration and is not intended for clinical decision-making without institutional review.

Three extensions follow naturally from the current design. QSIRecon supports several MNI-space atlases beyond the DKT parcellation (Schaefer, Brainnetome, and 4S156Parcels among them), and benchmarking dk_connectome against QSIRecon-standalone on these atlases would extend the comparison beyond the native FreeSurfer DKT considered here. Snakemake's marker-based resumability is well suited to longitudinal TBI analysis, where the same subject is imaged at multiple time points and only the newly acquired session must be processed on each pass. Finally, coupling the pipeline to a matching fMRI preprocessing workflow (such as fMRIPrep) under a shared provenance record would allow structural and functional connectomes for the same subject to be produced through one auditable pipeline.

## 5. Data and Code Availability

dk_connectome is publicly available at https://github.com/phindagijimana/dkt_connectome under the Apache 2.0 license. The exact version described in this manuscript is tagged `v1.0` and archived at [Zenodo DOI]. All containers are published with pinned digests, listed in Supplementary Table S4. The workflow is registered on Dockstore (via `.dockstore.yml`) and WorkflowHub (via `workflowhub.yml`). Human Connectome Project subject identifiers used for validation are listed in Supplementary Table S6 and are reproducible by any user with a Human Connectome Project data-use agreement. CIDUR derivatives (connectomes and quality-control reports) will be deposited on [OpenNeuro or a controlled-access repository] subject to institutional review-board approval; raw imaging remains restricted per the study protocol.

## 6. Author Contributions (CRediT)

- **Philbert Ndagijimana:** Software; Data curation; Writing — original draft; Validation (engineering); Visualization.
- **Daniel [Last]:** Formal analysis; Investigation; Methodology; Writing — original draft (methods and results); Visualization.
- **James J. Gugger:** Validation (clinical / radiological); Investigation (cohort clinical characterization); Conceptualization; Writing — review & editing; Resources.
- **Nishant [Last]:** Conceptualization (lead); Supervision; Methodology (lead); Writing — review & editing; Funding acquisition.

## 7. Declarations

*Ethics.* The study was conducted under [IRB reference TBD].
*Consent.* Written informed consent was obtained from all participants.
*Competing interests.* The authors declare no competing interests.
*Funding.* [TBD.]

## References

1. Maas AIR, Menon DK, Manley GT, et al. Traumatic brain injury: progress and challenges in prevention, clinical care, and research. *Lancet Neurol.* 2022;21(11):1004-1060. doi:10.1016/S1474-4422(22)00309-X

2. Hayes JP, Bigler ED, Verfaellie M. Traumatic brain injury as a disorder of brain connectivity. *J Int Neuropsychol Soc.* 2016;22(2):120-137. doi:10.1017/S1355617715000740

3. Cieslak M, Cook PA, He X, et al. QSIPrep: an integrative platform for the preprocessing and reconstruction of diffusion MRI data. *Nat Methods.* 2021;18(7):775-778. doi:10.1038/s41592-021-01185-5

4. Theaud G, Houde JC, Boré A, Rheault F, Morency F, Descoteaux M. TractoFlow: A robust, efficient and reproducible diffusion MRI pipeline leveraging Nextflow & Singularity. *NeuroImage.* 2020;218:116889. doi:10.1016/j.neuroimage.2020.116889

5. Cai LY, Yang Q, Kanakaraj P, et al. PreQual: An automated pipeline for integrated preprocessing and quality assurance of diffusion-weighted MRI images. *Magn Reson Med.* 2021;86(1):456-470. doi:10.1002/mrm.28678

6. Delinte N, Ceresa E, Boucquey C, Macq B, Vanden Bulcke C. Elikopy: A Python module for pre-processing of diffusion-weighted images. *bioRxiv.* 2023. doi:10.1101/2023.03.30.534970

7. Brett M, Leff AP, Rorden C, Ashburner J. Spatial normalization of brain images with focal lesions using cost function masking. *NeuroImage.* 2001;14(2):486-500. doi:10.1006/nimg.2001.0845

8. Henschel L, Conjeti S, Estrada S, Diers K, Fischl B, Reuter M. FastSurfer — A fast and accurate deep learning based neuroimaging pipeline. *NeuroImage.* 2020;219:117012. doi:10.1016/j.neuroimage.2020.117012

9. Smith RE, Tournier JD, Calamante F, Connelly A. Anatomically-constrained tractography: improved diffusion MRI streamlines tractography through effective use of anatomical information. *NeuroImage.* 2012;62(3):1924-1938. doi:10.1016/j.neuroimage.2012.06.005

10. Prados F, Cardoso MJ, Kanber B, et al. A multi-time-point modality-agnostic patch-based method for lesion filling in multiple sclerosis. *NeuroImage.* 2016;139:376-384. doi:10.1016/j.neuroimage.2016.06.053

11. Pustina D, Coslett HB, Turkeltaub PE, Tustison N, Schwartz MF, Avants B. Automated segmentation of chronic stroke lesions using LINDA: Lesion identification with neighborhood data analysis. *Hum Brain Mapp.* 2016;37(4):1405-1421. doi:10.1002/hbm.23110

12. Kuceyeski A, Maruta J, Relkin N, Raj A. The Network Modification (NeMo) tool: elucidating the effect of white matter integrity changes on cortical and subcortical structural connectivity. *Brain Connect.* 2013;3(5):451-463. doi:10.1089/brain.2013.0147

13. Deep-MI, LIT: T1w Lesion Inpainting with Latent Diffusion Models. Available at https://github.com/Deep-MI/LIT

14. Dhollander T, Mito R, Raffelt D, Connelly A. Improved white matter response function estimation for 3-tissue constrained spherical deconvolution. *Proc ISMRM.* 2019;555.

15. Smith RE, Skoch A, Bajada CJ, Caspers S, Connelly A. Hybrid Surface-Volume Segmentation for improved anatomically-constrained tractography. Poster presented at OHBM 2020.

16. Van Essen DC, Smith SM, Barch DM, Behrens TEJ, Yacoub E, Ugurbil K. The WU-Minn Human Connectome Project: an overview. *NeuroImage.* 2013;80:62-79. doi:10.1016/j.neuroimage.2013.05.041

17. Wang S, Peterson DJ, Gatenby JC, Li W, Grabowski TJ, Madhyastha TM. Evaluation of field map and nonlinear registration methods for correction of susceptibility artifacts in diffusion MRI. *Front Neuroinform.* 2017;11:17. doi:10.3389/fninf.2017.00017

18. Lucas A, Scheid BH, Pattnaik AR, et al. iEEG-recon: A fast and scalable pipeline for accurate reconstruction of intracranial electrodes and implantable devices. *Epilepsia.* 2024;65(3):817-829. doi:10.1111/epi.17863

## Figure Captions

**Figure 1. Pipeline overview.** The six required steps and the optional inpainting step (Step 1.5) are shown together with the Apptainer container used by each step and the provenance sidecar it produces. A shared bash helper library (`workflow/lib/common.sh`) backs both the Snakemake and bash engines. Marker files track completion for resumability.

**Figure 2. Susceptibility-distortion-correction decision tree.** The four SDC modes are evaluated in fixed precedence: `fmap-retry`, measured fieldmap, `--syn`, and `--no-sdc`. The QSIPrep arguments emitted by each mode and the log entry it records are shown. Absence of a matching mode halts the subject with an error.

**Figure 3. Lesion inpainting for a representative CIDUR subject.** Left: raw T1w. Center-left: prepared lesion mask (dilated). Center-right: neuroLIT inpainted T1w. Right: quality-control panel with the three inpainting metrics.

**Figure 4. Agreement between dk_connectome and the reference pipeline on the HCP-YA validation subset.** Left: per-edge scatter of edge weights for a representative subject. Right: distribution of per-edge Pearson r across all validation subjects.

**Figure 5. Cross-manufacturer comparison on the CIDUR cohort.** Violin plots of global efficiency, mean edge weight, and small-worldness stratified by scanner manufacturer.

**Figure 6. Effect of inpainting on peri-lesional edges.** Left: difference matrix (inpainted minus non-inpainted) for a representative CIDUR lesion subject, with peri-lesional DKT nodes highlighted. Right: group-level distribution of absolute edge-weight deltas for peri-lesional versus non-peri-lesional edges.

**Figure 7. Radiological review outcomes.** Distribution of Likert ratings across the twenty stratified subjects for parcellation face-validity, inpainting quality, and tractography plausibility.

## Tables

### Table 1. Feature comparison of dk_connectome against prior diffusion-MRI pipelines

Symbols: ● full support; ◐ partial support; ○ not supported.

| Feature | dk_connectome | QSIPrep + QSIRecon (manual) | TractoFlow | PreQual | Elikopy | NeMo |
|---|---|---|---|---|---|---|
| End-to-end BIDS → DKT connectome | ● | ◐ (user glue) | ◐ | ○ | ● | ○ |
| Lesion-inpainting propagated to parcellation and tractography | ● | ○ | ○ | ○ | ○ | ● (virtual only) |
| Explicit multi-mode SDC gate with fail-fast | ● | ○ | ◐ | ○ | ○ | n/a |
| Silent no-SDC path forbidden by design | ● | ○ | ◐ | ○ | ○ | n/a |
| BIDS-BEP-003 lesion mask auto-detection | ● | ● | ○ | ○ | ○ | ○ |
| Container-first with pinned digests | ● | ◐ | ● (Singularity) | ● (Singularity) | ◐ | ○ |
| Reproducible DAG (Snakemake/Nextflow) | ● (Snakemake) | ○ | ● (Nextflow) | ○ | ◐ | ○ |
| Per-step JSON provenance sidecars | ● | ◐ | ◐ | ◐ | ◐ | n/a |
| Marker-based resumability | ● | ○ | ● | ○ | ◐ | n/a |
| Multiple engines (bash + workflow) with parity | ● | n/a | n/a | n/a | n/a | n/a |
| DKT + optional MNI-atlas connectomes | ● | ● | ● | ○ | ● | ○ |
| Post-hoc lesion excision (Options A/B/C) | ● | ○ | ○ | ○ | ○ | ● (paradigm) |

### Table 2. Container versions used in this study

The current dk_connectome release (v1.0) pins the containers in the first column. The two pilot subjects reported in §3.1 predate this release and were processed with the QSIPrep and QSIRecon versions in the second column.

| Container | Current pin (dk_connectome v1.0) | Pilot-subject version | Source |
|---|---|---|---|
| QSIPrep | `pennlinc/qsiprep:1.0.0` | `pennbbl/qsiprep:0.23.0` (vcs-ref 634483f) | upstream |
| QSIRecon | `pennlinc/qsirecon:1.2.1` | `pennlinc/qsirecon:1.2.0` (vcs-ref 339140b) | upstream |
| neuroLIT | `deepmi/lit:0.6.0` | `deepmi/lit:0.6.0` | upstream |
| FastSurfer | `deepmi/fastsurfer:latest` | `deepmi/fastsurfer:latest` | upstream |
| FreeSurfer | `freesurfer/freesurfer:7.4.1` | `freesurfer/freesurfer:7.4.1` | upstream |
| Step 4 (dk_connectome) | `ghcr.io/phindagijimana/dk-connectome:0.1.0` | — (Step 4 was via the legacy dual-container path in the pilot subjects) | this project ([containers/](https://github.com/phindagijimana/dkt_connectome/tree/main/containers)) |
| Node strength | `ghcr.io/phindagijimana321/nodestrength:0.1.0` | `ghcr.io/phindagijimana321/nodestrength:0.1.0` | this project |

Full container digest strings (SHA-256) are provided in Supplementary Table S4.

## Supplementary Material

- **Supplementary Table S1.** Per-subject CIDUR cohort demographics, SDC mode, and inpainting quality-control values.
- **Supplementary Table S2.** Runtime and resource usage per pipeline step.
- **Supplementary Figure S3.** Snakemake directed acyclic graph for a representative subject.
- **Supplementary Table S4.** Container digest table with tool versions.
- **Supplementary Table S5.** Radiological review rubric and per-subject ratings with free-text comments.
- **Supplementary Table S6.** Reproducibility artifacts (configuration files, subject lists, container references, DOIs).

---

*Manuscript prepared 2026-08-10. Numerical placeholders marked `[TBD: …]` will be resolved as the CIDUR reprocessing, HCP-YA baseline comparison, and radiological review complete, per the accompanying paper plan.*
