---
title: Training judgment, falsification, and provenance
date: 2026-10-21
status: LAB_PRACTICE
companions: [AI_ERA_RIGOR.md, BIG_MINDS_EVAL_AI_ERA_TRAINING.md, EVALUATION_AS_SCIENCE.md]
---

# Training judgment, falsification, and provenance

**Product of AI-era methods work:** not more hypotheses or drafts — **judgment** (what to believe), **falsification** (what would kill the claim), **provenance** (how others reconstruct and challenge it).

Aligned with NIH/NASEM/COS training themes; see [BIG_MINDS_EVAL_AI_ERA_TRAINING.md](BIG_MINDS_EVAL_AI_ERA_TRAINING.md) and [AI_ERA_RIGOR_LITERATURE.md](AI_ERA_RIGOR_LITERATURE.md).

---

## 1. Judgment — what deserves to be believed

**Drills**
- Before analysis: one-sentence **claim** + **non-claim**.
- After result: **keep / demote to exploratory / kill** — no “maybe later” pile.
- Maintain a claim spine (primary vs secondary vs forbidden).

**Practice material**
- One methods paper per week: mark estimand, leakage risk, abstract overclaim.
- Take an AI-suggested new score; spend 15 minutes only on *how it would fool a reviewer*.

**Metric:** fraction of analyses with an explicit keep/kill note in the wave log.

---

## 2. Falsification — how would this be wrong?

**Before confirming**
- Write **two** ways the result could be fake (leakage, base-rate clash, wrong estimand, site shift, bug).
- Design the **cheapest** test that would hurt the claim.

**Standing habits**
- Negative controls (reseed, cross-site, strong-edge-only).
- When something fails (soft invent, G, ECE): **document and freeze** — do not retune to erase it.
- Red-team with AI as hostile reviewer — then run one attack.

**Metric:** every locked claim has a written falsifier and at least one run that tried it.

---

## 3. Provenance — can someone reconstruct and challenge it?

**Every session**
- Locks / JSON: cuts, seeds, containers, subject lists.
- Wave-log line: what changed and why (anti-retune).
- Outputs named by **claim**, not date soup.

**Exercises**
- Monthly: regenerate one figure from docs alone.
- Release checklist: version → CITATION → DOI.
- Refuse analyses that cannot point to a frozen protocol file.

**Metric:** future-you in 3 months can regenerate the number from a short recipe.

---

## 4. Weekly workout (60–90 min)

1. Pick one live claim (e.g. within-site \(P_L\)).  
2. Write claim + non-claim + falsifier (10 min).  
3. Run **one** hostile check (20–40 min).  
4. Update lock/log/DOI note (10 min).  
5. Kill or promote — no third option (5 min).

**Eval-as-science variant:** claim → metric → falsifier → stratum where it should break → run → lock pass **or** fail ([EVALUATION_AS_SCIENCE.md](EVALUATION_AS_SCIENCE.md)).

---

## 5. What not to optimize

- More hypotheses, more scores, more AI drafts.  
- Beauty of a pipeline that merely finishes.

**One sentence:** get better by making “what would kill this?” and “how do I prove I didn’t cheat?” mandatory *before* “how do I make the number look better?”
