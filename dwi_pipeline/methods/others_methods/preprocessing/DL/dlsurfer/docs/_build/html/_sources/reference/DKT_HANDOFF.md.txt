# Optional handoff notes (not a DKT dependency)

**DLSurfer does not implement or require the DKT connectome pipeline.**  
See [`ISOLATION.md`](ISOLATION.md).

If an operator wants to *read* DLSurfer outputs from DKT (or any other consumer):

```bash
dlsurfer handoff --consumer dkt --sd /path/subjects --sid sub-EG
# alias: dlsurfer handoff-dkt ...
```

| DLSurfer profile | Typical consumer use |
|------------------|----------------------|
| `core` | FastSurfer-shaped tree with DKT labels |
| `core-lesion` | Same after standalone LIT |
| `fs8` | FreeSurfer 8 tree (DK / Destrieux possible) |

Connectome / ACT / disconnectome remain entirely in the DKT stack.
