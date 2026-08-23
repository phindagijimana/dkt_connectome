# Contributing

How to develop, test, and document changes to the DKT Connectome.

---

## Getting started

```bash
git clone https://github.com/phindagijimana/dkt_connectome.git
cd dkt_connectome/dwi_pipeline
pip install snakemake sphinx
export FS_LICENSE=/path/to/license.txt
```

Read [Installation](installation.md) for Apptainer images and HPC setup.

---

## Repository layout

| Path | Purpose |
|------|---------|
| `run` | BIDS App entrypoint |
| `submit.sh` / `run_subject.sh` | HPC + Snakemake wrappers |
| `workflow/Snakefile` | Snakemake DAG |
| `workflow/rules/` | Per-step plugin rules |
| `workflow/config/config.yaml` | Default configuration |
| `scripts/` | Python/bash utilities |
| `docs/` | Sphinx site source (user-facing pages on [Read the Docs](https://dkt-connectome.readthedocs.io/en/latest/); QSIPrep-style RTD theme) |
| `docs/maintainer/` | **GitHub-only** release and registry runbooks (not published on RTD) |
| `containers/` | In-house image recipes |
| `schemas/` | JSON Schema for config validation |

---

## Making changes

1. **Branch** from `main` for non-trivial work.
2. **Match conventions** — read surrounding code before editing; minimal diffs.
3. **Update docs** when changing CLI flags, defaults, or outputs (`docs/usage.md`, `docs/configuration.md`, relevant Methods page).
4. **Run checks locally:**

```bash
cd dwi_pipeline/docs
pip install -r requirements.txt
make html
snakemake -s ../workflow/Snakefile --lint
# dry-run with test config if available
```

5. **Open a pull request** with a short description of *why* the change is needed.

---

## Documentation

- Build the **public site** locally: `cd docs && make html` (or `sphinx-build -b html . _build/html`)
- User-visible pages publish to [dkt-connectome.readthedocs.io](https://dkt-connectome.readthedocs.io/en/latest/)
- Add Methods content for scientific changes
- Update [Changelog](changelog.md) for user-visible changes

---

## Repository-local documentation

<a id="repository-local-documentation"></a>

The following files live in the repository but are **not** published on Read the Docs (maintainer credentials, release runbooks, auto-generated config dumps). Open them on GitHub:

| Topic | Path |
|-------|------|
| Open-work tracker (canonical) | [`remaining.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/remaining.md) |
| Maintainer one-shot tasks (release, Docker, RTD, Dockstore, Zenodo) | [`docs/maintainer/maintainer_tasks.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/maintainer_tasks.md) |
| Release checklist | [`docs/maintainer/publishing.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/publishing.md) |
| Readiness checklist (P0–P5) | [`docs/maintainer/readiness_checklist.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/readiness_checklist.md) |
| Integration CI (real containers) | [`docs/maintainer/integration_ci.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/integration_ci.md) |
| v1.0 science track | [`docs/maintainer/v1_science_track.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/v1_science_track.md) |
| Container digests | [`docs/maintainer/container_digests.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/container_digests.md) |
| BIDS Apps registry submission (optional) | [`docs/maintainer/bids_apps_registry.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/maintainer/bids_apps_registry.md) |
| Configuration catalog (auto-generated) | [`docs/config_catalog.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/config_catalog.md) |
| JSON Schema reference | [`docs/schema_reference.md`](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/schema_reference.md) |

Regenerate the config catalog after editing `workflow/config/config.yaml`:

```bash
python3 dwi_pipeline/scripts/generate_config_catalog.py
```

User-facing config summary: [Configuration](configuration.md).

---

## Adding a Snakemake rule

1. Create `workflow/rules/<step>.smk`
2. Include from `workflow/Snakefile`
3. Add `target_<step>` goal if standalone mode is needed
4. Document in [Snakemake workflow](snakemake_workflow.md) and [Pipeline steps](pipeline_steps.md)
5. Wire CLI in `workflow/run_subject.sh` and `./run` if user-facing

Config keys: [Configuration](configuration.md) · full schema on [GitHub](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/docs/schema_reference.md).

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
- [FAQ](faq.md)

---

## Code of conduct

Be respectful in issues and reviews. Neuroimaging software serves diverse clinical and research communities.

---

## See also

- [License information](license.md)
- [Snakemake workflow](snakemake_workflow.md)
