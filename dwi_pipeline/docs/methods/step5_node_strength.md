# Step 5 — Node strength report

**Theory and methods** for graph-theoretic summaries and clinical reporting from the connectome matrix. Operational details: [Pipeline steps § Step 5](../pipeline_steps.md#step-5-node-strength).

---

## Background

A connectome matrix describes **pairwise** connectivity. **Node strength** collapses each row (or column) to a single scalar — the total weighted connectivity of region *i* to all other regions (Rubinov & Sporns 2010):

\[
s_i = \sum_{j \neq i} W_{ij}
\]

In lesion and epilepsy cohorts, **interhemispheric asymmetry** of node strength and volume can highlight structurally disconnected or atrophic regions. Step 5 implements an ENIGMA-style reporting pipeline (Piper et al. 2026) generalized from thalamocortical epilepsy connectomics to whole-brain DKT/DK graphs.

Step 5 runs in a **separate container** (`nodestrength`) from Step 4 — graph analysis and visualization require a different software stack than spatial registration (see [Why a separate step](#why-a-separate-step)).

---

## What is computed

From the symmetric, zero-diagonal connectome produced by Step 4 (`tck2connectome -symmetric -zero_diagonal`):

| Quantity | Formula / definition |
|----------|---------------------|
| **Node strength** | \(s_i = \sum_{j \neq i} W_{ij}\) (undirected; BCT `strengths_und` or equivalent) |
| **Side asymmetry index (AI)** | \((L - R) / (L + R)\) per homologous pair |
| **Intrahemispheric strength** | Row sum using only within-hemisphere edges (excludes callosal dominance) |
| **Volume AI** | Same AI formula on per-node ROI volumes from `nodes.mif` |

Atlas resolution is **automatic**: the container inspects matrix shape at load time — 78×78 → DKT table; 84×84 → DK table. No shared config flag is needed between Step 4 and Step 5.

---

## Visualization vs. analysis atlases

| Layer | Atlas used | Why |
|-------|------------|-----|
| **Analysis** (strength, AI) | Same as connectome (DKT 78-node default) | Metrics must match the graph |
| **ENIGMA surface figure** | DK-based **fsaverage5** surface | ENIGMA Toolbox convention |

The 31 DKT cortical regions map one-to-one onto DK counterparts (DKT = DK minus bankssts and poles). Three DK-only regions have no painted value when analysis used DKT. `manifest.json` records `analysis_scheme` vs. `viz_scheme`.

---

## Outputs

Under `node_strength/` (or `NODESTRENGTH_OUT`):

```text
strength/per_subject/sub-<ID>_{strength,ai,strength_intra,ai_intra}.csv
volume/per_subject/sub-<ID>_{volume,volume_ai}.csv
compare/strength_vs_volume_ai.csv
reports/sub-<ID>/report.pdf              # clinical summary
reports/sub-<ID>/figures/                # PNG gallery
manifest.json                            # provenance, atlas, caveats
```

The PDF includes:

- Key-structure table (thalamus, hippocampus, amygdala, insula — strength, intra, volume AI)
- Top asymmetric regions
- ENIGMA cortical surface render
- Subcortical strength/volume panel
- Seed connectivity profiles

Skip with `--no-node-strength`.

---

## Why a separate step

| Container | Stack | Role |
|-----------|-------|------|
| `dkt_connectome.sif` (Step 4) | FreeSurfer, ANTs, MRtrix3 | Spatial alignment, streamline counting |
| `nodestrength` (Step 5) | numpy, pandas, scipy, bctpy, nilearn, ENIGMA Toolbox | Graph metrics, plotting, PDF |

Decoupling means changes to report layout or asymmetry math never require rebuilding the tractography/connectome container, and vice versa.

---

## Caveats

Recorded in every `manifest.json`:

- **Thalamus granularity:** DKT/DK provide one `Thalamus-Proper` node per hemisphere — not THOMAS per-nucleus breakdown (Piper et al. used THOMAS in epilepsy cohorts).
- **Normative z-scores:** values are raw asymmetry indices, not age/sex-adjusted ENIGMA normative z-scores. A normative cohort model would be needed for clinical normative comparison.

---

## References

| Topic | Citation | Link |
|-------|----------|------|
| **Graph strength metric** | Rubinov M, Sporns O. *NeuroImage* 2010 | [10.1016/j.neuroimage.2009.10.003](https://doi.org/10.1016/j.neuroimage.2009.10.003) |
| **Clinical connectomics report** | Piper RJ, et al. *Epilepsia* 2026 | [10.1002/epi.70099](https://doi.org/10.1002/epi.70099) |
| ENIGMA consortium | Thompson PM, et al. *NeuroImage* 2020 | [10.1016/j.neuroimage.2020.116689](https://doi.org/10.1016/j.neuroimage.2020.116689) |

Full table: [References § Step 5](../references.md#step-5-node-strength-report).

---

## See also

- [Step 4 — DKT connectome](step4_connectome.md)
- [Outputs § node strength](../outputs.md)
- [QC dashboard](../qc_dashboard.md)
