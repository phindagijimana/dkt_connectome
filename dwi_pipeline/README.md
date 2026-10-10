# dwi_pipeline

Canonical **DKT Connectome** BIDS App (v0.3.0). Snakemake engine + `./dkt`.

**New users:** start at the [root README](../README.md) or [Read the Docs](https://dkt-connectome.readthedocs.io/en/latest/).

```bash
cd dwi_pipeline
./dkt install && ./dkt check --strict
./dkt run --help
```

| Command | Use |
|---------|-----|
| `./dkt` | Install, check, run, log, version |
| `./run` | Same as `./dkt run` (BIDS App contract) |
| `bash submit.sh` | Slurm cohort (FastSurfer default) |

Do not use `subject.sh` for new work (deprecated bash engine).

**Docs:** [Tutorial](docs/tutorial.md) · [Usage](docs/usage.md) · [Configuration](docs/configuration.md) · [Containers](docs/containers.md) · [Changelog](docs/changelog.md)

**Public demos:** [IDEAS II](docs/datasets/ideas.md) · [BTC glioma](docs/datasets/btc_glioma.md)
