# FreeSurfer / FastSurfer DL methods (sources + how to run)

Concise literature + run notes for the FS/FastSurfer DL modules wired in
DLSurfer **v0.2.2**. Machine-readable mirrors: `engines.yaml` · `dlsurfer cite --profile …`
· `dlsurfer engines --id …`.

Dry-run first (`-q`); add `--execute` when ready. All paths write under `$SD/$SID`.

---

## SynthSeg 2.0 (`--robust` + QC)

| | |
|--|--|
| **Engine / profile / tool** | `synthseg_robust` · `seg-synthseg-robust` · `dlsurfer tool synthseg-robust` |
| **Upstream CLI** | `mri_synthseg` (FreeSurfer) |
| **Source** | FreeSurfer SynthSeg wiki · Billot domain-randomized U-Net |
| **Literature** | Billot B, et al. SynthSeg. *Medical Image Analysis* (SynthSeg 2.0 adds `--robust` / `--qc`). Wiki: https://surfer.nmr.mgh.harvard.edu/fswiki/SynthSeg |
| **When** | Odd contrast/resolution **and** you want automated Dice QC + volumes CSV |

```bash
dlsurfer tool synthseg-robust --t1 T1.nii.gz --sd "$SD" --sid "$SID" -q
dlsurfer tool synthseg-robust --t1 T1.nii.gz --sd "$SD" --sid "$SID" --execute
# → mri_synthseg --parc --robust --qc …/qc.csv --vol …/volumes.csv
```

Prefer `dlsurfer tool synthseg` when QC CSV is unnecessary.

---

## SuperSynth

| | |
|--|--|
| **Engine / profile / tool** | `super_synth` · `seg-super-synth` · `dlsurfer tool super-synth` |
| **Upstream CLI** | `mri_super_synth` (FS8+ / dev build + model download) |
| **Source** | FreeSurfer wiki SuperSynth (Iglesias / Billot SynthSeg+SynthSR lineage) |
| **Literature** | Wiki: https://surfer.nmr.mgh.harvard.edu/fswiki/SuperSynth · SynthSeg / SynthSR papers (Billot) for the underlying multi-task Synth* training |
| **When** | Multi-task seg + WMH + MNI reg + contrast synth + QC; low-field / ex vivo / hemi |

```bash
export SUPERSYNTH_MODE=invivo   # or exvivo|cerebrum|left-hemi|right-hemi
dlsurfer tool super-synth --t1 T1.nii.gz --sd "$SD" --sid "$SID" -q
dlsurfer tool super-synth --t1 T1.nii.gz --sd "$SD" --sid "$SID" --execute
# → mri_super_synth --i T1 --o $SD/$SID/mri/super_synth --mode $SUPERSYNTH_MODE
```

`dlsurfer doctor` reports whether `mri_super_synth` is on `PATH`.

---

## EasyAtlas

| | |
|--|--|
| **Engine / profile / tool** | `easyatlas` · `atlas-easyatlas` · `dlsurfer tool easyatlas` |
| **Upstream CLI** | `mri_easyatlas` (FS8+ / dev; builds on EasyReg) |
| **Source** | FreeSurfer EasyReg / EasyAtlas wiki |
| **Literature** | Iglesias JE, et al. EasyReg. *Scientific Reports* 2023. doi:10.1038/s41598-023-33781-0 · https://surfer.nmr.mgh.harvard.edu/fswiki/EasyReg |
| **When** | **Group** atlas from a directory of scans (not a single T1) |

```bash
export EASYATLAS_INPUT_DIR=/path/to/scan_dir
# optional: export EASYATLAS_RELIABILITY=1   # → --use_reliability_maps
dlsurfer tool easyatlas --t1 T1.nii.gz --sd "$SD" --sid "$SID" -q   # T1 unused; dir is EASYATLAS_INPUT_DIR
dlsurfer tool easyatlas --t1 T1.nii.gz --sd "$SD" --sid "$SID" --execute
# → mri_easyatlas --i $EASYATLAS_INPUT_DIR --o $SD/$SID/mri/easyatlas
```

Pairwise reg only: `dlsurfer tool easyreg` (`mri_easyreg`).

---

## NextBrain histo atlas (FireANTs)

| | |
|--|--|
| **Engine / profile / tool** | `histo_atlas` · `structure-histo-atlas` · `dlsurfer tool histo-atlas` |
| **Upstream CLI** | `mri_histo_atlas_segment_fireants` (FS dev + atlas download) |
| **Source** | FreeSurfer HistoAtlasSegmentation / NextBrain |
| **Literature** | Casamitjana A, et al. NextBrain probabilistic histological atlas. *Nature* 2025. doi:10.1038/s41586-025-09708-2 · Puonti O, et al. Fast segmentation with the NextBrain histological atlas. *Imaging Neuroscience* 2026. doi:10.1162/imag.a.1244 · Wiki: https://surfer.nmr.mgh.harvard.edu/fswiki/HistoAtlasSegmentation |
| **When** | Fine-grained (~300 ROI/hemi) histology-informed labels; in/ex vivo |

```bash
export HISTO_ATLAS_SIDE=left          # or right (run hemi sequentially to reuse SuperSynth preprocess)
export HISTO_ATLAS_MODE=invivo        # or exvivo|cerebrum|hemi
dlsurfer tool histo-atlas --t1 T1.nii.gz --sd "$SD" --sid "$SID" -q
dlsurfer tool histo-atlas --t1 T1.nii.gz --sd "$SD" --sid "$SID" --execute
# → mri_histo_atlas_segment_fireants --i T1 --o …/histo_atlas --side left --mode invivo
```

Needs latest FS with the CLI + NextBrain atlas assets (see wiki).

---

## HypVINN with T2

| | |
|--|--|
| **Engine / profile / tool** | `hypvinn_t2` · `structure-hypvinn-t2` · `dlsurfer tool hypvinn-t2` |
| **Upstream CLI** | FastSurfer `run_fastsurfer.sh … --t2 <T2w>` (hypothal module) |
| **Source** | Deep-MI FastSurfer HypVINN |
| **Literature** | Estrada S, et al. FastSurfer-HypVINN. *Imaging Neuroscience* 2023. · FastSurfer HypVINN module docs (`--t2`) |
| **When** | Co-registered T2 available; improves hypothalamic labeling vs T1-only |

```bash
# Dedicated HypVINN+T2 specialty
dlsurfer tool hypvinn-t2 --t1 T1.nii.gz --t2 T2.nii.gz --sd "$SD" --sid "$SID" -q
dlsurfer tool hypvinn-t2 --t1 T1.nii.gz --t2 T2.nii.gz --sd "$SD" --sid "$SID" --execute

# Or fold T2 into full FastSurfer core / recon-all
dlsurfer recon-all -i T1.nii.gz -sd "$SD" -s "$SID" --t2 T2.nii.gz -q
# env alternative: export HYPVINN_T2=/path/T2.nii.gz   # or DLSURFER_T2
```

XOR with ScLimbic for overlapping hypothalamus (`structure-sclimbic`).

---

## FS8 embedded DL helpers

| | |
|--|--|
| **Engine / profile / tool** | `fs8_dl_helpers` · `fs8-dl-modules` · `dlsurfer tool fs8-dl` |
| **Upstream CLI** | No separate binaries — inside FreeSurfer **8** `recon-all` |
| **Source** | FreeSurfer 8 release notes (sinus / MCA-dura pial guidance, EC WM DL, Synth* touches) |
| **Literature** | FreeSurfer 8 release notes · Fischl B. FreeSurfer. *NeuroImage* 2012;62:774–781 · Synth* (Billot) where FS8 embeds Synth modules |
| **When** | Inventory / exposure of FS8-internal DL; public DL morphometry default remains FastSurfer `core` |

```bash
dlsurfer tool fs8-dl --t1 T1.nii.gz --sd "$SD" --sid "$SID" -q
# step 1 [info]: lists embedded helpers
# step 2 [run]:  recon-all -s SID -sd SD -i T1 -all
dlsurfer tool fs8-dl --t1 T1.nii.gz --sd "$SD" --sid "$SID" --execute
```

Prefer `dlsurfer recon-all` (FastSurferVINN) for the public DL morphometry path.

---

## Cite helpers

```bash
dlsurfer cite --profile seg-super-synth
dlsurfer cite --profile structure-histo-atlas
dlsurfer engines --id super_synth
dlsurfer engines --id histo_atlas
```
