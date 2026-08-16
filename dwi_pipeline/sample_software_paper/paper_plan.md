# Paper plan — TrackTBI-Sub DWI pipeline

Target venue and plan of record for the software paper describing the
lesion-aware DWI connectome pipeline developed for the TrackTBI / URMC clinical MRI
cohorts.

---

## 1. Metadata

- **Target venue:** *Neuroinformatics* (Springer). Software/pipeline papers
  with validation and comparison sections are its bread and butter (impact
  factor ~3.5; typical decision time 2–4 months).
- **Working title (draft):**
  "TrackTBI-Sub: a lesion-aware, provenance-first BIDS pipeline for
  diffusion-MRI connectomics in traumatic brain injury cohorts."
- **Working short title:** TrackTBI-Sub DWI pipeline.
- **Target submission date:** 2026-12-15 (≈ 4 months from 2026-08-10).
- **Anticipated decision:** first-round decision ~2026-02, revised
  submission ~2026-04, in press ~2026-06.
- **Preprint:** post to *bioRxiv / arXiv (q-bio.NC)* at submission.
- **Word budget:** target ~5,000 words main text + ~1,500 words methods
  supplement. Neuroinformatics allows longer papers if justified but a
  focused submission is more likely to pass review quickly.

## 2. Authors and roles (CRediT)

Following the iEEG-recon (Lucas et al. 2024, *Epilepsia*) template of
software-first-author → clinician coauthor → senior corresponding
neuroscientist-engineer.

| Order | Name | Role | Primary CRediT contributions |
|-------|------|------|------------------------------|
| 1 | **Philbert** | Research Data Engineer | Software, Data curation, Writing — original draft, Validation (engineering), Visualization (pipeline figure) |
| 2 | **Daniel** | Post-doc, Neuroscience | Formal analysis, Investigation, Methodology, Writing — original draft (methods, results), Visualization (validation figures) |
| 3 | **James** | MD, Neurology | Validation (clinical/radiological), Investigation (cohort clinical characterization), Conceptualization, Writing — review & editing (clinical relevance, discussion), Resources (patient data access) |
| Last (corresponding) | **Nishant** | Neuroscientist & Engineer | Conceptualization (lead), Supervision, Methodology (lead), Writing — review & editing (framing, comparison to prior tools), Funding acquisition |

Authorship order and CRediT to be reconfirmed at the internal review stage
after Week 10.

## 3. Elevator pitch and singular novelty statement

**Problem this pipeline solves.**
Diffusion-MRI connectomics in traumatic brain injury (TBI) cohorts is
currently hard to run at scale: (a) manually-traced lesions distort
skull-stripping, atlas-based parcellation, and tractography priors, so
peri-lesional DKT nodes are unreliable or missing; (b) multi-site cohorts
mix scanner manufacturers with different fieldmap availability, and existing
tools handle only some of the SDC (susceptibility distortion correction)
cases; (c) reproducibility infrastructure (containers, DAG, provenance) is
patchy across the tools that are stitched together.

**One-sentence novelty claim.**
*TrackTBI-Sub is the first end-to-end BIDS-compliant, container-first DWI
connectome pipeline that carries DDPM-based (neuroLIT) lesion inpainting
through preprocessing, parcellation, tractography, and connectome
construction with per-step provenance and four explicit SDC modes,
validated on a multi-scanner TBI cohort with radiological review.*

**Why not just QSIPrep + QSIRecon + MRtrix directly?**
Because that composition (a) has no defined lesion pathway (QSIPrep uses
the lesion mask for T1w→MNI SyN but nothing downstream); (b) requires
manual, error-prone SDC decisions per subject; (c) has no unified
provenance across steps; (d) has no cohort-scale orchestration; (e) has
no accepted way to make lesion and non-lesion subjects comparable at the
connectome level. TrackTBI-Sub addresses all five.

## 4. Timeline (weeks from 2026-08-10)

Sequencing chosen to unblock the two hardest gaps (cohort validation,
expert clinical review) as early as possible.

| Weeks | Milestone | Owner(s) |
|-------|-----------|----------|
| 1–2 | Freeze pipeline v1.0. Push containers to public registry with pinned digests. CI (unit tests + Snakemake dry-run + `bash -n` + linting). Backfill markers on the 61 previously-completed URMC clinical cohort subjects. | Philbert |
| 1–2 | Draft comparison table against QSIPrep-standalone, TractoFlow, PreQual, NeMo, Elikopy. | Nishant + Philbert |
| 3–6 | Process 61 URMC clinical cohort subjects end-to-end under the new pipeline (Group 1 fmap + Group 2 no-sdc). Produce per-subject inpainting QC + DKT connectome CSV + peri-lesional node lists. | Daniel + Philbert |
| 3–6 | Healthy-baseline validation: 10 HCP-YA subjects through TrackTBI-Sub vs. QSIPrep + QSIRecon + MRtrix baseline. Report per-edge Pearson r, per-node strength difference, global-metric agreement. | Daniel |
| 5–7 | Expert clinical review: James inspects a stratified sample (20 subjects: 10 lesion + 10 non-lesion). Rate parcellation face-validity, inpainting quality, tractography plausibility. | James |
| 6–8 | Peri-lesional analysis: on the URMC lesion subjects, quantify inpainted vs. `--no-inpaint` DKT differences (peri-lesional vs. non-peri-lesional edges); optionally excise-connectome (Option C) sensitivity view per `lesion_masks.md`. | Daniel |
| 7–9 | Draft methods (Philbert), results (Daniel), clinical relevance (James), intro/discussion (Nishant). | All |
| 9–10 | First figures + tables ready; per-section internal review. | All |
| 11–12 | Full-draft internal review, figure polish, comparison-table sign-off, cover letter. | All |
| 13 | Preprint post (bioRxiv). | Philbert |
| 14 | Submit to *Neuroinformatics*. | Nishant |

Slack for unexpected reprocessing / QC failures: 2 weeks distributed across
weeks 4–8.

## 5. Paper structure and section budgets

### 5.1 Abstract (250 words)

Structured (Objective / Methods / Results / Significance) if
*Neuroinformatics* requires; unstructured otherwise. Must contain: the
one-sentence novelty claim (§3), cohort size, headline validation metric
against baseline, headline clinical-review outcome, availability (GitHub +
container registry + DOI).

### 5.2 Introduction (600–800 words)

- Paragraph 1 — Clinical motivation. TBI DWI connectomics needs and
  challenges. Cite epidemiology + rationale for connectome-based readouts.
- Paragraph 2 — Prior tools: QSIPrep (Cieslak 2021), QSIRecon,
  TractoFlow (Theaud 2020), PreQual (Cai 2021), Elikopy, MRtrix pipelines.
  What each does and what remains unsolved for TBI cohorts.
- Paragraph 3 — Lesion-handling gap: current DWI pipelines are lesion-blind
  after the T1w→MNI step. Cite Prados 2016, LINDA (Pustina 2016),
  Griffis 2019, Kuceyeski 2013. Motivate DDPM inpainting (neuroLIT).
- Paragraph 4 — Multi-scanner SDC gap: silent-fallback failure modes for
  mixed Siemens+GE cohorts.
- Paragraph 5 — Contribution statement (three bullets): (i) end-to-end
  lesion pathway; (ii) four explicit SDC modes with fail-fast gating;
  (iii) dual-engine parity + container-first + provenance-per-step.

### 5.3 Materials and Methods (1,800–2,200 words)

**5.3.1 Pipeline overview** — Figure 1 (architecture diagram). Text describes
the six steps + optional Step 1.5 inpaint + provenance layer.

**5.3.2 SDC handling — the four modes.** Reference `workflow/README.md`'s
table verbatim. Emphasize the fail-fast gate + `--use-syn-sdc error` rationale.

**5.3.3 Lesion mask pathway (Step 1.5).** Reference `lesion_masks.md`.
Detail neuroLIT inpainting, `prepare_lesion_mask.py`, `check_inpainting.py`
QC metrics (`outside_lesion_correlation`, `correlation_drop_vs_control`,
`geometry_preserved`), and the auditable JSON sidecar.

**5.3.4 QSIRecon + connectome construction.** SS3T-CSD ACT-HSVS spec, SIFT2
weights, DKT 78-node parcellation via `labelconvert` + `tck2connectome`.

**5.3.5 Optional post-hoc excision.** Reference the A / B / C options in
`lesion_masks.md` for single-subject sensitivity analysis.

**5.3.6 Architecture and reproducibility.** Snakemake DAG (default engine),
bash `subject.sh` (legacy engine), config-as-code, marker files for
resumability, container digests, `.dockstore.yml` and `workflowhub.yml`
registration.

**5.3.7 Cohorts.**
- URMC clinical cohort: 76 TBI patients, 82 subject-sessions from two scanners (Siemens
  Skyra/Vida-Fit *n*=34 sessions with fmaps; GE Signa Premier/Artist
  *n*=46 without fmaps).
- HCP-YA subset: 10 healthy young adults for baseline validation.
- Optional: OpenNeuro TBI dataset (e.g., `ds004097`) for external validation.

**5.3.8 Validation design.**
- *Baseline comparison.* On HCP-YA subset, compare TrackTBI-Sub DKT
  connectomes against QSIPrep + QSIRecon + MRtrix reference by per-edge
  Pearson r, per-node strength agreement, and global metric equivalence.
- *Cross-manufacturer.* On the URMC clinical cohort, quantify residual manufacturer effect
  after processing under matched SDC modes.
- *Lesion analysis.* Inpainted vs. `--no-inpaint` DKT connectomes on the URMC clinical cohort
  lesion subjects; report per-edge magnitude of change stratified by
  peri-lesional vs. non-peri-lesional.
- *Expert clinical review.* Radiological review protocol (§5.4).

### 5.4 Radiological / clinical review protocol (300 words)

Following the iEEG-recon Stein-review template.

- **Sample.** 20 URMC clinical cohort subjects stratified: 10 with lesion mask (all
  processed with inpaint on), 10 without lesion mask.
- **Rater.** James (MD, Neurology), blinded to subject metadata beyond
  what is necessary.
- **Rated items.** (1) Parcellation face validity near lesion (5-point
  Likert). (2) Inpainting quality on T1w (5-point). (3) Tractography
  plausibility (streamlines cover expected fascicles). (4) Free-text
  comments on any clinically meaningful anomalies.
- **Inter-rater.** Optional second rater (external) on a 5-subject subsample
  for reliability if time permits.
- **Outcome.** Report medians and ranges per item; discuss any subject
  flagged. Analogous to iEEG-recon's "radiologically validated through pre-
  and postimplant T1-MRI visual inspections" sentence, but formalized.

### 5.5 Results (1,200–1,500 words)

- **5.5.1 Baseline agreement with reference pipeline.** Report per-edge r,
  per-node strength difference, global metric agreement. Expect r ≥ 0.95
  for the majority of edges, similar to iEEG-recon's r=0.96 finding.
- **5.5.2 URMC clinical cohort processing outcomes.** Successful completion rates
  per SDC mode; QC pass/fail counts; runtime distributions per step.
- **5.5.3 Cross-manufacturer effect.** Manufacturer-stratified plots of
  global efficiency, mean node strength, mean streamline count.
- **5.5.4 Lesion inpainting quality.** Group summary of per-subject
  `outside_lesion_correlation` and `correlation_drop_vs_control`; scatter
  plot vs. lesion volume; per-subject provenance table in supplement.
- **5.5.5 Inpainting effect on connectomes.** Peri-lesional vs.
  non-peri-lesional edge-weight difference between inpainted and raw runs;
  demonstrate change is spatially confined and in the anatomically-expected
  direction.
- **5.5.6 Clinical review outcomes.** Median Likert ratings + James's
  free-text commentary summary.

### 5.6 Discussion (700–900 words)

- Summary of what the pipeline delivers (1 paragraph).
- Positioning against QSIPrep-standalone / QSIRecon / TractoFlow / PreQual /
  Elikopy / NeMo (1–2 paragraphs; refer to Table 1).
- Limitations (1 paragraph): (a) neuroLIT less reliable for very large
  lesions; (b) fieldmap-less SyN when it fails; (c) validation on
  Siemens-Skyra + GE-Signa-Premier — protocol coverage bounded; (d) not
  FDA-approved; (e) single-institution validation cohort so far.
- Future work: (a) additional atlases beyond DKT (MRtrix Schaefer /
  Brainnetome / 4S156Parcels are already supported via QSIRecon but not
  explicitly benchmarked here); (b) longitudinal TBI analysis; (c) fMRI
  co-processing.

### 5.7 Conclusions (150 words)

Restate contribution + call for external adoption + GitHub link.

## 6. Table 1 — Comparison against prior tools (draft)

To be finalized cell-by-cell with Nishant. Rows describe features
reviewers will ask about; columns are the pipelines. Green (yes) / yellow
(partial) / red (no) marking in the final version.

| Feature | TrackTBI-Sub (this work) | QSIPrep + QSIRecon (manual) | TractoFlow (Theaud 2020) | PreQual (Cai 2021) | Elikopy | NeMo (Kuceyeski 2013) |
|---|---|---|---|---|---|---|
| End-to-end BIDS → DKT connectome | yes | manual glue | partial | preprocessing only | yes | no (virtual only) |
| Lesion inpainting → parcellation → connectome pathway | **yes** | no | no | no | no | virtual only |
| Four explicit SDC modes with fail-fast gate | yes | manual | limited | limited | manual | n/a |
| Cross-manufacturer explicit (Siemens + GE) | yes | manual | limited | limited | manual | n/a |
| BIDS-BEP-003 lesion mask auto-detection | yes | QSIPrep only | no | no | no | no |
| Container-first with pinned digests | yes | partial | Nextflow-based | yes | partial | no |
| Reproducible DAG (Snakemake or equivalent) | yes | no | Nextflow | no | partial | no |
| Per-step provenance JSON | yes | partial | partial | partial | partial | n/a |
| Dual-engine parity (bash + Snakemake) | yes | n/a | n/a | n/a | n/a | n/a |
| DKT + optional MNI-atlas connectomes | yes | yes | yes | no | yes | no |
| Post-hoc lesion excision (Options A/B/C) documented | yes | no | no | no | no | yes (paradigm) |
| Runtime resumability (skip finished steps) | yes | manual | yes | no | partial | n/a |
| GUI | no | no | no | no | no | web |

## 7. Figures list

- **Figure 1 — Pipeline overview.** Six steps + Step 1.5 inpaint, with
  container hashes and provenance sidecars annotated. Analog of iEEG-recon
  Figure 1.
- **Figure 2 — SDC decision tree.** The four-mode gate with per-mode
  invocation examples and grep-able log lines.
- **Figure 3 — Inpainting pipeline detail.** Raw T1w → `prepare_lesion_mask`
  → neuroLIT → QC → recon input. Example subject visualization.
- **Figure 4 — Baseline agreement.** Scatter of TrackTBI-Sub vs. reference
  pipeline edge weights on HCP-YA; per-edge r annotated. Analog of
  iEEG-recon Figure 5.
- **Figure 5 — Cross-manufacturer.** Group-level violin plots of global
  metrics per manufacturer (Siemens fmap vs. GE no-sdc).
- **Figure 6 — Inpainting effect on peri-lesional edges.** Difference
  matrix (inpainted − no-inpaint) for a representative subject, with
  peri-lesional nodes highlighted. Group summary as a boxplot.
- **Figure 7 — Clinical review outcomes.** Bar/heatmap of James's Likert
  ratings across 20 reviewed subjects.

Supplementary figures: per-subject inpainting QC panels, example URMC
subject connectome trees, resource usage per step.

## 8. Supplement

- **S1** — Full URMC clinical cohort demographics + per-subject SDC mode + QC
  metrics table.
- **S2** — Runtime and resource benchmarks per step, per container.
- **S3** — Snakemake DAG figure (auto-generated).
- **S4** — Per-container digest table.
- **S5** — Radiological review rubric + per-subject rater output.
- **S6** — Reproducibility artifact list (config files, subject lists,
  container references, DOIs).

## 9. Data & code availability

- **Code.** GitHub repository (public before submission). Version-tagged
  release cited by DOI (Zenodo). CITATION.cff already present.
- **Containers.** Pushed to public registry (Docker Hub / GHCR) with pinned
  digests referenced in the paper.
- **Workflow registration.** Dockstore + WorkflowHub (already scaffolded
  via `.dockstore.yml` and `workflowhub.yml`).
- **Config + subject lists.** In-repo, versioned. `dwi_select_*.json`,
  `subject_list_urmc_{with_fmap,no_fmap}.txt` cited as reproducible artifacts.
- **URMC clinical data.** IRB permitting, deposit derivatives (connectomes, QC
  reports) on OpenNeuro or a controlled-access repo; raw imaging typically
  restricted.
- **HCP-YA validation subjects.** Publicly available; list of subject IDs +
  processing configs in supplement so anyone can reproduce.

## 10. Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| URMC cohort processing surfaces per-subject failures we haven't seen | med | med | Buffer weeks 4–6; retry with targeted fixes; document failures as part of methods. |
| SyN estimation fails on some GE subjects under new `error` gate | med | low | Fall-back to `--no-sdc` explicitly + document. |
| Reference-baseline r on HCP-YA is lower than expected (< 0.9 per-edge) | low | high | Investigate whether it's a spec/parameter mismatch; adjust config or discuss honestly in limitations. |
| Neuroradiologist review turnaround slower than 2 weeks | high | med | Send stratified sample early (week 5); accept written notes vs. formal rubric if time-constrained. |
| Journal returns "insufficient novelty" (algorithm-not-new critique) | med | high | Reframe as integration + validation paper explicitly (iEEG-recon template); pre-empt in cover letter. |
| Container publication requires org-approval process delays | low | med | Start container-push workflow in week 1; parallel to writing. |
| Reviewer asks for external-cohort validation beyond the URMC cohort | med | med | Have OpenNeuro TBI subset ready as a supplementary analysis; reference in cover letter if needed. |

## 11. Pre-submission checklist

- [ ] Pipeline v1.0 tagged in git with a release note listing all four SDC
  modes.
- [ ] Container digests pinned + published; digest table in supplement.
- [ ] Automated tests + CI green on main branch.
- [ ] URMC cohort n=61 processed end-to-end with per-subject QC in a summary CSV.
- [ ] HCP-YA n=10 baseline comparison run + statistics table computed.
- [ ] James's radiological review complete with rubric filled per subject.
- [ ] Comparison table (Table 1) reviewed by Nishant with each cell defended
  by a footnote / citation.
- [ ] Figures 1–7 finalized at journal-required DPI.
- [ ] Cover letter signed by Nishant emphasizing the singular novelty
  claim (§3) and iEEG-recon-style integration-and-validation positioning.
- [ ] Preprint posted (bioRxiv) with DOI referenced in submission.
- [ ] `CITATION.cff` updated with paper reference (post-acceptance).

## 12. Post-submission

- Respond to reviews within 30 days of decision letter.
- Track adoption: GitHub stars, issues, downstream citations.
- Plan follow-on methods paper on the peri-lesional analysis specifically
  (Options A / B / C from `lesion_masks.md`) if the reviewer feedback
  indicates appetite for it — venue *NeuroImage: Clinical* or *Human Brain
  Mapping*.

---

**Living document.** Last updated: 2026-08-10 by Philbert. Any change to
scope, authorship order, target venue, or timeline should be reflected
here first.
