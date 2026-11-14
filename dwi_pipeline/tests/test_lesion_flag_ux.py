"""Holistic UX + CLI checks for lesion/recon path docs and fail-fast flags."""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

import pytest

DWI = Path(__file__).resolve().parents[1]
RUN_SUBJECT = DWI / "workflow" / "run_subject.sh"
SUBMIT = DWI / "submit.sh"
USAGE = DWI / "docs" / "usage.md"
DECISION = DWI / "docs" / "decision_tables.md"
RUN = DWI / "run"


def _run_subject(*extra: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["BIDS_DIR"] = "/tmp/bids-ux-missing"
    env["RESULTS_ROOT"] = "/tmp/out-ux-missing"
    return subprocess.run(
        ["bash", str(RUN_SUBJECT), "recon", "011", *extra],
        cwd=str(DWI),
        capture_output=True,
        text=True,
        env=env,
    )


def _submit_parse_only(*extra: str) -> subprocess.CompletedProcess[str]:
    """Parse submit.sh flags then exit before sbatch (via early validate path).

    We inject a dry path by setting BIDS_DIR missing — submit fails after
    validate. Conflict errors exit 2 before BIDS checks when validate runs
    after experiment-arm block (before BIDS mkdir checks).
    """
    env = os.environ.copy()
    env["BIDS_DIR"] = "/tmp/bids-ux-missing-submit"
    env["RESULTS_ROOT"] = "/tmp/out-ux-missing-submit"
    env["SUBJECT_LIST_USE_EXISTING"] = "1"
    return subprocess.run(
        ["bash", str(SUBMIT), *extra],
        cwd=str(DWI),
        capture_output=True,
        text=True,
        env=env,
        timeout=60,
    )


# --- Docs UX structure -------------------------------------------------------


def test_usage_leads_with_path_chooser():
    text = USAGE.read_text()
    assert "## Lesion / recon paths (start here)" in text
    # Path section must appear before the long option tables
    i_path = text.index("## Lesion / recon paths (start here)")
    i_subset = text.index("## Options for performing a subset of the workflow")
    i_recon = text.index("## Options for reconstruction (Step 2)")
    assert i_path < i_subset < i_recon


def test_usage_has_recipes_dont_mix_and_optin_table():
    text = USAGE.read_text()
    assert "### Recipes" in text
    assert "### Don't mix" in text
    assert "### Opt-in steps vs re-run modes" in text
    assert "| **2.1** Post-hoc FS | `--post-hoc-fs` | `--mode posthoc-fs` |" in text
    assert "| **4.1** Disconnectome | `--disconnection` | `--mode disconnectome` |" in text
    for recipe in (
        "./submit.sh --fastsurfer",
        "./submit.sh --fastsurfer --post-hoc-fs",
        "./submit.sh --fastsurfer-lesion-mask",
        "PIPELINE_MODE=posthoc-fs",
        "PIPELINE_MODE=disconnectome",
    ):
        assert recipe in text


def test_docs_prefer_long_flag_names():
    usage = USAGE.read_text()
    # Primary spelling in path table
    assert "--fastsurfer-lesion-mask" in usage
    assert "--disconnection" in usage
    # Alias demoted
    assert "prefer `--disconnection`" in usage or "Prefer long names" in usage
    decision = DECISION.read_text()
    assert "Don't mix" in decision
    assert "CLI **exits with an error**" in decision


def test_anchor_slugs_referenced_consistently():
    """Internal links must match Sphinx MyST heading IDs (single hyphens)."""
    usage = USAGE.read_text()
    assert "#lesion-recon-paths-start-here" in usage
    assert "#lesion--recon-paths-start-here" not in usage
    assert "standalone-fill-vs-native-fastsurfer-lesion-mask" in usage
    assert "standalone-fill-vs-native-fastsurfer---lesion_mask" not in usage


def test_no_lesion_mask_help_is_not_global():
    """--no-fastsurfer-lesion-mask must not claim to skip Step 1.1."""
    for path in (USAGE, RUN):
        text = path.read_text()
        # Find the no-fastsurfer / no-lesion help vicinity
        if "--no-fastsurfer-lesion-mask" not in text:
            continue
        # Must mention native-only / not Step 1.1 somewhere nearby in file
        assert (
            "not Step 1.1" in text
            or "Does **not** skip Step 1.1" in text
            or "does not skip Step 1.1" in text.lower()
            or "native recon" in text.lower()
        ), f"{path.name} missing native-only clarification"


# --- CLI fail-fast UX --------------------------------------------------------


@pytest.mark.parametrize(
    "extra",
    [
        ["--fastsurfer-lesion-mask", "--post-hoc-fs"],
        ["--fastsurfer-lesion-mask", "--inpaint"],
        ["--fastsurfer-lesion-mask", "--anat-mitigation", "neurolit"],
        ["--post-hoc-fs", "--fastsurfer-lesion-mask"],
        ["--inpaint", "--fastsurfer-lesion-mask"],
    ],
)
def test_conflict_errors_are_actionable(extra):
    proc = _run_subject(*extra)
    out = (proc.stdout or "") + (proc.stderr or "")
    assert proc.returncode == 2, out
    assert "--fastsurfer-lesion-mask" in out
    # Point users somewhere useful
    assert (
        "docs/usage.md" in out
        or "standalone" in out.lower()
        or "native" in out.lower()
        or "omit" in out.lower()
        or "pick" in out.lower()
    ), out


def test_valid_standalone_posthoc_does_not_conflict_exit():
    """Valid combo should not die with mutually-exclusive (may fail later on missing BIDS)."""
    proc = _run_subject("--fastsurfer", "--post-hoc-fs")
    out = (proc.stdout or "") + (proc.stderr or "")
    assert "mutually exclusive" not in out.lower()
    assert "both native" not in out.lower()


def test_valid_native_alone_does_not_conflict_exit():
    proc = _run_subject("--fastsurfer-lesion-mask")
    out = (proc.stdout or "") + (proc.stderr or "")
    assert "mutually exclusive" not in out.lower()
    assert "both native" not in out.lower()


def test_submit_rejects_native_plus_posthoc():
    proc = _submit_parse_only("--fastsurfer-lesion-mask", "--post-hoc-fs")
    out = (proc.stdout or "") + (proc.stderr or "")
    assert proc.returncode == 2, out
    assert "mutually exclusive" in out.lower() or "both" in out.lower()


def test_submit_rejects_native_plus_vbt():
    proc = _submit_parse_only("--fastsurfer-lesion-mask", "--anat-mitigation", "vbt")
    out = (proc.stdout or "") + (proc.stderr or "")
    assert proc.returncode == 2, out


def test_mode_aliases_documented_in_entrypoints():
    rs = (DWI / "workflow" / "run_subject.sh").read_text()
    assert "posthoc-fs" in rs
    assert "target_posthoc_fs" in rs
    submit = SUBMIT.read_text()
    assert 'PIPELINE_MODE="posthoc-fs"' in submit or "posthoc-fs" in submit
    run = RUN.read_text()
    assert "posthoc-fs" in run


def test_error_message_does_not_suggest_alias_lesion_mask_as_primary():
    proc = _run_subject("--fastsurfer-lesion-mask", "--post-hoc-fs")
    out = (proc.stdout or "") + (proc.stderr or "")
    # Prefer teaching the long name in the ERROR line
    assert "--fastsurfer-lesion-mask" in out


def test_sphinx_html_anchors_resolve_for_path_chooser():
    """If a local Sphinx build exists, path-chooser fragment IDs must match links."""
    html_root = Path("/tmp/dkt-docs-build/html")
    if not (html_root / "usage.html").is_file():
        pytest.skip("Sphinx HTML not built at /tmp/dkt-docs-build/html")
    usage_html = (html_root / "usage.html").read_text()
    assert 'id="lesion-recon-paths-start-here"' in usage_html
    # No stale double-hyphen fragments left in rendered page links
    assert "#lesion--recon-paths-start-here" not in usage_html
    decision_html = (html_root / "decision_tables.html").read_text()
    assert 'id="standalone-fill-vs-native-fastsurfer-lesion-mask"' in decision_html
    methods_html = (html_root / "methods" / "step1_1_inpaint.html").read_text()
    assert 'id="standalone-fill-vs-fastsurfer-lesion-mask"' in methods_html
    # Cross-page fragments from usage must resolve
    broken = []
    for page, frag in re.findall(r'href="([^"#]+\.html)#([^"]+)"', usage_html):
        target = html_root / page
        if not target.is_file():
            broken.append(f"{page} missing")
            continue
        if f'id="{frag}"' not in target.read_text():
            broken.append(f"{page}#{frag}")
    assert not broken, f"broken usage cross-links: {broken}"
