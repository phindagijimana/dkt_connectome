# Doctor check

```bash
source env/cluster_containers.sh   # if using Apptainer wrappers
dlsurfer doctor
```

Expect:

```text
[READY] core live-run deps present
```

`[MISS]` lines for optional specialty tools (HippUnfold, SynthSeg-PC, Schaefer annots, `nvidia-smi` on login nodes) are normal.

Also useful:

```bash
dlsurfer smoke    # doctor + dry-run core-lesion plan
dlsurfer gates    # science/ops gates
```
