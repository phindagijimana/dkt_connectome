"""CLI / config guards for --fastsurfer-lesion-mask and --post-hoc-fs."""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest
import yaml

REPO = Path(__file__).resolve().parents[2]
DWI = REPO / "dwi_pipeline"
RUN_SUBJECT = DWI / "workflow" / "run_subject.sh"


def test_config_yaml_has_new_recon_keys():
    cfg = yaml.safe_load((DWI / "workflow" / "config" / "config.yaml").read_text())
    assert cfg["recon"]["lesion_mask"] is False
    assert cfg["recon"]["post_hoc_fs"] is False


def test_run_subject_help_lists_flags():
    # run_subject has no --help; parse via bash -n + grep in submit/run
    run_txt = (DWI / "run").read_text()
    assert "--fastsurfer-lesion-mask" in run_txt
    assert "--post-hoc-fs" in run_txt
    assert "posthoc-fs" in run_txt
    submit_txt = (DWI / "submit.sh").read_text()
    assert "--fastsurfer-lesion-mask" in submit_txt
    assert "POST_HOC_FS" in submit_txt
    assert "posthoc-fs" in submit_txt
    assert "_validate_lesion_recon_flags" in submit_txt
    rs = (DWI / "workflow" / "run_subject.sh").read_text()
    assert 'posthoc-fs)   TARGET="target_posthoc_fs"' in rs
    assert "target_posthoc_fs" in (DWI / "workflow" / "Snakefile").read_text()
    usage = (DWI / "docs" / "usage.md").read_text()
    assert "Lesion / recon paths (start here)" in usage
    assert "Don't mix" in usage


@pytest.mark.parametrize(
    "extra",
    [
        ["--fastsurfer-lesion-mask", "--post-hoc-fs"],
        ["--fastsurfer-lesion-mask", "--inpaint"],
        ["--fastsurfer-lesion-mask", "--anat-mitigation", "vbt"],
    ],
)
def test_run_subject_rejects_native_xor_standalone(extra):
    """Contradictory lesion/recon flags must fail fast (no silent last-wins)."""
    proc = subprocess.run(
        ["bash", str(RUN_SUBJECT), "recon", "011", *extra],
        cwd=str(DWI),
        capture_output=True,
        text=True,
        env={
            **dict(**{k: v for k, v in __import__("os").environ.items()}),
            "BIDS_DIR": "/tmp/bids-missing",
            "RESULTS_ROOT": "/tmp/out-missing",
        },
    )
    combined = (proc.stdout or "") + (proc.stderr or "")
    assert proc.returncode != 0
    assert "mutually exclusive" in combined.lower() or "both" in combined.lower()


def test_common_smk_rejects_lesion_mask_with_vbt(tmp_path):
    """Import-time WorkflowError when recon.lesion_mask + inpaint.backend=vbt."""
    snakefile = DWI / "workflow" / "Snakefile"
    cfg = {
        "results_root": str(tmp_path / "out"),
        "bids_dir": str(tmp_path / "bids"),
        "fs_license": str(tmp_path / "license.txt"),
        "containers": {
            "qsiprep": str(tmp_path / "q.sif"),
            "qsirecon": str(tmp_path / "r.sif"),
            "fastsurfer": str(tmp_path / "f.sif"),
            "freesurfer": str(tmp_path / "fs.sif"),
            "connectome": str(tmp_path / "c.sif"),
            "lit": str(tmp_path / "l.sif"),
            "nodestrength": str(tmp_path / "n.sif"),
        },
        "inpaint": {"enabled": True, "backend": "vbt"},
        "recon": {"tool": "fastsurfer", "lesion_mask": True, "post_hoc_fs": False},
    }
    (tmp_path / "license.txt").write_text("x\n")
    cfg_path = tmp_path / "cfg.yaml"
    cfg_path.write_text(yaml.dump(cfg))
    # Touch dummy sifs so missing-file is not the first failure path for containers
    for p in cfg["containers"].values():
        Path(p).write_bytes(b"")
    (tmp_path / "bids").mkdir()
    proc = subprocess.run(
        [
            "snakemake",
            "-s",
            str(snakefile),
            "--configfile",
            str(cfg_path),
            "--config",
            "subject=011",
            "-n",
            "--quiet",
        ],
        cwd=str(DWI),
        capture_output=True,
        text=True,
    )
    combined = (proc.stdout or "") + (proc.stderr or "")
    assert proc.returncode != 0
    assert "lesion_mask" in combined.lower() or "mutually exclusive" in combined.lower()
