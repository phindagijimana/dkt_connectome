# Python package

```bash
git clone https://github.com/phindagijimana/dlsurfer.git
cd dlsurfer
python3 -m venv .venv && source .venv/bin/activate   # optional
pip install -e ".[docs]"   # or: pip install -e .
```

Without install:

```bash
export PYTHONPATH=/path/to/dlsurfer
python -m dlsurfer --help
```

Entry point after install: `dlsurfer`.

## Dev / docs extras

```bash
pip install -e ".[dev,docs]"
pytest -q
mkdocs serve    # local docs site
```
