# Gaps remaining **without** a credible alternative

Run: `dlsurfer gaps-remaining`

Multimodal FS-suite gaps that **now have DL alternatives** (wired specialty):
TRACULA → TractSeg · PET MRI-parc path → pet-dl-quant · FS-FAST/fMRI helpers →
DeepPrep · FreeView-only raw QC triage → BrainQCNet. See [CREDIBILITY.md](CREDIBILITY.md).

| Gap | Why no alternative in DLSurfer | What to do instead |
|-----|--------------------------------|--------------------|
| **Dedicated DLSurfer meta-container (SIF/Docker)** | Packaging/ops only — not a morphometry method | Use pinned FastSurfer image + host FS; scaffold `containers/dlsurfer.def` |
| **Manual edit loops (`-autorecon2-*`)** | Interactive QC by design; no DL replaces topology edits | FreeView + targeted `recon-all -autorecon2-*`; use `qc-brainqcnet` for triage only |
| **Bit-identical `recon-all` reproducibility claim** | Non-claim vs FastSurfer/DLSurfer | `--allow-classical` profile `fs8` if you need classical FS tree semantics |
| **True Infant FreeSurfer neonate stream** | Partially covered (`fs-clinical`, `infant-ibeat`, `infant-dhcp`) | Install [Infant FreeSurfer](https://surfer.nmr.mgh.harvard.edu/fswiki/infantFS) separately when needed |
| ~~Native LIT + optimal GPU/CPU seg↔surf split~~ | **Solved** — LIT is DL separable only | `core-lesion` + `--stage gpu\|cpu`; [LIT_SPLIT.md](LIT_SPLIT.md). Upstream `--lesion_mask` not on public path. |

## Explicitly *not* “missing alternatives” (wired)

| Former gap | Best DL alternative | How |
|------------|---------------------|-----|
| TRACULA | TractSeg (B) | `dwi-tractseg` / `dlsurfer tool tractseg` |
| PET FS parc → SUVR | PET-DL quant (B) | `pet-dl-quant` |
| FS-FAST / fMRI helpers | DeepPrep (B) | `fmri-deepprep` |
| FreeView-only raw QC | BrainQCNet (B) | `qc-brainqcnet` |
| DK / Destrieux / Schaefer / long / HA / BS-thal / clinical | See ALTERNATIVES.md | profiles + `--allow-classical` for D |

See also: [`COMPARE_FS_FASTSURFER.md`](COMPARE_FS_FASTSURFER.md) · [`CREDIBILITY.md`](CREDIBILITY.md)
