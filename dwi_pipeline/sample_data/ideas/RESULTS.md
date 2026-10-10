# IDEAS II public demo run

Public demo of OpenNeuro **IDEAS II** `sub-1` (`ses-1`). This is **epilepsy** sample data, **not TRACK-TBI**.

**Local output (gitignored):** `sample_data/ideas/results/sub-1_public_demo/`

**Expected artifacts when complete:**

- `connectomes/sub-1/dkt_connectome.csv`
- `qc/sub-1/subject_qc.html`

## Reproduce

```bash
# from dwi_pipeline/
bash scripts/download_ideas_sample.sh sub-1
```

Then the `./dkt run` command in [docs/datasets/ideas.md](../../docs/datasets/ideas.md) (`--fastsurfer --syn --dwi-select config/dwi_select_ideas_b2500.json`), writing to `sample_data/ideas/results/sub-1_public_demo/`.

## Citation

Cite Taylor et al. 2026 (*Epilepsia*) and OpenNeuro ds007401:

> Taylor PN, Hall G, Horsley J, Wang Y, Vos SB, Winston GP, McEvoy AW, Miserocchi A, de Tisi J, Duncan JS. Open diffusion magnetic resonance imaging and connectivity data for epilepsy and surgery: The IDEAS II release. *Epilepsia* 2026;67(6):2912–2923. https://doi.org/10.1002/epi.70186

> OpenNeuro dataset ds007401. https://doi.org/10.18112/openneuro.ds007401.v1.0.0
