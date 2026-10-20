---
title: Plain language — planted shifts, probability, gold, protocol
date: 19 October 2026
---

# What we did, in the physics of the connectome

A streamline has two ends. Each end is assigned to a DKT parcel (`radial_4`). An **edge** is a pair of parcels. The **count** is how many streamlines sit on that pair. Ordinary QC can say PASS while the T1 parcels and the DWI grid are still off by a fraction of a millimetre. That leftover can change which parcel an end falls in, so the count changes.

## “Jump under planted small shifts”

**Planted** means we moved the assignment geometry by a **known** amount. We did not re-scan the person. We took the frozen 10M endpoints and translated them (or, in U’s confirmation, used the stored 1 mm count maps) by 0.25 mm, 0.5 mm, or 1 mm along \(x\), \(y\), or \(z\), then assigned again.

**Jump / moved** is a locked rule, not a feeling:

\[
\frac{|C^{\mathrm{plant}}_{ij}-C^0_{ij}|}{\max(C^{\mathrm{plant}}_{ij},C^0_{ij},\varepsilon)}>0.25
\quad\text{and}\quad
\max(C^0,C^{\mathrm{plant}})\ge 10.
\]

If the count on that edge changes by more than 25%, we call it a jump. \(U_{ij}\) is the **worst** such relative change on the small plants (\(\pm0.25\), \(\pm0.5\) mm). It **ranks** edges: high \(U\) means “this edge is fragile to small residual.”

That is a **sensitivity experiment** (Qi / Buchanan / Greene / Yeh). We occupy “1 mm can move edges.” We add: *which* edges, after QC-PASS, with a rule that was not retuned.

## “Planted 1 mm”

The **test** event for \(U\) and for calibrated \(U\) is the same algebra on **\(\pm 1\) mm** plants. We know the truth because we imposed the 1 mm. Calibrated \(U\) is a probability for **that phantom**: if we say 0.98, about 97% of those edges really jumped at 1 mm (experiment C).

**Limitation.** Real leftover after the usual warp is about **0.7 mm** (A5) and is **not** a pure 1 mm translation. So calibrated \(U\) is not “probability the edge is wrong in this patient.” It is “probability the edge jumps under the 1 mm plant we used to test \(U\).”

## Is planted 1 mm fabricated? Is it sound?

**We fabricated the shift, not the connectome.** Endpoints, SIFT2, DKT, and `radial_4` are the real freeze. We then impose a **known** translation and ask what moved. That is a digital phantom / perturbation test, the same class as Qi (2018), Buchanan (2014/2015), Greene (2018/2019), and Yeh (2019, 2021): millimetres change assignment. Those papers occupy “1 mm can move edges.” We occupy *which* edges, with a frozen rule, plus a checked probability for **that** event (C).

It is **not** leftover we measured. A5 leftover on confirmation is 0.66–0.81 mm (session median). L2 leftover-sized translation moved 1.9% of eligible edges; the 1 mm plant moved ~16%. So 1 mm is the same **order** as leftover (A5 p95 often >1.3 mm) but a **stronger edge event** than typical leftover. That is why C is scientifically sound as a 1 mm probability and **not** sound as \(\hat U\).

## A probability we have vs one we do not

| Sentence | Have it? |
|---|---|
| If residual were ~1 mm as planted, this edge jumps with probability \(P_{\mathrm{cal}}(U)\) | **Yes** (C) |
| Given leftover we **measured** on this person, this edge is wrong with probability \(\hat U\) | **No** |

The second sentence is gold \(\hat U\).

## New protocol — not inventing leftover

**Inventing** (not allowed): change \(e>0.25\), count≥10, or the 80% bin **after** seeing ECE so a failed exam looks like a win; plant more millimetres and call that leftover; name `proxyUhat` anyway.

**New protocol** (honest): write a **new question** and its pass/fail rule **before** looking at the new test numbers. Example: “Does frozen calibrated \(U\) stay calibrated when \(y\) is moved between two other-site connectomes?” If we write that rule first, then compute, a win or fail is a real result. That is pre-specification (DeGroot / Naeini), not HARKing.

A8 already used its one naming exam. Changing A8’s win rule because B9 was empty is inventing. Starting gold on **new leftover files** with a rule written first is not.

## proxy-\(\hat U\)

**Closed as a name.** A8 was the only exam that allowed calling the ANTs frequency proxy-\(\hat U\). It failed. We stop trying to give **that file** that name. We do **not** delete A5 millimetres or the frequency CSV. They stay measurements. We do **not** run another A8 on the same six sessions.

## Leftover / registration “noise model”

We do **not** have a leftover noise model that passed a probability exam.

- We **do** have leftover **millimetres** (A5). V1 won: voxel-median leftover 0.64–0.80 mm on confirmation (voxel SD ~0.2 mm). Still millimetres, still not a \(P\).
- We **tried** a cheap stand-in: 50 small ANTs re-registrations → edge frequency (Hub / Kybic). That is **not** Simpson’s \(p(\phi\mid I_{\mathrm{T1}},I_{\mathrm{dwi}})\). It **failed** as a probability (A8, L2).
- We **never ran** VoxelMorph / Simpson as a warp posterior (V2). Own lock later. Uncertainty on the **warp**, not gold \(\hat U\).

So we did not fail “registration UQ as a field.” We failed one cheap connectome-\(P\) recipe.

## Independent leftover — how it helps gold

Gold needs \(y\) = “did this edge move under leftover we did **not** plant and did **not** use to build \(P\)?”

| Source | What you get | Automatic gold? |
|---|---|---|
| Other TRACK-TBI site from the ~600 | New people’s leftover after **their** scanner / recon, same freeze, QC-PASS | **No.** You get the data to **run the exam**. Gold only if the written exam **wins** |
| Same-day `run-1` / `run-2` | Two real connectomes of the **same** person; difference ≈ leftover + scan noise | Same: data, then exam |
| Landmarks you click | Millimetre leftover after the usual warp | Same |

**Copying other-site subjects onto the home inbox does not grant \(\hat U\).** It opens G: process ≥2 QC-PASS freezes → `LIST.json` → `GOLD locked` → ECE → win or fail. Fail → keep calibrated \(U\). The ~600 are a **queue**, not 600 \(\hat U\) maps. Landing: `dwi_pipeline/sample_data/tracktbi_othersite/bids/` (see `work/sites_v1/INBOX.md`). No Gugger walk. TBI021030 is not leftover.

## What to write down before any new ECE (the lock)

1. **Who** — exact subject paths (e.g. two `TBI02…` BIDS roots).  
2. **Which number \(P\)** — frozen calibrated \(U\), or a new leftover model.  
3. **What counts as a move \(y\)** — relative change \(>0.25\), count≥10, between the two independent connectomes.  
4. **Who we must not train on.**  
5. **Win rule** — ECE, 10 bins, ±15 only on bins with ≥20 edges.

Then we compute. That is the whole gold attempt.
