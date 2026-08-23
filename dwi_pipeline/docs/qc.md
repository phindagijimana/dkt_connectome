# Quality control

HTML reports summarize pipeline outputs for Steps 1–5. This page covers **where to find reports**, **how to regenerate them**, and **what to inspect** in each panel.

Pipeline overview diagram: [How it works — science & theory](science_overview.md). Step 4.5 theory: [Disconnectome methods](methods/step4_5_disconnectome.md). Automated disconnectome checks: [Disconnectome § Integrity QC](disconnectome.md#integrity-qc).

---

## Per-subject dashboard

### Open the report

After `./run` participant or a full `run_subject.sh all` run:

```text
RESULTS_ROOT/qc/sub-<ID>/subject_qc.html
RESULTS_ROOT/qc/sub-<ID>/subject_qc.json
```

Snakemake builds this automatically when `qc.subject_html: true` (default).

Regenerate manually:

```bash
bash workflow/run_subject.sh all EXAMPLE
# or:
python3 scripts/render_subject_qc.py --results-root OUT --subject EXAMPLE
```

### What to inspect (by step)

#### Step 1 — QSIPrep

| Panel | What to look for |
|-------|------------------|
| Motion plot | Spikes → consider exclusion or re-acquisition |
| SDC / TOPUP | Brain boundaries aligned between DWI and T1w |
| Brain mask | Complete coverage; no cropped cerebellum |
| b=0 vs b>0 | Reasonable SNR; no striping artifacts |

Embedded from QSIPrep reportlets under `qsiprep_single_run_output/sub-<ID>/`.

Regenerate doc QC figures locally: `python3 scripts/render_qc_doc_figures.py` (requires local dwi_test_TBI outputs; figures are gitignored).

#### Step 1.5 — Inpaint (if lesion mask)

| Panel | What to look for |
|-------|------------------|
| Before / after T1w | Lesion filled; surrounding anatomy unchanged |
| `inpainting_qc.json` | `outside_lesion_correlation` ≥ 0.995 |
| Preview PNGs | No obvious blurring outside mask |

#### Step 2 — Recon

| Check | PASS |
|-------|------|
| FreeSurfer / FastSurfer tree exists | `freesurfer/sub-<ID>/` |
| Surfaces present (ACT-HSVS) | `surf/lh.white`, `surf/lh.pial` |
| DKT parcellation | `mri/aparc.DKTatlas+aseg.mgz` or FastSurfer equivalent |

Inspect with FreeView or FastSurfer QC tools if segmentation looks wrong near lesions.

#### Step 3 — QSIRecon

| Panel | What to look for |
|-------|------------------|
| Tractography density | Streamlines cover major WM bundles |
| ACT termination | Endpoints in GM, not floating in CSF |
| Session HTML | QSIRecon report under `qsirecon_single_run_output/` |

#### Step 4 — Connectome

| Artifact | Inspect |
|----------|---------|
| `parcellation.json` | 78 nodes (DKT); `empty_nodes` should be 0 or explained by lesion |
| `dkt_connectome.csv` | Symmetric; no all-zero rows except post-resection |
| `nodes.mif` | Overlay on `dwiref` — labels align with anatomy |

#### Step 4.5 — Disconnectome (if enabled)

Open `connectomes/sub-<ID>/disconnectome/disconnectome_qc.html`:

| Panel | Meaning |
|-------|---------|
| Disconnection heatmap | Fractional loss D_ij per node pair |
| Options A / B / C comparison | Spared vs primary connectome |
| Lesion overlap | Lesion voxels vs DKT nodes on DWI grid |

Validated examples: [Validation](validation.md).

#### Step 5 — Node strength

| Output | Inspect |
|--------|---------|
| `reports/sub-<ID>/report.pdf` | Clinical summary: asymmetry table, ENIGMA surface |
| `figures/` | PNG gallery behind the PDF |

---

## Cohort dashboards

```bash
./run BIDS OUT group
```

| File | Contents |
|------|----------|
| `OUT/cohort_qc.html` | All subjects, Steps 1–5 rollup |
| `OUT/disconnectome_cohort_qc.html` | Step 4.5 integrity across cohort |

Regenerate manually:

```bash
python3 scripts/render_cohort_qc.py --results-root OUT --write-subject-reports
```

---

## Configuration

```yaml
qc:
  enabled: true
  subject_html: true
```

Set in `workflow/config/config.local.yaml`. Disable per-subject HTML with `qc.subject_html: false` or omit QC from the Snakemake `all` target.

---

## Example paths (tutorial data)

After the [Tutorial](tutorial.md) on bundled TBI subjects:

```text
dwi_pipeline/dwi_test_TBI/sub-EXAMPLE_fastsurfer_inpaint/qc/sub-EXAMPLE/subject_qc.html
dwi_pipeline/dwi_test_TBI/sub-EXAMPLE_fastsurfer_inpaint/connectomes/sub-EXAMPLE/disconnectome/disconnectome_qc.html
```

```bash
firefox dwi_pipeline/dwi_test_TBI/sub-EXAMPLE_fastsurfer_inpaint/qc/sub-EXAMPLE/subject_qc.html
```

---

## See also

- [Outputs](outputs.md) — full derivatives layout
- [Disconnectome](disconnectome.md) — Step 4.5 CLI defaults and detail QC
- [Pipeline steps](pipeline_steps.md) — internal workflow reference
