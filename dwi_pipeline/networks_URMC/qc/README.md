# DWI image-quality tables

Each `*_desc-ImageQC_dwi.csv` is copied unchanged from QSIPrep. It contains one
row of acquisition and preprocessing quality measurements, including motion
(mean/max framewise displacement), bad-slice counts, neighboring-volume
correlation, contrast-to-noise estimates, and image dimensions. These fields
are quality-control covariates and exclusion aids; they are not connectivity
measurements.
