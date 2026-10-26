# FAQ

## Is DLSurfer a FreeSurfer replacement?

No. It orchestrates FastSurfer / FreeSurfer (and related DL tools) and writes a standard SUBJECTS_DIR.

## Why not wire VINN myself?

You lose the SUBJECTS_DIR contract, module glue, and HPC seg/surf split. See [engine policy](../workflows/engine_policy.md).

## `doctor` says READY but login has no GPU

Expected. Run VINN/LIT on a GPU allocation; login-node `nvidia-smi` MISS is fine.

## TopoFit fails with CUDA / `slow_conv3d`

FS 7.4.1 SIF torch may not run conv3d on newer GPUs. Use `--device cpu` for TopoFit.

## TopoFit: `norm.mgz is not a file`

surfa rejects symlinks. Hardlink/copy `orig_nu.mgz` → `norm.mgz`, or pass a real volume. Prefer `--seg_only --tal_reg` so `talairach.lta` exists.

## FastSurfer: unrecognized `--batch_size`

Use FastSurfer’s `--batch` (DLSurfer `--batch-size` maps correctly in current planner).

## Execute blocked by gates

`dlsurfer gates` — use `--allow-experimental` only for lab overrides, or wait until status is `passed`.
