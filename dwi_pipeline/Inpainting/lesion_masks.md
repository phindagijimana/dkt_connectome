# Lesion masks in the DWI pipeline

Index for lesion-mask documentation under `dwi_pipeline/Inpainting/`.

How manually-traced lesion masks flow through the pipeline — QSIPrep
registration, neuroLIT inpainting (Step 1.5), and optional post-hoc connectome
excision (Options A / B / C).

---

## BIDS mask and pipeline steps

| Doc | Topic |
|-----|--------|
| [bids_mask_format.md](bids_mask_format.md) | BIDS naming, multi-label values, immutability |
| [pipeline_usage.md](pipeline_usage.md) | Step 1 (QSIPrep) vs Step 1.5 (inpaint) |
| [qsiprep_integration.md](qsiprep_integration.md) | Auto-discovery, workflow nodes, why not binarize |
| [no_mask_behavior.md](no_mask_behavior.md) | Subjects without a lesion mask |

## Post-hoc connectome excision

| Doc | Topic |
|-----|--------|
| [disconnection.md](disconnection.md) | **Step 4.5** — full pipeline sketch, step-by-step, papers, tradeoffs |
| [connectome_excision_overview.md](connectome_excision_overview.md) | Motivation, inputs, options summary |
| [connectome_excision_option_a.md](connectome_excision_option_a.md) | Parcellation excision |
| [connectome_excision_option_b.md](connectome_excision_option_b.md) | Streamline exclusion |
| [connectome_excision_option_c.md](connectome_excision_option_c.md) | Both A and B |
| [connectome_excision_comparison.md](connectome_excision_comparison.md) | Comparison table and common practice |
| [connectome_excision_literature.md](connectome_excision_literature.md) | Griffis, NeMo, LINDA |
| [connectome_excision_risks.md](connectome_excision_risks.md) | Interpretation caveats |
| [connectome_excision_recommendations.md](connectome_excision_recommendations.md) | Single-subject and cohort guidance |

## References

| Doc | Topic |
|-----|--------|
| [references.md](references.md) | QSIPrep docs, pipeline code, papers |

---

Related: [../containers/lit/README.md](../containers/lit/README.md),
[../pipeline_science.md](../pipeline_science.md) §1.5,
[../sample_software_paper/paper_plan.md](../sample_software_paper/paper_plan.md)
