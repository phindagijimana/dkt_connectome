# Paper 2 — Clinical disconnectome → outcomes

**Status:** Conditional — pending clinical-data confirmation from PI.
Historically paused; PI has now indicated GOSE + other outcomes are
available for TBI cohort. Un-pause once complete-case N ≥ 40 is verified.

**Target:** *Journal of Neurotrauma* (default); *Brain* / *Neurology* stretch if
neuropsych battery + rs-fMRI + multisite harmonization are all added.

**Cross-refs:** [publication_strategy.md § Paper 2](../publication_strategy.md#paper-2--clinical-disconnectome-optional-paused)
· [Clinical outcomes for Paper 2](../publication_strategy.md#clinical-outcomes-for-paper-2)

---

## One-paragraph summary

A biology paper asking whether structural disconnection from focal TBI
lesions predicts functional outcome and cognitive recovery beyond lesion
volume alone, using one pre-specified lesion-aware arm (e.g. `neurolit-lesion`)
applied to ~40–55 TrackTBI subjects with complete clinical outcomes. The
primary outcome is GOSE at a fixed follow-up window (typically 6 months),
with lesion volume as a mandatory covariate to demonstrate incremental
validity — modeled after Griffis et al. 2019 (*Cell Reports*) on stroke.

## Candidate titles

- *Structural disconnection predicts functional outcome after traumatic brain injury beyond lesion volume*
- *Lesion-induced network disconnection and 6-month recovery in traumatic brain injury: a TRACK-TBI disconnectome study*
- *Beyond the cavity: how focal TBI lesions disconnect brain networks and shape cognitive recovery*
- *Lesion-aware structural disconnectomes as an outcome biomarker in traumatic brain injury*
- *Mapping structural disconnection from focal TBI lesions and its relationship to functional outcome*

## Research questions

| ID | Question |
|----|----------|
| RQ1 (primary) | Does global structural disconnection at 2-week timepoint predict 6-month GOSE, after adjusting for age, sex, GCS, education, and lesion volume? |
| RQ2 (incremental validity) | Does adding disconnection to a baseline model of (lesion volume + demographics + GCS) meaningfully improve outcome prediction? |
| RQ3 (mechanism, Griffis chain) | Does structural disconnection predict a corresponding disruption in resting-state **functional connectivity**, and does the SC → FC chain predict behavior better than either alone? |
| RQ4 (domain specificity) | Do specific networks' disconnection scores map onto specific cognitive deficits (attention, memory, executive function, language)? |
| RQ5 (face validity) | Is the group-average disconnectome (MNI space) spatially coherent with lesion topology? |
| RQ6 (positioning) | Does the interpretable disconnection-based model at least approach the AUC of end-to-end CNN models (e.g. Che et al. 2026)? |

## Griffis analog and gap

Griffis 2019 (*Cell Reports*, stroke N≈114) is the closest publishable
template. Adopt: cross-validated regression, permutation testing,
incremental-validity benchmarks vs lesion volume, network-native parcellation.

**rs-fMRI is available in the TBI BIDS.** The experiment BIDS at
`/mnt/nfs/Gugger_Lab/NIR/dwi_test_TBI_experiment/bids` includes
`task-rest_bold.nii.gz` per subject/session (2WK + 6MO on the pilot); the full
~100-subject cohort is assumed to mirror this structure. This unlocks the
**full Griffis chain — SC → FC → behavior — as a primary/secondary hypothesis**,
not a future extension. Plan an fMRI preprocessing arm (fMRIPrep + XCP-D or
similar) and add functional-connectivity outputs to the Paper 2 subject subset.

**Gaps to close for HBM/Brain-tier:**

- **Multi-domain outcomes** (not just GOSE) — request neuropsych composites from clinical export
- **Multisite harmonization** (ComBat or site regressors) — TRACK-TBI is multi-site; Griffis was single-site
- **Network-native parcellation** — add Schaefer/4S atlases alongside DKT for the Paper 2 subset
- **fMRI preprocessing arm** — ✅ **`fMRI_pipeline/`** built (fMRIPrep 24.1.1 + XCP-D 0.10.6 + DKT + lesion FC + fMRIStroke sensitivity); **7-subject neurolit-inpaint pilot complete** (Oct 2026). Cohort scale + document primary DKT BOLD source (pilot: fMRIPrep preproc fallback when XCP-D lacks T1w NIfTI).

## Our contribution relative to Griffis 2019 — expanded

Griffis 2019 (*Cell Reports*) is the closest publishable template for Paper 2.
This section spells out — point by point — what of their framework we adopt,
where we differentiate, and what genuine advance our paper contributes on top.

### 1. Adopt: the three-part chain SDC → FC → behavior

**Their chain:**

1. **Structural disconnection (SDC)** — per-patient parcel-to-parcel matrix of which connections lose fibers due to the lesion. Computed via HCP-842 normative tractogram overlay in Griffis 2019 (later published as LQT in Griffis 2021).
2. **Functional connectivity (FC) disruption** — per-patient parcel-to-parcel FC matrix from resting-state fMRI at ~2 weeks post-injury, then compared against a healthy-control normative distribution to derive FC-abnormality scores.
3. **Behavior** — factor-analyzed multi-domain neuropsych battery (motor, language, memory, attention, visual) from Corbetta et al. 2015.

**Why this chain is the publishable template:** it fuses mechanism (SDC → FC) with prediction (SDC + FC → behavior). A single-arm outcome-prediction study is not competitive with published stroke work; the mechanistic chain is what elevates the paper from descriptive to explanatory.

**Feasibility for us:**

| Component | Status |
|-----------|--------|
| Patient-level SDC | ✅ Pipeline fully built (Steps 1.1 through 4.1 with disconnection Options A/B/C) |
| rs-fMRI (raw) | ✅ Present in TBI BIDS: `task-rest_bold.nii.gz` per subject/session on both 2WK and 6MO for the pilot; full ~100-subject cohort presumed to mirror |
| fMRI preprocessing arm | ✅ Pilot complete (`run_pilot.sh --inpaint --fmristroke`); primary XCP-D + sensitivity fMRIStroke; DKT Arm B on DKT-78 |
| Empirical FC disconnection (Arm B) | ✅ Pilot 7/7 (`desc-empirical_fc_disconnection.csv`); exploratory coupling in `run_pilot_fc_analysis.sh` |
| Healthy-control FC normative distribution | ⚠️ Options: CIDUR controls if rs-fMRI available (~26 subjects); or public normative (HCP, UKB subset); Griffis used HC FC *abnormality* — we also use **patient empirical D** (Arm B) |
| Multi-domain behavior | ⚠️ Depends on TRACK-TBI clinical export scope — PI has confirmed GOSE + others; specific neuropsych battery to be verified |
| Prior work / novelty map | ✅ [prior_work_novelty.md](prior_work_novelty.md) (Oct 2026) |

**What we execute:**

1. ~~Preprocess rs-fMRI~~ — **done for pilot**; scale Paper 2 subset with same neurolit-inpaint policy where lesion ROI exists.
2. **Primary:** DKT-78 FC + Griffis-style empirical FC disconnection (Arm B); **sensitivity:** fMRIStroke stream ([FC.md §13.1](../../../../fMRI_pipeline/FC.md)).
3. Optional: Schaefer/4S from XCP-D for domain-specific analyses ([atlas_decision.md](../../../../fMRI_pipeline/configs/atlas_decision.md)).
4. Establish HC FC normative distribution if replicating Griffis *abnormality* path (in addition to Arm B).
5. Run **CCA** SDC ↔ FC disconnection (Griffis Fig. 2 analog) — prespecified in [analysis_plan.md](analysis_plan.md); not yet coded at group level.
6. Fit predictive models SDC + FC → GOSE / composites at 6 months after clinical merge.

### 2. Differentiate: patient-specific lesion-aware SDC vs normative-atlas SDC

**Their SDC method (normative-atlas, LQT):**

- Normalize the patient's lesion mask to MNI space
- Overlay on HCP-842 normative tractography atlas
- Count, per parcel-pair, how many normative streamlines pass through the lesion
- Output: parcel-to-parcel SDC matrix
- Fast (minutes per subject), no patient DWI required
- **Implicit assumption:** patient's tract paths conform to healthy template anatomy

**Our SDC method (patient-specific lesion-aware tractography):**

- Preprocess patient DWI (QSIPrep) → generate patient-specific FODs (QSIRecon MRtrix3)
- Recon patient anatomy (FastSurfer / FreeSurfer) → DKT parcellation
- Build patient-specific 5TT segmentation (HSVS from mitigated T1w, or Deep Atropos from native T1w)
- Register the individual lesion mask to individual DWI space
- Use MRtrix `5ttedit -path` to insert the lesion into the pathology channel of the 5TT
- Run iFOD2 anatomically-constrained tractography that respects the pathology prior
- SIFT2-weight the tractogram
- Build patient-specific parcel-to-parcel connectome
- Compute disconnection by comparing the primary connectome with connectomes computed under spared-connectome Options A/B/C (parcel-excised, streamline-excluded, both)
- Output: parcel-to-parcel disconnection matrix + provenance JSON
- Slow (hours per subject), requires patient DWI
- **No conformity assumption** — anatomy is what the individual actually has

**Why patient-specific is more principled:**

- **Individual anatomy** — gyral variability, ventricular size, and normal-variation midline configuration are all handled by using the patient's own segmentation.
- **Edema and mass effect** — TBI oedema pushes tracts off their template positions; a normative atlas cannot represent the displaced actual path of the corticospinal or arcuate fibers in an oedematous brain.
- **Bilateral injury** — TBI has bilateral lesions in ~30–40% of cases (contusions frequently in bilateral frontotemporal poles); the normative-atlas assumption of intact contralesional anatomy for the "healthy template" comparison breaks down.
- **Individual diffusion properties** — patient-specific FA/MD, direction sampling, and shell selection are all baked into the streamlines rather than assumed uniform.
- **Provenance and reproducibility** — our pipeline emits a JSON manifest per subject; a normative-atlas approach has no per-subject provenance because the atlas is the same for everyone.

**Why this differentiation matters especially in TBI (vs stroke, where Griffis validated):**

- Ischemic stroke usually respects one vascular territory (MCA, PCA, etc.), so lesion location is constrained and tract displacement is limited.
- Stroke lesions are usually unilateral (>90%).
- Stroke has less oedema (typically resolved by 2-week imaging window).
- TBI is heterogeneous: contusion (cortical), diffuse axonal injury (subcortical), hemorrhage (bloody), oedema (mass-effect), and their combinations.
- TBI lesion topology violates every one of the normative-atlas simplifying assumptions.

**The specific technical infrastructure we've built to enable this:**

- Containerized pipeline (`dkt_connectome.sif`, `dkt_lesion_act.sif`, `dkt_vbt.sif`) distributed on GHCR + DockerHub
- Snakemake DAG with per-step marker files for reproducibility
- Provenance JSON at every step (`lesion_aware_act.json`, `disconnectome.json`)
- Per-arm output isolation (`RESULTS_ROOT/arms/<arm>/`) for factorial experimentation
- QC dashboards (`disconnectome_qc.html` per subject)
- Six-arm factorial pilot on `sub-TBI011011` demonstrating the pipeline handles all combinations of anatomy mitigation × ACT mode

None of this exists in LQT or BCBtoolkit. Our method is *more expensive* to
run, so it needs to justify the expense; the head-to-head demonstration (§ 5
below) is where that justification lives.

### 3. Adopt: domain-specific behavioral factors (not just GOSE)

**Their behavioral framework (Corbetta et al. 2015):**

- Multi-test neuropsych battery administered to N=133 stroke patients at 2-week post-stroke
- Factor analysis identified orthogonal deficit domains: motor, language, memory, attention, visual
- Each patient gets a **factor score per domain** — a continuous, psychometrically-derived variable
- Griffis 2019 uses these factor scores to demonstrate **domain-specific** SDC → deficit mapping (attention deficits map to dorsal attention network SDC; language deficits map to language-network SDC; etc.)

**Why a single global score (like GOSE alone) is insufficient:**

- GOSE is 8 ordinal levels reflecting overall functional recovery — it collapses attention deficit, memory deficit, motor deficit, and language deficit into one number.
- The mechanism story requires matching a **specific network** to a **specific deficit**. Global outcome cannot support that.
- Reviewers at HBM/Brain will ask: *"Which cognitive domain does this network's disconnection predict?"* A single-GOSE paper cannot answer.
- The domain-specific network mapping is what gives Griffis 2019 biological rather than merely epidemiological content.

**What TRACK-TBI typically includes (per PI and earlier documentation):**

- **Attention / processing speed:** Trail Making A/B, WAIS Processing Speed Index, Symbol Digit Modalities Test (SDMT)
- **Memory:** California Verbal Learning Test-II (CVLT-II), Brief Visuospatial Memory Test-Revised (BVMT-R)
- **Language / fluency:** Controlled Oral Word Association (COWA)
- **Executive function:** Trail Making B (dual-task), possibly D-KEFS Verbal Fluency Switching
- **Global outcome:** GOSE, Disability Rating Scale
- **Symptom burden:** RPQ, PCL-5

**What we need to construct composites:**

1. Request **individual test scores per visit** from PI/data core — not just pre-collapsed composites (we want the raw variables to construct our own factor scores if needed).
2. Determine whether TRACK-TBI has published factor-analytic composites we can adopt directly (Corbetta 2015 factor structure may not port to TBI without recomputation).
3. If not, run factor analysis on the TrackTBI-Sub cohort to identify orthogonal deficit domains — this is a preregisterable analytic step.
4. Handle missing data — likely multiple imputation across time-points/tests.
5. Map each domain to a network-native parcellation choice (attention → dorsal attention Yeo7; memory → hippocampal + default-mode; language → left fronto-temporal; motor → sensorimotor).

**The ask to PI:**

*"For the TrackTBI-Sub subset with lesion masks and DWI, can we get individual neuropsych test scores per visit (not just composites) covering attention, memory, language, and executive function domains? Do published factor-analytic composites exist for TRACK-TBI (analog of Corbetta 2015 for stroke), or would we need to construct our own?"*

### 4. Adopt: incremental validity vs lesion volume as RQ2

**What incremental validity is (statistically):**

- Fit a **baseline model** predicting outcome from covariates + lesion volume only.
- Fit an **augmented model** predicting the same outcome from covariates + lesion volume + SDC (and optionally + FC).
- Compare model performance on **held-out data** (cross-validated ΔAUC for GOSE; ΔR² for continuous cognitive scores).
- Test statistical significance via permutation (shuffle SDC labels 10,000 times; compute the null distribution of ΔAUC or ΔR²).

**Why reviewers care about this specifically:**

- The null hypothesis is trivial: bigger lesions produce worse outcomes. Any SDC score will correlate with lesion volume by construction (larger lesions cut more tracts). A paper that shows "SDC predicts GOSE" without adjusting for lesion volume is showing an artifact.
- Incremental validity forces the claim: *"our SDC captures something above and beyond what lesion volume alone captures."* That is a substantively different claim.
- Griffis 2019's incremental validity vs lesion size (their Figure 5C) is what earned the paper its position in the field — it was the specific move that ruled out lesion-size-as-confound.

**Our specific implementation (to preregister before opening data):**

- **Baseline model:** ordinal regression for GOSE, or linear regression for continuous composites, on `outcome ~ age + sex + education + GCS + lesion_volume_mm3`.
- **+SDC model:** same + `SDC_summary` (choose one primary: e.g. total number of edges with D > 0, or first PC of the disconnection matrix).
- **+SDC+FC model:** same + `FC_abnormality_summary` (analog: mean absolute FC-abnormality score per subject).
- **Nested model comparison:** cross-validated ΔAUC (for GOSE, using 5-fold or leave-one-out) or ΔR² (for continuous outcomes), plus permutation p-values.
- Pre-specify the primary comparison (baseline vs +SDC) and the secondary comparison (+SDC vs +SDC+FC) *before* opening group results.
- Pre-specify the p-value threshold and multiple-comparison correction (Bonferroni across cognitive domains, or FDR).

**Why this is a preregistration priority:**

Without a locked baseline model, reviewers rightly suspect model-shopping. The
baseline covariate set (age, sex, education, GCS, lesion volume) is the
Griffis-2019 convention and should not be negotiated after seeing results.

### 5. The methods contribution stacked on top: head-to-head SDC divergence

This is the **only part of our Paper 2 that is genuinely new** — everything above (chain, differentiator, incremental validity, domain factors) is either adopted from Griffis or extended in the natural way.

**The contribution:** a systematic head-to-head comparison of patient-specific lesion-aware SDC (ours) vs normative-atlas SDC (LQT / BCBtoolkit) on the same TBI cohort, with downstream clinical validation.

**Explicit hypothesis:** *Patient-specific SDC and normative-atlas SDC diverge more in TBI than they would in stroke, because TBI has heterogeneous mass effect, oedema, and bilateral injury that violate the normative-atlas assumption of template-conforming anatomy. Furthermore, the divergence carries clinical signal — patient-specific SDC predicts FC disruption and behavior better than normative-atlas SDC in the same subjects.*

**Why this hypothesis is testable and defensible:**

- Both SDC types are computable on our cohort (LQT/BCB need only the MNI-normalized lesion mask; our pipeline needs patient DWI).
- Divergence has a natural per-subject metric (edge-wise correlation between the two SDC matrices).
- Downstream consequence has natural per-subject metrics (cross-validated ΔR² for FC prediction; cross-validated ΔAUC for behavior prediction).
- Existing stroke literature (Griffis 2019 → 2021 → 2023) provides an implicit comparator: divergence there should be smaller than in TBI.

**Comparison metrics we report:**

| Metric | What it shows |
|--------|---------------|
| Edge-wise Pearson correlation per subject | Distribution of SDC concordance; cases with r < 0.5 flagged |
| Global disconnection score (patient-specific) vs (LQT) | Absolute scaling difference |
| Voxel-wise concordance (with BCB voxel maps) | Spatial agreement of disconnection map |
| Cross-validated R² for predicting FC-abnormality from SDC (each method) | Which method captures FC signal better |
| Cross-validated AUC for predicting 6-month GOSE from SDC (each method), holding lesion volume constant | Which method has more clinical signal |
| Divergence stratified by lesion location, lesion volume, mass-effect score | Which patient subgroups are best-served by patient-specific processing |

**The "stacked" story:**

- **Biology layer** (Griffis-extended-to-TBI): SDC → FC disruption → behavior; incremental validity vs lesion volume; domain-specific network → deficit mapping.
- **Methods layer** (our new contribution): patient-specific SDC captures signal that normative-atlas SDC misses in TBI; the divergence has clinical consequence.

**Explicit statement for the discussion:**

*"This work extends the Griffis (2019) disconnection framework from ischemic stroke to traumatic brain injury and establishes that patient-specific lesion-aware tractography is not merely a computational alternative to normative-atlas approaches but captures clinically meaningful information that normative-atlas methods lose in the presence of TBI-typical mass effect and heterogeneous injury patterns. Future TBI network studies should default to patient-specific processing in cohorts with significant lesion morphology."*

**This is a genuine advance, not a repetition** — because:

- The biology chain (SDC → FC → behavior) is Griffis's; extending it to TBI is *incremental* but expected of the field.
- The head-to-head SDC comparison is *not* Griffis's; nobody has systematically compared patient-specific vs normative-atlas SDC in any patient population at cohort scale.
- The specific claim that patient-specific matters *more* in TBI than stroke is testable, novel, and clinically actionable (informs future study design).

### Summary: what to publish, at what tier

| Contribution | New? | Reviewer defense | Venue tier it unlocks |
|--------------|------|------------------|-----------------------|
| SDC → FC coupling in TBI | Incremental (extension of Griffis stroke → TBI) | Show CCA replicates in TBI | HBM |
| SDC → behavior (domain-specific) in TBI | Incremental (extension of Griffis stroke → TBI) | Show domain-network mapping holds | HBM / Brain |
| Incremental validity vs lesion volume in TBI | Incremental | Show ΔAUC/ΔR² above baseline | HBM / Brain |
| **Patient-specific vs normative-atlas SDC head-to-head in TBI** | **Genuinely new** | **Show divergence + clinical consequence** | **NeuroImage** |
| Combined story (biology + methods) | Combined | Deliver both cleanly | Nature Communications (stretch, needs replication) |

The methods contribution is the highest-leverage novelty. If it lands, we
publish at NeuroImage. If not, we publish at Brain (biology-lead) or HBM
(default). Either way, we do the head-to-head — because if it turns out
patient-specific and normative-atlas SDC agree closely in TBI, that itself
is a publishable methodological negative result (though it caps us at HBM).

## Design decisions to lock before opening data

Per [publication_strategy.md § Clinical outcomes for Paper 2](../publication_strategy.md#clinical-outcomes-for-paper-2):

- [ ] Fixed imaging arm (default `neurolit-lesion`)
- [ ] Primary outcome (default: GOSE at 6 months)
- [ ] Visit-timing rule (default: 2WK imaging → 6mo outcome)
- [ ] Mandatory covariate set (age, sex, education, GCS, lesion volume)
- [ ] Network-to-domain mapping (which parcellation, which composites)
- [ ] Complete-case N threshold (default: N ≥ 45 to proceed; N=30–44 with limitations; <30 fold into Paper 1)

## Complete-case spreadsheet template

Build BEFORE any group analysis:

```text
sub | ses | lesion_mask | neurolit-lesion_done | GOSE_6mo | RPQ_6mo | neuropsych_battery | age | sex | GCS | lesion_vol_mm3
```

## Prior-work analogs

- **Griffis et al. 2019** (Cell Reports, stroke N≈114) — closest publishable template (SC→FC→behavior chain)
- **Warren et al. 2015** (Brain, TBI graph→cognition) — TBI methods precedent
- **Palacios et al. 2022 TRACK-TBI** (J Neurotrauma, N≈391 mTBI) — multisite scale precedent
- **Che et al. 2026** (Brain Commun, TRACK-TBI Pilot, CT+GAN-MRI ResNet-18) — black-box outcome benchmark; positioning contrast (we offer interpretability)

### Comparator tools for the methods contribution

Both are normative-atlas disconnection tools; our patient-specific lesion-aware
pipeline is the alternative to compare against. Run these on the same lesion
masks (MNI-normalized) to produce head-to-head SDC/disconnection outputs.

| Tool | Reference | Output | Repo |
|------|-----------|--------|------|
| **LQT** (Lesion Quantification Toolkit) | Griffis et al. 2021, *NeuroImage: Clinical* 30:102639 | Parcel-to-parcel SDC matrix + tract-level disconnection % + parcel damage; HCP-842 normative atlas | https://github.com/JDGriffis/lesion-quantification-toolkit |
| **BCBtoolkit** (Brain Connectivity and Behaviour) | Foulon et al. 2018, *GigaScience* 7(3):giy004; Talozzi et al. 2023 | Voxel-level disconnection probability maps + Tractotron + disconnectome symptom mapping | https://toolkit.bcblab.com/ |

**Methods contribution framing:** compare patient-specific lesion-aware SDC
(this pipeline) vs normative-atlas SDC (LQT and/or BCB) on the same subjects.
Hypothesis: patient-specific SDC diverges more from normative-atlas SDC in TBI
than in stroke (because TBI has heterogeneous mass effect, edema, bilateral
injury), and the divergence has downstream consequences (better FC prediction
or better behavior prediction). If divergence is small, the methods
contribution shrinks and the paper leads with biology, with methods as
robustness supplement.

## Data-level ceiling and primary-paper mapping

Realistic venue ceiling depends on which data actually materialize from the
TRACK-TBI clinical export and cohort processing. Four practical scenarios,
each with the primary precedent papers that anchor the venue claim.

### Ceiling table

| Data on hand | Realistic ceiling | Anchoring precedents |
|--------------|-------------------|----------------------|
| **GOSE only + covariates, N ≥ 40** | *J Neurotrauma* solid; ordinal regression + incremental validity vs lesion volume | Palacios 2022, Warren 2015, Kuceyeski 2020 |
| **GOSE + RPQ, N ≥ 40** | Same tier, richer story (dual outcome) | Adds RPQ (King 1995 tool; TRACK-TBI standard practice) |
| **GOSE + neuropsych battery, N ≥ 50** | *Brain* / *HBM* in play — domain-specific network story (Griffis-analog) | Griffis 2019, Corbetta 2015, Salvalaggio 2020, Bey 2024 (LeAPP) |
| **GOSE + neuropsych + rs-fMRI, N ≥ 60** | *Brain* / *Neurology* stretch — full SC→FC→behavior Griffis chain | Griffis 2019, Salvalaggio 2020, Talozzi 2023, Boes 2015, Fox 2018 |

**Orthogonal path — methods-lead (any data level ≥ N=40):**
| **Methods head-to-head (any N, plus LQT/BCB run)** | *NeuroImage* if divergence lands cleanly | Griffis 2021 (LQT), Foulon 2018 (BCB), Kuceyeski 2013 (NeMo), Bey 2024, Radwan 2023 |

### Primary papers grouped by ceiling tier

**J Neurotrauma tier (baseline clinical outcome prediction):**

| Paper | Reference | Role |
|-------|-----------|------|
| Palacios et al. 2022 | *J Neurotrauma* 39(19-20):1272–1282; DOI [10.1089/neu.2022.0070](https://doi.org/10.1089/neu.2022.0070) | Multisite TRACK-TBI DTI + GOSE precedent, N≈391 |
| Warren et al. 2015 | *Brain* 138(9):2673–2687; DOI [10.1093/brain/awv075](https://doi.org/10.1093/brain/awv075) | TBI graph metrics → cognition classic |
| Kuceyeski et al. 2020 | *Human Brain Mapping* — verify exact citation | Small-cohort mTBI longitudinal connectome + cognition |

**Brain / HBM domain-specific tier (Griffis-analog in TBI):**

| Paper | Reference | Role |
|-------|-----------|------|
| Griffis et al. 2019 | *Cell Reports* 28(10):2527–2540; DOI [10.1016/j.celrep.2019.07.100](https://doi.org/10.1016/j.celrep.2019.07.100) | **The direct template we extend to TBI** |
| Corbetta et al. 2015 | *Neuron* 85(5):927–941 | Multi-domain behavioral factor analysis framework |
| Salvalaggio et al. 2020 | *Brain* 143(7):2173–2188; DOI [10.1093/brain/awaa156](https://doi.org/10.1093/brain/awaa156) | Multi-domain outcome prediction + combined SC/FC ridge regression |
| Bey et al. 2024 (LeAPP) | *Human Brain Mapping*; DOI [10.1002/hbm.26701](https://doi.org/10.1002/hbm.26701) | HBM precedent for our methodological family |

**Brain / Neurology stretch tier (full SC→FC→behavior chain):**

| Paper | Reference | Role |
|-------|-----------|------|
| Griffis et al. 2019 | (as above) | Full three-part chain in stroke — we replicate in TBI |
| Salvalaggio et al. 2020 | (as above) | Combined SC + FC modeling in stroke |
| Talozzi et al. 2023 | *Brain* 146(5):1963–1978; DOI [10.1093/brain/awad013](https://doi.org/10.1093/brain/awad013) | Current methodological frontier — latent disconnectome |
| Boes et al. 2015 | *Brain* 138(10):3061–3075; DOI [10.1093/brain/awv228](https://doi.org/10.1093/brain/awv228) | Parallel lineage — lesion network mapping using rs-fMRI |
| Fox 2018 | *NEJM* 379(23):2237–2245; DOI [10.1056/NEJMra1706158](https://doi.org/10.1056/NEJMra1706158) | High-visibility LNM paradigm review |

**NeuroImage methods-lead tier (patient-specific vs normative-atlas SDC head-to-head):**

| Paper | Reference | Role |
|-------|-----------|------|
| Griffis et al. 2021 (LQT) | *NeuroImage: Clinical* 30:102639; DOI [10.1016/j.nicl.2021.102639](https://doi.org/10.1016/j.nicl.2021.102639) | The direct normative-atlas comparator we run head-to-head against |
| Foulon et al. 2018 (BCBtoolkit) | *GigaScience* 7(3):giy004; DOI [10.1093/gigascience/giy004](https://doi.org/10.1093/gigascience/giy004) | Second normative-atlas comparator (voxel-level maps) |
| Kuceyeski et al. 2013 (NeMo) | *Brain Connectivity* 3(5):451–463; DOI [10.1089/brain.2013.0147](https://doi.org/10.1089/brain.2013.0147) | Older normative-atlas tool; sensitivity comparator if reviewers request |
| Bey et al. 2024 (LeAPP) | (as above) | Methodological ancestor of our patient-specific pipeline |
| Radwan et al. 2023 | *Network Neuroscience* 7(2):444–466; DOI [10.1162/netn_a_00277](https://doi.org/10.1162/netn_a_00277) | TBI + VBG + ACT small-N proof-of-concept; establishes we're not first to consider patient-specific tractography in TBI, but no cohort-scale head-to-head exists |

**NeuroImage: Clinical / Journal of Neurotrauma backup tier:**

| Paper | Reference | Role |
|-------|-----------|------|
| Palacios et al. 2022 | (as above) | TRACK-TBI subset precedent |
| Osmanlıoğlu et al. 2022 | *Human Brain Mapping* 43(5):1567–1583; DOI [10.1002/hbm.25894](https://doi.org/10.1002/hbm.25894) | TBI longitudinal + cognition, normative-score approach |

**Caveat:** verify citation details (issue, pages, DOI, author order) against
source before including in submitted manuscript — some metadata may need
correction, particularly for the Kuceyeski 2020 HBM entry.

## Journal-tier landscape

**Full analysis:** [`journal_tier.md`](../journal_tier.md) / [`journal_tier.docx`](../journal_tier.docx) — per-venue framing, required analyses, section-by-section manuscript breakdowns, effort estimates, and failure modes.

Summary condensed below.


### Full venue table

| Venue | Realistic? | Framing that lands it | What we'd need to deliver | What we don't yet have |
|-------|-----------|----------------------|---------------------------|------------------------|
| *Nature* (main) | ❌ Not in play | Paradigm-shifting biology + broad reach beyond TBI | N > 500, multi-cohort replication, cross-disease generalizability | Everything |
| *Nature Neuroscience* | ❌ Stretch of stretch | Broad neuroscience insight beyond stroke/TBI | Very large N or exceptional mechanistic depth | Cohort scale, replication |
| *Nature Communications* | ⚠️ Stretch, conceivable | Full SC→FC→behavior + methods novelty + external replication | N ≥ 80 complete cases; independent replication cohort; crisp methods-vs-normative figure with clinical consequence | Replication cohort; N confirmation |
| *Nature Human Behaviour* | ⚠️ Stretch | Behavior-forward, domain-specific network mapping | Multi-domain neuropsych factor scores + clean domain-network mapping | Neuropsych battery confirmation |
| *Brain* | ✅ Realistic | Biology-lead: clinical-mechanistic story | N ≥ 50 complete cases + neuropsych + clean SC→FC coupling + incremental validity vs lesion volume | Clean cohort delivery |
| *NeuroImage* | ✅ Realistic | Methods-lead: patient-specific vs normative-atlas SDC head-to-head | Quantitative divergence figure vs LQT/BCB with downstream consequence (FC or behavior prediction) | The head-to-head analysis run |
| *NeuroImage: Clinical* | ✅ Very realistic | TBI-focused imaging-clinical | Standard clinical-imaging deliverables | Solid backup — no gap |
| *Medical Image Analysis* | ⚠️ Fit-dependent | Pipeline/engineering lead | Would require rewriting away from Griffis story | Different framing |
| *Human Brain Mapping* | ✅ Default landing | Either framing at lower N/novelty bar | Coherent whole; LeAPP was here | Nothing extra |
| *Cell Reports* (Griffis's venue) | ❌ Not open | — | — | They published Griffis; won't accept extension |

### Editorial identity of the 3 target venues

**NeuroImage** — neuroimaging methods + rigorous applications.

- Reader base: imaging methodologists, tool developers, imaging labs.
- Reviewers reward: methods innovation with quantitative validation, head-to-head comparisons against standard tools (LQT/BCB), sensitivity/robustness across parameters, reproducibility (containers, open code).
- Reviewers reject on: biology-only stories without methods innovation; qualitative rather than quantitative claims; missing benchmarks.
- Our fit: patient-specific lesion-aware SDC vs normative-atlas SDC in TBI is a proper head-to-head; we already have containers + provenance JSON + Snakemake DAG for reproducibility.

**Brain** — clinical neurology + translational neuroscience.

- Reader base: clinical neurologists, translational cognitive neuroscientists.
- Reviewers reward: biological/mechanistic story with clinical implications, symptom-anatomy-mechanism triads, prognostic value, cohort-level generalizability.
- Reviewers reject on: pure methods papers; no clinical interpretation; case reports; unclear biology.
- Our fit: SC → FC → behavior chain in TBI (defined patient population, ~2M/year US, real clinical decision-support relevance); Griffis 2019 stroke → TBI extension is a documented empty niche.

**Human Brain Mapping (HBM)** — neuroimaging + cognitive/clinical applications.

- Reader base: broad — imaging labs, clinical, translational, methods.
- Reviewers reward: solid neuroscience with imaging methods, especially connectivity/network analyses; N=40–100 with honest interpretation is welcome.
- Reviewers reject on: paradigm-shift novelty is not required; incoherent whole or unclear contribution will get rejected.
- Our fit: LeAPP (Bey 2024, our comparator) was HBM; they explicitly welcome our methodological family; safe fallback under either framing.

### What determines which path we actually take

Three empirical questions with unknown answers today:

| Question | If yes → | If no → |
|----------|----------|---------|
| Do patient-specific and normative-atlas SDC diverge meaningfully in TBI? | NeuroImage path viable | HBM (methods becomes supplement) |
| Is the SC→FC coupling reproducible cohort-wide? | Brain path viable | HBM |
| Do we have neuropsych battery + N ≥ 50 complete cases? | Brain path stronger | HBM |

### Strategic recommendation

1. **Design the analysis to unlock either path** — implement both LQT/BCB comparators (methods head-to-head) *and* the full SC→FC chain (biology story).
2. **Look at results** — quantitatively assess which contribution is stronger.
3. **Choose venue after results** — but lock the *analysis plan* now (contrasts, primary metrics, benchmarks) so "picking venue after results" is not "picking based on p-hacking."
4. **Do not design for *Nature Communications* from day one** — plan for HBM/Brain/NeuroImage; let quality of results decide any stretch.

### Bottom line

- **NeuroImage** if patient-specific lesion-aware SDC captures signal the normative approach misses in TBI (methods head-to-head wins).
- **Brain** if the full Griffis SC→FC→behavior chain is clean with N ≥ 50 and neuropsych domains (biology story wins).
- **HBM** as safe landing — publishable under either framing even if neither the methods head-to-head nor the biology chain is exceptional.

## Immediate operational next steps

1. Ask PI (or clinical data core) for a **data dictionary** — exact variables + visits available
2. Build complete-case spreadsheet on lesion-mask subjects
3. Count N; if N ≥ 45, un-pause and lock design; if 30–44, run with limitations; if <30 fold into Paper 1
4. Once locked, submit `neurolit-lesion` (or chosen fixed arm) on Paper 2 subject list
5. Add Schaefer/4S parcellation runs on the Paper 2 subset for network-native analysis
6. **Confirm rs-fMRI coverage** cohort-wide (pilot has it; assume full cohort mirrors — verify)
7. **Add fMRI preprocessing arm** to the pipeline (fMRIPrep + XCP-D or similar) to produce functional-connectivity outputs for the Paper 2 subset — enables Griffis SC→FC→behavior chain

## Related pipeline docs

- Step 4.1 disconnectome: [../disconnectome.md](../../disconnectome.md)
- Lesion-aware methods: [../lesion_aware.md](../../lesion_aware.md)
- Validation: [../validation.md](../../validation.md)
- References: [../references.md](../../references.md)
