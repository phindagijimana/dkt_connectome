#!/usr/bin/env python3
"""Run ANTsPyNet Deep Atropos six-tissue segmentation on native T1w."""

from __future__ import annotations

import argparse
import inspect
import json
import os
import sys
from pathlib import Path


def _patch_figshare_downloads() -> None:
    """Use ndownloader.figshare.com; figshare.com URLs fail WAF on compute nodes."""
    import tensorflow as tf

    original_get_file = tf.keras.utils.get_file

    def get_file_with_ndownloader(fname, origin, *args, **kwargs):
        if isinstance(origin, str):
            origin = origin.replace(
                "https://figshare.com/ndownloader/",
                "https://ndownloader.figshare.com/",
            )
        return original_get_file(fname, origin, *args, **kwargs)

    tf.keras.utils.get_file = get_file_with_ndownloader


def _prefetch_deep_atropos_assets(*, cache_dir: Path, verbose: bool = True) -> None:
    import antspynet

    required_networks = (
        "brainExtractionRobustT1",
        "sixTissueOctantBrainSegmentationWithPriors1",
    )
    required_data = (
        "croppedMni152",
        "croppedMni152Priors",
    )
    for network_id in required_networks:
        if verbose:
            print(f"[deep-atropos-seg] prefetch network: {network_id}", flush=True)
        antspynet.get_pretrained_network(network_id)
    for data_id in required_data:
        if verbose:
            print(f"[deep-atropos-seg] prefetch data: {data_id}", flush=True)
        antspynet.get_antsxnet_data(data_id)


def run_deep_atropos_seg(
    *,
    t1w: Path,
    output_seg: Path,
    output_json: Path | None = None,
    do_preprocessing: bool = True,
    use_spatial_priors: int = 1,
    cache_dir: Path | None = None,
    verbose: bool = True,
) -> dict:
    try:
        import ants  # type: ignore
        import antspynet  # type: ignore
        import numpy as np  # type: ignore
    except ImportError as exc:
        raise SystemExit(
            "ERROR: ants and antspynet are required (install in dkt_deep_atropos_seg.sif)"
        ) from exc

    t1w = t1w.resolve()
    if not t1w.is_file():
        raise FileNotFoundError(t1w)

    cache = str(cache_dir.resolve()) if cache_dir else None
    if cache:
        os.environ["ANTSXNET_CACHE"] = cache
        os.environ["KERAS_HOME"] = cache
        antspynet.set_antsxnet_cache_directory(cache)

    _patch_figshare_downloads()
    _prefetch_deep_atropos_assets(cache_dir=cache_dir or Path("/opt/antsxnet_cache"), verbose=verbose)

    image = ants.image_read(str(t1w))
    kwargs: dict = {
        "do_preprocessing": do_preprocessing,
        "use_spatial_priors": use_spatial_priors,
        "verbose": verbose,
    }
    sig = inspect.signature(antspynet.deep_atropos)
    if cache and "antsxnet_cache_directory" in sig.parameters:
        kwargs["antsxnet_cache_directory"] = cache
    result = antspynet.deep_atropos(image, **kwargs)

    seg_img = result["segmentation_image"]
    output_seg.parent.mkdir(parents=True, exist_ok=True)
    ants.image_write(seg_img, str(output_seg))

    seg_np = np.asarray(seg_img.numpy(), dtype=np.int16)
    labels = sorted(int(v) for v in np.unique(seg_np))
    expected = set(range(7))
    if not set(labels).issubset(expected):
        raise ValueError(f"unexpected Deep Atropos labels in output: {labels}")

    payload = {
        "t1w": str(t1w),
        "deep_atropos_segmentation": str(output_seg.resolve()),
        "segmentation_source": "generated",
        "generator": "antspynet.deep_atropos",
        "do_preprocessing": do_preprocessing,
        "use_spatial_priors": use_spatial_priors,
        "antsxnet_cache_directory": cache,
        "labels_present": labels,
        "shape": list(seg_np.shape),
    }
    if output_json is not None:
        output_json.write_text(json.dumps(payload, indent=2) + "\n")
    return payload


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--t1w", type=Path, required=True, help="Native BIDS T1w NIfTI")
    parser.add_argument("--output", type=Path, required=True, help="Output integer seg NIfTI")
    parser.add_argument("--json", type=Path, default=None, help="Optional provenance JSON")
    parser.add_argument(
        "--no-preprocessing",
        action="store_true",
        help="Skip internal ANTsPyNet preprocessing (T1w already brain-extracted/normalized)",
    )
    parser.add_argument(
        "--use-spatial-priors",
        type=int,
        default=1,
        choices=(0, 1),
        help="ANTsPyNet spatial priors flag (default 1)",
    )
    parser.add_argument(
        "--cache-dir",
        type=Path,
        default=Path("/opt/antsxnet_cache"),
        help="Directory for ANTsXNet model weights",
    )
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    run_deep_atropos_seg(
        t1w=args.t1w,
        output_seg=args.output,
        output_json=args.json,
        do_preprocessing=not args.no_preprocessing,
        use_spatial_priors=args.use_spatial_priors,
        cache_dir=args.cache_dir,
        verbose=not args.quiet,
    )


if __name__ == "__main__":
    main()
