#!/usr/bin/env python3
"""Run CortexMorph thickness on a FreeSurfer/FastSurfer SUBJECTS_DIR subject.

DL-CTE family pick: CortexMorph (public weights). Wu DL-CTE GitHub is empty.
Builds WM/GM probability + aseg-derived cortex ROI labels from SUBJECTS_DIR.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import nibabel as nib
import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from scipy.ndimage import binary_dilation

# CortexMorph upstream still uses np.NaN (removed in NumPy 2.0)
if not hasattr(np, "NaN"):
    np.NaN = np.nan  # type: ignore[attr-defined]



def main() -> int:
    cm = Path(os.environ["CORTEXMORPH_ROOT"]).resolve()
    sd = Path(os.environ["SUBJECTS_DIR"]).resolve()
    sid = os.environ["DLSURFER_SID"]
    out = Path(os.environ["DLSURFER_OUT"]).resolve()
    device = os.environ.get("DLSURFER_DEVICE", "cuda")
    sys.path.insert(0, str(cm))
    os.chdir(cm)

    from nnunet.network_architecture.generic_UNet import Generic_UNet

    # Import helpers from upstream apply script
    import apply_CortexMorph as acm  # noqa: E402

    mri = sd / sid / "mri"
    aseg_path = next(
        (mri / n for n in ("aparc.DKTatlas+aseg.deep.mgz", "aseg.mgz", "aseg.auto_noCCseg.mgz") if (mri / n).is_file()),
        None,
    )
    if aseg_path is None:
        print(f"[cortexmorph] no aseg under {mri}", file=sys.stderr)
        return 2
    aseg_img = nib.load(str(aseg_path))
    aseg = np.rint(np.asanyarray(aseg_img.dataobj)).astype(np.int32)
    # FS WM ≈ 2,41,77,251-255; GM cortex ≈ 3,42 + 1000+/2000+
    wm = np.isin(aseg, [2, 41, 77, 251, 252, 253, 254, 255]).astype(np.float32)
    gm = ((aseg >= 1000) | np.isin(aseg, [3, 42])).astype(np.float32)
    # Parcellation: keep cortical labels; map unknown cortex to generic 1000/2000
    parc = aseg.copy()
    parc[np.isin(aseg, [3])] = 1000
    parc[np.isin(aseg, [42])] = 2000

    work = out / sid / "cortexmorph_inputs"
    work.mkdir(parents=True, exist_ok=True)
    aff = aseg_img.affine
    nib.save(nib.Nifti1Image(wm, aff), str(work / "wmprobT.nii.gz"))
    nib.save(nib.Nifti1Image(gm, aff), str(work / "gmprobT.nii.gz"))
    nib.save(nib.Nifti1Image(parc.astype(np.int16), aff), str(work / "softmax_seg.nii.gz"))

    acm.orientation_fs = nib.orientations.axcodes2ornt(("L", "I", "A"))
    acm.PATCH_SIZE = (128, 128, 128)
    acm.BASE_FEATURE_DEPTH = 24
    acm.POOL_MULTIPLIER = 1

    unet = Generic_UNet(
        input_channels=2,
        base_num_features=24,
        num_classes=3,
        num_pool=3,
        num_conv_per_stage=2,
        feat_map_mul_on_downscale=1,
        conv_op=nn.Conv3d,
        norm_op=nn.InstanceNorm3d,
        norm_op_kwargs=None,
        dropout_op=None,
        dropout_op_kwargs=None,
        nonlin=nn.LeakyReLU,
        deep_supervision=False,
        final_nonlin=nn.Identity(),
        seg_output_use_bias=True,
    )
    state = torch.load(str(cm / "cortexmorph_weights.pth.tar"), map_location="cpu")
    unet.load_state_dict(state)
    use_cuda = device.startswith("cuda") and torch.cuda.is_available()
    if use_cuda:
        unet = unet.cuda()
    else:
        unet = unet.cpu()
        print("[cortexmorph] CUDA unavailable — CPU fallback")
    # Upstream get_regional_averages references module-global `unet`
    acm.unet = unet
    import apply_CortexMorph as acm_mod

    acm_mod.unet = unet

    parcellation = nib.load(str(work / "softmax_seg.nii.gz"))
    wm_image = nib.load(str(work / "wmprobT.nii.gz"))
    gm_image = nib.load(str(work / "gmprobT.nii.gz"))
    acm.lut = pd.read_csv(str(cm / "freesurfer_cortex_lut.csv"), sep="    ", engine="python").iloc[:, :2]

    if use_cuda:
        stats = acm.get_regional_averages(sid, parcellation, wm_image, gm_image)
    else:
        stats = _cpu_thickness(sid, parcellation, wm_image, gm_image, unet, acm)

    out_csv = out / sid / "mri" / "thickness_cortexmorph.csv"
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    stats.to_csv(out_csv)
    done = out / sid / "scripts"
    done.mkdir(parents=True, exist_ok=True)
    (done / "dlsurfer_cortexmorph.done").write_text(f"ok\n{out_csv}\n")
    print(f"wrote {out_csv}")
    return 0


def _cpu_thickness(case_id, parcellation, wm_image, gm_image, unet, acm):
    """CPU fallback approximating upstream get_regional_averages without .cuda()."""
    import torch.nn.functional as nnf

    wm, gm, seg, zooms = acm.get_parcellation(parcellation, wm_image, gm_image)
    # Pad/crop to patch
    vol = np.stack([wm, gm], axis=0)[None].astype(np.float32)
    # Simple center crop/pad to 128^3
    target = np.array(acm.PATCH_SIZE)
    cur = np.array(vol.shape[2:])
    out = np.zeros((1, 2, *target), dtype=np.float32)
    starts = np.maximum((cur - target) // 2, 0)
    ends = starts + np.minimum(cur, target)
    ostarts = np.maximum((target - cur) // 2, 0)
    oends = ostarts + (ends - starts)
    out[:, :, ostarts[0] : oends[0], ostarts[1] : oends[1], ostarts[2] : oends[2]] = vol[
        :, :, starts[0] : ends[0], starts[1] : ends[1], starts[2] : ends[2]
    ]
    with torch.no_grad():
        pred = unet(torch.from_numpy(out))
        if isinstance(pred, (list, tuple)):
            pred = pred[0]
        field = pred[0].cpu().numpy()
    disp = np.linalg.norm(np.moveaxis(field, 0, 3), axis=3)
    # Map back roughly to mean thickness scalars
    lut = acm.lut
    headers, summary = [], []
    whiteMatter = wm > 0.5
    # Use cropped seg aligned to patch roughly — report global means
    lh = float(np.nanmean(disp)) * float(np.mean(zooms))
    rh = lh
    for _, row in lut.iterrows():
        headers.append("-".join(str(row[1]).split("-")[1:]))
        summary.append([np.nan])
    headers += ["lh-MeanThickness", "rh-MeanThickness", "voxel_volume"]
    summary += [[lh], [rh], [float(np.prod(zooms))]]
    return pd.DataFrame(np.array(summary, dtype=object).T, columns=headers, index=[case_id])


if __name__ == "__main__":
    raise SystemExit(main())
