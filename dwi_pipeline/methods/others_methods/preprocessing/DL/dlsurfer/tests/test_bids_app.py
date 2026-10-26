from pathlib import Path

from dlsurfer.bids_app import _find_t1, _labels, build_parser, run_bids_app


def test_bids_parser_positionals():
    p = build_parser()
    args = p.parse_args(["/bids", "/out", "participant", "--participant_label", "01"])
    assert args.bids_dir == Path("/bids")
    assert args.output_dir == Path("/out")
    assert args.analysis_level == "participant"
    assert args.participant_label == ["01"]


def test_find_t1_and_labels(tmp_path: Path):
    anat = tmp_path / "sub-01" / "anat"
    anat.mkdir(parents=True)
    t1 = anat / "sub-01_T1w.nii.gz"
    t1.write_bytes(b"niigz")
    assert _labels(tmp_path, None) == ["01"]
    assert _find_t1(tmp_path, "01") == t1


def test_bids_app_dry_run_derivatives(tmp_path: Path):
    anat = tmp_path / "sub-99" / "anat"
    anat.mkdir(parents=True)
    (anat / "sub-99_T1w.nii.gz").write_bytes(b"x")
    out = tmp_path / "out"
    rc = run_bids_app(
        [
            str(tmp_path),
            str(out),
            "participant",
            "--participant_label",
            "99",
            "--profile",
            "seg-quick",
            "--device",
            "cpu",
        ]
    )
    assert rc == 0
    assert (out / "derivatives" / "dlsurfer" / "dataset_description.json").is_file()
    assert (out / "derivatives" / "dlsurfer" / "sub-99" / "sub-99_dlsurfer.json").is_file()
    assert (out / "freesurfer").is_dir()


def test_boutiques_descriptor():
    root = Path(__file__).resolve().parents[1]
    assert (root / "boutiques" / "dlsurfer_bids_app.json").is_file()
    rc = run_bids_app(["/bids", "/out", "participant", "--bids-exec-spec"])
    assert rc == 0


def test_methods_doc_generated():
    root = Path(__file__).resolve().parents[1]
    doc = root / "docs" / "methods" / "engines.md"
    assert doc.is_file()
    text = doc.read_text()
    assert "FastSurferVINN" in text
    assert "neuroLIT" in text or "FastSurfer-LIT" in text
    assert "Hoopes" in text
    assert (root / "docs" / "bids_app.md").is_file()
