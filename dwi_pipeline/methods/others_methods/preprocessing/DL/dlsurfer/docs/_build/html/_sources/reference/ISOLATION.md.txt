# Isolation from DKT connectome

**Rule.** DLSurfer lives only under:

`dwi_pipeline/methods/others_methods/preprocessing/DL/dlsurfer/`

It must **not** modify, import, or depend on the DKT connectome pipeline code (`dwi_pipeline/workflow/`, Snakemake rules, `dkt_*` submit scripts, etc.).

| Boundary | DLSurfer | DKT connectome |
|----------|----------|----------------|
| Owns | Morphometry orchestration (T1 → SUBJECTS_DIR) | DWI, ACT, connectomes, disconnectome |
| May write | Its own `--sd` subject trees | Pipeline derivatives under DKT out dirs |
| May read | User T1 / lesion / FS license | Optional: a finished SUBJECTS_DIR if operator points at it |
| Must not | Patch DKT configs, share process state, require DKT install | Call `dlsurfer` as a hard dependency (optional later adapter only) |

**Handoff is optional and one-way.**  
`dlsurfer handoff` prints how a *consumer* (DKT or other) can *read* FreeSurfer-shaped outputs. It does not run DKT.

**Atlases.** DKT is one default cortical labeling scheme, not the product identity. See [`ATLASES.md`](ATLASES.md). Connectome node sets stay a DKT-pipeline concern unless a future optional adapter is added **outside** this package.
