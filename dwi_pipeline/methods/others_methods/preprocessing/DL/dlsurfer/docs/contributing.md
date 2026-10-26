# Contributing

```bash
pip install -e ".[dev,docs]"
python scripts/gen_methods_docs.py   # after editing engines.yaml
pytest -q
mkdocs build --strict
mkdocs serve
```

- Keep **claims** honest (`docs/reference/CLAIMS.md`) — orchestrate, don’t replace science.  
- New engines: add to `engines.yaml` with `cite`, `cli`, `why`, `alternatives`; regenerate methods docs.  
- Experimental profiles: wire a gate in `gates.yaml` before `--execute` in production.  
- Docs IA mirrors [DKT Connectome](https://dkt-connectome.readthedocs.io/) (Getting started / Using / Methods / Reference) plus QSIPrep-style install/usage depth.

PRs: [github.com/phindagijimana/dlsurfer](https://github.com/phindagijimana/dlsurfer).
