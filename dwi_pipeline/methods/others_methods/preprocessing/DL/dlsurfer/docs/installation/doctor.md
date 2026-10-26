# Doctor check

```bash
source env/cluster_containers.sh   # if using Apptainer wrappers
dlsurfer doctor          # full OK/MISS wall
dlsurfer doctor --brief  # core checks + READY only
```

Expect:

```text
[READY] core live-run deps present
```

`[MISS]` lines for optional specialty tools (HippUnfold, SynthSeg-PC, Schaefer annots, `nvidia-smi` on login nodes) are normal — `--brief` collapses them to one note.

Also useful:

```bash
dlsurfer smoke -q              # brief doctor + quiet plan
dlsurfer gates                 # science/ops gates
dlsurfer freeview --sd $SD --sid $SID --check
```
