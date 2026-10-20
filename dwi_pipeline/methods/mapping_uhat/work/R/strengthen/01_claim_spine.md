# Strengthen §1 — Rewrite the claim spine

Status: **locked paper framing** (2026-10-20). Supersedes any leftover-AUROC / hat{U} primary narrative.

## Title-level promise (what the paper is about)

**Edge-level uncertainty for streamline-count connectomes under controlled endpoint perturbation**, with an honest public scan–rescan boundary test.

Not: “we predict which edges change between visits” as the lead claim.

## Claim A — positive (methods + plant validation)

**Shift sensitivity \(U\) and jitter leakage \(F\) measure which edges are fragile under a known ~1 mm endpoint plant and under measured assignment jitter.**

| Support | Number / fact |
|---|---|
| Planted AUROC \(U\) | ≈ 0.91–0.94 (dev + TBI confirm) |
| Planted AUROC \(F\) | ≈ 0.89–0.93 |
| Calibrated \(U\) | P(edge moves under **planted 1 mm**), C win |
| Software | `edgeuq shift` / `jitter`; frozen cuts |

**Abstract sentence:**  
> We quantify connectome fragility to small endpoint displacement and assignment noise.

## Claim B — negative / boundary (retest exam)

**On public same-day retest pairs, leftover edge moves are not well ranked by \(U\)/\(F\), and planted-1 mm calibration does not transfer to leftover \(y\).**

| Support | Number / fact |
|---|---|
| AUROC \(U\)/\(F\) | ≈ 0.58–0.60 (Kirby + Boekel GOLD) |
| G ECE | ≈ 0.32; bin band fail |
| Soft invent | FAIL (>0.001 both pilots) |
| Reseed floor | ≈ 9.5% vs leftover 36–54% |

**Abstract sentence:**  
> Retest shows these scores are not detectors of natural visit-to-visit change.

Treating Claim B as a **result** (not a failed paper) is what keeps credibility after GOLD FAIL.

## Claim C — secondary method (optional, named separately)

**Ses-1 count instability \(L=-\log(1+C_0)\) ranks leftover movers better than \(U\)/\(F\) on the same pilots (AUROC ≈ 0.70), as a distinct method (`edgeuq instability`).**

Not a retune of \(U\). Not \(\hat{U}\). Details in Strengthen §3.

## Explicit non-claims (do not write these)

1. Not \(\hat{U}\) / proxy-\(\hat{U}\) from leftover.
2. Not “\(U\)/\(F\) calibrate real change rates.”
3. Not “soft connectome wins” under invent ≤ 0.001.
4. Not that loosening invent / refitting isotonic on leftover “rescues” Claim B.

## Paper section map

1. Intro: perturbation UQ for counts; open question of retest transfer.
2. Methods: shift, jitter, soft, (optional) \(L\).
3. Results A: planted validation (positive).
4. Results B: retest exam (negative for transfer; positive for honesty).
5. Results C: descriptive flags (threshold uncertainty, reseed floor) — Strengthen §2.
6. Results D: \(L\) as second method — Strengthen §3.
7. Discussion: two jobs (plant fragility vs leftover instability); limits; scaling descriptive only.

## Decision

Freeze this spine. All later strengthen points and new directions hang under A/B/C — they do not reopen frozen plant cuts to make B look like a leftover win.
