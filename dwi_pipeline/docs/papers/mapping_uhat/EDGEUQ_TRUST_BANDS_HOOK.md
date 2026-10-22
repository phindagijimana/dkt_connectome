---
title: Optional edgeuq trust-band hook for DKT-Connectome
date: 2026-10-21
status: DESIGN
default: off
---

# EDGEUQ_TRUST_BANDS_HOOK

## Goal

After DKT count construction, optionally write edge-level companions next to the matrix so users see **trust bands**, not only point counts.

## Inputs (already produced by connectome step)

- Tractogram `.tck` (same space as nodes)
- Nodes image / `*_nodes.mif`
- `*_connectome_count.csv` (ses-1; ses-2 if TRT)

## Outputs (sidecar directory e.g. `.../edgeuq/`)

| File | Source | Paper |
|------|--------|-------|
| `U.csv` / `Ucal.csv` | `edgeuq shift` | P1 |
| `F.csv`, `Esoft.csv` | `edgeuq jitter` | P1 |
| `L.csv` | `edgeuq instability` | P2 |
| `P_L.csv` (optional) | frozen isotonic / site map — only if provided | P2 |
| `README_symbols.md` | generated stub | both |

## Config (proposed)

```yaml
connectome:
  edgeuq_trust_bands: false   # default
  edgeuq_container: edgeuq.sif  # or PATH to edgeuq CLI
  edgeuq_sigma_mm: null         # or set; else derive per protocol
```

## Semantics (must appear in CLI help)

- \(U\)/\(F\): fragility under **planted / jittered endpoints** — not visit-change probability.
- \(L\)/\(P_L\): **leftover / scan–rescan** instability — not plant \(\hat{U}\).
- Soft invent / threshold-uncertain flags are diagnostics; frozen invent gate stays reported, not retuned in the app.

## Implementation note

Prefer a **separate Snakemake rule** `edgeuq_trust_bands` with `input: count, tck, nodes` and `output: edgeuq/.done`, gated by config, over baking Python into `dkt_connectome.sif`. Keeps assigner image small; pins `edgeuq` version independently for Paper 1/2 releases.
