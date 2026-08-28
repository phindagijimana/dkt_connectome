#!/usr/bin/env python3
"""Tests for Deep Atropos segmentation helpers (Figshare URL patch, prefetch CLI)."""

from __future__ import annotations

import sys
from pathlib import Path
from unittest import mock

import pytest

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import run_deep_atropos_seg as seg  # noqa: E402


def test_figshare_url_rewrite():
    captured: dict[str, str] = {}

    def fake_get_file(fname, origin, *args, **kwargs):
        captured["origin"] = origin
        return "/tmp/fake"

    fake_tf = mock.Mock()
    fake_tf.keras.utils.get_file = fake_get_file
    with mock.patch.dict(sys.modules, {"tensorflow": fake_tf}):
        seg._patch_figshare_downloads()
        fake_tf.keras.utils.get_file("w", "https://figshare.com/ndownloader/files/123")
    assert captured["origin"] == "https://ndownloader.figshare.com/files/123"


def test_figshare_url_rewrite_preserves_other_origins():
    captured: dict[str, str] = {}

    def fake_get_file(fname, origin, *args, **kwargs):
        captured["origin"] = origin
        return "/tmp/fake"

    fake_tf = mock.Mock()
    fake_tf.keras.utils.get_file = fake_get_file
    with mock.patch.dict(sys.modules, {"tensorflow": fake_tf}):
        seg._patch_figshare_downloads()
        fake_tf.keras.utils.get_file("w", "https://example.com/model.h5")
    assert captured["origin"] == "https://example.com/model.h5"


def test_prefetch_only_exits_without_segmentation(tmp_path, monkeypatch):
    calls: list[str] = []

    def fake_prefetch(*, cache_dir, verbose=True):
        calls.append(str(cache_dir))

    monkeypatch.setattr(seg, "_patch_figshare_downloads", lambda: None)
    monkeypatch.setattr(seg, "prefetch_deep_atropos_assets", fake_prefetch)
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "run_deep_atropos_seg.py",
            "--prefetch-only",
            "--cache-dir",
            str(tmp_path),
        ],
    )
    with mock.patch.dict(sys.modules, {"antspynet": mock.Mock()}):
        seg.main()
    assert calls == [str(tmp_path.resolve())]
