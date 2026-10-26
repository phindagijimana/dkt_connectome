# Output layout (FreeSurfer-shaped contract)

All DLSurfer profiles write under a **FreeSurfer-looking SUBJECTS_DIR**.
SSOT: `dlsurfer/outputs_registry.yaml`. Inspect / validate:

```bash
dlsurfer contract --list
dlsurfer contract --sd $SD --sid $SID --profile core
dlsurfer contract --sd $SD --sid $SID --ensure-tree
```

## Tree

```text
$SD/$SID/
  mri/                 # volumes (aseg*, aparc*, DL structure under mri/<tool>/)
  surf/                # ?h.white / ?h.pial / ?h.sphere.reg (canonical)
  surf/dlsurfer/       # non-promoted DL meshes (cortexode, pialnn, …)
  label/               # ?h.aparc*.annot, schaefer, …
  stats/               # aseg.stats / thickness CSVs when produced
  scripts/             # logs, dlsurfer_metrics.tsv, dlsurfer_*.done
  tmp/  touch/         # staging / FS touch markers

  dwi/tractseg/        # multimodal (not stuffed into mri/)
  pet/dl_quant/
  fmri/deepprep/
  qc/brainqcnet/

  hippunfold/          # third-party app trees (documented)
  ibeat/
  dhcp/
```

## Core morphometry (`core` / `core-lesion`)

```text
  mri/orig.mgz
  mri/aparc.DKTatlas+aseg.deep.mgz
  mri/aseg.auto_noCCseg.mgz
  mri/inpainted.lit.nii.gz     # core-lesion only
  surf/lh.white  rh.white  lh.pial  rh.pial
  stats/
  scripts/recon-surf.done      # classical FastSurfer
  scripts/dlsurfer_metrics.tsv
```

## DL surfaces (`core-dl-surf`, `surf-dl-*`, `sphere-sugar`)

Meshes are installed into canonical `surf/` names via `dlsurfer-install-surfaces`
(`fs_surf_contract`). Marker: `scripts/dlsurfer_surf_dl.done`.
Backup CSR tools write under `surf/dlsurfer/<backend>/` until promoted.

## Structure / nuclei / lesion

| Profile | Path |
|---------|------|
| `structure-hippunfold` | `hippunfold/` |
| `structure-sclimbic` | `mri/sclimbic.mgz` |
| `structure-brainstem-mars` | `mri/brainstem_mars/` |
| `nuclei-thalamic-dti-cnn` | `mri/thalamic_nuclei_dti_cnn/` |
| `seg-wmh-synthseg` | `mri/wmh_synthseg/` |
| … | see `dlsurfer contract --list` |

## Policy

- Do **not** invent empty classical files to look like recon-all.
- Soft `scripts/recon-surf.done` from DL surface install ≠ classical recon-surf.
- Isolation: [reference/ISOLATION.md](../reference/ISOLATION.md).
