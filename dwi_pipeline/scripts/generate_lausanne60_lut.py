#!/usr/bin/env python3
"""Generate FreeSurfer and MRtrix LUT files for Lausanne-60 from graphml."""

from __future__ import annotations

import argparse
import xml.etree.ElementTree as ET
from pathlib import Path


def parse_graphml(graphml_path: Path) -> list[dict[str, str]]:
    root = ET.parse(graphml_path).getroot()
    key_ids: dict[str, str] = {}
    for key in root.iter():
        if key.tag.endswith("key"):
            key_ids[key.attrib.get("id", "")] = key.attrib.get("attr.name", "")

    nodes: list[dict[str, str]] = []
    for node in root.iter():
        if not node.tag.endswith("node"):
            continue
        data: dict[str, str] = {}
        for elem in node:
            if not elem.tag.endswith("data"):
                continue
            attr = key_ids.get(elem.attrib.get("key", ""), elem.attrib.get("key", ""))
            data[attr] = elem.text or ""
        nodes.append(
            {
                "id": node.get("id", ""),
                "region": data.get("dn_region", ""),
                "fsname": data.get("dn_fsname", ""),
                "hemisphere": data.get("dn_hemisphere", ""),
                "correspondence_id": data.get("dn_correspondence_id", ""),
                "name": data.get("dn_name", ""),
                "aseg_val": data.get("dn_fs_aseg_val", ""),
            }
        )
    return nodes


def write_luts(nodes: list[dict[str, str]], out_dir: Path) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    fs_lut = out_dir / "lausanne60_fs_lut.txt"
    mrtrix_lut = out_dir / "lausanne60_mrtrix_lut.txt"
    nodes_tsv = out_dir.parent / "atlas-Lausanne60_nodes.tsv"

    ordered = sorted(
        nodes,
        key=lambda n: int(n["correspondence_id"]) if n["correspondence_id"].isdigit() else 10**9,
    )
    corr_ids = [int(n["correspondence_id"]) for n in ordered if n["correspondence_id"].isdigit()]
    if not corr_ids:
        raise ValueError("no correspondence IDs found in graphml")

    fs_lines = ["# Lausanne-60 (resolution150) — generated from resolution150.graphml"]
    mrtrix_lines = ["# Lausanne-60 MRtrix labelconvert LUT"]
    tsv_lines = ["index\tlabel_id\tname\themisphere\tregion\tfsname"]

    for index, node in enumerate(ordered, start=1):
        label_id = int(node["correspondence_id"])
        name = node["name"] or node["fsname"]
        r = (index * 37) % 256
        g = (index * 91) % 256
        b = (index * 53) % 256
        fs_lines.append(f"{label_id}  {name}  {r}  {g}  {b}  0")
        mrtrix_lines.append(f"{label_id}  {name.replace('_', '-')}  {index}")
        tsv_lines.append(
            f"{index}\t{label_id}\t{name}\t{node['hemisphere']}\t{node['region']}\t{node['fsname']}"
        )

    fs_lut.write_text("\n".join(fs_lines) + "\n")
    mrtrix_lut.write_text("\n".join(mrtrix_lines) + "\n")
    nodes_tsv.write_text("\n".join(tsv_lines) + "\n")
    return len(ordered)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--graphml",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "atlas" / "lausanne60" / "resolution150.graphml",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "atlas" / "lausanne60" / "mrtrix_lut",
    )
    args = parser.parse_args()
    count = write_luts(parse_graphml(args.graphml), args.out_dir)
    print(f"Wrote {count} nodes to {args.out_dir}")


if __name__ == "__main__":
    main()
