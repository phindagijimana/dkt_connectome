# Command-line reference

```text
dlsurfer <command> [options]
```

**Identity:** deep-learning **FreeSurfer-suite** methods (T1 morphometry + multimodal
specialty: TractSeg, PET-DL, DeepPrep, BrainQCNet). Classical D modules hidden
unless `--all` / `--allow-classical`.
Policy: `dlsurfer credibility` · [CREDIBILITY.md](reference/CREDIBILITY.md).

## Commands

| Command | Purpose |
|---------|---------|
| `recon-all` | **DL** morphometry orchestrator (FastSurferVINN `core`) — not classical `recon-all` |
| `tool` | Run one DL / specialty module by FS-style name (`hippunfold`, `synthseg`, …) |
| `tools` | List FS-style aliases with credibility tier A/B/C (`--tier A`) |
| `credibility` | Print A/B/C/D policy (specialty allowed; not TBI-only) |
| `doctor` | Dependency / READY check (`--brief` / `-q`) |
| `smoke` | Doctor + dry-run `core-lesion` (`-q` compact) |
| `run` | Build/execute a profile plan (`-q` compact; `--allow-classical` for non-DL) |
| `freeview` | Open `$SD/$SID` in FreeView (`--check` headless; needs `DISPLAY` to launch) |
| `profiles` | List **DL** profiles (`--all` includes classical) |
| `gates` | List production gates |
| `engines` | Engine registry (`--alternatives`; `--all` includes classical) |
| `atlases` | Atlas notes |
| `cite` | Citation boilerplate for a profile |
| `compare` | FS vs FastSurfer summary (`--full` matrix) |
| `gaps-remaining` | Gaps without DL alts (`--full` markdown) |
| `handoff` | Print-only consumer notes |
| `bids-app` | BIDS App–style stub (`bids_dir output_dir level`) — [status](bids_app.md) |

## FreeSurfer-shaped contracts (DL only)

```bash
# Full tree (recon-all analogue → profile core)
dlsurfer recon-all -i T1.nii.gz -sd "$SD" -s "$SID"           # dry-run
dlsurfer recon-all -i T1.nii.gz -sd "$SD" -s "$SID" --execute
dlsurfer recon-all -i T1.nii.gz -sd "$SD" -s "$SID" --lesion-mask lesion.nii.gz --execute

# One module at a time (like FS utilities)
dlsurfer tools
dlsurfer tool hippunfold --t1 T1.nii.gz --sd "$SD" --sid "$SID" -q
dlsurfer tool synthseg   --t1 T1.nii.gz --sd "$SD" --sid "$SID" --execute
dlsurfer tool sclimbic   --t1 T1.mgz    --sd "$SD" --sid "$SID" --execute

# FS / FastSurfer DL (sources + flags: reference/FS_DL_METHODS.md)
dlsurfer tool synthseg-robust --t1 T1.nii.gz --sd "$SD" --sid "$SID" -q
SUPERSYNTH_MODE=invivo dlsurfer tool super-synth --t1 T1.nii.gz --sd "$SD" --sid "$SID" -q
EASYATLAS_INPUT_DIR=/scans dlsurfer tool easyatlas --t1 T1.nii.gz --sd "$SD" --sid "$SID" -q
HISTO_ATLAS_SIDE=left dlsurfer tool histo-atlas --t1 T1.nii.gz --sd "$SD" --sid "$SID" -q
dlsurfer tool hypvinn-t2 --t1 T1.nii.gz --t2 T2.nii.gz --sd "$SD" --sid "$SID" -q
dlsurfer recon-all -i T1.nii.gz -sd "$SD" -s "$SID" --t2 T2.nii.gz -q
dlsurfer tool fs8-dl --t1 T1.nii.gz --sd "$SD" --sid "$SID" -q
```

Also on `PATH` after `source env/cluster_containers.sh`: `dlsurfer-recon-all` and
`dlsurfer-*` specialty wrappers. Outputs remain FreeSurfer-shaped under `$SD/$SID`.

Literature + env for the FS wiki DL set: [FS_DL_METHODS.md](reference/FS_DL_METHODS.md).

## `freeview`

Thin launcher for FreeSurfer’s GUI (not a reimplementation). After `source env/cluster_containers.sh`:

```bash
dlsurfer freeview --sd "$SD" --sid "$SID"
dlsurfer freeview --sd "$SD" --sid "$SID" --aseg --pial
dlsurfer freeview --sd "$SD" --sid "$SID" --dry-run
dlsurfer freeview --sd "$SD" --sid "$SID" --check   # headless readiness
```

```bash
dlsurfer doctor --brief
dlsurfer compare            # short summary
dlsurfer gaps-remaining     # bullets
dlsurfer compare --full     # full markdown
```

## `run` — important flags

| Flag | Meaning |
|------|---------|
| `--profile` | Profile id (required) |
| `--t1` | T1 NIfTI (required) |
| `--sd` / `--sid` | SUBJECTS_DIR / subject |
| `--fs-license` | FreeSurfer license |
| `--lesion-mask` | For lesion profiles |
| `--device` | `auto` / `cpu` / `cuda` |
| `--threads` | Thread count |
| `--batch-size` | FastSurfer `--batch` |
| `--viewagg-device` | FastSurfer view aggregation device |
| `--atlas` | Labeling scheme (default DKT) |
| `--no-cc` / `--no-cereb` / `--no-hypothal` | Module offs |
| `--t2` | Co-registered T2w for HypVINN (also `HYPVINN_T2`) |
| `--stage` | HPC slice for DL LIT: `gpu` = fill+seg · `cpu` = surf+post · [LIT_SPLIT](reference/LIT_SPLIT.md) |
| `--vox-size` | FastSurfer voxel size |
| `--hpc` | `srun` / `brun` |
| `--execute` | Actually run |
| `--allow-experimental` | Override open gates |
| `-q` / `--quiet` | Compact plan (commands only) |

```bash
dlsurfer run --help
dlsurfer smoke --quiet
```
