# SUBJECTS_DIR

Always pass a **DLSurfer-owned** `--sd` unless you intentionally reuse a finished FreeSurfer tree (e.g. TopoFit-only on an existing subject).

```text
$SD/
  $SID/
    mri/ surf/ label/ stats/ scripts/ tmp/ touch/   # FreeSurfer-shaped
    dwi/ pet/ fmri/ qc/                             # multimodal
    hippunfold/ ibeat/ dhcp/                        # app trees
    surf/dlsurfer/                                  # non-promoted DL meshes
```

Full registry: `dlsurfer contract --list` · [outputs/layout.md](../outputs/layout.md).

Do not point `--sd` at an active DKT-connectome work tree unless that is an explicit handoff choice. Isolation policy: [reference/ISOLATION.md](../reference/ISOLATION.md).
