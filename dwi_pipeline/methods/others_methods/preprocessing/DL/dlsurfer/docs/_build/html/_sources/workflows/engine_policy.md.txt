# Engine policy — wrap FastSurfer / FreeSurfer

**Keep wrapping FastSurfer / FreeSurfer for default morphometry (`core`, `core-lesion`).**  
Use individual engines as cited stages and specialty modules — not as a DIY replacement of `run_fastsurfer.sh` for production SUBJECTS_DIR.

| Need | Individual tools only | FastSurfer / FS wrap |
|------|----------------------|----------------------|
| FreeSurfer-shaped `SUBJECTS_DIR` | Fragile glue | **Native contract** |
| GPU seg / CPU surf split | DIY | `--seg_only` / `--surf_only` |
| Versioned cited stack | Many pins | One FastSurfer pin + modules |
| “Orchestrate, don’t replace” | Looks like a fork | Matches claim |

Full detail: [reference/ENGINE_POLICY.md](../reference/ENGINE_POLICY.md).
