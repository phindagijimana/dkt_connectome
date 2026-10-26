# Gaps remaining **without** a credible alternative

These COMPARE gaps have **no** best alternative implemented (and often none that belong in DLSurfer).  
Everything else from `COMPARE_FS_FASTSURFER.md` now has a wired best alternative (profile, flag, or engine).

Run: `dlsurfer gaps-remaining`

| Gap | Why no alternative in DLSurfer | What to do instead |
|-----|--------------------------------|--------------------|
| **Dedicated DLSurfer meta-container (SIF/Docker)** | Packaging/ops only — not a morphometry method. No separate science tool substitutes for “our” image. | Use pinned FastSurfer image + host FS; scaffold `containers/dlsurfer.def` |
| **Manual edit loops (`-autorecon2-*`)** | Interactive QC by design; automation would fight FreeSurfer’s edit model | FreeView + targeted `recon-all -autorecon2-*` outside DLSurfer |
| **Full QC GUI (FreeView workflows)** | GUI is FreeSurfer’s product; DLSurfer is CLI orchestration | Open SUBJECTS_DIR in FreeView |
| **TRACULA / PET / fMRI helper streams** | Explicitly out of scope (diffusion/PET/fMRI ≠ T1 morphometry orchestrator) | Use FreeSurfer / modality-specific pipelines |
| **Bit-identical `recon-all` reproducibility claim** | Non-claim: FastSurfer/DLSurfer do not promise bit-identity with classical recon-all | Prefer FS8 profile if you need classical FS tree semantics |
| **True Infant FreeSurfer neonate stream** | Only partially covered: `fs-clinical` = clinical/odd-contrast, **not** Infant FS | Install [Infant FreeSurfer](https://surfer.nmr.mgh.harvard.edu/fswiki/infantFS) separately (documented runner-up under `recon_all_clinical`) |
| **Native LIT + optimal GPU/CPU seg↔surf split** | Upstream FastSurfer constraint (`--lesion_mask` blocks `--seg_only`/`--surf_only`) — not solvable by another engine | Prefer profile `core-lesion` (standalone neuroLIT) |

## Explicitly *not* “missing alternatives”

These looked like gaps but now have a **chosen best alternative** wired:

| Former gap | Best alternative | How |
|------------|------------------|-----|
| DK / `--fsaparc` | FastSurfer `--fsaparc` | `--atlas dk` or profile `core-dk` |
| Destrieux | FS `-a2009s` | profile `atlas-destrieux` |
| Schaefer / MMP-style | `mri_surf2surf` annot project | profile `atlas-schaefer` (MMP same pattern) |
| Longitudinal | FS `-base` / `-long` | profile `fs-long` |
| HA subfields | `segmentHA_T1.sh` | profile `subfields-ha` (+ HippUnfold/Hippodeep as runners-up) |
| Brainstem / thalamic | `segmentBS` + `segmentThalamicNuclei` | profile `nuclei-bs-thal` |
| Clinical / odd contrast | `recon-all-clinical` | profile `fs-clinical` |
| Module toggles | FastSurfer `--no_*` | `--no-cc` / `--no-cereb` / `--no-hypothal` |
| HPC `srun` / `brun` | Upstream wrappers | `--hpc srun\|brun` |
| High-res VINN | FastSurfer `--vox_size` | `--vox-size <mm>` |
| DL surfaces / fast thickness | TopoFit / V2C-Flow / SUGAR / DL-CTE | existing Phase 3 experimental profiles |

See also: [`COMPARE_FS_FASTSURFER.md`](COMPARE_FS_FASTSURFER.md) · [`ALTERNATIVES.md`](ALTERNATIVES.md)
