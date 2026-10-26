# Command-line reference

```text
dlsurfer <command> [options]
```

## Commands

| Command | Purpose |
|---------|---------|
| `doctor` | Dependency / READY check |
| `smoke` | Doctor + dry-run `core-lesion` |
| `gates` | List production gates |
| `run` | Build/execute a profile plan |
| `engines` | Engine registry (`--alternatives`) |
| `atlases` | Atlas notes |
| `compare` | FS vs FastSurfer matrix |
| `gaps-remaining` | Gaps without DL alts |
| `cite` | Citation boilerplate for a profile |
| `handoff` | Print-only consumer notes |
| `bids-app` | BIDS App–style stub (`bids_dir output_dir level`) — [status](bids_app.md) |

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
| `--vox-size` | FastSurfer voxel size |
| `--hpc` | `srun` / `brun` |
| `--execute` | Actually run |
| `--allow-experimental` | Override open gates |

```bash
dlsurfer run --help
```
