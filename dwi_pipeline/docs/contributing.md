# Contributing

How to develop, test, and document changes to the DKT Connectome.

---

## Getting started

```bash
git clone https://github.com/phindagijimana/dkt_connectome.git
cd dkt_connectome/dwi_pipeline
pip install snakemake mkdocs
export FS_LICENSE=/path/to/license.txt
```

Read [Installation](installation.md) for Apptainer images and HPC setup.

---

## Repository layout

| Path | Purpose |
|------|---------|
| `run` | BIDS App entrypoint |
| `subject.sh` / `submit.sh` | HPC wrappers |
| `workflow/Snakefile` | Snakemake DAG |
| `workflow/rules/` | Per-step plugin rules |
| `workflow/config/config.yaml` | Default configuration |
| `scripts/` | Python/bash utilities |
| `docs/` | MkDocs site source |
| `containers/` | In-house image recipes |
| `schemas/` | JSON Schema for config validation |

---

## Making changes

1. **Branch** from `main` for non-trivial work.
2. **Match conventions** — read surrounding code before editing; minimal diffs.
3. **Update docs** when changing CLI flags, defaults, or outputs (`docs/usage.md`, `docs/configuration.md`, relevant Methods page).
4. **Run checks locally:**

```bash
cd dwi_pipeline
mkdocs build --strict
snakemake -s workflow/Snakefile --lint
# dry-run with test config if available
```

5. **Open a pull request** with a short description of *why* the change is needed.

---

## Documentation

- Build locally: `mkdocs serve` in `dwi_pipeline/`
- Publishing checklist: [Maintainer → Publishing](maintainer/publishing.md)
- Add Methods content for scientific changes
- Update [Changelog](changelog.md) for user-visible changes

---

## Adding a Snakemake rule

1. Create `workflow/rules/<step>.smk`
2. Include from `workflow/Snakefile`
3. Add `target_<step>` goal if standalone mode is needed
4. Document in [Snakemake workflow](snakemake_workflow.md) and [Pipeline steps](pipeline_steps.md)
5. Wire CLI in `workflow/run_subject.sh` and `./run` if user-facing

See [Schema reference](schema_reference.md) for config keys.

---

## Tests

```bash
# From repo root or dwi_pipeline/
pytest dwi_pipeline/tests/ -q
```

Fixtures: `dwi_pipeline/tests/fixtures/`.

---

## Issues and help

- [GitHub Issues](https://github.com/phindagijimana/dkt_connectome/issues)
- [Getting help](getting_help.md) — NeuroStars tags, upstream docs

---

## Code of conduct

Be respectful in issues and reviews. Neuroimaging software serves diverse clinical and research communities.

---

## See also

- [Schema reference](schema_reference.md)
- [BIDS Apps registry](bids_apps_registry.md)
- [License information](license.md)
