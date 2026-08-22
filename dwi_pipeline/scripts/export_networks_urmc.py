#!/usr/bin/env python3
"""Export completed URMC connectomes and analysis tables."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
from pathlib import Path


NODE_METRICS = {
    "strength": ("strength/per_subject/sub-{subject}_strength.csv", 78),
    "strengthAI": ("strength/per_subject/sub-{subject}_ai.csv", 39),
    "volume": ("volume/per_subject/sub-{subject}_volume.csv", 78),
    "volumeAI": ("volume/per_subject/sub-{subject}_volume_ai.csv", 39),
}

NODE_METRICS_README = """# DKT node metrics

These tables are copied from Step 5 of the DKT connectome pipeline. The
underlying graph is the symmetric, zero-diagonal, count-weighted DKT-78
connectome generated from probabilistic iFOD2 tractography.

## Strength

`*_measure-strength_nodes.csv` has one row per DKT node (78 rows). Node strength
is the sum of every edge touching node *i*:

`strength_i = sum(W_ij for j != i)`

Because the exported connectome is count-weighted, strength is a sum of
streamline counts. It is not an anatomical axon count and depends on the
tractography and seeding configuration.

**Why it is calculated:** strength reduces a full row of the connectome to one
regional summary, making it easier to rank regions, compare homologous nodes,
and test whether a region has relatively reduced or increased total structural
connectivity.

## Strength asymmetry

`*_measure-strengthAI_nodes.csv` has one row per left/right homologous pair
(39 rows). `side_ai` is:

`(L_strength - R_strength) / (L_strength + R_strength)`

Positive values mean greater left strength, negative values mean greater right
strength, and zero is symmetric. `log_ai` is `ln(L_strength / R_strength)`.
These are raw asymmetry measures, not normative z-scores. Bilateral injury can
leave the asymmetry near zero.

**Why it is calculated:** paired asymmetry controls partly for global scaling
and highlights lateralized connectivity differences that may accompany a
focal injury. It must be interpreted with the bilateral-injury caveat above.

## Volume

`*_measure-volume_nodes.csv` has one row per DKT node (78 rows).
`volume_mm3` is the number of voxels assigned to the node in `nodes.mif`
multiplied by voxel volume. The labels have been resampled to the DWI grid, so
this is the connectome-node volume used by the pipeline, not a native-space
FreeSurfer morphometry measurement or an intracranial-volume-normalized value.

**Why it is calculated:** node size helps interpret connectivity because larger
regions can contain more tissue and receive more streamline endpoints. It also
provides an anatomical measurement against which strength differences can be
compared.

## Volume asymmetry

`*_measure-volumeAI_nodes.csv` has one row per left/right homologous pair
(39 rows). `side_ai` is:

`(L_volume_mm3 - R_volume_mm3) / (L_volume_mm3 + R_volume_mm3)`

Positive values indicate a larger left node and negative values a larger right
node. `log_ai` is `ln(L_volume_mm3 / R_volume_mm3)`.

**Why it is calculated:** volume asymmetry indicates whether a left/right
connectivity difference may be accompanied by regional size asymmetry. Comparing
strength AI with volume AI helps distinguish a connectivity imbalance from a
purely morphological or parcellation-size effect.

Use `atlas-DKT78_nodes.tsv` at the dataset root for node order and labels.
"""

QC_README = """# DWI image-quality tables

Each `*_desc-ImageQC_dwi.csv` is copied unchanged from QSIPrep. It contains one
row of acquisition and preprocessing quality measurements, including motion
(mean/max framewise displacement), bad-slice counts, neighboring-volume
correlation, contrast-to-noise estimates, and image dimensions. These fields
are quality-control covariates and exclusion aids; they are not connectivity
measurements.
"""


def matrix_shape_and_empty_nodes(path: Path) -> tuple[int, int, int]:
    rows: list[list[float]] = []
    with path.open(newline="") as stream:
        for row in csv.reader(stream):
            if row:
                rows.append([float(value) for value in row])
    n_rows = len(rows)
    n_cols = len(rows[0]) if rows else 0
    if any(len(row) != n_cols for row in rows):
        raise ValueError(f"ragged matrix: {path}")
    empty = sum(
        all(value == 0 for value in rows[index])
        and all(rows[row][index] == 0 for row in range(n_rows))
        for index in range(min(n_rows, n_cols))
    )
    return n_rows, n_cols, empty


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def csv_row_count(path: Path) -> int:
    with path.open(newline="") as stream:
        return sum(1 for _ in csv.reader(stream)) - 1


def resolve_session(results_root: Path, subject: str) -> str:
    qsirecon = results_root / "qsirecon_single_run_output"
    sessions = {
        path.name
        for path in qsirecon.glob(f"**/sub-{subject}/ses-*")
        if path.is_dir()
    }
    if len(sessions) != 1:
        raise ValueError(
            f"sub-{subject}: expected one processed session, found "
            f"{sorted(sessions) or 'none'}"
        )
    return sessions.pop()


def write_node_lookup(lut: Path, destination: Path) -> None:
    # The LUT accepts both FreeSurfer thalamus spellings at IDs 33 and 40.
    # Keep the later *-Proper aliases so each matrix index appears once.
    nodes: dict[int, tuple[str, str]] = {}
    for line in lut.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        try:
            node_id = int(fields[0])
        except (ValueError, IndexError):
            continue
        if node_id == 0:
            continue
        nodes[node_id] = (fields[1], fields[2])

    if len(nodes) != 78:
        raise ValueError(f"expected 78 DKT labels in {lut}, found {len(nodes)}")
    with destination.open("w", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t")
        writer.writerow(["node_id", "abbreviation", "freesurfer_label"])
        writer.writerows(
            (node_id, *nodes[node_id]) for node_id in sorted(nodes)
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pipeline-root", type=Path, required=True)
    parser.add_argument("--subject-list", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--group", default="Group 1")
    args = parser.parse_args()

    pipeline_root = args.pipeline_root.resolve()
    results_root = pipeline_root / "results"
    output = args.output.resolve()
    matrix_root = output / "probabilistic_tractography" / "DKT-78"
    deterministic_root = output / "deterministic_tractography" / "DKT-78"
    matrix_root.mkdir(parents=True, exist_ok=True)
    deterministic_root.mkdir(parents=True, exist_ok=True)

    subjects = [
        line.strip()
        for line in args.subject_list.read_text().splitlines()
        if line.strip() and not line.startswith("#")
    ]
    exported: list[dict[str, object]] = []
    artifacts: list[dict[str, object]] = []
    skipped: list[dict[str, str]] = []
    skipped_artifacts: list[dict[str, str]] = []

    for subject in subjects:
        connectome_dir = results_root / "connectomes" / f"sub-{subject}"
        legacy_source = connectome_dir / "dkt_connectome.csv"
        count_source = connectome_dir / "dkt_connectome_count.csv"
        if not count_source.is_file():
            count_source = legacy_source
        if not count_source.is_file():
            skipped.append({"subject": f"sub-{subject}", "reason": "matrix missing"})
            continue

        try:
            session = resolve_session(results_root, subject)
            n_rows, n_cols, empty_nodes = matrix_shape_and_empty_nodes(count_source)
            if (n_rows, n_cols) != (78, 78):
                raise ValueError(f"unsupported matrix shape {n_rows}x{n_cols}")
        except ValueError as error:
            skipped.append({"subject": f"sub-{subject}", "reason": str(error)})
            continue

        destination_dir = matrix_root / f"sub-{subject}" / session / "dwi"
        destination_dir.mkdir(parents=True, exist_ok=True)
        matrix_sources = {
            "count": (count_source, "streamline count"),
            "sift2": (connectome_dir / "dkt_connectome_sift2.csv", "SIFT2 weight"),
            "meanlength": (
                connectome_dir / "dkt_connectome_meanlength.csv",
                "mean streamline length (mm)",
            ),
            "meanfa": (
                connectome_dir / "dkt_connectome_meanfa.csv",
                "mean tract-sampled FA",
            ),
            "meanmd": (
                connectome_dir / "dkt_connectome_meanmd.csv",
                "mean tract-sampled MD",
            ),
        }
        for measure, (source, measure_label) in matrix_sources.items():
            if not source.is_file():
                if measure != "count":
                    skipped_artifacts.append(
                        {
                            "subject": f"sub-{subject}",
                            "session": session,
                            "artifact": f"connectome {measure}",
                            "reason": "source missing",
                        }
                    )
                continue
            rows, cols, measure_empty_nodes = matrix_shape_and_empty_nodes(source)
            if (rows, cols) != (78, 78):
                skipped_artifacts.append(
                    {
                        "subject": f"sub-{subject}",
                        "session": session,
                        "artifact": f"connectome {measure}",
                        "reason": f"unsupported matrix shape {rows}x{cols}",
                    }
                )
                continue
            filename = (
                f"sub-{subject}_{session}_atlas-DKT78_model-iFOD2_"
                f"measure-{measure}_connectome.csv"
            )
            destination = destination_dir / filename
            shutil.copy2(source, destination)
            exported.append(
                {
                    "subject": f"sub-{subject}",
                    "session": session,
                    "group": args.group,
                    "tractography": "probabilistic iFOD2",
                    "atlas": "DKT-78",
                    "measure": measure_label,
                    "matrix_shape": "78x78",
                    "empty_nodes": measure_empty_nodes,
                    "source": str(source),
                    "exported_file": str(destination.relative_to(output)),
                    "sha256": sha256(destination),
                }
            )

        sd_destination_dir = deterministic_root / f"sub-{subject}" / session / "dwi"
        sd_sources = {
            measure: (
                connectome_dir / f"dkt_model-SDSTREAM_connectome_{measure}.csv",
                measure_label,
            )
            for measure, (_, measure_label) in matrix_sources.items()
        }
        for measure, (source, measure_label) in sd_sources.items():
            if not source.is_file():
                continue
            rows, cols, measure_empty_nodes = matrix_shape_and_empty_nodes(source)
            if (rows, cols) != (78, 78):
                skipped_artifacts.append(
                    {
                        "subject": f"sub-{subject}",
                        "session": session,
                        "artifact": f"SD_STREAM connectome {measure}",
                        "reason": f"unsupported matrix shape {rows}x{cols}",
                    }
                )
                continue
            sd_destination_dir.mkdir(parents=True, exist_ok=True)
            destination = sd_destination_dir / (
                f"sub-{subject}_{session}_atlas-DKT78_model-SDSTREAM_"
                f"measure-{measure}_connectome.csv"
            )
            shutil.copy2(source, destination)
            exported.append(
                {
                    "subject": f"sub-{subject}",
                    "session": session,
                    "group": args.group,
                    "tractography": "deterministic SD_STREAM",
                    "atlas": "DKT-78",
                    "measure": measure_label,
                    "matrix_shape": "78x78",
                    "empty_nodes": measure_empty_nodes,
                    "source": str(source),
                    "exported_file": str(destination.relative_to(output)),
                    "sha256": sha256(destination),
                }
            )

        lausanne_count = connectome_dir / "lausanne60_connectome_count.csv"
        if lausanne_count.is_file():
            lausanne_root = output / "probabilistic_tractography" / "Lausanne-60"
            lausanne_root.mkdir(parents=True, exist_ok=True)
            lausanne_dir = lausanne_root / f"sub-{subject}" / session / "dwi"
            lausanne_dir.mkdir(parents=True, exist_ok=True)
            lausanne_sources = {
                "count": (lausanne_count, "streamline count"),
                "sift2": (connectome_dir / "lausanne60_connectome_sift2.csv", "SIFT2 weight"),
                "meanlength": (
                    connectome_dir / "lausanne60_connectome_meanlength.csv",
                    "mean streamline length (mm)",
                ),
                "meanfa": (
                    connectome_dir / "lausanne60_connectome_meanfa.csv",
                    "mean tract-sampled FA",
                ),
                "meanmd": (
                    connectome_dir / "lausanne60_connectome_meanmd.csv",
                    "mean tract-sampled MD",
                ),
            }
            for measure, (source, measure_label) in lausanne_sources.items():
                if not source.is_file():
                    continue
                rows, cols, measure_empty_nodes = matrix_shape_and_empty_nodes(source)
                if (rows, cols) != (129, 129):
                    skipped_artifacts.append(
                        {
                            "subject": f"sub-{subject}",
                            "session": session,
                            "artifact": f"Lausanne-60 connectome {measure}",
                            "reason": f"unsupported matrix shape {rows}x{cols}",
                        }
                    )
                    continue
                destination = lausanne_dir / (
                    f"sub-{subject}_{session}_atlas-Lausanne60_model-iFOD2_"
                    f"measure-{measure}_connectome.csv"
                )
                shutil.copy2(source, destination)
                exported.append(
                    {
                        "subject": f"sub-{subject}",
                        "session": session,
                        "group": args.group,
                        "tractography": "probabilistic iFOD2",
                        "atlas": "Lausanne-60",
                        "measure": measure_label,
                        "matrix_shape": "129x129",
                        "empty_nodes": measure_empty_nodes,
                        "source": str(source),
                        "exported_file": str(destination.relative_to(output)),
                        "sha256": sha256(destination),
                    }
                )

        node_root = results_root / "node_strength"
        node_destination_dir = output / "node_metrics" / f"sub-{subject}" / session
        for metric, (relative_source, expected_rows) in NODE_METRICS.items():
            metric_source = node_root / relative_source.format(subject=subject)
            if not metric_source.is_file():
                skipped_artifacts.append(
                    {
                        "subject": f"sub-{subject}",
                        "session": session,
                        "artifact": metric,
                        "reason": "source missing",
                    }
                )
                continue
            rows = csv_row_count(metric_source)
            if rows != expected_rows:
                skipped_artifacts.append(
                    {
                        "subject": f"sub-{subject}",
                        "session": session,
                        "artifact": metric,
                        "reason": f"expected {expected_rows} rows, found {rows}",
                    }
                )
                continue
            node_destination_dir.mkdir(parents=True, exist_ok=True)
            metric_destination = node_destination_dir / (
                f"sub-{subject}_{session}_atlas-DKT78_"
                f"measure-{metric}_nodes.csv"
            )
            shutil.copy2(metric_source, metric_destination)
            artifacts.append(
                {
                    "subject": f"sub-{subject}",
                    "session": session,
                    "artifact": f"node {metric}",
                    "rows": rows,
                    "source": str(metric_source),
                    "exported_file": str(metric_destination.relative_to(output)),
                    "sha256": sha256(metric_destination),
                }
            )

        qc_sources = sorted(
            (
                results_root
                / "qsiprep_single_run_output"
                / f"sub-{subject}"
                / session
                / "dwi"
            ).glob("*_desc-ImageQC_dwi.csv")
        )
        if len(qc_sources) != 1:
            skipped_artifacts.append(
                {
                    "subject": f"sub-{subject}",
                    "session": session,
                    "artifact": "DWI ImageQC",
                    "reason": f"expected one source, found {len(qc_sources)}",
                }
            )
        else:
            qc_source = qc_sources[0]
            qc_destination_dir = output / "qc" / f"sub-{subject}" / session / "dwi"
            qc_destination_dir.mkdir(parents=True, exist_ok=True)
            qc_destination = qc_destination_dir / (
                f"sub-{subject}_{session}_desc-ImageQC_dwi.csv"
            )
            shutil.copy2(qc_source, qc_destination)
            artifacts.append(
                {
                    "subject": f"sub-{subject}",
                    "session": session,
                    "artifact": "DWI ImageQC",
                    "rows": csv_row_count(qc_source),
                    "source": str(qc_source),
                    "exported_file": str(qc_destination.relative_to(output)),
                    "sha256": sha256(qc_destination),
                }
            )

        tensor_destination_dir = (
            output / "tensor_maps_native" / f"sub-{subject}" / session / "dwi"
        )
        for metric in ("FA", "MD"):
            tensor_source = connectome_dir / f"dkt_desc-{metric}_dwi.nii.gz"
            if not tensor_source.is_file():
                skipped_artifacts.append(
                    {
                        "subject": f"sub-{subject}",
                        "session": session,
                        "artifact": f"{metric} tensor map",
                        "reason": "source missing",
                    }
                )
                continue
            tensor_destination_dir.mkdir(parents=True, exist_ok=True)
            tensor_destination = tensor_destination_dir / (
                f"sub-{subject}_{session}_space-T1w_desc-{metric}_dwi.nii.gz"
            )
            shutil.copy2(tensor_source, tensor_destination)
            artifacts.append(
                {
                    "subject": f"sub-{subject}",
                    "session": session,
                    "artifact": f"{metric} tensor map",
                    "rows": "",
                    "source": str(tensor_source),
                    "exported_file": str(tensor_destination.relative_to(output)),
                    "sha256": sha256(tensor_destination),
                }
            )

    manifest_fields = [
        "subject",
        "session",
        "group",
        "tractography",
        "atlas",
        "measure",
        "matrix_shape",
        "empty_nodes",
        "source",
        "exported_file",
        "sha256",
    ]
    with (output / "manifest.tsv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=manifest_fields, delimiter="\t")
        writer.writeheader()
        writer.writerows(exported)

    with (output / "skipped.tsv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=["subject", "reason"], delimiter="\t")
        writer.writeheader()
        writer.writerows(skipped)

    artifact_fields = [
        "subject",
        "session",
        "artifact",
        "rows",
        "source",
        "exported_file",
        "sha256",
    ]
    with (output / "artifacts_manifest.tsv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=artifact_fields, delimiter="\t")
        writer.writeheader()
        writer.writerows(artifacts)

    with (output / "skipped_artifacts.tsv").open("w", newline="") as stream:
        writer = csv.DictWriter(
            stream,
            fieldnames=["subject", "session", "artifact", "reason"],
            delimiter="\t",
        )
        writer.writeheader()
        writer.writerows(skipped_artifacts)

    lut = (
        pipeline_root
        / "containers"
        / "connectome"
        / "mrtrix_lut"
        / "fs_dkt.txt"
    )
    write_node_lookup(lut, output / "atlas-DKT78_nodes.tsv")

    description = {
        "Name": "URMC structural networks",
        "DatasetType": "derivative",
        "Description": f"Completed {args.group} DKT connectomes and analysis tables.",
        "Tractography": [
            "QSIRecon MRtrix3 iFOD2 probabilistic tractography",
            "Optional MRtrix3 SD_STREAM deterministic tractography",
        ],
        "Atlas": "Desikan-Killiany-Tourville, 78 nodes",
        "Measure": "streamline count",
        "ConnectomeMeasures": ["count", "sift2", "meanlength", "meanfa", "meanmd"],
        "TensorMaps": ["FA", "MD"],
        "NodeMetrics": ["strength", "strengthAI", "volume", "volumeAI"],
        "QualityControl": "QSIPrep DWI ImageQC",
        "ExportedSubjects": len({row["subject"] for row in exported}),
        "ExportedMatrices": len(exported),
        "SkippedSubjects": len(skipped),
    }
    (output / "dataset_description.json").write_text(
        json.dumps(description, indent=2) + "\n"
    )

    readme = f"""# URMC structural networks

This directory contains DKT connectomes and related analysis tables for
URMC **{args.group}**. It contains {len({row["subject"] for row in exported})} completed subjects.

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
│           ├── *_measure-count_connectome.csv
│           ├── *_measure-sift2_connectome.csv
│           ├── *_measure-meanlength_connectome.csv
│           ├── *_measure-meanfa_connectome.csv
│           └── *_measure-meanmd_connectome.csv
├── deterministic_tractography/
│   └── DKT-78/
│       └── sub-<ID>/ses-<ID>/dwi/
│           └── *_model-SDSTREAM_measure-<measure>_connectome.csv
├── node_metrics/
│   └── sub-<ID>/ses-<ID>/
│       ├── *_measure-strength_nodes.csv
│       ├── *_measure-strengthAI_nodes.csv
│       ├── *_measure-volume_nodes.csv
│       └── *_measure-volumeAI_nodes.csv
├── tensor_maps_native/
│   └── sub-<ID>/ses-<ID>/dwi/
│       ├── *_desc-FA_dwi.nii.gz
│       └── *_desc-MD_dwi.nii.gz
└── qc/
    └── sub-<ID>/ses-<ID>/dwi/
        └── *_desc-ImageQC_dwi.csv
```

The export contains available DKT 78-node Count, SIFT2, MeanLength, MeanFA,
and MeanMD connectomes; native T1w-space FA/MD maps; Step 5 node strength and
volume summaries; and QSIPrep DWI image-quality measurements. CountScaled,
deterministic tractography, and Lausanne atlases are exported when present.

Use `atlas-DKT78_nodes.tsv` for matrix row/column order. `manifest.tsv` records
the connectome source, matrix validation, empty-node count, and SHA-256 digest.
`artifacts_manifest.tsv` provides equivalent provenance for node metrics and
QC. See `node_metrics/README.md` for formulas and interpretation.
"""
    (output / "README.md").write_text(readme)
    (output / "node_metrics").mkdir(parents=True, exist_ok=True)
    (output / "node_metrics" / "README.md").write_text(NODE_METRICS_README)
    (output / "qc").mkdir(parents=True, exist_ok=True)
    (output / "qc" / "README.md").write_text(QC_README)

    exported_subjects = len({row["subject"] for row in exported})
    print(
        f"Exported {exported_subjects} subjects "
        f"({len(exported)} connectome matrices) to {output}"
    )
    print(f"Skipped {len(skipped)} subjects; see {output / 'skipped.tsv'}")
    print(
        f"Exported {len(artifacts)} metric/QC artifacts; "
        f"skipped {len(skipped_artifacts)}"
    )


if __name__ == "__main__":
    main()
