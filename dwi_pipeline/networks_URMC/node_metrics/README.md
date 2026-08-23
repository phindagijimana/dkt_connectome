# DKT node metrics

These tables are copied from Step 5 of the DKT connectome pipeline. The
underlying graph is the symmetric, zero-diagonal, count-weighted DKT-78
connectome generated from probabilistic iFOD2 tractography.

## Strength

`*_measure-strength_nodes.csv` has one row per DKT node (78 rows). Node strength
is the sum of every edge touching node *i*:

`strength_i = sum(W_ij for j != i)`

Because the exported connectome is count-weighted, strength is a sum of
streamline counts. It is not an anatomical axon count and depends on the
tractography and seeding configuration.

**Why it is calculated:** strength reduces a full row of the connectome to one
regional summary, making it easier to rank regions, compare homologous nodes,
and test whether a region has relatively reduced or increased total structural
connectivity.

## Strength asymmetry

`*_measure-strengthAI_nodes.csv` has one row per left/right homologous pair
(39 rows). `side_ai` is:

`(L_strength - R_strength) / (L_strength + R_strength)`

Positive values mean greater left strength, negative values mean greater right
strength, and zero is symmetric. `log_ai` is `ln(L_strength / R_strength)`.
These are raw asymmetry measures, not normative z-scores. Bilateral injury can
leave the asymmetry near zero.

**Why it is calculated:** paired asymmetry controls partly for global scaling
and highlights lateralized connectivity differences that may accompany a
focal injury. It must be interpreted with the bilateral-injury caveat above.

## Volume

`*_measure-volume_nodes.csv` has one row per DKT node (78 rows).
`volume_mm3` is the number of voxels assigned to the node in `nodes.mif`
multiplied by voxel volume. The labels have been resampled to the DWI grid, so
this is the connectome-node volume used by the pipeline, not a native-space
FreeSurfer morphometry measurement or an intracranial-volume-normalized value.

**Why it is calculated:** node size helps interpret connectivity because larger
regions can contain more tissue and receive more streamline endpoints. It also
provides an anatomical measurement against which strength differences can be
compared.

## Volume asymmetry

`*_measure-volumeAI_nodes.csv` has one row per left/right homologous pair
(39 rows). `side_ai` is:

`(L_volume_mm3 - R_volume_mm3) / (L_volume_mm3 + R_volume_mm3)`

Positive values indicate a larger left node and negative values a larger right
node. `log_ai` is `ln(L_volume_mm3 / R_volume_mm3)`.

**Why it is calculated:** volume asymmetry indicates whether a left/right
connectivity difference may be accompanied by regional size asymmetry. Comparing
strength AI with volume AI helps distinguish a connectivity imbalance from a
purely morphological or parcellation-size effect.

Use `atlas-DKT78_nodes.tsv` at the dataset root for node order and labels.
