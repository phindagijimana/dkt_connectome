# Test fixtures

## `bids_minimal/`

Minimal **public** BIDS dataset for CI smoke tests and BIDS Apps registry validation.
Synthetic 8×8×8 NIfTI volumes — no participant data.

Regenerate:

```bash
python3 dwi_pipeline/tests/fixtures/generate_bids_fixture.py
```

Smoke test (dry-run, no containers):

```bash
export BIDS_APP_CI=1
export FS_LICENSE=/tmp/license.txt
touch /tmp/license.txt
./run tests/fixtures/bids_minimal /tmp/out participant \
  --participant-label EXAMPLE \
  --session-filter baseline \
  --dry-run --no-sdc --no-dwi-filter --random-seed 42
```
