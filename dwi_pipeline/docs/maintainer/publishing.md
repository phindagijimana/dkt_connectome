# Publishing documentation

Checklist for keeping [dkt-connectome.readthedocs.io](https://dkt-connectome.readthedocs.io/en/latest/) in sync with `main`.

---

## One-time setup

1. **Import project** at [readthedocs.org](https://readthedocs.org/) → GitHub → `phindagijimana/dkt_connectome`.
2. **Project slug:** `dkt-connectome` (must match URLs in `app.json`).
3. **Display name:** [Admin → Settings](https://app.readthedocs.org/dashboard/dkt-connectome/edit/) → **DKT Connectome** (not TrackTBI Connectome Pipeline).
4. **Config file:** repo root [`.readthedocs.yaml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.readthedocs.yaml) → `dwi_pipeline/mkdocs.yml`.
5. **Automatic rebuilds** (pick one):
   - **Option A:** GitHub secret `READTHEDOCS_TOKEN` ([create token](https://readthedocs.org/accounts/tokens/)) — workflow [`.github/workflows/readthedocs.yml`](https://github.com/phindagijimana/dkt_connectome/blob/main/.github/workflows/readthedocs.yml) triggers on docs pushes.
   - **Option B:** [RTD Integrations](https://app.readthedocs.org/dashboard/dkt-connectome/integrations/) → connect GitHub webhook (no token needed).

---

## After every docs push

```bash
# Local strict build (matches CI)
cd dwi_pipeline && mkdocs build --strict

# Live site check (after RTD rebuild completes, ~2–5 min)
bash scripts/verify_rtd_live.sh
```

Expected: `<title>DKT Connectome</title>` and sidebar **DKT Connectome** — no **TrackTBI Connectome**.

---

## Manual rebuild (if CI skipped token)

1. [Builds → Trigger build](https://app.readthedocs.org/projects/dkt-connectome/builds/) for version **latest**.
2. Wait for green build.
3. Run `bash dwi_pipeline/scripts/verify_rtd_live.sh`.

---

## Stale site symptoms

| Symptom | Fix |
|---------|-----|
| Tab title **TrackTBI Connectome Pipeline** | Rebuild RTD; set project display name to **DKT Connectome** |
| Old Methods pages missing | Build must use commit ≥ `4077d88` |
| Wrong favicon | Clear custom RTD favicon override; hard-refresh browser |
| GitHub README updated but RTD old | RTD not rebuilding — set up token or webhook (above) |

---

## Local preview

```bash
pip install mkdocs
cd dwi_pipeline
mkdocs serve
# http://127.0.0.1:8000
```

---

## CI jobs

| Workflow | What it checks |
|----------|----------------|
| `readthedocs.yml` | Triggers RTD API (if token set); local `mkdocs build --strict`; title/favicon/svg assets |
| Live verify step | Curls production URL; **informational** until RTD rebuilds |

See also: legacy notes in [Read the Docs setup](../readthedocs_setup.md).
