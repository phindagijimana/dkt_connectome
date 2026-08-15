# Theory deep dive

Extended scientific notes for developers and methods-heavy publications. The user-facing summary lives in [Methods](../methods/index.md).

The full developer reference (~800 lines) is maintained in the repository:

**[pipeline_science.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/pipeline_science.md)**

---

## Topics covered in pipeline_science.md

| Section | Content |
|---------|---------|
| End-to-end data flow | Coordinate spaces, inpaint routing |
| Lesion inpainting | DDPM, VINN, QC math |
| Biology | GM / WM / CSF / 5TT roles |
| Physics | DWI signal, anisotropy, single-shell |
| Mathematics | CSD, transforms, graph metrics |
| Geometry | Surfaces, conformed vs native grids |
| 5TT / HSVS / ACT | Tissue classification for tractography |
| CSD / SS3T | Response functions, spec tokens |
| Tractography / SIFT2 | Streamline integration, weights |
| FreeSurfer outputs | Files consumed per step |
| Connectome warping | Three-stage alignment, DKT vs DK pitfalls |
| Node strength | ENIGMA report, atlas auto-detection |
| Design choices | Alternatives and trade-offs |
| References | Extended bibliography |

---

## Disconnectome specification

Full Step 4.5 implementation spec (Options A/B/C, provenance, QC):

**[Inpainting/disconnection.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/Inpainting/disconnection.md)**

User-facing summary: [Methods § Step 4.5](../methods/step4_5_disconnectome.md) · [Disconnectome](../disconnectome.md).

---

## Container implementation notes

| Step | README |
|------|--------|
| 1.5 neuroLIT | [containers/lit/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/lit/README.md) |
| 4 Connectome | [containers/connectome/README.md](https://github.com/phindagijimana/dkt_connectome/blob/main/dwi_pipeline/containers/connectome/README.md) |

---

## See also

- [Methods](../methods/index.md)
- [References by step](../references.md)
- [Schema reference](../schema_reference.md)
