# dwi_test_TBI — local BIDS inputs + pipeline RESULTS_ROOT

Keep **inputs and outputs together** under this folder. Leave large cohort
archives (e.g. local BIDS storage) for data storage only.

## Layout

```text
dwi_pipeline/dwi_test_TBI/
  bids/                                 # BIDS inputs (gitignored)
    dataset_description.json
    sub-TBI011011/
    sub-TBI011204/
  sub-TBI011011_fastsurfer_inpaint/     # RESULTS_ROOT
  sub-TBI011204_fastsurfer_inpaint/     # RESULTS_ROOT
  README.md                             # tracked
```

## RESULTS_ROOT naming (required format)

One subdirectory per subject × pipeline settings:

```text
sub-<SUBJECT>_<recon>[_<flags>]/
```

| Piece | Meaning | Examples |
|-------|---------|----------|
| `sub-<SUBJECT>` | BIDS subject id | `sub-TBI011011` |
| `<recon>` | Recon tool | `fastsurfer`, `recon-all` |
| optional flags | Notable step choices | `inpaint` when Step 1.5 ran |

Examples:

- `sub-TBI011011_fastsurfer_inpaint`
- `sub-TBI011204_fastsurfer_inpaint`
- `sub-TBI011011_recon-all` (no inpaint)

Do not reuse a `RESULTS_ROOT` for a different settings combination.

## Run

```bash
cd /path/to/TrackTBI-Sub

export BIDS_DIR="$(pwd)/dwi_pipeline/dwi_test_TBI/bids"
export RESULTS_ROOT="$(pwd)/dwi_pipeline/dwi_test_TBI/sub-TBI011011_fastsurfer_inpaint"

# example: re-run Step 5 only
# bash dwi_pipeline/workflow/run_subject.sh nodestrength TBI011011
```

Do not write derivatives into `bids/`. Contents of this folder (except this
README) are gitignored.
