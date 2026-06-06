# Kubernetes profile

End-to-end recipe for running `dk_connectome` on any Kubernetes cluster the
`snakemake-executor-plugin-kubernetes` plugin can reach.

## 1. Cluster pre-requisites

```bash
kubectl create namespace dk-connectome
kubectl apply -n dk-connectome -f pvc.example.yaml      # see template below
```

Container images must be reachable from the cluster. The four images this
workflow needs are already public on Docker Hub / ghcr.io, so no private
registry is required out of the box:

| image                                                | size  |
|------------------------------------------------------|-------|
| `pennlinc/qsiprep:1.0.0`                             | ~7 GB |
| `pennlinc/qsirecon:1.2.1`                            | ~6 GB |
| `freesurfer/freesurfer:7.4.1`                        | ~12 GB |
| `ghcr.io/phindagijimana/dk-connectome:0.1.0`         | ~0.9 GB |

If your cluster pulls from a private registry, attach an `imagePullSecret`
to the service account this profile uses (default: the namespace's `default`
SA). With public images, no auth is needed.

## 2. PersistentVolumeClaim

The plugin requires a shared volume mounted at `/workdir` in every pod so
that intermediate sentinel files survive between rule executions.

`pvc.example.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dk-connectome-workdir
spec:
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 500Gi              # tune per cohort size
  storageClassName: ""            # set to your RWX class (e.g. nfs-csi, efs-sc)
```

The Snakemake plugin auto-mounts a PVC named `dk-connectome-workdir` in the
profile's namespace at `/workdir`. To rename, pass `--kubernetes-pvc-name`.

## 3. Run

From a workstation with `kubectl` on PATH and `~/.kube/config` pointing at
the target cluster:

```bash
./connectome install --no-deps --no-containers       # subjects.tsv only
snakemake --profile profiles/k8s --configfile config/config.yaml
```

Or via the CLI shim:

```bash
./connectome start --mode local -- --profile profiles/k8s
```

(The CLI's `--mode` switch only controls whether it submits via `sbatch`
vs `nohup`; passing `--profile profiles/k8s` after `--` makes Snakemake use
the Kubernetes executor regardless.)

## 4. Tear-down

```bash
./connectome stop                                    # SIGTERMs the local driver
kubectl -n dk-connectome delete jobs --all           # idempotent
```

## 5. Notes

* `use-singularity: false` because pods run the OCI image directly; the
  rule's `shell:` block invokes `apptainer` only because that's what works
  on Slurm + bare-metal clusters. On Kubernetes, the apptainer call still
  works (the pod has apptainer in PATH if the base image includes it), but
  for cluster-native runs it's cleaner to refactor the rule to use
  Snakemake's `container:` directive — see `docs/k8s-native-rules.md` for
  the planned migration.
* Resource units differ slightly: `disk_mb` becomes the pod's
  `ephemeral-storage` request, `mem_mb` becomes `memory`, threads become
  `cpu`. The plugin does the translation.
