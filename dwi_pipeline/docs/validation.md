# Validation

Benchmark subjects, integrity QC expectations, and cohort context for the DKT Connectome.

---

## Study context

The pipeline is **study-agnostic** — it runs on any BIDS DWI dataset with optional lesion masks.

This software was used on the **TRACK-TBI DoD** project (Phase 1: on the order of **650** participants, **two timepoints** each; about **100** with lesion masks). Those inputs and derivatives stay under the study **data-use agreement** and are **not** in this repository.

What we share for software checks is **one IDEAS II subject** (no lesion) and **one BTC glioma subject** (lesion-aware path). Those two runs show the pipeline works; they are **not** TRACK-TBI clinical validation.

Cite dataset use separately from pipeline software — see [Citation](citation.md).

---

## Orchestrator image vs host runs

The published BIDS App image (`phindagijimana321/dkt-connectome:0.3.1` / GHCR) is an **orchestrator**: Snakemake + `./run`. It does **not** contain QSIPrep, FreeSurfer, or the other step `.sif` files.

| What | Where it was checked | What it proves |
|------|----------------------|----------------|
| `docker run … --version` / `dkt version` → `0.3.1` | GitHub Actions **Docker publish** on tag `v0.3.1` | Image identity |
| Fixture `--dry-run --mode qsiprep` (including `--fastsurfer-device`, `--force-syn`, `--act-mode`, `--connectome-atlases`) | Same CI job + HPC Apptainer of the Hub image | Wrapper flags and Snakemake DAG |
| IDEAS II `sub-1` / `sub-6` Steps 1–5 | Host `./run` + Apptainer **step** SIFs | Default no-lesion path |
| BTC glioma PAT20 (lesion-aware / `--disconnection`) | Host `./run` + step SIFs | Lesion path |

A from-scratch IDEAS or glioma **rerun inside the orchestrator container** is not required to list the app: the container and the host `./run` are the same scripts. Pull step SIFs with `./dkt install` (or `-e DKT_AUTO_INSTALL=1`) before a real participant run.

---

## Public software demos

| Demo | Role | OpenNeuro |
|------|------|-----------|
| **IDEAS II** | First-run / no-lesion path | [ds007401](https://openneuro.org/datasets/ds007401) |
| **BTC glioma PAT20** | Lesion-aware path (`--disconnection`) | [ds001226](https://openneuro.org/datasets/ds001226) |

These subjects demonstrate that the pipeline runs. They are **not** a TBI clinical validation cohort.

QSIPrep / QSIRecon-style reportlets and the QC table: **[Sample results](sample_results.md)**.

---

## IDEAS II (no-lesion demo)

| Resource | Link |
|----------|------|
| Download | `bash dwi_pipeline/scripts/download_ideas_sample.sh` |
| Subjects | `sub-1`, `sub-6` (`ses-1`: T1w, FLAIR, DWI) |
| DWI shells | 0, 300, 700, **2500** s/mm² — use `config/dwi_select_ideas_b2500.json` |
| OpenNeuro | [ds007401](https://openneuro.org/datasets/ds007401) |
| Docs | [Sample data (IDEAS II)](datasets/ideas.md) |

**Golden run command:** see [IDEAS sample page](datasets/ideas.md#example-run). Snakemake dry-run with `config/dwi_select_ideas_b2500.json` validates the full DAG (QSIPrep → FastSurfer → QSIRecon → connectome → nodestrength → QC).

**Cite when using these data:** Taylor PN, et al. *Epilepsia* 2026. [10.1002/epi.70186](https://doi.org/10.1002/epi.70186) and OpenNeuro dataset [10.18112/openneuro.ds007401.v1.0.0](https://doi.org/10.18112/openneuro.ds007401.v1.0.0).

---

## BTC glioma PAT20 (lesion-aware demo)

One public glioma subject with a tumor mask renamed to the pipeline lesion convention (`*_T1w_label-lesion_roi.nii.gz`). Use `--disconnection` to exercise Step 4.1.

| Resource | Link |
|----------|------|
| Download | `bash dwi_pipeline/scripts/download_btc_glioma_sample.sh` |
| Docs | [BTC glioma sample](datasets/btc_glioma.md) |
| OpenNeuro | [ds001226](https://openneuro.org/datasets/ds001226) |

This is a **software demo of lesion-aware inputs**, not a TBI or glioma outcome study.

---

## Golden QC (produced locally)

Golden QC is **not shipped** in the repository. After you complete the [Tutorial](tutorial.md) on the public IDEAS II sample, open QC HTML under `RESULTS_ROOT/qc/sub-<ID>/` and (if disconnectome ran) `RESULTS_ROOT/connectomes/sub-<ID>/disconnectome/`.

Doc figures: [Quality control](qc.md) (`docs/img/qc/*.png`).

---

## Disconnectome integrity (Step 4.1)

Script: `scripts/evaluate_disconnectome_integrity.py`

### Local integrity checks

After a full disconnectome run on local test data, run `scripts/evaluate_disconnectome_integrity.py` and review PASS/WARN/FAIL in the terminal or JSON sidecars. Criteria are documented in [Disconnectome § Integrity QC](disconnectome.md#integrity-qc); numeric benchmarks are environment-specific and belong in local notes, not the public repo.

### PASS criteria (summary)

| Check | PASS |
|-------|------|
| Options B & C under **count** weighting | Zero `spared > primary` edges |
| `disconnection_matrix.csv` | Matches spared option C (default) |
| D values | In [0, 1]; symmetric |

Full spec: [Disconnectome § Integrity QC](disconnectome.md#integrity-qc) · [Methods § Step 4.1](methods/step4_1_disconnectome.md).

---

## Connectome checks (Step 4)

| Check | Expected |
|-------|----------|
| Matrix shape | 78×78 (DKT default) |
| `parcellation.json` | `n_nodes: 78`, correct segmentation file |
| Empty nodes | 0 for standard DKT; warn if >0 post-resection |
| Weighting | `count` unless explicitly using SIFT2 |

---

## Inpainting QC (Step 1.1)

From `inpainting_qc.json` / `check_inpainting.py`:

| What | Rule |
|------|------|
| Step FAIL | No volume, wrong grid, NaN *r*, or empty mask |
| Outside-mask Pearson *r*, control *r*, drop | Always printed (descriptive IQMs) |
| 0.995 / 0.01 | Optional local defaults, **not** a published cutoff. They abort the run only if `INPAINT_FAIL_ON_QC=1` |

Pollak et al. 2025 report SSIM/PSNR of the fill and Dice/HD95 of FastSurfer, not a Pearson *r* ≥ 0.995 gate. Judge the before/after PNGs (MRIQC-style visual QC). Details: [Methods § Step 1.1](methods/step1_1_inpaint.md).

---

## Regression testing

CI runs on GitHub Actions:

- Snakemake lint + dry-run
- MkDocs strict build
- Schema validation tests

Maintainers: re-run integrity scripts after changing connectome or disconnectome logic.

---

## Reporting in publications

1. Cite upstream tools per [References by step](references.md)
2. State pipeline version (`./run --version` → `app.json`)
3. Document flags: recon tool, SDC mode, weighting, disconnectome opt-in
4. Report integrity QC pass/fail for disconnectome cohorts
5. For the six-arm factorial on lesion subjects: report per-arm completion, Step 3.1 pathology QA, and pre-specified contrasts — see **[TBI experimental arms](TBI_Experimental_Arms.md)**

---

## See also

- [Quality control](qc.md)
- [Disconnectome § Integrity QC](disconnectome.md#integrity-qc)
- [Tutorial](tutorial.md)
