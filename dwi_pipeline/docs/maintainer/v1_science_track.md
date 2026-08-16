# v1.0 science track (P4)

Runbook for **QSIPrep-level trust**: cohort validation, paper artifacts, and the **v1.0** release. This does **not** block BIDS App usage at v0.2.x.

**Paper plan (living):** [`sample_software_paper/paper_plan.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/sample_software_paper/paper_plan.md) §11.

**Engineering prerequisite:** [Integration CI](integration_ci.md) green with real QSIPrep before claiming v1.0 reproducibility.

---

## Version policy

| Tag | Meaning |
|-----|---------|
| **v0.2.x** | BIDS App + docs + CI dry-run; registry optional |
| **v1.0** | Frozen science claim: SDC matrix documented, digest table, URMC n=61 + HCP n=10 QC, preprint DOI |

Do **not** tag v1.0 until P4.3–P4.4 complete and [container digests](container_digests.md) regenerated from production pulls.

---

## P4 checklist (who / what)

| # | Task | Owner | Command / artifact |
|---|------|-------|-------------------|
| P4.1 | Freeze **v1.0** + release notes (4 SDC modes) | Philbert | `dwi_pipeline/RELEASE_NOTES.md`, `git tag v1.0` |
| P4.2 | Pin container digests + supplement S4 | Philbert | `bash scripts/install.sh --mode all` → `python3 scripts/generate_container_digests_md.py` |
| P4.3 | URMC **n=61** end-to-end + QC CSV | Daniel + Philbert | `submit.sh` + `batch_postprocess.sh` → `cohort_qc.html` |
| P4.4 | HCP-YA **n=10** baseline stats | Daniel | Public HCP IDs in supplement S6 |
| P4.5 | Radiological review rubric | James | Supplement S5 |
| P4.6 | Comparison Table 1 finalized | Nishant | `paper_plan.md` |
| P4.7 | Figures 1–7 journal DPI | Team | `sample_software_paper/` |
| P4.8 | bioRxiv preprint DOI | Philbert | Cross-link Zenodo software DOI |
| P4.9 | `CITATION.cff` paper reference | Philbert | After journal acceptance |

---

## URMC n=61 batch (P4.3)

**Inputs (in-repo):**

- Subject lists: `subject_list_urmc_with_fmap.txt`, `subject_list_urmc_no_fmap.txt`
- Config: `workflow/config/config.yaml` + site `config.local.yaml`

**Run:**

```bash
export BIDS_DIR=/path/to/URMC/BIDS
export RESULTS_ROOT=/scratch/tracktbi/dkt_v1
export FS_LICENSE=/path/to/license.txt
export SUBJECT_LIST_FILE=dwi_pipeline/subject_list_urmc_with_fmap.txt

bash dwi_pipeline/submit.sh          # Slurm array
bash dwi_pipeline/scripts/batch_postprocess.sh   # cohort QC + derivatives
```

**Deliverables:**

- `RESULTS_ROOT/cohort_qc.html`
- Per-subject `subject_qc/sub-*/index.html`
- Summary CSV for paper (script TBD or export from cohort QC JSON)
- Failed subjects logged with SDC mode + retry notes (SyN / `--no-sdc` policy)

**Backfill:** Subjects processed under older pins → `workflow/backfill_markers.sh` before re-run policy.

---

## HCP-YA n=10 (P4.4)

1. Select 10 HCP subject IDs (document in supplement S6).
2. BIDS layout per HCP conversion used at URMC.
3. Run `./run` with **same v1.0 config** as URMC (no site-specific hacks).
4. Compare DKT connectome edges to reference (correlation / ICC table in manuscript §3).
5. If r &lt; 0.9 per-edge, document in limitations — do not silently change specs.

---

## Zenodo + v1.0 tag (ties to P2.2)

1. Enable [Zenodo–GitHub integration](https://docs.github.com/en/architecture/backup-and-restore/zenodo-for-github) for `phindagijimana/dkt_connectome`.
2. Cut **GitHub Release v1.0** → Zenodo archives → copy DOI.
3. Update `CITATION.cff`, [citation.md](../citation.md), `app.json` HowToAcknowledge.
4. Manuscript §Data availability: replace `[Zenodo DOI]` placeholder.

See [Maintainer tasks §17](maintainer_tasks.md#17-zenodo-archive-doi).

---

## Suggested timeline

```text
Parallel track A (engineering):  integration CI green → digest table → v1.0-rc tag
Parallel track B (cohorts):      URMC 61 + HCP 10 on frozen config
Merge:                           radiology review → figures → bioRxiv → v1.0 tag + Zenodo
```

---

*Update rows when tasks close. Link PRs or commit SHAs in Notes column if helpful.*
