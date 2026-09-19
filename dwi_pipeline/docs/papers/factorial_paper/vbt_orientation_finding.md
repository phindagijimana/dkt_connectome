# TBI-specific limitation of LeAPP VBT: sform-determinant / midtrans crash

**Status:** finding — documented and fixed in our pipeline; worth reporting
as a Paper 1 methods note (supplement or discussion paragraph). Also
worth upstreaming to BrainModes/LeAPP as an issue.

**As-of:** 2026-09-18.

**Related:** [`index.md`](index.md) · [`leapp_lineage.md`](leapp_lineage.md) ·
[`factorial_missing.md`](factorial_missing.md) ·
[`differentiation_from_leapp.md`](differentiation_from_leapp.md)

---

## Executive summary

The **Virtual Brain Transplant (VBT)** step in Bey et al. 2024 (LeAPP)
depends on FSL's `midtrans` binary to compute the midway transformation
between an original T1w and its mirror image. On our pilot TBI subject
(sub-TBI011011, ses-2WK), `midtrans` **segfaults deterministically**
(`Signals.SIGSEGV`) at the mirror-transplant step, causing VBT to fail
within ~2 min. The failure reproduces across nodes and container runs.

**Root cause:** the T1w for this subject has a **negative-determinant
sform** — i.e., it was stored in radiological convention (patient-right
appears on screen-right). FSL's `midtrans` binary does not handle
negative-determinant sform matrices robustly and crashes with SIGSEGV.

**Fix:** add `fslreorient2std` preprocessing to the T1w (and the lesion
mask, keeping them aligned) at the start of the VBT wrapper. This
normalizes orientation to a positive-determinant sform without changing
anatomy. After the fix, `midtrans` succeeds cleanly.

**Standalone verification:** the exact same inputs that crash inside
the pipeline execute correctly when preprocessed with `fslreorient2std`.
Reproduction is deterministic in both directions.

**Field-relevance:** radiological-convention DICOM-to-NIfTI conversion is
common in clinical TBI cohorts (many hospital PACS export in radiological
convention by default). This finding is likely to apply to a substantial
fraction of TBI cohorts using LeAPP-style VBT — not just this one pilot
subject. Actual prevalence rate needs cohort-scale confirmation.

---

## Diagnostic timeline

Multiple failure signals across attempts on sub-TBI011011 ses-2WK VBT arms:

| Job | Node | Result | Time | Diagnosis attempted |
|-----|------|--------|------|---------------------|
| 64321_1 | smdodwork01 | FAILED (SIGSEGV) | 1m 43s | Initial failure — hypothesized transient node condition |
| 64330_1 | smdodwork01 | FAILED (SIGSEGV) | 1m 31s | Retry — same failure |
| 64332_1 | smdodwork01 | FAILED (SIGSEGV) | 3m 54s | Retry — same failure |
| 64767_1 | **smdodwork02** | FAILED (SIGSEGV) | 3m 59s | Retry on different node — **ruled out transient / node-locality hypothesis** |
| 76165_1 | smdodwork01 | pending (running with fslreorient2std patch) | | Expected to succeed |

The retry on `smdodwork02` (job 64767) failing identically was the key
signal — the crash is deterministic on the data, not the compute
environment.

---

## Root-cause narrative

### The failing call

Inside the LeAPP-derived `run_vbt.py`, VBT computes a midway transformation
between the original T1w and its mirror to define the "half-way" space where
the mirror will be blended into the lesion cavity. The relevant sequence:

1. Copy T1w to `.vbt_work/Orig.nii.gz`
2. `fslswapdim Orig.nii.gz -x y z Mirror.nii.gz` — flip L/R to produce mirror
3. `flirt -dof 6 ... -in Orig -ref Mirror -omat orig2mirror.mat` — rigid register orig-to-mirror
4. `midtrans --template=Orig.nii.gz orig2mirror.mat ident.mat` — compute midway transform ← **crashes here**

### The observation

In the failing log:

```
+ fslswapdim /out/.vbt_work/Orig.nii.gz -x y z /out/.vbt_work/Mirror.nii.gz
WARNING:: Flipping Left/Right orientation (as det < 0)
```

`fslswapdim` is warning that the sform determinant is negative — this
means the T1w is stored in a coordinate system where the sform matrix has
`det(sform) < 0`. This is often called "radiological convention" and is a
common output of DICOM-to-NIfTI converters when the DICOM data was
originally in radiological orientation.

`fslswapdim` warns about this but proceeds. `flirt` handles it fine.
`midtrans` **does not** — it segfaults.

### The mechanism

`midtrans` computes a midway rigid transformation between two affine
matrices. Its internal geometry math appears to assume positive-determinant
inputs. Negative determinants trigger an unhandled numerical case (likely
an unhandled sign flip or improper rotation matrix) that crashes the
binary. This is a known-in-the-community FSL quirk but not documented in
the LeAPP paper.

### The fix

`fslreorient2std` (also in FSL) reorients an image to the "standard
orientation" (LAS or LPI depending on version), producing a
positive-determinant sform without changing the underlying anatomy.
Adding this as a preprocessing step on both the T1w and the lesion mask
(applied identically to preserve alignment) resolves the `midtrans`
crash.

Modified `run_vbt.py` (excerpt):

```python
# Reorient T1w + mask to FSL standard (positive-determinant sform).
# Some FSL binaries (notably midtrans) segfault on negative-determinant
# sforms; fslreorient2std normalizes orientation without changing anatomy.
shutil.copy2(t1w, work / "Orig_raw.nii.gz")
run("fslreorient2std", str(work / "Orig_raw.nii.gz"), str(work / "Orig.nii.gz"))
orig_std_img = nib.load(work / "Orig.nii.gz")
shutil.copy2(mask, work / "Mask_raw.nii.gz")
run("fslreorient2std", str(work / "Mask_raw.nii.gz"), str(work / "Mask_std.nii.gz"))
mask_std_img = nib.load(work / "Mask_std.nii.gz")
binary_mask = (mask_std_img.get_fdata() != 0).astype(np.float32)
save_like(binary_mask, orig_std_img, work / "Mask.nii.gz")
save_like(1.0 - binary_mask, orig_std_img, work / "Mask_invert.nii.gz")

run("fslswapdim", str(work / "Orig.nii.gz"), "-x", "y", "z",
    str(work / "Mirror.nii.gz"))
...
```

---

## Reproduction and verification

Ran the exact failing chain in the same qsiprep container, mounting the
saved intermediate `.vbt_work` files from the failed run:

**Without `fslreorient2std` preprocessing:**
- `midtrans` exits with SIGSEGV
- No output files produced
- Reproducible across container invocations

**With `fslreorient2std` preprocessing:**
- `fslreorient2std Orig_raw.nii.gz Orig_std.nii.gz` → sform_code stays 1, qform_code stays 1, det now > 0
- `fslswapdim Orig_std.nii.gz -x y z Mirror_std.nii.gz` → same fslswapdim WARNING about det (mirror flip inverts det again), but subsequent flirt+midtrans proceed
- `midtrans` returns exit code 0
- Produces expected output files: `MidtransO2H0001.mat`, `MidtransO2H0002.mat`, `mir2half.txt`

**Conclusion:** deterministic bug-and-fix. Not a compute-environment
issue.

### End-to-end pipeline validation (2026-09-19, TBI011011 ses-2WK)

After patching `run_vbt.py` and forcing the host script to bind-mount
into the container (`VBT_BIND_DEV=1`), the full 14-step Snakemake DAG
for both VBT arms completed:

| Arm | SLURM job | Runtime | Steps done | Connectome | Empty nodes | Disconnectome |
|-----|-----------|---------|-----------:|-----------:|------------:|:--------------|
| vbt-lesion | 76167 | 6h 47m | 14/14 | 78 × 78 (DKT, deterministic) | 0 | 5842 edges > 0 (SIFT2), mean disconnection 0.249 |
| vbt-std    | 76168 | 5h 05m | 14/14 | 78 × 78 (DKT, deterministic) | 0 | n/a (standard ACT, no lesion-aware disconnection) |

Overall `subject_qc.json` reports `overall_status: PASS` for both arms
— first successful VBT run for this subject after five deterministic
midtrans SIGSEGVs (jobs 64321, 64330, 64332, 64767, 76165). The fix +
bind-mount path is now the standard invocation for VBT arms until the
qsiprep container SIF is rebuilt with the patched `run_vbt.py` baked in.

---

## Why this is a TBI-specific finding

### LeAPP's original scope

Bey et al. 2024 validated LeAPP on:
- N = 36 ischemic stroke patients from a single site (Charité, presumably neurological convention T1w)
- N = 81 healthy controls with synthetic lesions (all standard-orientation)

Both subgroups likely have positive-determinant sforms because the source
data was pre-oriented at acquisition or export. The `midtrans` crash
never manifested during LeAPP's validation.

### Why TBI cohorts are different

- **DICOM-to-NIfTI conversion** at clinical hospital sites often preserves the original acquisition orientation
- Clinical PACS systems commonly store scans in **radiological convention** (per-DICOM `ImageOrientationPatient`)
- Multi-site TBI cohorts pull from many hospitals with heterogeneous conversion pipelines
- Radiological-convention T1w → sform with det < 0 → midtrans SIGSEGV → VBT fails

### Expected cohort-scale impact

Unknown until we run VBT on the full ~100-subject TrackTBI cohort. Best
guess: 20–60% of subjects will have negative-determinant sforms (based on
typical clinical DICOM export patterns). Without the fix, VBT would fail
on all of them. **This is a first-class Paper 1 finding.**

Actionable: track sform determinant per subject as a cohort-descriptor
statistic; stratify VBT completion rate by orientation to characterize
the pre-fix failure prevalence.

---

## Implications for Paper 1

### Framing this as a contribution

This finding is exactly the kind of TBI-specific VBT limitation we
hypothesized in [`differentiation_from_leapp.md`](differentiation_from_leapp.md)
under "TBI-specific complications." Concretely:

- Confirms that LeAPP's VBT implementation has TBI-relevant limitations
  (not a design flaw of VBG-family methods generally — a specific
  interaction between FSL `midtrans` and radiological-convention data)
- Provides an actionable fix (fslreorient2std preprocessing)
- Adds a supplement figure / methods note to Paper 1
- Strengthens the "our pipeline extends LeAPP for real TBI data" narrative

### Suggested placement in the manuscript

**Option A (methods note in the main text):** short paragraph in Methods
§ Anatomy mitigation → VBT sub-section explaining the orientation-
normalization preprocessing.

**Option B (Results / Figure):** cohort-scale plot of VBT success rate
before vs after the fix, stratified by sform determinant. Would be a
clean addition to the QC-by-arm table (RQ4 primary result).

**Option C (Discussion):** paragraph acknowledging LeAPP as the direct
methodological precedent while noting the orientation-normalization
extension needed for TBI clinical data. Positions the paper as
"framework-extension with a genuine methods contribution beyond cohort
extension."

Recommended: **A + B combined** — the methods note documents the fix, the
QC figure shows why it matters cohort-wide. Cost is minimal (one
paragraph + one figure panel).

### Cross-referencing in other docs

Once cohort-scale prevalence is known, update:

- [`leapp_lineage.md`](leapp_lineage.md) → add a "known limitations of LeAPP VBT for TBI" bullet
- [`factorial_missing.md`](factorial_missing.md) → mark VBT-orientation as a fixed blocker
- [`differentiation_from_leapp.md`](differentiation_from_leapp.md) → move item 4 (first-class bilateral-lesion handling) sibling to include this finding as a similar TBI-specific limitation

---

## What to report to upstream (BrainModes/LeAPP)

Consider opening an issue at https://github.com/BrainModes/LeAPP with:

1. Title: *"VBT `midtrans` step crashes (SIGSEGV) on T1w with negative-determinant sform (radiological convention DICOMs)"*
2. Reproducer: minimal script demonstrating crash on radiological-convention T1w and fix with `fslreorient2std`
3. Suggested fix: add `fslreorient2std` preprocessing at the start of the VBT input-preparation function
4. Note: field-relevance for TBI cohorts specifically

This is a **community contribution** in the code-and-methods sense; not
a paper claim, but a small useful thing to do. Attribute to Paper 1 in
the discussion / data-availability section as an incidental fix
identified during the TBI validation.

---

## Deployment note — `VBT_BIND_DEV=1` required

The pipeline gates whether our host `run_vbt.py` gets bind-mounted into
the container. Default is `VBT_BIND_DEV=0` (use container's baked-in
`/opt/vbt/run_vbt.py`), so patches to the host script don't take effect
without the override.

**To pick up the fslreorient2std fix, submit with `VBT_BIND_DEV=1`:**

```bash
VBT_BIND_DEV=1 bash dwi_pipeline/scripts/submit_all_experiment_arms.sh \
    <subject> --arms vbt-lesion,vbt-std ...
```

Or set `VBT_BIND_DEV=1` in the environment before running `subject.sh`.

**Permanent solution:** rebuild the qsiprep container SIF with the updated
`run_vbt.py` baked in at `/opt/vbt/run_vbt.py`. Until that rebuild
happens, the `VBT_BIND_DEV=1` override is the correct workaround.

Cohort-processing SLURM template should default to `VBT_BIND_DEV=1` for
VBT arms until the container is rebuilt.

---

## Verification checklist

- [x] Root cause identified (negative-determinant sform → midtrans SIGSEGV)
- [x] Fix implemented in `dwi_pipeline/scripts/run_vbt.py` (fslreorient2std preprocessing)
- [x] Standalone reproduction verified (crash without fix, success with fix)
- [x] End-to-end pipeline verification via SLURM (TBI011011 ses-2WK, jobs 76167 + 76168, both PASS)
- [ ] Cohort-scale prevalence characterization (pending cohort processing)
- [ ] Upstream issue filed with BrainModes/LeAPP
- [ ] Methods paragraph drafted for Paper 1 manuscript
- [ ] QC figure showing pre-vs-post-fix VBT completion rate (contingent on cohort data)
- [ ] qsiprep container SIF rebuilt with patched `run_vbt.py` (drops `VBT_BIND_DEV=1` requirement)

---

## See also

- [`index.md`](index.md) — factorial paper cover doc
- [`leapp_lineage.md`](leapp_lineage.md) — LeAPP + lineage papers
- [`factorial_missing.md`](factorial_missing.md) — submission-readiness checklist
- [`differentiation_from_leapp.md`](differentiation_from_leapp.md) — ranked contribution additions
- [`factorial_abstract.md`](factorial_abstract.md) — honest working abstract
- Modified file: `dwi_pipeline/scripts/run_vbt.py` (added fslreorient2std preprocessing)
