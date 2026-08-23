# URMC structural networks

This directory contains DKT connectomes and related analysis tables for
URMC **CIDUR**. It contains 57 completed subjects.

```text
networks_URMC/
├── dataset_description.json
├── atlas-DKT78_nodes.tsv
├── manifest.tsv
├── artifacts_manifest.tsv
├── skipped.tsv
├── skipped_artifacts.tsv
├── probabilistic_tractography/
│   └── DKT-78/
│       └── sub-<ID>/ses-<ID>/dwi/
│           └── *_atlas-DKT78_model-iFOD2_measure-count_connectome.csv
├── node_metrics/
│   └── sub-<ID>/ses-<ID>/
│       ├── *_measure-strength_nodes.csv
│       ├── *_measure-strengthAI_nodes.csv
│       ├── *_measure-volume_nodes.csv
│       └── *_measure-volumeAI_nodes.csv
└── qc/
    └── sub-<ID>/ses-<ID>/dwi/
        └── *_desc-ImageQC_dwi.csv
```

The export contains the DKT 78-node streamline-count connectome, Step 5 node
strength and volume summaries, and QSIPrep DWI image-quality measurements.
Mean FA, mean MD, mean length, CountScaled, deterministic tractography, and
Lausanne atlases are not generated and are therefore not represented.

Use `atlas-DKT78_nodes.tsv` for matrix row/column order. `manifest.tsv` records
the connectome source, matrix validation, empty-node count, and SHA-256 digest.
`artifacts_manifest.tsv` provides equivalent provenance for node metrics and
QC. See `node_metrics/README.md` for formulas and interpretation.
