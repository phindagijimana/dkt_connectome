# Field maps, QSIPrep SDC, and dual results folders (CIDUR_BIDS)

This note consolidates findings from comparing **`results_fmaps`** and **`results_fmaps_syn`** (previously referred to as **`data_results`** in some submit scripts) under CIDUR_BIDS, plus related questions on `--use-syn-sdc`, failures, literature, and research directions.

**Paths (authoritative on this system):**

- BIDS: `/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/data_bids`
- Outputs — measured-fmap–oriented run: `/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/results_fmaps`
- **Per-subject status table (QSIPrep / QSIRecon / BIDS fmaps / SDC):** `.../results_fmaps/qsiprep_qsirecon_fmap_status.csv` — regenerate with `python3 TrackTBI-Sub/build_results_fmaps_status_csv.py` (writes into that `results_fmaps` folder by default).
- Outputs — SyN-oriented / legacy tree: `/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/CIDUR_BIDS/results_fmaps_syn`
- Slurm logs referencing `RESULTS_ROOT=.../results_fmaps`: e.g. `TrackTBI-Sub/logs/qsiprep_results_fmaps_*.out`

---

## 1. Cohort coverage (`results_fmaps`)

- **76** BIDS `sub-*` folders total.
- **61** subjects have at least one DWI NIfTI under a `dwi` directory (same inclusion idea as `submit_qsiprep_array.sh` with `SUBJECT_LIST_ONLY_DWI=1`).
- **15** subjects have **no** DWI NIfTI (not in default QSIPrep list): 016, 020, 025, 027, 030, 036, 041, 042, 047, 048, 050, 055, 065, 069, 072.

For the **61 DWI subjects**, under **`results_fmaps`**:

- Each has **`qsiprep_single_run_output/sub-*`** with at least one `*desc-preproc*dwi*.nii.gz`.
- Each has **QSIRecon** outputs (e.g. `*bundlestats.csv` under `qsirecon_single_run_output` / `derivatives/qsirecon-DSIStudio/...`).

---

## 2. Subjects *without* BIDS field maps (`results_fmaps`)

**Behavior:** There is **no** `fmap/` NIfTI in BIDS for **46** of the 61 DWI subjects (15 have BIDS fmaps).

**Not “synthetic fmaps.”** QSIPrep does **not** fabricate TOPUP-style field map volumes. It uses **fieldmap-less susceptibility distortion correction via SyN-SDC** when measured fmaps are not in play.

**Saved config pattern (example `sub-002`, latest run):**

- `ignore = []`
- `use_syn_sdc = "warn"`

**Slurm / wrapper message (example):**

```text
QSIPrep: sub-002: no fmap/ NIfTI -> --use-syn-sdc warn
```

So the **extra QSIPrep CLI flag** for those subjects is **`--use-syn-sdc warn`** (no `--ignore fieldmaps` unless you deliberately force it).

**Figures:** Subjects **with** BIDS fmaps tend to have **`*topup*`**-style figures under `qsiprep_single_run_output/sub-*/figures/`; subjects **without** do not.

---

## 3. Subjects *with* BIDS field maps (`results_fmaps`)

**Saved config pattern (example `sub-001`, latest run):**

- `ignore = []`
- `use_syn_sdc = false`

**Log line (nipype):**

```text
Using single-stage SDC, TOPUP-only
```

**Wrapper message:**

```text
QSIPrep: sub-001: fmap/ NIfTI present -> measured fmaps (no --use-syn-sdc)
```

So for **fmap-present** subjects, **`results_fmaps`** uses **measured fmaps / TOPUP-style** SDC, **not** SyN.

---

## 4. When QSIPrep *fails* on measured fmaps (retry path)

This is **different** from “no fmaps in BIDS.”

**Script:** `submit_qsiprep_fmap_retry_array.sh` (and `submit_qsiprep_fmap_retry_extra5_array.sh`).

**Documented behavior:**

- **`--ignore fieldmaps --use-syn-sdc`** with **`QSIPREP_FMAP_RETRY=1`**
- Intended for subjects whose QSIPrep failed on **measured fmap EPI** (e.g. gather_inputs / bval issues).

**Default `RESULTS_ROOT`** in those submit scripts still points at **`.../CIDUR_BIDS/data_results`** in the repo text; on disk the SyN-oriented tree is now **`results_fmaps_syn`** — align paths when re-running.

**`results_fmaps` configs checked:** `ignore = []` everywhere sampled — successful outputs there are **not** the “explicitly ignore all fieldmaps” retry recipe; that recipe shows up in **`results_fmaps_syn`** for at least some fmap-present subjects (see below).

---

## 5. `results_fmaps` vs `results_fmaps_syn` (same QSIPrep version, different SDC for fmap-present IDs)

**QSIPrep version** in compared configs: `0.23.1.dev0+g634483f.d20240830` (same build family).

### 5.1 `sub-001` (has BIDS fmaps)

| Setting | `results_fmaps_syn` (e.g. run `20260405-024018_...`) | `results_fmaps` (e.g. run `20260415-020422_...`) |
|--------|--------------------------------------------------------|--------------------------------------------------|
| `ignore` | `["fieldmaps"]` | `[]` |
| `use_syn_sdc` | `"warn"` | `false` |

Interpretation:

- **`results_fmaps_syn`:** **`--ignore fieldmaps`** + **`--use-syn-sdc warn`** → **SyN fieldmap-less** path even though fmaps exist in BIDS.
- **`results_fmaps`:** **Measured fmaps / TOPUP** (`use_syn_sdc = false`).

### 5.2 `sub-002` (no BIDS fmaps)

Both trees show **`ignore = []`** and **`use_syn_sdc = "warn"`** in the saved `qsiprep.toml` — i.e. **`--use-syn-sdc warn`**, no ignore-fieldmaps flag.

**Conclusion:**

- **No-fmap subjects:** both folders use the **same SyN-SDC strategy** (`warn`).
- **Fmap-present subjects:** **`results_fmaps`** = TOPUP; **`results_fmaps_syn`** = **ignore fieldmaps + SyN warn** (not the same command).

Full one-line **`apptainer run ...`** commands are **not** stored in `qsiprep.toml`; bind mounts and every flag must be taken from the wrapper script / cluster logs if needed.

---

## 6. What `--use-syn-sdc` means

- **`--use-syn-sdc`** enables **SyN-based susceptibility distortion correction** when **measured field maps are not used** (NiPreps-style fieldmap-less SDC).
- It is **not** “synthetic TOPUP field map NIfTIs.”
- **`warn`** mode: SyN-SDC is used in the **warn** policy (QSIPrep’s handling of when to apply vs warn), as reflected in `use_syn_sdc = "warn"` in configs.

---

## 7. Credible papers (DWI: field maps vs SyN / registration-style correction)

**Note:** These compare **classes of methods** (FUGUE + field map vs ANTs SyN b0–T1, etc.). They are **not** formal validations of the **exact** QSIPrep `--use-syn-sdc` graph.

1. **Irfanoglu et al., 2017** — *Frontiers in Neuroinformatics*.  
   [Evaluation of Field Map and Nonlinear Registration Methods for Correction of Susceptibility Artifacts in Diffusion MRI](https://doi.org/10.3389/fninf.2017.00017).  
   Compares **B0 field map + FSL FUGUE** vs **ANTs SyN** registration of b0 to T1 on **test–retest DTI** cohorts.

2. **Schilling et al., 2020** — *PLOS ONE*.  
   [Distortion correction of diffusion weighted MRI without reverse phase-encoding scans or field-maps](https://doi.org/10.1371/journal.pone.0236418).  
   Synb0 + TOPUP vs gold-standard **TOPUP** with dual PE; discusses limits of **registration-based** correction.

3. **Montez et al., 2023** — *Developmental Cognitive Neuroscience*.  
   [Using synthetic MR images for distortion correction](https://pmc.ncbi.nlm.nih.gov/articles/PMC10106483/) (PMC).  
   Synthetic contrast from T1/T2 for fieldmap-less correction; relevant multimodal context.

**fMRIPrep / general pipeline (not DWI head-to-head):** Esteban et al., 2019, *Nature Methods* — [fMRIPrep](https://doi.org/10.1038/s41592-018-0235-4).

---

## 8. Publishable research directions (given both result trees)

**Asset:** Same BIDS cohort with **paired** processing for **fmap-present** subjects: **TOPUP (`results_fmaps`)** vs **ignore fmaps + SyN (`results_fmaps_syn`)**.

**Check first:** For subjects **without** BIDS fmaps, **`results_fmaps`** and **`results_fmaps_syn`** may be **near-duplicate** SyN runs — verify numerically before treating them as two independent conditions.

### 8.1 Method comparison

1. Voxel- or tract-wise **FA/MD (and other scalars)** difference maps between pipelines (fmap-present subset, aligned space).
2. **Geography of disagreement** (orbitofrontal, temporal poles, brainstem).
3. **QSIRecon bundlestats** paired differences; which bundles shift most?
4. **QC predictors** (ImageQC, motion, MI b0–T1) vs magnitude of pipeline difference.

### 8.2 Inference / cohort design

5. Same **group model** run on both pipelines: how often do **tract-level inferences** change?
6. Cost of **mixed SDC strategies** across subjects (variance / false-positive risk).

### 8.3 Stratification / clinical (TBI)

7. **Lesion proximity** × pipeline interaction.
8. **Longitudinal bias** near susceptibility regions.
9. Stability of **outcome–imaging correlations** across SDC choice.

### 8.4 Open science

10. Pre-registered comparison + shared **difference tables** / minimal code to reproduce from BIDS + two `RESULTS_ROOT`s.
11. **Harmonization** (e.g. ComBat on bundle features) to reduce TOPUP–SyN batch effects.

---

## 9. Quick reference: flags vs situation

| Situation | Typical QSIPrep behavior (from configs + logs) |
|-----------|-----------------------------------------------|
| No BIDS fmap NIfTI | `--use-syn-sdc warn`; `ignore = []` |
| BIDS fmaps present, use them (`results_fmaps`) | Measured fmaps / TOPUP; `use_syn_sdc = false`; `ignore = []` |
| Fmaps present but retry ignores them (`results_fmaps_syn` style) | `ignore = ["fieldmaps"]`; `use_syn_sdc = "warn"` |
| Documented Slurm retry for gather_inputs / fmap EPI failures | `QSIPREP_FMAP_RETRY=1` → **`--ignore fieldmaps --use-syn-sdc`** (see submit scripts) |

---

## 10. Extended publishable research questions (full enumeration)

Useful if designing a pre-registration or grant; subset can be main paper, rest supplement.

**Method comparison**

1. Global agreement: whole-brain DWI scalars (FA, MD, etc.) **paired** between `results_fmaps` and `results_fmaps_syn` in common space (fmap-present subset).
2. Local disagreement maps: effect-size / difference maps; **where** do TOPUP vs SyN-QSIPrep outputs diverge?
3. Tractography: streamline counts, length, graph metrics — systematic bias between pipelines?
4. **Bundlestats:** paired shifts per tract; orbitofrontal / temporal susceptibility geography.
5. **Registration proxy:** does MI or boundary mismatch (b0 vs T1) or ImageQC predict **size** of pipeline difference?
6. **Motion / eddy:** do outlier counts or RMS motion **mediate** TOPUP–SyN differences?

**Inference & design**

7. Same group model twice (both `RESULTS_ROOT`s): how often do **significance or direction** flip at tract level?
8. **Mixed SDC** across subjects: variance inflation or false-positive risk vs uniform SDC?
9. Express method-induced shifts as **standardized effects** vs typical TBI effect sizes in literature.

**Prediction / stratification**

10. Predict **large** TOPUP–SyN disagreement from vendor, resolution, PE dir, QC (who “needs” fmaps on this cohort?).
11. Simple **decision rule** (QC thresholds) for when SyN is acceptable vs fmaps mandatory.

**TBI-specific**

12. **Lesion proximity:** amplified disagreement near contusion / hemorrhage / interface?
13. **Longitudinal:** spurious FA / volume shifts near susceptibility regions in follow-up?
14. Stability of **clinical–imaging correlations** across SDC choice.

**Open science & harmonization**

15. Pre-registered comparison + shared diff tables / code (BIDS + two output roots).
16. Post-hoc **harmonization** (e.g. ComBat on bundle features) to reduce batch effect without killing biology.

**Internal validation (methods text)**

17. **No-fmap redundancy:** numerically compare `results_fmaps` vs `results_fmaps_syn` for no-fmap IDs; if identical within tolerance, **exclude** from two-condition design and emphasize **fmap-present** contrast only.
18. **Provenance:** archive `qsiprep.toml` (`ignore`, `use_syn_sdc`, run UUID), container digest, and `recon_bundlestats.csv` / `qc_by_scan.csv` hashes for reproducibility.

---

## 11. Log and secondary artifacts

- **Slurm stdout** (example pattern): `logs/qsiprep_results_fmaps_<jobid>_<array>.out` — first lines show `RESULTS_ROOT`, per-subject **fmap vs `--use-syn-sdc warn`** branch, then nipype QSIPrep; later **`=== QSIRecon (dsi_studio_autotrack): sub-XXX ===`** and QSIRecon version line.
- **Aggregated QC (results_fmaps):** `results_fmaps/qc_by_scan.csv`, `results_fmaps/recon_bundlestats.csv`.
- **Per-subject QSIPrep config:** `.../qsiprep_single_run_output/sub-<ID>/log/<run_uuid>/qsiprep.toml` (`[workflow]` block for `ignore`, `use_syn_sdc`).

---

---

## 12. Planned re-run: 11 fmap refresh, then “no fmap + no SyN” (optional, risky)

Cohort split for **`results_fmaps`** among the 61 **DWI** participants:

- **15** already ran with **measured fmaps (TOPUP)** — **do not re-run** unless you intend to change BIDS or the pipeline. Reference: `TrackTBI-Sub/subject_list_skip_topup_ok_15.txt`.
- **11** BIDS has **fmap/** NIfTI now, but a prior `results_fmaps` run used **SyN** (no `fmap/` at run time) — re-run to pick up TOPUP. Use **`TrackTBI-Sub/submit_dwi_11.sh`** (QSIPrep+QSIrecon, array **`%5`** by default) and `subject_list_rerun_bids_fmap_topup_11.txt`. **`QSIPREP_FMAP_RETRY=0`** (not the fmap *retry* path). Confirm logs show **measured fmaps** and `use_syn_sdc = false` in the new `qsiprep.toml`. (Legacy name: `submit_rerun_11_fmap_topup.sh` → same script.)
- **35** have **no** BIDS fmaps and previously used **`use_syn_sdc = warn`**. Second job: **`submit_dwi_35.sh`** with **`QSIPREP_NO_SYN_SDC=1`** (wrapper omits `--use-syn-sdc`). Turning SyN off without measured fmaps means **no fieldmap-based in-plane SDC** in the usual BIDS+QSIPrep sense — validate vs keeping SyN *or* limiting changes to the 11. (Legacy: `submit_rerun_35_dwi_no_fmap_no_syn.sh` → same.)

**15 no-DWI** BIDS `sub-*` are outside the 61 and are naturally skipped if you use DWI-based lists only.

*Document generated to capture the dual-folder SDC discussion; update paths if BIDS or `RESULTS_ROOT` defaults change.*

---

## 13. Production ACT/connectome pipeline (automatic)

New scripts under `TrackTBI-Sub` provide a fully automatic QSIPrep+QSIRecon production path for:

- `mrtrix_singleshell_ss3t_ACT-hsvs` recon spec (tractography/connectome inside QSIRecon spec)
- FreeSurfer license wiring (`--fs-license-file`) for anat-constrained workflows
- Slurm-array execution with DWI-only auto subject list and `%5` throttling by default

Entry point:

- `dwi_pipeline/submit.sh` (Slurm: `array.sh` → `subject.sh`)

Main controls:

- `QSIRECON_SPEC` (default: `mrtrix_singleshell_ss3t_ACT-hsvs`)
- `QSIRECON_ATLASES` (optional atlases passed to QSIRecon)
- `RESULTS_ROOT` (default: `.../results_fmaps_act_connectome`)
- `PIPELINE_MODE=all|qsiprep|qsirecon`
