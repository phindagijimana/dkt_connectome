# Disconnectome

See [`Inpainting/disconnection.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/disconnection.md) for the full method specification.

Part of the [DKT Connectome documentation](index.md).

## Defaults

- **A/B/C** all built by default; skip with `--skip-option-a` etc.
- **D default spared = C** (`--disconnection-spared C`)
- **Weighting default = count** (matches Step 4); optional `--connectome-weighting sift2`
- **Opt-in** via `--disconnection` on `./run` / `subject.sh all` (off by default; method under validation)
- Standalone: `--mode disconnectome` or `subject.sh disconnectome` (requires `lesion_mask_prepared.nii.gz` from Step 1.5)
- **SIFT1 is not used** in this pipeline

## Lesion definition (primary)

- **Binary union** of labels in `lesion_mask_prepared.json` (default: core `1` + oedema `2`)
- **Erosion: 0** (`--lesion-erode-voxels 0`) — definition-faithful primary
- **Sensitivities:** `--lesion-erode-voxels 1` (border robustness); `--core-only` (oedema exclusion)

## QC

See [integrity_qc.md](integrity_qc.md) for checks, exit codes, and validated TBI results.

**Per-subject HTML report** (auto-written by Snakemake / Step 4.5):

```text
connectomes/sub-<ID>/disconnectome/disconnectome_qc.html
connectomes/sub-<ID>/disconnectome/disconnectome_qc.json
```

**Cohort index** (BIDS App group level):

```bash
./run BIDS OUT group
# -> OUT/disconnectome_cohort_qc.html
```

CLI:

```bash
python3 scripts/evaluate_disconnectome_integrity.py --disconnectome-dir ...
python3 scripts/render_disconnectome_qc.py --disconnectome-dir ...
python3 scripts/render_disconnectome_cohort_qc.py --results-root OUT --write-subject-reports
```
