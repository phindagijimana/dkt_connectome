---
title: Convenience wrapper (not a FreeSurfer / FastSurfer replacement)
subtitle: Positioning for a single-entry FastSurfer (+ LIT) + DWI handoff
date: 23 October 2026
---

# DL preprocessing convenience — device-flexible wrapper

**Claim boundary.** We are **not** replacing FreeSurfer or FastSurfer science. This note is about **operator convenience**: one runtime path so lesion subjects do not bounce between GPU and CPU jobs.

**One-line positioning**

> A single-entry, device-flexible wrapper around FastSurfer (+ LIT) and our DWI stack so lesion subjects don’t bounce between GPU and CPU jobs — FreeSurfer-compatible outputs, no claim to replace FreeSurfer or FastSurfer.

That framing is stronger and more honest than a “replacement” pitch. Convenience = **one runtime path**, not better anatomy than FastSurfer.

---

## The pain today

Typical hop:

1. **GPU** — VINN / neuroLIT inpaint  
2. **CPU** — recon-surf / FreeSurfer bits / MRtrix  
3. **Maybe GPU again** — downstream DL  

Queues, modules, containers, and PATH breaks cost more than the last 10% of morphometry cleverness. Lab share context for standalone vs native LIT arms: `analysis/gugger_eg_lit/fastsurfer_inpainting/`.

---

## What “convenience” can credibly mean

| Goal | Claim |
|------|--------|
| **One subject command** | seg → surfaces → (optional LIT) → handoff to DWI without re-submitting across partitions |
| **One container / one env** | Apptainer + pinned torch + tools; no module roulette |
| **One device policy** | auto: GPU if free, else CPU — same code path |
| **Same outputs contract** | Still FreeSurfer-shaped dirs so QSIRecon / connectome don’t care |
| **Explicit non-claim** | Orchestration & packaging — **not** “replaces FreeSurfer / FastSurfer science” |

**Impact of that narrower project**

- **Operators** (lab, TRACK-TBI throughput): moderate-to-high  
- **Methods paper**: modest unless you measure **wall-time, queue time, and failure rate** vs the current split  

Still publishable as **infrastructure / reproducible workflow**, especially with lesion / LIT baked in.

---

## What not to do under this banner

- Do **not** reimplement recon-surf in DL “because GPU.”  
- Only pull in another DL surface / registration method if it **removes a CPU hop you actually run**, or clearly cuts queue pain — **not** to out-FastSurfer FastSurfer.

---

## PI story (short)

Same debugging reality, clean pitch: orchestration that keeps lesion subjects on one device-flexible path, FreeSurfer-compatible handoff, science credit stays with FreeSurfer / FastSurfer / LIT authors.

---

## Literature map

Deep dive (limitation vs reusable tools): [`LITERATURE_MAP.md`](LITERATURE_MAP.md). Canvas: [DL preprocess literature map](/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/.cursor/projects/mnt-nfs-home-urmc-sh-rochester-edu-pndagiji-Documents-TrackTBI-Sub/canvases/dl-preprocess-literature-map.canvas.tsx).

## Tool catalog (build order)

Start inside FreeSurfer + FastSurfer DL modules, then add external validated papers: [`CATALOG.md`](CATALOG.md).

DL alternatives to **classical** stages (surfaces / thickness / spherical reg): [`DL_ALTERNATIVES.md`](DL_ALTERNATIVES.md).

Master table (every classical method → many alternatives + readiness): [`CLASSICAL_TO_DL_TABLE.md`](CLASSICAL_TO_DL_TABLE.md).

## DLSurfer product plan

Curated FreeSurfer-shaped DL orchestrator (name: **dlsurfer**): [`DLSURFER_PLAN.md`](DLSURFER_PLAN.md).

**Implementation (Phases 0–4 scaffold):** [`dlsurfer/`](dlsurfer/) — `pip install -e dlsurfer/` then `dlsurfer doctor` / `dlsurfer engines` / `dlsurfer run ...`.
