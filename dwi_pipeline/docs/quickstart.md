# Quick start

This page moved to the **[Tutorial](tutorial.md)** — end-to-end walkthrough with IDEAS sample data or bundled TBI test outputs.

Minimal dry-run (IDEAS II):

```bash
bash dwi_pipeline/scripts/download_ideas_sample.sh
export BIDS_DIR="$(pwd)/dwi_pipeline/sample_data/ideas/bids"
export FS_LICENSE=/path/to/license.txt

cd dwi_pipeline
./run "${BIDS_DIR}" /tmp/ideas_out participant \
  --participant-label 1 \
  --session-filter ses-1 \
  --fastsurfer \
  --syn \
  --dwi-select config/dwi_select_ideas_b2500.json \
  --dry-run
```

Full flag reference: [Usage](usage.md) · [Decision tables](decision_tables.md).
