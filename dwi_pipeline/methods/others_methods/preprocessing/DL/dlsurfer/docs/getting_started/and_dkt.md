# DLSurfer and DKT Connectome

| | **DLSurfer** | **DKT Connectome** |
|--|--------------|---------------------|
| Docs | [phindagijimana.github.io/dlsurfer](https://phindagijimana.github.io/dlsurfer/) | [dkt-connectome.readthedocs.io](https://dkt-connectome.readthedocs.io/) |
| Input | T1w ± lesion (explicit paths; BIDS stub) | BIDS DWI + T1w |
| Output | FreeSurfer `SUBJECTS_DIR` | 78-node DKT connectome (+ optional disconnectome) |
| BIDS App | **Short of** standard ([status](../bids_app.md)) | Full `./run bids out participant` |
| Coupling | None — isolated package | May consume a finished SUBJECTS_DIR |

```bash
# Morphometry only (this repo)
dlsurfer run --profile core-lesion --t1 T1.nii.gz --lesion-mask L.nii.gz --sd SD --sid sub-01

# Connectomics (other repo) — after or instead of DLSurfer recon
./dkt run BIDS OUT participant --participant-label 01 --fastsurfer --syn
```

Print-only handoff notes: `dlsurfer handoff --consumer dkt --sd SD --sid SID` (does **not** run DKT).
