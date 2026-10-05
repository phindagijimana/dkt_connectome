# Reproducible SyN, label file, and empty-node behavior

These four changes sit on top of the v0.3.0 pipeline. They do not rebuild the
connectome image. A run that uses the pinned v0.3.0 digest
(`ghcr.io/phindagijimana/dk-connectome:0.3.0`) still executes the scripts baked
into that image. What changed is how the workflow chooses the label file, how
it asks QSIPrep for SyN, when a connectome is allowed to finish with empty
nodes, and how a b=3000 shell is selected.

Each choice is written into the run itself: the QSIPrep log line, or
`parcellation.json` next to the matrices.

## Label file

The default label file is the one inside the image, `{CONNECTOME_LUT_BAKED}`
(`/opt/dkt/lut/fs_dkt.txt` in v0.3.0). Before tractography-to-connectome, the
rule checks that path inside the image.

- If the file is there, the run passes `--mrtrix-lut` to that path and mounts
  nothing. `parcellation.json` records `lut_source: "baked"` and `lut_sha256`
  of the file in the image.
- If the file is missing, the rule mounts only
  `dwi_pipeline/containers/connectome/mrtrix_lut/fs_dkt.txt` at
  `/lut/fs_dkt.txt`. It does not mount `run_connectome.sh`. Replacing the
  entrypoint would make the run a different script from the one in the image.
  `parcellation.json` records `lut_source: "host"` and the SHA-256 of the host
  file.
- If neither file exists, the step fails and names both paths.

`CONNECTOME_BIND_DEV=1` is unchanged and is still the dev override: it mounts
the host label file and the host `run_connectome.sh`. That mode is not the
reproducible default. The log line says when it was used.

## SyN when a fieldmap is present

`--use-syn-sdc` alone does not build the SyN workflow, and `--force-syn` alone
does not either. A run that asks for SyN (`--syn`, `--use-syn-sdc`,
`--force-syn`, or `qsiprep.use_syn_sdc` / `qsiprep.force_syn`) passes both
flags.

That request wins over a fieldmap. Previously, a fieldmap inside the BIDS
filter selected measured distortion correction even when the run had asked for
SyN. Measured correction remains the default when the filter contains a
fieldmap and the run did not ask for SyN.

`--fmap-retry` still ignores fieldmaps and now also passes both SyN flags.

The QSIPrep log records the decision in one line:

    sdc=syn force_syn=true fmap_in_filter=1

`fmap_in_filter` is `0` or `1`. `sdc` is `syn`, `measured`, or `none`.

`qsiprep.force_syn` defaults to false in `config.yaml`. `--syn` sets it true
for that submission so the config override used by Snakemake matches the flags
that were passed.

## Empty nodes

`connectome.max_empty_nodes` defaults to 10. After `tck2connectome`, more empty
nodes than that fails the connectome step. A few empty nodes can be a
resection or a large lesion. A larger count means labels are missing from the
parcellation image, which points at the reconstruction or the DWI-to-T1w
registration rather than at tractography.

`connectome.fail_on_empty_nodes` still means "fail if any node is empty". It
stays off by default.

`parcellation.json` records both `empty_nodes` and `max_empty_nodes`, so the
cutoff that was applied is part of the output. Override the cutoff with
`connectome.max_empty_nodes` in config or `CONNECTOME_MAX_EMPTY_NODES` in the
environment. Runs that previously exited successfully with more empty nodes
than the limit now fail. That is the check.

## b=3000 selectors

`config/dwi_select_b3000.json` keeps `dwi_acquisition: "b3000"`, so it only
matches a series labeled `acq-b3000`.

`config/dwi_select_b3000_ses-2WK.json` and
`config/dwi_select_b3000_ses-6MO.json` use the same fields as the b=1300
session selectors, with `target_shell_b` 3000 and `dwi_acquisition` null. The
shell value selects the series. They do nothing until a run passes
`--dwi-select` with one of those files.

The QSIPrep log prints the selector path and its SHA-256. A later edit of the
JSON is not the file that a finished job used. If more than one DWI series
matches, selection still errors: the selector does not pick among ties.

## What this release does not change

- The connectome image digest stays at v0.3.0. No container rebuild.
- Runs that do not pass `--syn` and do not hit the empty-node limit keep the
  previous distortion-correction and connectome outcomes.
- `CONNECTOME_BIND_DEV=1` remains a dev override, not the way to supply a
  missing label file.
